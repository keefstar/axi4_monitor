/* SVA assertions for wr_queue AXI4-Lite transactions */

import a4lite_pkg::*;

module wr_queue_sva #(
    parameter int unsigned DEPTH = a4lite_pkg::DEPTH,
    parameter int unsigned TIMEOUT_CYCLES = a4lite_pkg::TIMEOUT_COUNTER
)(
    input logic clk,
    input logic rst_n,
    input logic b_timeout_hit,
    input logic epoch_clr,
    input logic flush,
    input logic timeout_pulse,
    input logic w_fault_pulse,
    input logic [$clog2(DEPTH+1)-1:0] outst_cnt,
    input logic [$clog2(DEPTH+1)-1:0] drain_cnt,
    input wr_state_e wr_state,
    input wpair_state_e wpair_state,
    input logic [a4lite_pkg::TIMEOUT_WIDTH-1:0] w_timer,
    input logic [a4lite_pkg::TIMEOUT_WIDTH-1:0] b_timer,
    input logic w_timer_run,
    input logic b_timer_run,
    input logic downstream_aw_fire,
    input logic downstream_w_fire,
    input logic downstream_pair_done,
    input logic ghost_fire,
    input logic inject_fire,
    input logic pair_fire,
    input logic retire_fire,
    axi4l_if s,
    axi4l_if m
);

localparam int unsigned CNT_W = $clog2(DEPTH + 1);


/* completed downstream writes owed upstream cannot be erased */
NO_CLEAR_WHILE_OWING_WRITE_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    epoch_clr |-> (outst_cnt == '0)
) else $error("SVA: epoch_clr asserted while write responses still owed: outst_cnt=%0d", outst_cnt);


/* WDT: W timer only runs after AW has been accepted and W is still missing */
W_TIMER_ONLY_WHILE_WAITING_FOR_W_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    w_timer_run |-> ((wpair_state == WPAIR_AW_ONLY) && !s.wvalid)
) else $error("SVA: write-data timer running outside AW-only wait state");


/* WDT: write-data timeout must enter the dedicated fault state */
W_TIMEOUT_ENTERS_FAULT_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    w_fault_pulse |=> (wpair_state == WPAIR_W_FAULT)
) else $error("SVA: write-data timeout did not enter WPAIR_W_FAULT");


/* WDT: incomplete AW-only write must not fabricate a BRESP */
NO_BRESP_FOR_W_FAULT_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (wpair_state == WPAIR_W_FAULT) |-> !s.bvalid
) else $error("SVA: BVALID presented for incomplete write-data-timeout transaction");


/* WDT-06: AW must not be forwarded downstream before W is available */
NO_DOWNSTREAM_WRITE_WITHOUT_W_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((wpair_state == WPAIR_AW_ONLY) && !s.wvalid)
    |-> (!m.awvalid && !m.wvalid)
) else $error("SVA: incomplete upstream write was launched downstream");


/* injected write-response timeout must present SLVERR */
INJECTING_SHOWS_SLVERR_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (wr_state == WR_INJECTING)
    |-> (s.bvalid && (s.b.resp == RESP_SLVERR))
) else $error("SVA: WR_INJECTING without upstream SLVERR");


/* late downstream B responses must not be forwarded as current responses */
NO_FORWARDING_GHOST_B_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (drain_cnt != '0)
    |-> !(s.bvalid && (wr_state == WR_TRACKING))
) else $error("SVA: ghost B response forwarded upstream while drain_cnt=%0d", drain_cnt);


/* drain count must remain representable */
DRAIN_OVERFLOW_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    drain_cnt <= CNT_W'(DEPTH)
) else $error("SVA: write drain_cnt overflow: %0d", drain_cnt);


/* WDT-01 */
WDT01_TIMEOUT_EXERCISED_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    w_fault_pulse
) $display("SVA_COVER: WDT-01 write-data timeout exercised");

/* WDT-02 */
WDT02_FAULT_STATE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    wpair_state == WPAIR_W_FAULT
) $display("SVA_COVER: WDT-02 WPAIR_W_FAULT state exercised");

/* WDT-03 */
WDT03_DELAYED_W_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wpair_state == WPAIR_AW_ONLY) &&
    s.wvalid &&
    (w_timer >= TIMEOUT_CYCLES - 16) &&
    (w_timer < TIMEOUT_CYCLES)
) $display("SVA_COVER: WDT-03 delayed legal WVALID exercised");

/* WDT-04: WVALID at the timeout boundary must suppress write-data timeout */
WDT04_BOUNDARY_NO_TIMEOUT_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((wpair_state == WPAIR_AW_ONLY) && s.wvalid && (w_timer == TIMEOUT_CYCLES)) |-> !w_fault_pulse
) else $error("SVA: false write-data timeout when WVALID arrived at legal boundary");

