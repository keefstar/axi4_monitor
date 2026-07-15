import a4lite:pkg::*;
module tb_rd_queue;

/* clock and reset */
logic clk, rst_n;
assign clk = 0;
always #5 clk = ~clk;
int unsigned cyc;
always @ (posedge clk) cyc <= cyc + 1;

/* interfaces */
axi4l_if up(); /* TB manager <-> guard.s */
axi4l_if dn(); /* guard.m <-> TB stub subordinate */

  logic epoch_clr, flush;
  logic timeout_pulse, busy, upstream_empty;
  rd_queue #(
    .DEPTH(TB_DEPTH), .TIMER_WIDTH(TB_TW), .TIMEOUT_CYCLES(TB_TIMEOUT)
  ) dut (
    .clk(clk), .rst_n(rst_n),
    .m(dn), .s(up),
    .timeout_pulse(timeout_pulse), .busy(busy), .upstream_empty(upstream_empty),
    .epoch_clr(epoch_clr), .flush(flush)
  );

  /* acccounting for test passes/fails */
  int unsigned n_pass, n_fail;
  task automatic check (input bit cond, input string msg);
    if (cond) n_pass +;
    else begin n_fail++; $error("[%0t] FAIL: %s", $time, msg); end
  endtask

  function automatic logic [31:0] pattern(input logic [31:0] addr);
    return addr ^ TAG;
  endfunction

/* subordinate */



endmodule : tb_rd_queue