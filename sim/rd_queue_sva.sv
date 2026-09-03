
/* SVA assertions for read_queue for AXI4-lite transactions */
import a4lite_pkg::*;
/* `bind` places this instance inside rd_queue's scope, but that does NOT give
   it implicit visibility into rd_queue's internal (non-port) signals by name.
   Every DUT signal an assertion below touches (outst_cnt, drain_cnt, rd_state,
   timer_run, inject_fire, s, m) must be a port here and explicitly wired up in
   the bind statement, since the RHS of each .port(net) is what gets resolved
   in the target's scope. */
module rd_queue_sva #(
    parameter int unsigned DEPTH = a4lite_pkg::DEPTH
)(
    input logic clk, rst_n,
    input logic epoch_clr, flush,
    input logic timeout_pulse,
    input logic [$clog2(DEPTH+1)-1:0] outst_cnt,
    input logic [$clog2(DEPTH+1)-1:0] drain_cnt,
    input rd_state_e rd_state,
    input logic timer_run,
    input logic inject_fire,
    input logic ghost_fire,
    input logic ar_fire,
    input logic retire_fire,
    input logic s_arvalid,
    input logic s_arready,
    /* Plain (unmodported) interface ports: this is a passive monitor, so it
       only ever reads s/m, never drives them. */
    axi4l_if s,
    axi4l_if m
);

localparam int unsigned CNT_W = $clog2(DEPTH + 1);

/* Assertion 1: if the guard is being erased, it mus tnot be done so if the manager is still owed responses (either real or injected SLVERR) */
NO_CLEAR_WHILE_OWING_CHK : assert property ( 
    @ (posedge clk) disable iff (!rst_n)
    /* antacedent/enabling condiiton - consequent/fulfilling condition */
    /* (|-> is for same cycle checks; |=> is for next cycle. if antacedent is true in cycle N, consequent must be in N + 1) */
    /* if a variable is not included in a condition, its value is 'don't care'. */
    /* eg: epoch_clr would not be checked at cycle N + 1 if using |=> */
    epoch_clr |-> (outst_cnt == '0)
) else $error("SVA: epoch_clr asserted with outst_cnt = %0d", outst_cnt);

/* Assertion 2: If nothing is happening in the FSM, the counter must likewise agree*/
IDLE_MEANS_NO_READS_CHK : assert property(
    @ (posedge clk) disable iff (!rst_n)
    ((rd_state == RD_IDLE) == (outst_cnt == '0))
)  else $error("SVA: state/count desync: rd_state=%s outst_cnt=%0d", rd_state.name(), outst_cnt);

/* Assertion 3 */
NO_FORWARDING_GHOSTS_CHK: assert property (
    @ (posedge clk) disable iff (!rst_n)
    ((drain_cnt != 0)|-> !(s.rvalid && (rd_state == RD_TRACKING)))
) else $error("SVA: forwarded while drain_cnt=%0d", drain_cnt);

DRAIN_OVERFLOW_CHK: assert property (
    @ (posedge clk) disable iff (!rst_n)
    (drain_cnt <= CNT_W'(DEPTH))
) else $error("SVA: drain_cnt overflow: %0d", drain_cnt);

FREEZE_ON_REAL_RESP_CHK: assert property (
    @ (posedge clk) disable iff (!rst_n)
    (((m.rvalid && (drain_cnt == '0)) && (rd_state == RD_TRACKING)) |-> !timer_run)
) else $error ("SVA: timer did not stop once the subordinate became ready to return read data");

DRAIN_ONLY_ON_INJECTION_CHK: assert property (
    @ (posedge clk) disable iff (!rst_n)
    (drain_cnt > $past(drain_cnt)) |-> $past(inject_fire)
) else $error ("SVA: drain count increased without an injector");

INJECTING_SHOWS_SLVERR_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (rd_state == RD_INJECTING) |-> (s.rvalid && (s.r.resp == RESP_SLVERR))
) else $error("SVA: INJECTING without SLVERR presented");

/* RTO-04: injected SLVERR must remain valid and stable while upstream manager applies backpressure */
INJECTED_SLVERR_STABLE_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((rd_state == RD_INJECTING) && s.rvalid && !s.rready)
    |=> (s.rvalid && (s.r.resp == RESP_SLVERR) && $stable(s.r))
) else $error("SVA: injected SLVERR changed or deasserted while upstream RREADY was low");

/* Did simulation ever reach a cycle where the SCC was injecting a response and the upstream manager was backpressuring it? */
RTO04_STALL_EXERCISED_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (rd_state == RD_INJECTING) && s.rvalid && !s.rready
) $display("SVA_COVER: RTO-04 stalled injected SLVERR exercised");

/* RTO-05: confirm a late downstream response was actually drained */
RTO05_GHOST_DRAIN_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ghost_fire
) $display("SVA_COVER: RTO-05 ghost response drain exercised"); 

/* QUEUE-01:
   exercise more than one simultaneously outstanding read transaction. */
QUEUE01_MULTIPLE_OUTSTANDING_READS_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt >= 2
) $display(
    "SVA_COVER: QUEUE-01 multiple outstanding reads exercised, outst_cnt=%0d",
    $sampled(outst_cnt)
);

QUEUE01_THREE_OUTSTANDING_READS_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt >= 3
) $display(
    "SVA_COVER: QUEUE-01 at least three reads simultaneously outstanding"
);

/* QUEUE-02:
   Once multiple reads are outstanding, each response retirement must remove
   exactly one outstanding upstream obligation. */
QUEUE02_SINGLE_RETIREMENT_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (retire_fire && !ar_fire && (outst_cnt != '0))
    |=> outst_cnt == ($past(outst_cnt) - 1'b1)
) else $error("SVA: read retirement did not decrement outst_cnt by exactly one");


/* Exercise sequential retirement while multiple requests are outstanding. */
QUEUE02_ORDERED_RETIREMENT_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (outst_cnt >= 3)
    ##[1:$] (retire_fire && outst_cnt == 3)
    ##[1:$] (retire_fire && outst_cnt == 2)
    ##[1:$] (retire_fire && outst_cnt == 1)
) $display("SVA_COVER: QUEUE-02 three outstanding reads retired sequentially");

/* Outstanding bookkeeping must never exceed the implemented queue depth. */
QUEUE01_READ_OUTSTANDING_OVERFLOW_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt <= DEPTH
) else $error("SVA: read outstanding count exceeded DEPTH");

/* QUEUE-03:
   the read outstanding count must never exceed the configured queue depth. */
QUEUE03_NO_READ_OVERFLOW_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt <= DEPTH
) else $error("SVA: read outstanding count exceeded DEPTH");


/* When the queue is full, an additional upstream read request must not be
   accepted until capacity becomes available. */
QUEUE03_BLOCK_WHILE_FULL_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((outst_cnt == DEPTH) && s_arvalid)
    |-> (!s_arready && !ar_fire)
) else $error("SVA: read request accepted while outstanding queue was full");