WDT04_BOUNDARY_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wpair_state == WPAIR_AW_ONLY) &&
    s.wvalid &&
    (w_timer == TIMEOUT_CYCLES)
) $display("SVA_COVER: WDT-04 final legal WVALID boundary exercised");

/* temporary WDT-04 timing diagnostic */
WDT04_W_ARRIVAL_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wpair_state == WPAIR_AW_ONLY) && s.wvalid
) $display(
    "WDT04_DEBUG: WVALID arrived with sampled w_timer=%0d, TIMEOUT_CYCLES=%0d",
    $sampled(w_timer),
    TIMEOUT_CYCLES
);

/* WDT-05: late write data after timeout must not be accepted. */
WDT05_LATE_W_NOT_ACCEPTED_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (wpair_state == WPAIR_W_FAULT && s.wvalid)
    |-> !s.wready
) else $error("SVA: late WVALID accepted after write-data timeout");


/* WDT-05: late write data must not resurrect the failed write downstream. */
WDT05_LATE_W_NOT_FORWARDED_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (wpair_state == WPAIR_W_FAULT && s.wvalid)
    |-> (!m.awvalid && !m.wvalid)
) else $error("SVA: timed-out write relaunched downstream by late WVALID");


WDT05_LATE_W_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wpair_state == WPAIR_W_FAULT) && s.wvalid
) $display("SVA_COVER: WDT-05 late WVALID after write-data timeout exercised");

/* WDT-06: AW accepted while W remains absent and no downstream write launches. */
WDT06_AW_ONLY_CONTAINED_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wpair_state == WPAIR_AW_ONLY) &&
    !s.wvalid &&
    !m.awvalid &&
    !m.wvalid
) $display("SVA_COVER: WDT-06 AW-only write contained upstream");

/* WRT-01: missing downstream B response must exercise write-response timeout. */
WRT01_TIMEOUT_EXERCISED_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    b_timeout_hit
) $display("SVA_COVER: WRT-01 write-response timeout exercised");

/* WRT-02: write-response timeout must enter SLVERR injection state. */
WRT02_TIMEOUT_ENTERS_INJECTING_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    b_timeout_hit |=> wr_state == WR_INJECTING
) else $error("SVA: write-response timeout did not enter WR_INJECTING");


WRT02_INJECTING_SLVERR_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wr_state == WR_INJECTING) &&
    s.bvalid &&
    (s.b.resp == RESP_SLVERR)
) $display("SVA_COVER: WRT-02 upstream SLVERR injection exercised");

/* WRT-03: injected write SLVERR must remain asserted and stable while BREADY is low. */
WRT03_SLVERR_STABLE_UNDER_BACKPRESSURE_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (wr_state == WR_INJECTING && s.bvalid && !s.bready)
    |=> (s.bvalid && s.b.resp == RESP_SLVERR)
) else $error("SVA: injected write SLVERR was not held under BREADY backpressure");


WRT03_BACKPRESSURE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wr_state == WR_INJECTING) &&
    s.bvalid &&
    !s.bready
) $display("SVA_COVER: WRT-03 injected SLVERR held under BREADY backpressure");


/* WRT-04: late real B after timeout must be consumed as a ghost response. */
WRT04_GHOST_B_DRAIN_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ghost_fire
) $display("SVA_COVER: WRT-04 late downstream B response drained");

/* WRT-05: exercise a real downstream B response close to timeout expiry. */
WRT05_DELAYED_B_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wr_state == WR_TRACKING) &&
    m.bvalid &&
    (b_timer >= TIMEOUT_CYCLES - 16) &&
    (b_timer < TIMEOUT_CYCLES)
) $display("SVA_COVER: WRT-05 delayed legal downstream BVALID exercised");

WRT05_DELAYED_B_NO_TIMEOUT_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (wr_state == WR_TRACKING &&
     m.bvalid &&
     b_timer < TIMEOUT_CYCLES)
    |-> !b_timeout_hit
) else $error("SVA: false write-response timeout while legal BVALID was present");

/* WRT-06: BVALID present at the final legal boundary must suppress timeout. */
WRT06_BOUNDARY_NO_TIMEOUT_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((wr_state == WR_TRACKING) &&
     m.bvalid &&
     (b_timer == TIMEOUT_CYCLES))
    |-> !b_timeout_hit
) else $error("SVA: false write-response timeout at legal BVALID boundary");


WRT06_BOUNDARY_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wr_state == WR_TRACKING) &&
    m.bvalid &&
    (b_timer == TIMEOUT_CYCLES)
) $display(
    "SVA_COVER: WRT-06 final legal downstream BVALID boundary exercised"
);

