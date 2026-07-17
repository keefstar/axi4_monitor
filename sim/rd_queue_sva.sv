
/* SVA assertions for read_queue for AXI4-lite transactions */
import a4lite_pkg::*;
module rd_queue_sva(
    input logic clk, rst_n,
    input logic epoch_clr, flush,
    input logic timeout_pulse
);

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

endmodule : rd_queue_sva

/* Bind into every rd_queue instance */
/* bind, design module, assertion module, instnatiation name, design module variable)*/
/* interfaces wo */
bind rd_queue rd_queue_sva rd_sva (
    .clk(clk), .rst_n(rst_n),
    .epoch_clr(epoch_clr), .flush(flush),
    .timeout_pulse(timeout_pulse)
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
