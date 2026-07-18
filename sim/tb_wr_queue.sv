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
  localparam int unsigned TB_DEPTH = 4;
  localparam int unsigned TB_TW = 8;
  localparam logic[TB_TW - 1:0] TB_TIMEOUT = TB_TW'(20);
  localparam logic[31:0] TAG = 32'hA5A5_A5A5;
  
  /* interfaces */
  axi4l_if up(.clk(clk), .aresetn(rst_n)); /* TB manager <-> guard.s */
  axi4l_if dn(.clk(clk), .aresetn(rst_n)); /* guard.m    <-> TB stub subordinate */
  
  logic epoch_clr, flush;
  logic timeout_pulse, w_fault_pulse, busy, upstream_empty;
  
  /* write queue instantiation */
  wr_queue#(
    .DEPTH(TB_DEPTH), .TIMER_WIDTH(TB_TW), .TIMEOUT_CYCLES(TB_TIMEOUT)) dut(
    .clk(clk), .rst_n(rst_n),
    .m(dn), .s(up),
    .timeout_pulse(timeout_pulse),
    .w_fault_pulse(w_fault_pulse),
    .busy(busy), .upstream_empty(upstream_empty),
    .epoch_clr(epoch_clr), .flush(flush));
  
  /* pass/fail accounting */
  int unsigned n_pass, n_fail;
  task automatic check(input bit cond, input string msg);
    assert (cond) n_pass++;
    else begin
      n_fail++;
      $error("[%0t] FAIL: %s", $time, msg);
    end
  endtask
  
  /* B responses carry no data, so there is nothing to fingerprint. We keep a
     TAG-based pattern only for the WDATA the manager sends, so the downstream
     monitor can confirm the guard forwarded the correct write payload. */
  function automatic logic[31:0] pattern(input logic[31:0] addr);
    return addr ^ TAG;
  endfunction
  
  /**************************************************************************
   * Upstream manager BFM -- TB plays manager on `up` (guard.s)
   * A write needs BOTH halves: an address on AW and data on W. up_push_write
   * enqueues both together; two independent drivers present them, each holding
   * its VALID until the matching READY (the guard's hold-AW logic pairs them).
   **************************************************************************/
  logic[ADDR_WIDTH - 1:0] aw_q[$];
  logic[DATA_WIDTH - 1:0] w_q[$];
  b_beat_t bx_q[$]; /* accepted B responses, in order */
  
  task automatic up_push_aw(input logic[31:0] addr);
    aw_q.push_back(addr);
  endtask
  task automatic up_push_w(input logic[31:0] data);
    w_q.push_back(data);
  endtask
  
  /* convenience: push a full write (AW and W together, as most tests want).
     data defaults to pattern(addr) so the downstream monitor can check it. */
  task automatic up_push_write(input logic[31:0] addr, input logic[31:0] data = 32'hFFFF_FFFF);
    up_push_aw(addr);
    up_push_w((data == 32'hFFFF_FFFF) ? pattern(addr) : data);
  endtask
  
  task automatic wait_for_b(output b_beat_t b);
    while (bx_q.size() == 0) @(posedge clk);
    b = bx_q.pop_front();
  endtask
  
  task automatic up_set_bready(input bit v);
    @(negedge clk);
    up.bready = v;
  endtask
  
  /* Accept flags, sampled AT the posedge (pre-edge values, exactly what the
     DUT's own registers capture). The guard's hold-AW design lets AWREADY and
     WREADY go combinationally high mid-cycle, driven by a state transition
     from THIS same transaction (wpair_state flipping on the very edge that
     admits AW). A driver that re-reads awvalid/awready or wvalid/wready live
     at the following negedge can see that freshly-settled high and conclude
     "accepted" one negedge before the DUT actually captures it -- dropping
     VALID right before the real capturing posedge and wedging the pair FSM
     forever. Sampling here and reacting to the sampled flag one negedge later
     guarantees the driver only advances on a transfer the DUT truly captured. */
  logic aw_accepted, w_accepted;
  always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) aw_accepted <= 1'b0;
    else        aw_accepted <= up.awvalid && up.awready;
  end
  always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) w_accepted <= 1'b0;
    else        w_accepted <= up.wvalid && up.wready;
  end

  /* AW driver: hold AWVALID until AWREADY, then advance. */
  initial begin
    up.awvalid = 1'b0;
    up.aw = '0;
    forever begin
      @(negedge clk);
      if (!up.awvalid && aw_q.size() != 0) begin
        up.aw.addr = aw_q.pop_front();
        up.aw.prot = '0;
        up.awvalid = 1'b1;
      end
      else if (aw_accepted) begin
        if (aw_q.size() != 0) up.aw.addr = aw_q.pop_front();
        else up.awvalid = 1'b0;
      end
    end
  end

  /* W driver: hold WVALID until WREADY, then advance. Decoupled from AW --
     the guard enforces AW-first; the manager just keeps its offer stable. */
  initial begin
    up.wvalid = 1'b0;
    up.w = '0;
    forever begin
      @(negedge clk);
      if (!up.wvalid && w_q.size() != 0) begin
        up.w.data = w_q.pop_front();
        up.w.strb = '1;
        up.wvalid = 1'b1;
      end
      else if (w_accepted) begin
        if (w_q.size() != 0) up.w.data = w_q.pop_front();
        else up.wvalid = 1'b0;
      end
    end
  end
  
  /* B sink: keep BREADY high by default, record every accepted B in order.
     SAMPLE at posedge (handshake is true there) -- driving/sampling on the
     same edge is what hangs a TB. */
  initial begin
    up.bready = 1'b1;
    forever begin
      @(posedge clk);
      if (up.bvalid && up.bready) bx_q.push_back(up.b);
    end
  end
  
  /**************************************************************************
   * Downstream subordinate stub -- TB plays subordinate on `dn` (guard.m)
   *   sub_aw_ready / sub_w_ready : accept-side readiness (both high default)
   *   sub_bresp_enable           : 0 = accept the pair but never answer B
   *                                    -> forces a B-timeout (subordinate fault)
   **************************************************************************/
  logic[31:0] sub_pending_q[$]; /* accepted writes awaiting a B */
  bit sub_aw_ready = 1'b1;
  bit sub_w_ready = 1'b1;
  bit sub_bresp_enable = 1'b1;
  
  task automatic sub_set_bresp_enable(input bit v);
    @(negedge clk);
    sub_bresp_enable = v;
  endtask
  
  /* readiness driver: change at negedge */
  initial begin
    dn.awready = 1'b1;
    dn.wready = 1'b1;
    forever begin
      @(negedge clk);
      dn.awready = sub_aw_ready;
      dn.wready = sub_w_ready;
    end
  end
  
  /* pair sampler: the guard forwards AW+W together, so accept when BOTH
     handshake in the same cycle. SAMPLE at posedge. */
  initial begin
    forever begin
      @(posedge clk);
      if (dn.awvalid && dn.awready && dn.wvalid && dn.wready)
        sub_pending_q.push_back(dn.aw.addr);
    end
  end
  
  /* B driver: present a response for each accepted write, unless disabled.
     Deassert only after the guard accepts (dn.bready), advance to next. */
  initial begin
    dn.bvalid = 1'b0;
    dn.b = '0;
    forever begin
      @(negedge clk);
      if (dn.bvalid && dn.bready) dn.bvalid = 1'b0; /* prior B accepted */
      if (!dn.bvalid && sub_bresp_enable && sub_pending_q.size() != 0) begin
        void'(sub_pending_q.pop_front());
        dn.b.resp = RESP_OKAY;
        dn.bvalid = 1'b1;
      end
    end
  end
  
  /* Reset: clear all BFM state so each directed test starts clean. */
  task automatic reset_dut();
    rst_n = 1'b0;
    epoch_clr = 1'b0;
    flush = 1'b0;
    aw_q.delete();
    w_q.delete();
    bx_q.delete();
    sub_pending_q.delete();
    sub_aw_ready = 1'b1;
    sub_w_ready = 1'b1;
    sub_bresp_enable = 1'b1;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
  endtask
  
  /**************************************************************************
   * Directed tests
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
    $display("[%0t] test_passthrough", $time);
    up_push_write(32'h0000_1000);
    wait_for_b(b);
    check(b.resp == RESP_OKAY, "passthrough: B RESP_OKAY");
    check(timeout_pulse == 1'b0, "passthrough: no B-timeout fired");
    check(w_fault_pulse == 1'b0, "passthrough: no W-fault fired");
    check(dut.wr_state == WR_IDLE, "passthrough: back to WR_IDLE");
    check(dut.wpair_state == WPAIR_IDLE, "passthrough: pair FSM back to IDLE");
  endtask
  
  task automatic test_pipelined();
    b_beat_t b;
    int unsigned i;
    $display("[%0t] test_pipelined", $time);
    for (i = 0; i < 3; i++) up_push_write(32'h0000_2000 + 32'(4 * i));
    for (i = 0; i < 3; i++) begin
      wait_for_b(b);
      check(b.resp == RESP_OKAY, $sformatf("pipelined: write %0d OKAY", i));
    end
    check(dut.wr_state == WR_IDLE, "pipelined: all retired, WR_IDLE");
  endtask
  
  task automatic test_queue_full_backpressure();
    int unsigned i;
    $display("[%0t] test_queue_full_backpressure", $time);
    sub_set_bresp_enable(1'b0); /* pairs admitted, B withheld -> outst_cnt grows */
    for (i = 0; i < TB_DEPTH; i++) up_push_write(32'h0000_3000 + 32'(4 * i));
    while (dut.outst_cnt != TB_DEPTH) @(posedge clk);
    check(dut.full == 1'b1, "full: outst_cnt reached DEPTH");
    up_push_write(32'h0000_3000 + 32'(4 * TB_DEPTH)); /* one too many */
    repeat (5) @(posedge clk);
    check(up.awready == 1'b0, "full: AWREADY withheld while full");
  endtask
  
  /* B-timeout: subordinate accepts the pair, never sends B. Subordinate-side
     fault -> LEGAL SLVERR injection, then the late B is drained as a ghost. */
  task automatic test_b_timeout_and_ghost();
    b_beat_t b;
    int unsigned guard;
    $display("[%0t] test_b_timeout_and_ghost", $time);
    sub_set_bresp_enable(1'b0);
    up_push_write(32'h0000_4000);
    
    guard = 0;
    while (!timeout_pulse && guard < TB_TIMEOUT + 10) begin
      @(posedge clk);
      guard++;
    end
    check(timeout_pulse == 1'b1, "b_timeout: pulse fired");
    
    wait_for_b(b);
    check(b.resp == RESP_SLVERR, "b_timeout: injected SLVERR delivered");
    check(dut.drain_cnt == 1, "b_timeout: ghost owed after injection");
    
    sub_set_bresp_enable(1'b1); /* subordinate finally answers -> ghost */
    repeat (5) @(posedge clk);
    check(dut.drain_cnt == 0, "ghost: late B absorbed");
    check(bx_q.size() == 0, "ghost: no extra B leaked upstream");
    check(dut.wr_state == WR_IDLE, "ghost: settled to WR_IDLE");
  endtask
  
  /* W-timeout: AW accepted, W NEVER sent. Manager-side fault -> NO SLVERR is
     legal, W_FAULT must fire (interrupt only), and no B may appear upstream. */
  task automatic test_w_timeout_fault();
    int unsigned guard;
    $display("[%0t] test_w_timeout_fault", $time);
    /* push only the AW half -- withhold W entirely */
    up_push_aw(32'h0000_5000);
    while (dut.wpair_state != WPAIR_AW_ONLY) @(posedge clk);
    
    guard = 0;
    while (!w_fault_pulse && guard < TB_TIMEOUT + 10) begin
      @(posedge clk);
      guard++;
    end
    check(w_fault_pulse == 1'b1, "w_fault: W-timeout pulse fired");
    check(dut.wpair_state == WPAIR_W_FAULT, "w_fault: parked in WPAIR_W_FAULT");
    check(bx_q.size() == 0, "w_fault: NO B response sent upstream");
    check(timeout_pulse == 1'b0, "w_fault: this is NOT a B-timeout");
    
    /* only epoch_clr may clear W_FAULT */
    @(negedge clk);
    epoch_clr = 1'b1;
    @(posedge clk);
    @(negedge clk);
    epoch_clr = 1'b0;
    repeat (2) @(posedge clk);
    check(dut.wpair_state == WPAIR_IDLE, "w_fault: epoch_clr returns pair FSM to IDLE");
    /* flush the stranded W driver state for the next test */
    w_q.delete();
    up.wvalid = 1'b0;
  endtask
  
  /* AW-first rule: present W before AW; the guard must withhold WREADY until
     AW is accepted (no WPAIR_W_ONLY state exists). */
  task automatic test_aw_first_enforced();
    $display("[%0t] test_aw_first_enforced", $time);
    /* push W only, no AW */
    up_push_w(pattern(32'h0000_6000));
    repeat (4) @(posedge clk);
    check(up.wready == 1'b0, "aw_first: WREADY withheld with no AW");
    check(dut.wpair_state == WPAIR_IDLE, "aw_first: pair FSM still IDLE");
    /* now supply the AW -- the pair should complete */
    up_push_aw(32'h0000_6000);
    begin
      b_beat_t b;
      wait_for_b(b);
      check(b.resp == RESP_OKAY, "aw_first: pair completes once AW arrives");
    end
  endtask
  
  task automatic test_flush_forces_injection();
    b_beat_t b;
    $display("[%0t] test_flush_forces_injection", $time);
    sub_set_bresp_enable(1'b0);
    up_push_write(32'h0000_7000);
    while (dut.outst_cnt != 1) @(posedge clk);
    @(negedge clk);
    flush = 1'b1;
    repeat (2) @(posedge clk);
    check(dut.wr_state == WR_INJECTING, "flush: forces injection before timeout");
    check(timeout_pulse == 1'b0, "flush: not from the timer");
    wait_for_b(b);
    check(b.resp == RESP_SLVERR, "flush: SLVERR delivered");
    check(upstream_empty == 1'b1, "flush: upstream drained");
    @(negedge clk);
    flush = 1'b0;
  endtask
  
  task automatic test_epoch_clr_legal();
    $display("[%0t] test_epoch_clr_legal", $time);
    sub_set_bresp_enable(1'b0);
    up_push_write(32'h0000_8000);
    while (dut.outst_cnt != 1) @(posedge clk);
    check(busy == 1'b1, "epoch_clr: busy before clear");
    /* drain lawfully first (flush), THEN clear -- SVA requires it */
    @(negedge clk);
    flush = 1'b1;
    while (!upstream_empty) @(posedge clk);
    @(negedge clk);
    flush = 1'b0;
    @(negedge clk);
    epoch_clr = 1'b1;
    @(posedge clk);
    @(negedge clk);
    epoch_clr = 1'b0;
    check(dut.outst_cnt == '0, "epoch_clr: outst_cnt wiped");
    check(dut.drain_cnt == '0, "epoch_clr: drain_cnt wiped");
    check(dut.wr_state == WR_IDLE, "epoch_clr: wr_state IDLE");
    check(dut.wpair_state == WPAIR_IDLE, "epoch_clr: pair FSM IDLE");
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
    test_pipelined();
    reset_dut();
    test_queue_full_backpressure();
    reset_dut();
    test_b_timeout_and_ghost();
    reset_dut();
    test_w_timeout_fault();
    reset_dut();
    test_aw_first_enforced();
    reset_dut();
    test_flush_forces_injection();
    reset_dut();
    test_epoch_clr_legal();
    
    $display("==== wr_queue directed TB: %0d passed, %0d failed ====", n_pass, n_fail);
    if (n_fail != 0) $fatal(1, "wr_queue directed TB FAILED");
    $finish;
  end
  
  /* watchdog */
  initial begin
    #500us;
    $fatal(1, "WATCHDOG: wr_queue TB hung -- last printed test is the culprit");
  end
  
endmodule : tb_wr_queue