WRT06_B_ARRIVAL_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (wr_state == WR_TRACKING) && m.bvalid
) $display(
    "WRT06_DEBUG: BVALID arrived with sampled b_timer=%0d, TIMEOUT_CYCLES=%0d",
    $sampled(b_timer),
    TIMEOUT_CYCLES
);

/* QUEUE-04: write outstanding count must never exceed queue depth. */
QUEUE04_WRITE_OUTSTANDING_OVERFLOW_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt <= DEPTH
) else $error("SVA: write outstanding count exceeded DEPTH");


/* Exercise more than one completed write awaiting B response. */
QUEUE04_MULTIPLE_OUTSTANDING_WRITES_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt >= 2
) $display("SVA_COVER: QUEUE-04 multiple outstanding writes exercised, outst_cnt=%0d", $sampled(outst_cnt));


/* Stronger evidence: reach at least three simultaneously outstanding writes. */
QUEUE04_THREE_OUTSTANDING_WRITES_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt >= 3
) $display("SVA_COVER: QUEUE-04 at least three writes simultaneously outstanding");


/* A B retirement removes exactly one obligation when no new pair completes. */
QUEUE04_SINGLE_WRITE_RETIREMENT_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (retire_fire && !pair_fire && (outst_cnt != '0))
    |=> outst_cnt == ($past(outst_cnt) - 1'b1)
) else $error("SVA: write retirement did not decrement outst_cnt by exactly one");

/*
 * QUEUE-05:
 * Verify write-queue capacity and admission control. Once the outstanding
 * response count reaches DEPTH, another upstream AW must be backpressured.
 * Admission must resume after an earlier B response retires and frees space.
 */

/* Outstanding write bookkeeping must never exceed the implemented depth. */
QUEUE05_NO_WRITE_OVERFLOW_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt <= DEPTH
) else $error("SVA: write outstanding count exceeded DEPTH");


/* A new write address must not be accepted while the response queue is full. */
QUEUE05_BLOCK_WHILE_FULL_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((outst_cnt == DEPTH) && s.awvalid)
    |-> (!s.awready)
) else $error("SVA: write address accepted while outstanding queue was full");


/* Prove that the configured write capacity was actually reached. */
QUEUE05_WRITE_FULL_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt == DEPTH
) $display("SVA_COVER: QUEUE-05 write queue reached configured DEPTH");


/* Prove an additional write was actively backpressured while full. */
QUEUE05_FULL_BACKPRESSURE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (outst_cnt == DEPTH) && s.awvalid && !s.awready
) $display("SVA_COVER: QUEUE-05 additional write blocked while queue full");


/* Prove admission resumed after capacity became available. */
QUEUE05_REOPEN_ADMISSION_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((outst_cnt == DEPTH) && s.awvalid && !s.awready)
    ##[1:$]
    pair_fire
) $display("SVA_COVER: QUEUE-05 write admission resumed after queue capacity became available");

/*
 * PROT-03:
 * Once the guard presents a downstream write-address request, AXI requires
 * AWVALID and its associated payload to remain stable while AWREADY is low.
 */
PROT03_AW_STABLE_WHILE_STALLED_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (m.awvalid && !m.awready)
    |=> (
        m.awvalid &&
        $stable(m.aw.addr) &&
        $stable(m.aw.prot)
    )
) else $error("SVA: downstream AWVALID or AW payload changed while AWREADY was low");


/*
 * Prove that sustained downstream AW backpressure was genuinely exercised
 * before the address handshake eventually completed.
 */
PROT03_AW_BACKPRESSURE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (m.awvalid && !m.awready)
    ##1
    (m.awvalid && !m.awready)
    ##[1:$]
    (m.awvalid && m.awready)
) $display("SVA_COVER: PROT-03 downstream AW remained asserted through backpressure and completed");

/*
 * PROT-04:
 * Once the guard presents downstream write data, AXI requires WVALID and its
 * associated payload to remain stable while WREADY is low.
 */
PROT04_W_STABLE_WHILE_STALLED_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (m.wvalid && !m.wready)
    |=> (
        m.wvalid &&
        $stable(m.w.data) &&
        $stable(m.w.strb)
    )
) else $error("SVA: downstream WVALID or W payload changed while WREADY was low");


/*
 * Prove sustained downstream W-channel backpressure and eventual handshake.
 */
PROT04_W_BACKPRESSURE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (m.wvalid && !m.wready)
    ##1
    (m.wvalid && !m.wready)
    ##[1:$]
    (m.wvalid && m.wready)
) $display("SVA_COVER: PROT-04 downstream W remained asserted through backpressure and completed");