/* Prove that the configured queue capacity was actually reached. */
QUEUE03_READ_FULL_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    outst_cnt == DEPTH
) $display("SVA_COVER: QUEUE-03 read queue reached configured DEPTH");


/* Prove that an additional AR request was actively backpressured while full. */
QUEUE03_FULL_BACKPRESSURE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (outst_cnt == DEPTH) &&
    s_arvalid &&
    !s_arready
) $display("SVA_COVER: QUEUE-03 additional read request blocked while queue full");


/* Prove that the blocked request is subsequently admitted after capacity
   becomes available. */
QUEUE03_REOPEN_ADMISSION_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((outst_cnt == DEPTH) && s_arvalid && !s_arready)
    ##[1:$]
    ar_fire
) $display("SVA_COVER: QUEUE-03 read admission resumed after queue capacity became available");

/*
 * QUEUE-07:
 * Verify that retired read-queue capacity can be reused. Occupancy must first
 * rise, fall as responses retire, then rise again when new requests are
 * admitted into the freed entries.
 */

/* A retirement cannot occur when no upstream read obligation exists. */
QUEUE07_NO_READ_UNDERFLOW_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    retire_fire |-> (outst_cnt != '0)
) else $error("SVA: read retirement occurred with no outstanding transaction");


/* Prove occupancy falls after several reads retire and subsequently rises
   again when new requests reuse the released queue capacity. */
QUEUE07_READ_CAPACITY_REUSE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (outst_cnt >= 4)
    ##[1:$] ((outst_cnt <= 2) && (outst_cnt != '0))
    ##[1:$] (outst_cnt >= 4)
) $display("SVA_COVER: QUEUE-07 retired read capacity was reused by later requests");


/* Prove new admission occurs after occupancy has previously fallen. */
QUEUE07_READ_REENTRY_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (outst_cnt >= 4)
    ##[1:$] ((outst_cnt <= 2) && (outst_cnt != '0))
    ##[1:$] ar_fire
) $display("SVA_COVER: QUEUE-07 new read admitted after earlier retirements freed capacity");

/*
 * QUEUE-08:
 * Verify timeout behavior when the timed-out head transaction is not the only
 * outstanding read. Followers must remain represented in the bookkeeping,
 * while injected responses create downstream ghost-response debt that is
 * subsequently drained when the real subordinate responses arrive.
 */

