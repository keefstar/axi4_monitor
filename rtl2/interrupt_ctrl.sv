/* LEVEL-TRIGGERED, SOFTWARE-CLEARED INTERRUPT MECHANISM
 *
 * Author: Keefee Rahman
 *
 * Sits in tp_lvl. Collects fault reports from the two guards, latches
 * them so a one-cycle pulse isn't missed, applies a software mask, and
 * raises a level-sensitive irq that software clears by acknowledging.
 *
 * WHERE IT SITS IN THE INCIDENT TIMELINE:
 *   fault -> flush (drain) -> quiescent -> IRQ -> software resets the
 *   subordinate -> software writes clear_reg -> rcvy_ack -> epoch_clr.
 *
 * The guard has no authority to reset anything. This module is how the
 * hardware asks software for help, and how software answers.
 *
 * SIGNALS:
 *   violation_notif -- one bit per fault source, pulsed for a single cycle
 *                      by the guards:
 *                        [READ_TIMEOUT]       <- rd_queue.timeout_pulse
 *                        [WRITE_DATA_TIMEOUT] <- wr_queue.w_fault_pulse
 *                        [WRITE_RESP_TIMEOUT] <- wr_queue.timeout_pulse
 *   status_reg      -- sticky latch. The pulses above are one cycle wide;
 *                      software reads this register long afterward and
 *                      still learns WHICH fault fired.
 *   enable_reg      -- software mask. A 0 bit suppresses that source's irq
 *                      but the status bit still latches (visible on poll).
 *   quiescent       -- from tp_lvl: both guards report upstream_empty.
 *                      Gates the irq so software is only woken once every
 *                      upstream obligation has been discharged -- otherwise
 *                      software could reset the subordinate while the guard
 *                      is still draining SLVERRs through it.
 *   irq             -- level-sensitive. Stays high until software clears
 *                      the status bit(s). No edge to miss.
 *   clear_reg       -- write-1-to-clear from software. Acknowledging a
 *                      source means "I have reset the subordinate."
 *   rcvy_ack        -- registered copy of clear_reg, fed to tp_lvl, which
 *                      ANDs it with quiescence to produce epoch_clr.
 *
 * RESET: async, active-low (rst_n) -- matches rd_queue and wr_queue.
 * Mixing reset styles across a design infers different flop types and
 * fails reset-domain checks, so all three modules use the same one.
 */

import a4lite_pkg::*;

module interrupt_ctrl (
    input  logic clk,
    input  logic rst_n,

    /* from the guards (via tp_lvl) */
    input  logic [NUM_FAULT_SOURCES-1:0] violation_notif,
    input  logic                         quiescent,

    /* from software (CSR writes) */
    input  logic [NUM_FAULT_SOURCES-1:0] enable_reg,
    input  logic [NUM_FAULT_SOURCES-1:0] clear_reg,

    /* out */
    output logic [NUM_FAULT_SOURCES-1:0] status_reg,  /* readable by software */
    output logic [NUM_FAULT_SOURCES-1:0] rcvy_ack,
    output logic                         irq
);

    logic [NUM_FAULT_SOURCES-1:0] pending;

    /* A source is pending if it fired AND software wants to hear about it. */
    assign pending = status_reg & enable_reg;

    /* Level-sensitive, and gated on quiescence: do not wake software until
     * the guards have discharged every upstream obligation. Software's job
     * is to reset the subordinate -- doing that mid-drain would destroy the
     * subordinate while the guard is still relaying real responses through
     * it. Note status_reg still latches during containment; software polling
     * the register early will see the fault, it just won't be interrupted. */
    assign irq = (|pending) && quiescent;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_reg <= '0;
            rcvy_ack   <= '0;
        end else begin
            /* Clear what software acknowledged, then OR in anything that
             * fired this cycle. Both can happen at once -- a new fault
             * landing in the same cycle as an ack must NOT be lost, which
             * is why the OR comes after the mask. */
            status_reg <= (status_reg & ~clear_reg) | violation_notif;

            /* One-cycle registered ack, handed to tp_lvl. Registering it
             * (rather than passing clear_reg straight through) keeps the
             * software write off the epoch_clr combinational path. */
            rcvy_ack <= clear_reg;
        end
    end

endmodule : interrupt_ctrl