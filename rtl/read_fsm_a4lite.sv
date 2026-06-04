

module read_fsm_a4lite #(
    parameter TIMEOUT_COUNTER = 200,
    localparam TIMER_WIDTH = $clog2(TIMEOUT_COUNTER)
)(
    input logic clk,
    input logic reset,
    input logic ARVALID, ARREADY, RVALID, RREADY, 
    input logic rcvy_ack,
    output logic violation_notif,
    output logic inject_en, /* notify top level to substitute SLVERR */
    output logic regulate_en /* notify top-level to pull ARREADY low*/
);

typedef enum logic [2:0] {
    IDLE, /* no transaction in flight; timer is zero */
    R_ACTIVE, /* ar_handshake is complete */
    R_VIOLATION, /* timer hit threshold */
    R_INJECT, 
    R_RECOVERY
} state_t;

logic ar_handshake = (ARVALID && ARREADY);
logic r_handshake = (RVALID && RREADY);
logic [TIMER_WIDTH - 1: 0] timer;
state_t state, next_state;

/* Combinational logic block */
always_comb begin
    next_state = state;
    violation_notif = 1'b0;
    inject_en = 1'b0;
    regulate_en = 1'b0;
    case (state)
    IDLE: begin
        next_state = (ar_handshake) ? R_ACTIVE : IDLE;
    end
    R_ACTIVE: begin
    if (timer >= TIMEOUT_COUNTER) next_state = R_VIOLATION;
    else next_state = (r_handshake) ? IDLE : R_ACTIVE;
    end
    R_VIOLATION: begin
        next_state = R_INJECT;
        regulate_en = 1'b1;
        violation_notif = 1'b1; /* One pulse is enough */ 
    end
    R_INJECT: begin
        inject_en = 1'b1;
        regulate_en = 1'b1;
        next_state = (r_handshake) ? R_RECOVERY : R_INJECT;
    end
    R_RECOVERY: begin
        regulate_en = 1'b1;
        next_state = (rcvy_ack) ? IDLE : R_RECOVERY;
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
        if (state == R_ACTIVE) timer++; 
        else timer <= '0;
    end
end

endmodule