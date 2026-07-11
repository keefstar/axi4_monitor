/* LEVEL-TRIGGERED, SOFTWARE-CLEARED INTERRUPT MECHANISM
 *
 * CHANGED: import swapped from watchdog_pkg to firewall_pkg.
 * CHANGED: NUM_SOURCES parameter removed — width now comes directly from
 * firewall_pkg::NUM_FAULT_SOURCES (3 sources: READ_TIMEOUT,
 * WRITE_DATA_TIMEOUT, WRITE_RESP_TIMEOUT).  A local parameter that could
 * diverge from the package defeated the single-source-of-truth principle.
 * Logic is otherwise identical — the mechanism is fully generic over N bits.
 *
 * How it works:
 *   violation_notif  — one bit per fault source; pulsed by the scoreboard
 *                      when a slot transitions into a fault/inject state.
 *   status_reg       — sticky latch; records which faults have fired.
 *   enable_reg       — software mask; a 0 bit suppresses that fault's IRQ.
 *   pending          — status_reg & enable_reg; any set bit means the
 *                      processor should be interrupted.
 *   irq              — OR of pending; level-sensitive, stays high until
 *                      software clears the relevant status bit.
 *   clear_reg        — software writes 1 to clear a status bit (W1C).
 *   rcvy_ack         — registered copy of clear_reg; fans out to scoreboard
 *                      slots as force_free for the matching fault source.
 */
import firewall_pkg::*;

module interrupt_ctrl (
    input  logic clk, reset,
    input  logic [NUM_FAULT_SOURCES-1:0] violation_notif,
    input  logic [NUM_FAULT_SOURCES-1:0] enable_reg,
    input  logic [NUM_FAULT_SOURCES-1:0] clear_reg,
    output logic [NUM_FAULT_SOURCES-1:0] rcvy_ack,
    output logic irq
);

logic [NUM_FAULT_SOURCES-1:0] status_reg;
logic [NUM_FAULT_SOURCES-1:0] pending;

assign pending = status_reg & enable_reg;
assign irq     = |pending;

always_ff @(posedge clk) begin
    if (reset) begin
        status_reg <= '0;
        rcvy_ack   <= '0;
    end else begin
        /* Clear bits software acknowledged, then OR in any new faults
         * that fired this cycle — both can happen in the same cycle. */
        status_reg <= (status_reg & ~clear_reg) | violation_notif;
        rcvy_ack   <= clear_reg;
    end
end

endmodule
