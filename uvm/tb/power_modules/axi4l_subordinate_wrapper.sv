
/* Problem:
The switchable subordinate was connected to the guard through a SystemVerilog interface/modport, and Xcelium UPF could identify the interface members but could not use them as explicit isolation objects.
 A wrapper therefore exposes the AXI signals as conventional module ports at the power-domain boundary, allowing UPF isolation to operate on a conventional structural boundary.
*/
module axi4l_subordinate_wrapper (
  input logic clk,
  input logic rst_n,

  input logic awvalid,
  input a4lite_pkg::aw_beat_t aw,
  output logic awready,

  input logic wvalid,
  input a4lite_pkg::w_beat_t w,
  output logic wready,

  output logic bvalid,
  output a4lite_pkg::b_beat_t b,
  input logic bready,

  input logic arvalid,
  input a4lite_pkg::ar_beat_t ar,
  output logic arready,

  output logic rvalid,
  output a4lite_pkg::r_beat_t r,
  input logic rready
);

  axi4l_if int_if(.clk(clk), .aresetn(rst_n));

  assign int_if.awvalid = awvalid;
  assign int_if.aw = aw;
  assign awready = int_if.awready;

  assign int_if.wvalid = wvalid;
  assign int_if.w = w;
  assign wready = int_if.wready;

  assign bvalid = int_if.bvalid;
  assign b = int_if.b;
  assign int_if.bready = bready;

  assign int_if.arvalid = arvalid;
  assign int_if.ar = ar;
  assign arready = int_if.arready;

  assign rvalid = int_if.rvalid;
  assign r = int_if.r;
  assign int_if.rready = rready;

  axi4l_subordinate_model sub (
    .clk(clk),
    .rst_n(rst_n),
    .s(int_if)
  );

endmodule : axi4l_subordinate_wrapper