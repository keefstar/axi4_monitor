`timescale 1ns/1ps
import a4lite_pkg::*;
module tb_rd_queue;

/* clock and reset */
logic clk, rst_n;
initial clk = 1'b0;
always #5 clk = ~clk;
int unsigned cyc;
always @ (posedge clk) cyc <= cyc + 1;

/* knobs */
localparam int unsigned TB_DEPTH = 4; /* how many outstanding transactions to hold */
localparam int unsigned TB_TW = 8; /* timer width */
localparam logic [TB_TW-1:0] TB_TIMEOUT = TB_TW'(20);
localparam logic [31:0] TAG = 32'hA5A5_A5A5;

/* interfaces */
axi4l_if up(.clk(clk), .aresetn(rst_n)); /* TB manager <-> guard.s */
axi4l_if dn(.clk(clk), .aresetn(rst_n)); /* guard.m <-> TB stub subordinate */

logic epoch_clr, flush;
logic timeout_pulse, busy, upstream_empty;

rd_queue #(
    .DEPTH(TB_DEPTH), .TIMER_WIDTH(TB_TW), .TIMEOUT_CYCLES(TB_TIMEOUT) ) dut (
    .clk(clk), .rst_n(rst_n),
    .m(dn), .s(up),
    .timeout_pulse(timeout_pulse), .busy(busy), .upstream_empty(upstream_empty),
    .epoch_clr(epoch_clr), .flush(flush) );

/* acccounting for test passes/fails */
int unsigned n_pass, n_fail;
task automatic check (input bit cond, input string msg);
    if (cond) n_pass++;
    else begin n_fail++; $error("[%0t] FAIL: %s", $time, msg); end
endtask

function automatic logic [31:0] pattern(input logic [31:0] addr);
    return addr ^ TAG;
endfunction

 /* Upstream manager BFM -- TB plays manager on `up` (guard.s)
 *   up_push_ar()   queues an address; a free-running driver presents AR
 *                  beats one at a time and blocks on ARREADY like a real
 *                  manager would.
 *   wait_for_r()   blocks the calling test until one R beat has been
 *                  accepted, returning it in program order.
 */

logic [31:0] ar_q[$];
r_beat_t     rx_q[$];

task automatic up_push_ar(input logic [31:0] addr);
    ar_q.push_back(addr);
endtask

task automatic wait_for_r(output r_beat_t r);
    while (rx_q.size() == 0) @ (posedge clk);
    r = rx_q.pop_front();
endtask

task automatic up_set_rready(input bit v);
    @ (negedge clk);
    up.rready = v;
endtask

/* AR driver: one bus cycle to present a beat, one more to notice ARREADY.
   That under-drives peak throughput but keeps the loop trivial to read;
   this TB is about correctness, not saturating the channel. */
initial begin
    up.arvalid = 1'b0;
    up.ar = '0;
    forever begin
        @ (negedge clk);
        if (!up.arvalid && ar_q.size() != 0) begin
            up.ar.addr = ar_q.pop_front();
            up.ar.prot = '0;
            up.arvalid = 1'b1;
        end else if (up.arvalid && up.arready) begin
            if (ar_q.size() != 0) up.ar.addr = ar_q.pop_front();
            else up.arvalid = 1'b0;
        end
    end
end

/* R sink: accepts whenever up.rready is high (default) and records beats
   in arrival order for wait_for_r() to hand back to the test. */
initial begin
    up.rready = 1'b1;
    forever begin
        @ (posedge clk);
        if (up.rvalid && up.rready) rx_q.push_back(up.r);
    end
end

/**************************************************************************
 * Downstream subordinate stub -- TB plays subordinate on `dn` (guard.m)
 *   sub_set_ar_ready()   forces ARREADY low/high (unused by default tests)
 *   sub_set_resp_enable() 0 = accept AR but never answer -> forces a timeout
 **************************************************************************/
logic [31:0] sub_pending_q[$];
bit sub_ar_ready     = 1'b1;
bit sub_resp_enable  = 1'b1;

task automatic sub_set_ar_ready(input bit v);
    @ (negedge clk);
    sub_ar_ready = v;
endtask

task automatic sub_set_resp_enable(input bit v);
    @ (negedge clk);
    sub_resp_enable = v;
endtask

initial begin  //driver
    dn.arready = 1'b1;
    forever begin @(negedge clk); dn.arready = sub_ar_ready; end
end
initial begin  //sampler
    forever begin
        @(posedge clk);
        if (dn.arvalid && dn.arready) sub_pending_q.push_back(dn.ar.addr);
    end
end

initial begin
    dn.rvalid = 1'b0;
    forever begin
        @ (negedge clk);
        if (dn.rvalid && dn.rready) dn.rvalid = 1'b0; /* prior beat accepted */
        if (!dn.rvalid && sub_resp_enable && sub_pending_q.size() != 0) begin
            dn.r.data = pattern(sub_pending_q.pop_front());
            dn.r.resp = RESP_OKAY;
            dn.rvalid = 1'b1;
        end
    end
end

/**************************************************************************
 * Reset: also clears BFM queues/knobs so each directed test starts clean.
 **************************************************************************/
task automatic reset_dut();
    rst_n = 1'b0;
    epoch_clr = 1'b0; flush = 1'b0;
    ar_q.delete(); rx_q.delete(); sub_pending_q.delete();
    sub_ar_ready = 1'b1; sub_resp_enable = 1'b1;
    repeat (3) @ (posedge clk);
    rst_n = 1'b1;
    @ (posedge clk);
endtask

/**************************************************************************
 * Directed tests -- one narrative per named FSM behaviour.
 **************************************************************************/
task automatic test_reset();
    r_beat_t r;
    $display("[%0t] test_reset", $time);
    check(dut.rd_state == RD_IDLE, "reset: rd_state == RD_IDLE");
    check(dut.outst_cnt == '0,     "reset: outst_cnt == 0");
    check(dut.drain_cnt == '0,     "reset: drain_cnt == 0");
    check(upstream_empty == 1'b1,  "reset: upstream_empty asserted");
    check(busy == 1'b0,            "reset: busy deasserted");
endtask

task automatic test_passthrough();
    r_beat_t r;
    logic [31:0] addr;
    $display("[%0t] test_passthrough", $time);
    addr = 32'h0000_1000;
    up_push_ar(addr);
    wait_for_r(r);
    check(r.resp == RESP_OKAY,        "passthrough: RESP_OKAY");
    check(r.data == pattern(addr),    "passthrough: data matches subordinate");
    check(timeout_pulse == 1'b0,      "passthrough: no timeout fired");
    check(dut.rd_state == RD_IDLE,    "passthrough: back to RD_IDLE");
endtask

task automatic test_queue_full_backpressure();
    int unsigned i;
    $display("[%0t] test_queue_full_backpressure", $time);
    sub_set_resp_enable(1'b0); /* subordinate accepts AR but withholds R, so outst_cnt only grows */
    for (i = 0; i < TB_DEPTH; i++) up_push_ar(32'h0000_2000 + i);
    while (dut.outst_cnt != TB_DEPTH) @ (posedge clk);
    check(dut.full == 1'b1,     "full: outst_cnt reached DEPTH");
    up_push_ar(32'h0000_2000 + TB_DEPTH); /* one more than the queue can hold */
    repeat (5) @ (posedge clk);
    check(up.arready == 1'b0,        "full: ARREADY withheld while full");
    check(ar_q.size() != 0,          "full: extra AR still parked in the driver, never accepted");
endtask

task automatic test_timeout_and_ghost_drain();
    r_beat_t r;
    logic [31:0] addr;
    int unsigned guard;
    $display("[%0t] test_timeout_and_ghost_drain", $time);
    addr = 32'h0000_3000;
    sub_set_resp_enable(1'b0); /* subordinate accepts AR, then goes silent */
    up_push_ar(addr);

    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
        @ (posedge clk); guard++;
    end
    check(timeout_pulse == 1'b1, "timeout: pulse fired within TIMEOUT_CYCLES");

    wait_for_r(r);
    check(r.resp == RESP_SLVERR, "timeout: injected SLVERR delivered to manager");
    check(dut.drain_cnt == 1,    "timeout: ghost owed after injection accepted");

    sub_set_resp_enable(1'b1); /* subordinate finally answers the timed-out request */
    repeat (5) @ (posedge clk);
    check(dut.drain_cnt == 0,   "ghost: late real response silently absorbed");
    check(rx_q.size() == 0,     "ghost: no extra beat leaked to the manager");
    check(dut.rd_state == RD_IDLE, "ghost: FSM settled back to RD_IDLE");
endtask

task automatic test_inject_cascade_multi_outstanding();
    r_beat_t r0, r1;
    logic [31:0] a0, a1;
    int unsigned guard;
    $display("[%0t] test_inject_cascade_multi_outstanding", $time);
    a0 = 32'h0000_4000; a1 = 32'h0000_4004;
    sub_set_resp_enable(1'b0); /* both ARs accepted, neither ever answered */
    up_push_ar(a0);
    up_push_ar(a1);
    while (dut.outst_cnt != 2) @ (posedge clk);

    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
        @ (posedge clk); guard++;
    end
    wait_for_r(r0);
    check(r0.resp == RESP_SLVERR,    "cascade: first head injected SLVERR");
    check(dut.rd_state == RD_TRACKING, "cascade: second entry still owed, FSM stays TRACKING");

    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
        @ (posedge clk); guard++;
    end
    wait_for_r(r1);
    check(r1.resp == RESP_SLVERR, "cascade: second head also injected SLVERR");
    check(dut.rd_state == RD_IDLE, "cascade: FSM idle once both entries retired");
endtask

task automatic test_flush_forces_injection();
    r_beat_t r;
    logic [31:0] addr;
    $display("[%0t] test_flush_forces_injection", $time);
    addr = 32'h0000_5000;
    sub_set_resp_enable(1'b0);
    up_push_ar(addr);
    while (dut.outst_cnt != 1) @ (posedge clk);

    @ (negedge clk); flush = 1'b1;
    repeat (2) @ (posedge clk);
    check(dut.rd_state == RD_INJECTING, "flush: forces injection well before TIMEOUT_CYCLES");
    check(timeout_pulse == 1'b0,        "flush: injection did not come from the timer");

    wait_for_r(r);
    check(r.resp == RESP_SLVERR, "flush: SLVERR delivered");
    @ (negedge clk); flush = 1'b0;
endtask

task automatic test_epoch_clr_clears_counts();
    logic [31:0] addr;
    $display("[%0t] test_epoch_clr_clears_counts", $time);
    addr = 32'h0000_6000;
    sub_set_resp_enable(1'b0);
    up_push_ar(addr);
    while (dut.outst_cnt != 1) @ (posedge clk);
    check(busy == 1'b1, "epoch_clr: guard busy before clear");

    @ (negedge clk); epoch_clr = 1'b1;
    @ (posedge clk);
    @ (negedge clk); epoch_clr = 1'b0;

    check(dut.outst_cnt == '0,     "epoch_clr: outst_cnt wiped");
    check(dut.drain_cnt == '0,     "epoch_clr: drain_cnt wiped");
    check(dut.rd_state == RD_IDLE, "epoch_clr: rd_state forced back to RD_IDLE");
    check(upstream_empty == 1'b1,  "epoch_clr: upstream_empty asserted");
endtask

initial begin
    n_pass = 0; n_fail = 0;

    reset_dut(); test_reset();
    reset_dut(); test_passthrough();
    reset_dut(); test_queue_full_backpressure();
    reset_dut(); test_timeout_and_ghost_drain();
    reset_dut(); test_inject_cascade_multi_outstanding();
    reset_dut(); test_flush_forces_injection();
    reset_dut(); test_epoch_clr_clears_counts();

    $display("==== rd_queue directed TB: %0d passed, %0d failed ====", n_pass, n_fail);
    if (n_fail != 0) $fatal(1, "rd_queue directed TB FAILED");
    $finish;
end

endmodule : tb_rd_queue