/* Prove that a read timeout occurred while follower obligations still existed. */
QUEUE08_HEAD_TIMEOUT_WITH_FOLLOWERS_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    timeout_pulse && (outst_cnt >= 3)
) $display("SVA_COVER: QUEUE-08 head read timed out with follower reads outstanding");


/* The timed-out head must be retired by an injected response while additional
   upstream obligations still remain. */
QUEUE08_HEAD_INJECTION_WITH_FOLLOWERS_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    inject_fire && (outst_cnt >= 2)
) $display("SVA_COVER: QUEUE-08 timed-out head retired while follower obligations remained");


/* Timeout injection must create downstream response debt. */
QUEUE08_GHOST_DEBT_CREATED_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    inject_fire
    ##[1:$]
    (drain_cnt != '0)
) $display("SVA_COVER: QUEUE-08 timeout created downstream ghost-response debt");


/* Late real responses must eventually consume that debt. */
QUEUE08_GHOST_RESPONSES_DRAINED_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (drain_cnt != '0)
    ##[1:$]
    ghost_fire
    ##[1:$]
    (drain_cnt == '0)
) $display("SVA_COVER: QUEUE-08 late follower/head responses drained all ghost debt");


/*
 * PROT-01:
 * Once the guard presents a downstream read-address request, AXI requires
 * VALID and its associated payload to remain stable while READY is low.
 */
PROT01_AR_STABLE_WHILE_STALLED_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (m.arvalid && !m.arready)
    |=> (
        m.arvalid &&
        $stable(m.ar.addr) &&
        $stable(m.ar.prot)
    )
) else $error("SVA: downstream ARVALID or AR payload changed while ARREADY was low");


/*
 * Prove that the test exercised genuine downstream read-address backpressure
 * for multiple cycles and subsequently completed the handshake.
 */
PROT01_AR_BACKPRESSURE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (m.arvalid && !m.arready)
    ##1
    (m.arvalid && !m.arready)
    ##[1:$]
    (m.arvalid && m.arready)
) $display("SVA_COVER: PROT-01 downstream AR remained asserted through backpressure and completed");

/*
 * PROT-02:
 * Once the guard presents an upstream read response, AXI requires RVALID and
 * its associated response payload to remain stable while RREADY is low.
 */
PROT02_R_STABLE_WHILE_STALLED_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (s.rvalid && !s.rready)
    |=> (
        s.rvalid &&
        $stable(s.r.data) &&
        $stable(s.r.resp)
    )
) else $error("SVA: upstream RVALID or read-response payload changed while RREADY was low");


/*
 * Prove that genuine upstream response backpressure was exercised for
 * multiple cycles before the response was finally accepted.
 */
PROT02_R_BACKPRESSURE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (s.rvalid && !s.rready)
    ##1
    (s.rvalid && !s.rready)
    ##[1:$]
    (s.rvalid && s.rready)
) $display("SVA_COVER: PROT-02 upstream read response remained asserted through backpressure and completed");

endmodule : rd_queue_sva

/* Bind into every rd_queue instance */
/* bind, design module, assertion module, instnatiation name, design module variable)*/
/* interfaces wo */
bind rd_queue rd_queue_sva #(.DEPTH(DEPTH)) rd_sva (
    .clk(clk), .rst_n(rst_n),
    .epoch_clr(epoch_clr), .flush(flush),
    .timeout_pulse(timeout_pulse),
    .s_arvalid (s.arvalid),
    .s_arready (s.arready),
    .outst_cnt(outst_cnt), .drain_cnt(drain_cnt),
    .ar_fire     (ar_fire),
    .retire_fire (retire_fire),
    .rd_state(rd_state), .timer_run(timer_run), .inject_fire(inject_fire), .ghost_fire(ghost_fire),
    .s(s), .m(m)
);

/*
notes from cadence:
Assertion-Based Verification (ABV): structured use of assertions to describe nad verify deisgn properties.
assertions monitor and report 1) expected behavioru, 2) forbidden hevaiour.
used by static verifcation tools (no test vectors, formal math proof), and by dynamic verification tools
ABV also encompasses SVA constructs


CONCURRENT ASSERTIONS: DESCRIBE BEHAVIOURS THAT SPAN OVER TIME. UNLIKE IMMEDIAT ASSERTIONS, THE E EVALUATION MODEL IS BASED ON A BLOCK SO THAT A CONCNURRENT ASSERTION IS EVALUATED ONLY AT THE OCCURANCE OF A CLOCK TICK
RW_CHK : assert property ( @ (negedge clk) ! (we_en && rd_en));
*/
