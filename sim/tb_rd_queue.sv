`timescale 1ns/1ps
import a4lite_pkg::*;
module tb_rd_queue;
  
  /* clock and reset */
  logic clk, rst_n;
  initial clk = 1'b0;
  always #5 clk = ~clk;
  int unsigned cyc;
  always @(posedge clk) cyc <= cyc + 1;
  
  /* knobs */
  localparam int unsigned TB_DEPTH = 4; /* how many outstanding transactions to hold */
  localparam int unsigned TB_TW = 8; /* timer width */
  localparam logic[TB_TW - 1:0] TB_TIMEOUT = TB_TW'(20);
  localparam logic[31:0] TAG = 32'hA5A5_A5A5;
  
  /* interfaces */
  axi4l_if up(.clk(clk), .aresetn(rst_n)); /* TB manager <-> guard.s */
  axi4l_if dn(.clk(clk), .aresetn(rst_n)); /* guard.m <-> TB stub subordinate */
  
  logic epoch_clr, flush;
  logic timeout_pulse, busy, upstream_empty;
  
  /* read queue instantiation */
  rd_queue#(
    .DEPTH(TB_DEPTH), .TIMER_WIDTH(TB_TW), .TIMEOUT_CYCLES(TB_TIMEOUT)) dut(
    .clk(clk), .rst_n(rst_n),
    .m(dn), .s(up),
    .timeout_pulse(timeout_pulse), .busy(busy), .upstream_empty(upstream_empty),
    .epoch_clr(epoch_clr), .flush(flush));
  
  /* acccounting for test passes/fails */
  int unsigned n_pass, n_fail;
  task automatic check(input bit cond, input string msg);
    assert (cond) n_pass++;
    else begin
      n_fail++;
      $error("[%0t] FAIL: %s", $time, msg);
    end
  endtask
  
  /* helper function to create fake (and predictable) read data */
  /* uses self-inverse property of XOR to produce predictable address-dependent data */
  function automatic logic[31:0] pattern(input logic[31:0] addr);
    return addr ^ TAG;
  endfunction
  
  /* system verilog queues */
  logic[ADDR_WIDTH - 1:0] ar_q[$]; /* store read addresses */
  r_beat_t rx_q[$]; /* queue to hold R beat (read-response) transfer on R channel */
  
  /* task to add a read address into the AW channel queue */
  task automatic up_push_ar(input logic[31:0] addr);
    ar_q.push_back(addr); /* add AR to (back of the) queue */
  endtask
  
  /* Waits until an accepted R-channel response is available, then removes
     and returns the oldest response captured by the upstream R monitor. */
  task automatic wait_for_r(output r_beat_t r);
    while (rx_q.size() == 0) @(posedge clk);
    r = rx_q.pop_front();
  endtask
  
  /* Sets upstream RREADY on the falling edge, allowing tests to accept
     responses or deliberately apply R-channel backpressure. */
  /* signify that the manager is ready (or not) to take the read data*/
  task automatic up_set_rready(input bit v);
    @(negedge clk);
    up.rready = v;
  endtask
  
  /* AR driver: one bus cycle to present a beat, one more to notice ARREADY.
     That under-drives peak throughput but keeps the loop trivial to read;
     this TB is about correctness, not saturating the channel. */
  
  
  /* execute this at the start, but keep running forever */
  initial begin
    up.arvalid = 1'b0;
    up.ar = '0;
    forever begin
      @(negedge clk);
      /* no read address is currently being presented, and at least one address is waiting in the manager's request queue. */
      if (!up.arvalid && ar_q.size() != 0) begin
        up.ar.addr = ar_q.pop_front(); /* take first addr from queue to and place it on AXI bus */
        up.ar.prot = '0; /* Use default ARPROT attributes for this testbench. */
        up.arvalid = 1'b1; /* assert valid signal for the bus */
        /* If an AR request is already valid and the guard asserts ARREADY,
        the current address has been accepted. Load the next queued address,
        or deassert ARVALID if no more requests are waiting. */
      end
      else if (up.arvalid && up.arready) begin
        if (ar_q.size() != 0) up.ar.addr = ar_q.pop_front();
        else up.arvalid = 1'b0;
      end
    end
  end
  
  /* Keeps the upstream manager ready and records every accepted R-channel response in rx_q. */
  initial begin
    up.rready = 1'b1; /* TB has upstream manager ready to accept read resopnes by default; execute this line once */
    forever begin
      @(posedge clk);
      if (up.rvalid && up.rready) rx_q.push_back(up.r); /* take read resp currently on AXI R channel and save copy at the back of rx_q */
    end
  end
  
  /**************************************************************************
   * Downstream subordinate stub -- TB plays subordinate on `dn` (guard.m)
   *   sub_set_ar_ready()   forces ARREADY low/high (unused by default tests)
   *   sub_set_resp_enable() 0 = accept AR but never answer -> forces a timeout
   **************************************************************************/
  
  
  logic[31:0] sub_pending_q[$]; /* queue of read addresses that downstream sub has accepted (but not answered) */
  bit sub_ar_ready = 1'b1; /* signal to assert AR accepting readiness */
  bit sub_resp_enable = 1'b1; /* bit to control whetehr sub is allowed to generate read responses */
  
  /* helper function to set ARREADY bit */
  task automatic sub_set_ar_ready(input bit v);
    @(negedge clk);
    sub_ar_ready = v;
  endtask
  
  /* helper function to set resp enabale (TB only knob) */
  task automatic sub_set_resp_enable(input bit v);
    @(negedge clk);
    sub_resp_enable = v;
  endtask
  
  initial begin //driver
    dn.arready = 1'b1; /* initial readiness */
    forever begin
      @(negedge clk); /* gives the signal half a clock to settle before the DUT looks at it */
      dn.arready = sub_ar_ready; /* else copy TB control variable */
    end
  end
  initial begin //sampler
    forever begin
      @(posedge clk); /* watch for AR handshake */
      if (dn.arvalid && dn.arready) sub_pending_q.push_back(dn.ar.addr);
    end
  end
  
  initial begin
    dn.rvalid = 1'b0; /* initial; sub is not presenting valid read response */
    forever begin
      @(negedge clk);
      if (dn.rvalid && dn.rready) dn.rvalid = 1'b0; /* if prior beat accepted by guard, clear RVALID*/
      if (!dn.rvalid && sub_resp_enable && sub_pending_q.size() != 0) begin
        dn.r.data = pattern(sub_pending_q.pop_front()); /* use the pattern function to generate a read data */
        dn.r.resp = RESP_OKAY;
        dn.rvalid = 1'b1;
      end
    end
  end
  
  /* Reset: also clears BFM queues/knobs so each directed test starts clean */
  task automatic reset_dut();
    rst_n = 1'b0; /* assert active low reset in design */
    epoch_clr = 1'b0;
    flush = 1'b0; /* both tplvl control inputs into inctive state */
    ar_q.delete();
    rx_q.delete();
    sub_pending_q.delete(); /* delete everything from every queue */
    sub_ar_ready = 1'b1;
    sub_resp_enable = 1'b1; /* restore sub to default states (willing to accept AR, and ability to generate resp) */
    repeat (3) @(posedge clk);
    rst_n = 1'b1; /* deassert reset after a few clock cycles to settle */
    @(posedge clk);
  endtask
  
  /**************************************************************************
   * Directed tests -- one narrative per named FSM behaviour.
   **************************************************************************/
  task automatic test_reset();
    r_beat_t r;
    $display("[%0t] test_reset", $time);
    check(dut.rd_state == RD_IDLE, "reset: rd_state == RD_IDLE");
    check(dut.outst_cnt == '0, "reset: outst_cnt == 0");
    check(dut.drain_cnt == '0, "reset: drain_cnt == 0");
    check(upstream_empty == 1'b1, "reset: upstream_empty asserted");
    check(busy == 1'b0, "reset: busy deasserted");
  endtask
  
  task automatic test_passthrough();
    r_beat_t r;
    logic[31:0] addr;
    $display("[%0t] test_passthrough", $time);
    addr = 32'h0000_1000;
    up_push_ar(addr);
    wait_for_r(r);
    check(r.resp == RESP_OKAY, "passthrough: RESP_OKAY");
    check(r.data == pattern(addr), "passthrough: data matches subordinate");
    check(timeout_pulse == 1'b0, "passthrough: no timeout fired");
    check(dut.rd_state == RD_IDLE, "passthrough: back to RD_IDLE");
  endtask
  
  task automatic test_queue_full_backpressure();
    int unsigned i;
    $display("[%0t] test_queue_full_backpressure", $time);
    sub_set_resp_enable(1'b0); /* subordinate accepts AR but withholds R, so outst_cnt only grows */
    for (i = 0; i < TB_DEPTH; i++) up_push_ar(32'h0000_2000 + i);
    while (dut.outst_cnt != TB_DEPTH) @(posedge clk);
    check(dut.full == 1'b1, "full: outst_cnt reached DEPTH");
    up_push_ar(32'h0000_2000 + TB_DEPTH); /* one more than the queue can hold */
    repeat (5) @(posedge clk);
    check(up.arready == 1'b0, "full: ARREADY withheld while full");
    check(ar_q.size() != 0, "full: extra AR still parked in the driver, never accepted");
  endtask
  
  task automatic test_timeout_and_ghost_drain();
    r_beat_t r;
    logic[31:0] addr;
    int unsigned guard;
    $display("[%0t] test_timeout_and_ghost_drain", $time);
    addr = 32'h0000_3000;
    sub_set_resp_enable(1'b0); /* subordinate accepts AR, then goes silent */
    up_push_ar(addr);
    
    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
      @(posedge clk);
      guard++;
    end
    check(timeout_pulse == 1'b1, "timeout: pulse fired within TIMEOUT_CYCLES");
    
    wait_for_r(r);
    check(r.resp == RESP_SLVERR, "timeout: injected SLVERR delivered to manager");
    check(dut.drain_cnt == 1, "timeout: ghost owed after injection accepted");
    
    sub_set_resp_enable(1'b1); /* subordinate finally answers the timed-out request */
    repeat (5) @(posedge clk);
    check(dut.drain_cnt == 0, "ghost: late real response silently absorbed");
    check(rx_q.size() == 0, "ghost: no extra beat leaked to the manager");
    check(dut.rd_state == RD_IDLE, "ghost: FSM settled back to RD_IDLE");
  endtask
  
  task automatic test_inject_cascade_multi_outstanding();
    r_beat_t r0, r1;
    logic[31:0] a0, a1;
    int unsigned guard;
    $display("[%0t] test_inject_cascade_multi_outstanding", $time);
    a0 = 32'h0000_4000;
    a1 = 32'h0000_4004;
    sub_set_resp_enable(1'b0); /* both ARs accepted, neither ever answered */
    up_push_ar(a0);
    up_push_ar(a1);
    while (dut.outst_cnt != 2) @(posedge clk);
    
    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
      @(posedge clk);
      guard++;
    end
    wait_for_r(r0);
    check(r0.resp == RESP_SLVERR, "cascade: first head injected SLVERR");
    check(dut.rd_state == RD_TRACKING, "cascade: second entry still owed, FSM stays TRACKING");
    
    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
      @(posedge clk);
      guard++;
    end
    wait_for_r(r1);
    check(r1.resp == RESP_SLVERR, "cascade: second head also injected SLVERR");
    check(dut.rd_state == RD_IDLE, "cascade: FSM idle once both entries retired");
  endtask
  
  task automatic test_flush_forces_injection();
    r_beat_t r;
    logic[31:0] addr;
    $display("[%0t] test_flush_forces_injection", $time);
    addr = 32'h0000_5000;
    sub_set_resp_enable(1'b0);
    up_push_ar(addr);
    while (dut.outst_cnt != 1) @(posedge clk);
    
    @(negedge clk);
    flush = 1'b1;
    repeat (2) @(posedge clk);
    check(dut.rd_state == RD_INJECTING, "flush: forces injection well before TIMEOUT_CYCLES");
    check(timeout_pulse == 1'b0, "flush: injection did not come from the timer");
    
    wait_for_r(r);
    check(r.resp == RESP_SLVERR, "flush: SLVERR delivered");
    @(negedge clk);
    flush = 1'b0;
  endtask
  
  task automatic test_epoch_clr_clears_counts();
    logic[31:0] addr;
    $display("[%0t] test_epoch_clr_clears_counts", $time);
    addr = 32'h0000_6000;
    sub_set_resp_enable(1'b0);
    up_push_ar(addr);
    while (dut.outst_cnt != 1) @(posedge clk);
    check(busy == 1'b1, "epoch_clr: guard busy before clear");
    
    @(negedge clk);
    epoch_clr = 1'b1;
    @(posedge clk);
    @(negedge clk);
    epoch_clr = 1'b0;
    
    check(dut.outst_cnt == '0, "epoch_clr: outst_cnt wiped");
    check(dut.drain_cnt == '0, "epoch_clr: drain_cnt wiped");
    check(dut.rd_state == RD_IDLE, "epoch_clr: rd_state forced back to RD_IDLE");
    check(upstream_empty == 1'b1, "epoch_clr: upstream_empty asserted");
  endtask
  
  initial begin
    n_pass = 0;
    n_fail = 0;
    
    reset_dut();
    test_reset();
    reset_dut();
    test_passthrough();
    reset_dut();
    test_queue_full_backpressure();
    reset_dut();
    test_timeout_and_ghost_drain();
    reset_dut();
    test_inject_cascade_multi_outstanding();
    reset_dut();
    test_flush_forces_injection();
    reset_dut();
    test_epoch_clr_clears_counts();
    
    $display("==== rd_queue directed TB: %0d passed, %0d failed ====", n_pass, n_fail);
    if (n_fail != 0) $fatal(1, "rd_queue directed TB FAILED");
    $finish;
  end
  
endmodule : tb_rd_queue