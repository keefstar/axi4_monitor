import a4lite_pkg::*;

module tp_lvl_d4 (
    input  logic clk, rst_n,
    axi4l_if.a4l_sub s,
    axi4l_if.a4l_mgr m,
    input  logic [NUM_FAULT_SOURCES-1:0] enable_reg,
    input  logic [NUM_FAULT_SOURCES-1:0] clear_reg,
    output logic irq,
    output logic [NUM_FAULT_SOURCES-1:0] status_reg,
    output logic guard_busy
);

tp_lvl #(
    .DEPTH(4),
    .TIMER_WIDTH(16),
    .TIMEOUT_CYCLES(16'd256)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .s(s),
    .m(m),
    .enable_reg(enable_reg),
    .clear_reg(clear_reg),
    .irq(irq),
    .status_reg(status_reg),
    .guard_busy(guard_busy)
);

endmodule : tp_lvl_d4
