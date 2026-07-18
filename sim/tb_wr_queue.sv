`timescale 1ns/1ps
import a4lite_pkg::*;
module tb_wr_queue;
  
  /* clock and reset */
  logic clk, rst_n;
  initial clk = 1'b0;
  always #5 clk = ~clk;
  int unsigned cyc;
  always @(posedge clk) cyc <= cyc + 1;
  
  /* knobs */
  localparam int unsigned TB_DEPTH = 4; /* how many outstanding writes to hold */
  localparam int unsigned TB_TW = 8; /* timer width */
  localparam logic[TB_TW - 1:0] TB_TIMEOUT = TB_TW'(20);
  
  /* interfaces */
  axi4l_if up(.clk(clk), .aresetn(rst_n)); /* TB manager <-> guard.s */
  axi4l_if dn(.clk(clk), .aresetn(rst_n)); /* guard.m <-> TB stub subordinate */
  
  logic epoch_clr, flush;
  logic timeout_pulse, busy, upstream_empty, w_fault_pulse;
  
  /* write queue instantiation */
  wr_queue#(
    .DEPTH(TB_DEPTH), .TIMER_WIDTH(TB_TW), .TIMEOUT_CYCLES(TB_TIMEOUT)) dut(
    .clk(clk), .rst_n(rst_n),
    .m(dn), .s(up),
    .timeout_pulse(timeout_pulse), .busy(busy), .upstream_empty(upstream_empty),
    .epoch_clr(epoch_clr), .flush(flush),
    .w_fault_pulse(w_fault_pulse));
  
  /* acccounting for test passes/fails */
  int unsigned n_pass, n_fail;
  task automatic check(input bit cond, input string msg);
    assert (cond) n_pass++;
    else begin
      n_fail++;
      $error("[%0t] FAIL: %s", $time, msg);
    end
  endtask
  
  /* system verilog queues */
  logic[ADDR_WIDTH - 1:0] aw_q[$]; /* store write addresses waiting on the AW channel */
  logic[DATA_WIDTH - 1:0] w_q[$]; /* store write data waiting on the W channel */
  b_beat_t bx_q[$]; /* queue to hold B beat (write-response) transfers on the B channel */
  
  /* task to add a write address into the AW channel queue */
  task automatic up_push_aw(input logic[31:0] addr);
    aw_q.push_back(addr);
  endtask
  
  /* task to add write data into the W channel queue */
  task automatic up_push_w(input logic[31:0] data);
    w_q.push_back(data);
  endtask
  
  /* convenience: push a full write (AW and W together, as most tests want) */
  task automatic up_push_write(input logic[31:0] addr, input logic[31:0] data);
    up_push_aw(addr);
    up_push_w(data);
  endtask
  
  /* Waits until an accepted B-channel response is available, then removes
     and returns the oldest response captured by the upstream B monitor. */
  task automatic wait_for_b(output b_beat_t b);
    while (bx_q.size() == 0) @(posedge clk);
    b = bx_q.pop_front();
  endtask
  
  /* Sets upstream BREADY on the falling edge, allowing tests to accept
     responses or deliberately apply B-channel backpressure. */
  task automatic up_set_bready(input bit v);
    @(negedge clk);
    up.bready = v;
  endtask
  
  /* AW driver: one bus cycle to present a beat, one more to notice AWREADY.
     That under-drives peak throughput but keeps the loop trivial to read;
     this TB is about correctness, not saturating the channel. */
  initial begin
    up.awvalid = 1'b0;
    up.aw = '0;
    forever begin
      @(negedge clk);
      /* no write address is currently being presented, and at least one address is waiting in the manager's request queue. */
      if (!up.awvalid && aw_q.size() != 0) begin
        up.aw.addr = aw_q.pop_front(); /* take first addr from queue and place it on the AXI bus */
        up.aw.prot = '0; /* Use default AWPROT attributes for this testbench. */
        up.awvalid = 1'b1; /* assert valid signal for the bus */
      end
      else if (up.awvalid && up.awready) begin
        /* If an AW request is already valid and the guard asserts AWREADY,
        the current address has been accepted. Load the next queued address,
        or deassert AWVALID if no more requests are waiting. */
        if (aw_q.size() != 0) up.aw.addr = aw_q.pop_front();
        else up.awvalid = 1'b0;
      end
    end
  end
  
  /* W driver: mirrors the AW driver, but decoupled -- AXI4-Lite lets W trail
     (or even sit waiting behind) AW; the guard is what enforces AW-first. */
  initial begin
    up.wvalid = 1'b0;
    up.w = '0;
    forever begin
      @(negedge clk);
      if (!up.wvalid && w_q.size() != 0) begin
        up.w.data = w_q.pop_front();
        up.w.strb = '1; /* full-word writes for this testbench */
        up.wvalid = 1'b1;
      end
      else if (up.wvalid && up.wready) begin
        if (w_q.size() != 0) up.w.data = w_q.pop_front();
        else up.wvalid = 1'b0;
      end
    end
  end
  
  /* Keeps the upstream manager ready and records every accepted B-channel response in bx_q. */
  initial begin
    up.bready = 1'b1; /* TB has upstream manager ready to accept write responses by default; execute this line once */
    forever begin
      @(posedge clk);
      if (up.bvalid && up.bready) bx_q.push_back(up.b); /* take write resp currently on AXI B channel and save copy at the back of bx_q */
    end
  end
  
  /**************************************************************************
   * Downstream subordinate stub -- TB plays subordinate on `dn` (guard.m)
   *   sub_set_awready()/sub_set_wready() force AW/W readiness low or high
   *   sub_set_bresp_enable() 0 = accept AW+W but never answer -> forces a timeout
   **************************************************************************/
  
  logic[31:0] sub_pending_q[$]; /* queue of write addresses that downstream sub has accepted (but not answered) */
  bit sub_awready = 1'b1; /* signal to assert AW accepting readiness */
  bit sub_wready = 1'b1; /* signal to assert W accepting readiness */
  bit sub_bresp_enable = 1'b1; /* bit to control whether sub is allowed to generate write responses */
  
  /* content-check hooks: last address/data the guard actually forwarded downstream */
  logic[31:0] last_dn_addr, last_dn_data;
  
  /* helper task to set AWREADY bit */
  task automatic sub_set_awready(input bit v);
    @(negedge clk);
    sub_awready = v;
  endtask
  
  /* helper task to set WREADY bit */
  task automatic sub_set_wready(input bit v);
    @(negedge clk);
    sub_wready = v;
  endtask
  
  /* helper task to set resp enable (TB only knob) */
  task automatic sub_set_bresp_enable(input bit v);
    @(negedge clk);
    sub_bresp_enable = v;
  endtask
  
  initial begin //driver
    dn.awready = 1'b1; /* initial readiness */
    dn.wready = 1'b1;
    forever begin
      @(negedge clk); /* gives the signal half a clock to settle before the DUT looks at it */
      dn.awready = sub_awready;
      dn.wready = sub_wready;
    end
  end
  initial begin //sampler
    forever begin
      @(posedge clk); /* watch for the joint AW+W handshake -- the guard always presents both together */
      if (dn.awvalid && dn.awready && dn.wvalid && dn.wready) begin
        sub_pending_q.push_back(dn.aw.addr);
        last_dn_addr = dn.aw.addr;
        last_dn_data = dn.w.data;
      end
    end
  end
  
  initial begin
    dn.bvalid = 1'b0; /* initial; sub is not presenting a valid write response */
    forever begin
      @(negedge clk);
      if (dn.bvalid && dn.bready) dn.bvalid = 1'b0; /* if prior beat accepted by guard, clear BVALID */
      if (!dn.bvalid && sub_bresp_enable && sub_pending_q.size() != 0) begin
        sub_pending_q.pop_front();
        dn.b.resp = RESP_OKAY;
        dn.bvalid = 1'b1;
      end
    end
  end
  
  /* Reset: also clears BFM queues/knobs so each directed test starts clean */
  task automatic reset_dut();
    rst_n = 1'b0; /* assert active low reset in design */
    epoch_clr = 1'b0;
    flush = 1'b0; /* both tplvl control inputs into inactive state */
    aw_q.delete();
    w_q.delete();
    bx_q.delete();
    sub_pending_q.delete(); /* delete everything from every queue */
    sub_awready = 1'b1;
    sub_wready = 1'b1;
    sub_bresp_enable = 1'b1; /* restore sub to default states (willing to accept AW/W, and ability to generate resp) */
    repeat (3) @(posedge clk);
    rst_n = 1'b1; /* deassert reset after a few clock cycles to settle */
    @(posedge clk);
  endtask
  
  /**************************************************************************
   * Directed tests -- one narrative per named FSM behaviour.
   **************************************************************************/
  task automatic test_reset();
    $display("[%0t] test_reset", $time);
    check(dut.wr_state == WR_IDLE, "reset: wr_state == WR_IDLE");
    check(dut.wpair_state == WPAIR_IDLE, "reset: wpair_state == WPAIR_IDLE");
    check(dut.outst_cnt == '0, "reset: outst_cnt == 0");
    check(dut.drain_cnt == '0, "reset: drain_cnt == 0");
    check(upstream_empty == 1'b1, "reset: upstream_empty asserted");
    check(busy == 1'b0, "reset: busy deasserted");
  endtask
  
  task automatic test_passthrough();
    b_beat_t b;
    logic[31:0] addr, data;
    $display("[%0t] test_passthrough", $time);
    addr = 32'h0000_1000;
    data = 32'hCAFE_BABE;
    up_push_write(addr, data);
    wait_for_b(b);
    check(b.resp == RESP_OKAY, "passthrough: RESP_OKAY");
    check(last_dn_addr == addr, "passthrough: AW address reached subordinate unchanged");
    check(last_dn_data == data, "passthrough: W data reached subordinate unchanged");
    check(timeout_pulse == 1'b0, "passthrough: no B timeout fired");
    check(w_fault_pulse == 1'b0, "passthrough: no W timeout fired");
    check(dut.wr_state == WR_IDLE, "passthrough: back to WR_IDLE");
    check(dut.wpair_state == WPAIR_IDLE, "passthrough: back to WPAIR_IDLE");
  endtask
  
  task automatic test_queue_full_backpressure();
    int unsigned i;
    $display("[%0t] test_queue_full_backpressure", $time);
    sub_set_bresp_enable(1'b0); /* subordinate accepts AW+W but withholds B, so outst_cnt only grows */
    for (i = 0; i < TB_DEPTH; i++) up_push_write(32'h0000_2000 + i, 32'h0000_9000 + i);
    while (dut.outst_cnt != TB_DEPTH) @(posedge clk);
    check(dut.full == 1'b1, "full: outst_cnt reached DEPTH");
    up_push_write(32'h0000_2000 + TB_DEPTH, 32'h0000_9000 + TB_DEPTH); /* one more than the queue can hold */
    repeat (5) @(posedge clk);
    check(up.awready == 1'b0, "full: AWREADY withheld while full");
    check(aw_q.size() != 0, "full: extra AW still parked in the driver, never accepted");
  endtask
  
  task automatic test_timeout_and_ghost_drain();
    b_beat_t b;
    logic[31:0] addr, data;
    int unsigned guard;
    $display("[%0t] test_timeout_and_ghost_drain", $time);
    addr = 32'h0000_3000;
    data = 32'h0000_3333;
    sub_set_bresp_enable(1'b0); /* subordinate accepts AW+W, then goes silent on B */
    up_push_write(addr, data);
    
    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
      @(posedge clk);
      guard++;
    end
    check(timeout_pulse == 1'b1, "timeout: B-side pulse fired within TIMEOUT_CYCLES");
    
    wait_for_b(b);
    check(b.resp == RESP_SLVERR, "timeout: injected SLVERR delivered to manager");
    check(dut.drain_cnt == 1, "timeout: ghost owed after injection accepted");
    
    sub_set_bresp_enable(1'b1); /* subordinate finally answers the timed-out write */
    repeat (5) @(posedge clk);
    check(dut.drain_cnt == 0, "ghost: late real response silently absorbed");
    check(bx_q.size() == 0, "ghost: no extra beat leaked to the manager");
    check(dut.wr_state == WR_IDLE, "ghost: FSM settled back to WR_IDLE");
  endtask
  
  task automatic test_inject_cascade_multi_outstanding();
    b_beat_t b0, b1;
    logic[31:0] a0, a1, d0, d1;
    int unsigned guard;
    $display("[%0t] test_inject_cascade_multi_outstanding", $time);
    a0 = 32'h0000_4000;
    d0 = 32'h0000_4444;
    a1 = 32'h0000_4004;
    d1 = 32'h0000_4445;
    sub_set_bresp_enable(1'b0); /* both pairs accepted, neither ever answered */
    up_push_write(a0, d0);
    up_push_write(a1, d1);
    while (dut.outst_cnt != 2) @(posedge clk);
    
    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
      @(posedge clk);
      guard++;
    end
    wait_for_b(b0);
    check(b0.resp == RESP_SLVERR, "cascade: first head injected SLVERR");
    check(dut.wr_state == WR_TRACKING, "cascade: second entry still owed, FSM stays TRACKING");
    
    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
      @(posedge clk);
      guard++;
    end
    wait_for_b(b1);
    check(b1.resp == RESP_SLVERR, "cascade: second head also injected SLVERR");
    check(dut.wr_state == WR_IDLE, "cascade: FSM idle once both entries retired");
  endtask
  
  task automatic test_flush_forces_injection();
    b_beat_t b;
    logic[31:0] addr, data;
    $display("[%0t] test_flush_forces_injection", $time);
    addr = 32'h0000_5000;
    data = 32'h0000_5555;
    sub_set_bresp_enable(1'b0);
    up_push_write(addr, data);
    while (dut.outst_cnt != 1) @(posedge clk);
    
    @(negedge clk);
    flush = 1'b1;
    repeat (2) @(posedge clk);
    check(dut.wr_state == WR_INJECTING, "flush: forces injection well before TIMEOUT_CYCLES");
    check(timeout_pulse == 1'b0, "flush: injection did not come from the timer");
    
    wait_for_b(b);
    check(b.resp == RESP_SLVERR, "flush: SLVERR delivered");
    @(negedge clk);
    flush = 1'b0;
  endtask
  
  task automatic test_epoch_clr_clears_counts();
    logic[31:0] addr, data;
    $display("[%0t] test_epoch_clr_clears_counts", $time);
    addr = 32'h0000_6000;
    data = 32'h0000_6666;
    sub_set_bresp_enable(1'b0);
    up_push_write(addr, data);
    while (dut.outst_cnt != 1) @(posedge clk);
    check(busy == 1'b1, "epoch_clr: guard busy before clear");
    
    @(negedge clk);
    epoch_clr = 1'b1;
    @(posedge clk);
    @(negedge clk);
    epoch_clr = 1'b0;
    
    check(dut.outst_cnt == '0, "epoch_clr: outst_cnt wiped");
    check(dut.drain_cnt == '0, "epoch_clr: drain_cnt wiped");
    check(dut.wr_state == WR_IDLE, "epoch_clr: wr_state forced back to WR_IDLE");
    check(dut.wpair_state == WPAIR_IDLE, "epoch_clr: wpair_state forced back to WPAIR_IDLE");
    check(upstream_empty == 1'b1, "epoch_clr: upstream_empty asserted");
  endtask
  
  /* Write-specific: AW arrives, W never does -- a manager-side fault the read
     path has no analogue for. No B is ever owed (the subordinate never even
     saw the write), so the guard can only raise w_fault_pulse and park in
     WPAIR_W_FAULT until epoch_clr; it has no legal SLVERR to inject. */
  task automatic test_w_fault_aw_only_timeout();
    int unsigned guard;
    $display("[%0t] test_w_fault_aw_only_timeout", $time);
    up_push_aw(32'h0000_7000); /* AW only -- W deliberately withheld */
    
    guard = 0;
    while (dut.wpair_state != WPAIR_AW_ONLY && guard < 20) begin
      @(posedge clk);
      guard++;
    end
    check(dut.wpair_state == WPAIR_AW_ONLY, "w_fault: AW accepted, waiting on W");
    
    guard = 0;
    while (!w_fault_pulse && guard < TB_TIMEOUT + 10) begin
      @(posedge clk);
      guard++;
    end
    check(w_fault_pulse == 1'b1, "w_fault: pulse fired within TIMEOUT_CYCLES");
    check(timeout_pulse == 1'b0, "w_fault: no B-side timeout, nothing was ever owed");
    
    repeat (5) @(posedge clk);
    check(dut.wpair_state == WPAIR_W_FAULT, "w_fault: FSM parked in WPAIR_W_FAULT");
    check(busy == 1'b1, "w_fault: guard still busy, no B was ever completed");
    
    @(negedge clk);
    epoch_clr = 1'b1;
    @(posedge clk);
    @(negedge clk);
    epoch_clr = 1'b0;
    check(dut.wpair_state == WPAIR_IDLE, "w_fault: epoch_clr releases the parked fault");
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
    reset_dut();
    test_w_fault_aw_only_timeout();
    
    $display("==== wr_queue directed TB: %0d passed, %0d failed ====", n_pass, n_fail);
    if (n_fail != 0) $fatal(1, "wr_queue directed TB FAILED");
    $finish;
  end
  
endmodule : tb_wr_queue