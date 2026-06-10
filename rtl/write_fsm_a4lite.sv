/** Author: Keefee Rahman
 * @brief AXI4-Lite write-channel finite-state machine.
 * Monitors an AXI4-Lite write transaction from the write-address
 * handshake through the write-response handshake. A timeout counter
 * may be used to detect stalled transactions.
 *
 * @param TIMEOUT_COUNTER Maximum number of cycles allowed before a timeout.
 * @input  clk      Rising-edge clock.
 * @input  reset    Reset signal. Document whether this is active-high or active-low.
 * @input  AWREADY  Write-address ready signal.
 * @input  AWVALID  Write-address valid signal.
 * @input  WREADY   Write-data ready signal.
 * @input  WVALID   Write-data valid signal.
 * @input  BREADY   Write-response ready signal.
 * @input  BVALID   Write-response valid signal.
 *
 * @output BRESP    Two-bit AXI4-Lite write-response code.
 */
import watchdog_pkg::*;
module write_fsm_a4lite #(
    parameter TIMEOUT_COUNTER = 200,
    localparam TIMER_WIDTH = $clog2(TIMEOUT_COUNTER)
)(
    input logic clk,
    input logic reset,
    input logic AWREADY, AWVALID, WREADY, WVALID, WLAST, BREADY, BVALID, /* keep WLAST despite redundancy */
    input logic [NUM_SOURCES - 1 : 0] rcvy_ack,
    output logic violation_notif,
    output logic inject_en, /* notify top level to substitute SLVERR */
    output logic regulate_en /* notify top-level to pull AWREADY low*/
);

typedef enum logic [2:0] { 
    IDLE, /* No transaction in flight; timer is zero */
    AW_RECEIVED, /* The AW handshake just completed (AWVALID + AW_READY) */
    W_ACTIVE, /* AW and W (WLAST && WVALID && WREADY) handshakes are complete; timer is counting */ 
    W_VIOLATION, /* timer hit threshold */ 
    W_INJECT, /* here actively drive BVALID high with SLVERR on the B channel */ 
    W_RECOVERY /* manager accepts SLVERR. transaction closed from manager's perspective */
 } state_t;

logic [TIMER_WIDTH - 1: 0] timer;
/* Define handshake registers */ 
logic aw_handshake;
assign aw_handshake = (AWREADY && AWVALID);
logic w_handshake;
assign w_handshake = (WREADY && WVALID && WLAST);
logic b_handshake;
assign b_handshake = (BREADY && BVALID);
 /* define state and next_state variables */
state_t state, next_state;

/* Combinational logic block to determine states */
always_comb begin
    next_state = state;
    violation_notif = 1'b0;
    inject_en = 1'b0;
    regulate_en = 1'b0;
    case (state) 
        IDLE: begin
        next_state = (aw_handshake) ? AW_RECEIVED : IDLE;
        end
        AW_RECEIVED: next_state = (w_handshake) ? W_ACTIVE : AW_RECEIVED;
        W_ACTIVE: begin
        if (timer >= TIMEOUT_COUNTER) next_state = W_VIOLATION;
        else next_state = (b_handshake) ? IDLE : W_ACTIVE;
        end
        W_VIOLATION: begin
            next_state = W_INJECT;
            regulate_en = 1'b1;
            violation_notif = 1'b1; /* One pulse is enough */ 
        end
        W_INJECT: begin
            inject_en = 1'b1;
            regulate_en = 1'b1;
            next_state = (b_handshake) ? W_RECOVERY : W_INJECT;
        end
        W_RECOVERY: begin
            regulate_en = 1'b1;
            next_state = (rcvy_ack[WRITE_FAULT]) ? IDLE : W_RECOVERY;
        end
        default: next_state = IDLE;
    endcase
end
/* Sequential Procedural Block */
always_ff @ (posedge clk) begin
    if (reset) begin
        state <= IDLE;
        timer <= '0;
    end
    else begin
        state <= next_state;
        if (state == W_ACTIVE) timer++; 
        else timer <= '0;
    end
end
/* During W_RECOVERY — manager got its B response. It's free now. It could immediately send a new write transaction. But your subordinate is still frozen and not reset yet. This is the dangerous window.*/
endmodule;

