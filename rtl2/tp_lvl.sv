import a4lite_pkg::*;

module tp_lvl (
    input  logic clk, rst_n,
    /* the two links -- guards sit between them */
    axi4l_if.a4l_sub s,       
    axi4l_if.a4l_mgr m,       
    /* software-facing */
    input  logic [NUM_FAULT_SOURCES-1:0] enable_reg,
    input  logic [NUM_FAULT_SOURCES-1:0] clear_reg,  // W1C from software
    output logic irq,
    output logic [NUM_FAULT_SOURCES-1:0] status_reg,
    output logic guard_busy
);

guard_mode_e mode, mode_nxt;

/* signals to the guards */
logic flush, epoch_clr;
assign flush = (mode != GUARD_NORMAL);
/* signals from the two guards */
logic rd_timeout_pulse, rd_busy, rd_upstream_empty;
logic wr_timeout_pulse, wr_w_fault_pulse, wr_busy, wr_upstream_empty;

/* read transaction*/
rd_queue u_rd (
    .clk(clk), .rst_n(rst_n), .m(m), .s(s),
    .timeout_pulse(rd_timeout_pulse),
    .busy(rd_busy), .upstream_empty(rd_upstream_empty),
    .epoch_clr(epoch_clr), .flush(flush)
);

/* write transaction */
wr_queue u_wr (
    .clk(clk), .rst_n(rst_n), .m(m), .s(s),
    .timeout_pulse(wr_timeout_pulse),
    .w_fault_pulse(wr_w_fault_pulse),
    .busy(wr_busy), .upstream_empty(wr_upstream_empty),
    .epoch_clr(epoch_clr), .flush(flush)
);

/* interrupt controller plumbing */
logic [NUM_FAULT_SOURCES-1:0] violation_notif, rcvy_ack;
logic all_upstream_empty;
assign all_upstream_empty = rd_upstream_empty && wr_upstream_empty;

assign violation_notif[READ_TIMEOUT]       = rd_timeout_pulse;
assign violation_notif[WRITE_DATA_TIMEOUT] = wr_w_fault_pulse;
assign violation_notif[WRITE_RESP_TIMEOUT] = wr_timeout_pulse;

assign epoch_clr = (mode == GUARD_RECOVERY) && (|rcvy_ack) && all_upstream_empty;

interrupt_ctrl u_irq (
    .clk(clk), .rst_n(rst_n),
    .violation_notif(violation_notif),
    .quiescent(all_upstream_empty),
    .enable_reg(enable_reg),
    .clear_reg(clear_reg),
    .status_reg(status_reg),
    .rcvy_ack(rcvy_ack),
    .irq(irq)
);

assign guard_busy = rd_busy || wr_busy;

always_comb begin
    mode_nxt = mode;
    unique case (mode)
        GUARD_NORMAL: mode_nxt = (|violation_notif) ? GUARD_CONTAINING : GUARD_NORMAL;
        GUARD_CONTAINING: mode_nxt = (all_upstream_empty) ? GUARD_RECOVERY : GUARD_CONTAINING;
        GUARD_RECOVERY: mode_nxt = (epoch_clr) ? GUARD_NORMAL : GUARD_RECOVERY;
        default: mode_nxt = GUARD_NORMAL;
    endcase
end

always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) mode <= GUARD_NORMAL;
    else mode <= mode_nxt;
end

endmodule: tp_lvl