/*
 * PROT-05:
 * PR-01 deliberately forbids acceptance of upstream write data before the
 * corresponding write address has been accepted.
 */
PROT05_NO_W_ACCEPT_BEFORE_AW_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((wpair_state == WPAIR_IDLE) && s.wvalid && !s.awvalid)
    |-> !s.wready
) else $error("SVA: PR-01 violation: upstream WREADY asserted before the corresponding AW was presented");


/*
 * While W arrives early and the write pair is still waiting for its address,
 * WREADY must remain withheld.
 */
PROT05_EARLY_W_HELD_OFF_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((wpair_state == WPAIR_IDLE) && s.wvalid && !s.awvalid)
    |=> (!s.wready until_with (s.awvalid && s.awready))
) else $error("SVA: PR-01 violation: early upstream W was accepted before AW handshake");


/*
 * Prove that WVALID genuinely arrived before AWVALID and was held pending the
 * later address transfer.
 */
PROT05_W_BEFORE_AW_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (s.wvalid && !s.awvalid && !s.wready)
    ##1
    (s.wvalid && !s.awvalid && !s.wready)
    ##[1:$]
    (s.awvalid && s.awready)
    ##[0:2]
    (s.wvalid && s.wready)
) $display("SVA_COVER: PROT-05 early upstream W was withheld until the corresponding AW was accepted");


/*
 * While an upstream AW has been accepted but no corresponding W is yet
 * available, PR-01 forbids downstream launch of either channel.
 */
PROT06_NO_DOWNSTREAM_LAUNCH_WITHOUT_W_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((wpair_state == WPAIR_AW_ONLY) && !s.wvalid)
    |-> (!m.awvalid && !m.wvalid)
) else $error("SVA: PR-01 violation: downstream AW/W launched while corresponding upstream W was unavailable");


/*
 * Prove that the accepted AW was genuinely retained while W remained absent.
 */
PROT06_AW_HELD_WAITING_FOR_W_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((wpair_state == WPAIR_AW_ONLY) && !s.wvalid && !m.awvalid && !m.wvalid)
    ##1
    ((wpair_state == WPAIR_AW_ONLY) && !s.wvalid && !m.awvalid && !m.wvalid)
) $display("SVA_COVER: PROT-06 accepted upstream AW was held while waiting for corresponding W");


/*
 * Once W becomes available, the complete pair may launch immediately.
 * Verify that downstream AW and W are initiated together.
 */
PROT06_PAIR_LAUNCH_AFTER_W_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((wpair_state == WPAIR_AW_ONLY) && s.wvalid)
    ##0
    (m.awvalid && m.wvalid)
) $display("SVA_COVER: PROT-06 downstream AW/W launched together when delayed W became available");

/*
 * PROT-07:
 * Once the guard presents an upstream write response, AXI requires BVALID and
 * BRESP to remain stable while the manager withholds BREADY.
 */
PROT07_B_STABLE_WHILE_STALLED_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (s.bvalid && !s.bready)
    |=> (
        s.bvalid &&
        $stable(s.b.resp)
    )
) else $error("SVA: upstream BVALID or BRESP changed while BREADY was low");


/*
 * Prove that genuine upstream B-channel backpressure was sustained for
 * multiple cycles before the response was eventually accepted.
 */
PROT07_B_BACKPRESSURE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (s.bvalid && !s.bready)
    ##1
    (s.bvalid && !s.bready)
    ##[1:$]
    (s.bvalid && s.bready)
) $display("SVA_COVER: PROT-07 upstream write response remained asserted through backpressure and completed");

endmodule : wr_queue_sva

bind wr_queue wr_queue_sva #(
    .DEPTH(DEPTH),
    .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
) wr_sva (
    .clk(clk),
    .rst_n(rst_n),
    .epoch_clr(epoch_clr),
    .flush(flush),
    .timeout_pulse(timeout_pulse),
    .w_fault_pulse(w_fault_pulse),
    .outst_cnt(outst_cnt),
    .drain_cnt(drain_cnt),
    .wr_state(wr_state),
    .wpair_state(wpair_state),
    .w_timer(w_timer),
    .w_timer_run(w_timer_run),
    .b_timer_run(b_timer_run),
    .pair_fire   (pair_fire),
    .retire_fire (retire_fire),
    .b_timer(b_timer),
    .b_timeout_hit(b_timeout_hit),
    .downstream_aw_fire(downstream_aw_fire),
    .downstream_w_fire(downstream_w_fire),
    .downstream_pair_done(downstream_pair_done),
    .ghost_fire(ghost_fire),
    .inject_fire(inject_fire),
    .s(s),
    .m(m)
);