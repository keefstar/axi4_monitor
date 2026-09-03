/*
 * Recovery and epoch-management assertions.
 *
 * These properties verify the top-level recovery protocol implemented by
 * tp_lvl. Individual read/write queue assertions verify the source faults;
 * this checker verifies how the guard responds to those faults globally.
 */

module tp_lvl_recovery_sva (
    input logic clk,
    input logic rst_n,
    input guard_mode_e mode,
    input logic [NUM_FAULT_SOURCES-1:0] violation_notif,
    input logic flush,
    input logic all_upstream_empty,
    input logic [NUM_FAULT_SOURCES-1:0] status_reg,
    input logic irq,
    input logic [NUM_FAULT_SOURCES-1:0] clear_reg,
    input logic epoch_clr,
    input logic [NUM_FAULT_SOURCES-1:0] rcvy_ack
);

  import a4lite_pkg::*;


/*
 * REC-01:
 * A fault detected while the guard is operating normally must force the
 * top-level guard into containment on the following cycle.
 */
REC01_FAULT_ENTERS_CONTAINMENT_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_NORMAL) && (|violation_notif))
    |=> (mode == GUARD_CONTAINING)
) else $error("SVA: fault detected in NORMAL did not transition guard into CONTAINING");


/*
 * Containment must assert flush so that outstanding upstream obligations are
 * resolved rather than allowing the failed transaction epoch to continue.
 */
REC01_CONTAINMENT_ASSERTS_FLUSH_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (mode == GUARD_CONTAINING) |-> flush
) else $error("SVA: flush was not asserted while guard was in CONTAINING");


/*
 * Visible evidence that REC-01 exercised the complete transition of interest.
 */
REC01_CONTAINMENT_ENTRY_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_NORMAL) && (|violation_notif))
    ##1
    ((mode == GUARD_CONTAINING) && flush)
) $display("SVA_COVER: REC-01 fault forced guard from NORMAL into CONTAINING with flush asserted");

/*
 * REC-02:
 * While containment still owes one or more upstream completions, the failed
 * transaction epoch is not quiescent and the guard must remain in CONTAINING.
 */
REC02_HOLD_CONTAINMENT_UNTIL_QUIESCENT_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_CONTAINING) && !all_upstream_empty)
    |=> (mode == GUARD_CONTAINING)
) else $error("SVA: guard left CONTAINING while upstream obligations remained");


/*
 * Any transition from CONTAINING into RECOVERY must have been authorized by
 * upstream quiescence in the preceding cycle.
 */
REC02_RECOVERY_REQUIRES_QUIESCENCE_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (($past(mode) == GUARD_CONTAINING) && (mode == GUARD_RECOVERY))
    |-> $past(all_upstream_empty)
) else $error("SVA: guard entered RECOVERY before upstream quiescence");


/*
 * Prove that REC-02 actually exercised containment while transactions were
 * still outstanding rather than entering containment only after quiescence.
 */
REC02_NONQUIESCENT_CONTAINMENT_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (mode == GUARD_CONTAINING) && !all_upstream_empty
) $display("SVA_COVER: REC-02 guard remained in containment with upstream obligations outstanding");


/*
 * Prove that the containment episode eventually reached upstream quiescence.
 */
REC02_CONTAINMENT_REACHES_QUIESCENCE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_CONTAINING) && !all_upstream_empty)
    ##[1:$]
    ((mode == GUARD_CONTAINING) && all_upstream_empty)
) $display("SVA_COVER: REC-02 containment reached upstream quiescence before recovery");


/*
 * REC-03:
 * Once READ_TIMEOUT has been recorded, its sticky status must survive the
 * containment episode until software explicitly writes the corresponding
 * clear bit.
 */
REC03_STATUS_PERSISTS_UNTIL_CLEAR_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (status_reg[READ_TIMEOUT] && !clear_reg[READ_TIMEOUT])
    |=> status_reg[READ_TIMEOUT]
) else $error("SVA: READ_TIMEOUT status cleared without software acknowledgment");


/*
 * Once the failed epoch is upstream-quiescent, an enabled pending fault must
 * continue to assert IRQ until software acknowledgment occurs.
 */
REC03_IRQ_PERSISTS_UNTIL_CLEAR_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (irq && !(|(clear_reg & status_reg)))
    |=> irq
) else $error("SVA: IRQ deasserted before fault acknowledgment");

/*
 * Prove that the fault status survives beyond containment and remains pending
 * after upstream quiescence has been established.
 */
REC03_STATUS_AT_QUIESCENCE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    status_reg[READ_TIMEOUT]
    ##[1:$]
    (all_upstream_empty && status_reg[READ_TIMEOUT])
) $display("SVA_COVER: REC-03 READ_TIMEOUT status persisted through containment to quiescence");


/*
 * Prove that IRQ remained asserted for multiple cycles while software delayed
 * its acknowledgment.
 */
REC03_IRQ_HELD_PENDING_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    irq && !clear_reg[READ_TIMEOUT]
    ##1
    irq && !clear_reg[READ_TIMEOUT]
    ##1
    irq && !clear_reg[READ_TIMEOUT]
) $display("SVA_COVER: REC-03 IRQ remained asserted while fault acknowledgment was withheld");


/*
 * Prove eventual explicit acknowledgment of the pending READ_TIMEOUT fault.
 */
REC03_CLEAR_ACK_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    status_reg[READ_TIMEOUT] && irq
    ##[1:$]
    clear_reg[READ_TIMEOUT]
) $display("SVA_COVER: REC-03 software acknowledgment issued for persistent READ_TIMEOUT fault");


/*
 * REC-04:
 * Epoch clear is forbidden while upstream obligations remain. An early
 * software acknowledgment must therefore be unable to terminate the failed
 * transaction epoch prematurely.
 */
REC04_NO_EPOCH_CLEAR_BEFORE_QUIESCENCE_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    !all_upstream_empty |-> !epoch_clr
) else $error("SVA: epoch_clr asserted before upstream quiescence");


/*
 * An early clear request during containment must not return the guard directly
 * to NORMAL while unresolved upstream obligations remain.
 */
REC04_EARLY_CLEAR_CANNOT_RETURN_NORMAL_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_CONTAINING) && !all_upstream_empty && (|clear_reg))
    |=> (mode != GUARD_NORMAL)
) else $error("SVA: early fault clear returned guard to NORMAL before quiescence");


/*
 * Prove that REC-04 actually issued software acknowledgment while containment
 * still had unresolved upstream obligations.
 */
REC04_EARLY_CLEAR_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (mode == GUARD_CONTAINING) && !all_upstream_empty && clear_reg[READ_TIMEOUT]
) $display("SVA_COVER: REC-04 READ_TIMEOUT clear issued before upstream quiescence");


/*
 * Prove that the early clear did not generate epoch_clr.
 */
REC04_EARLY_CLEAR_BLOCKED_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_CONTAINING) && !all_upstream_empty && clear_reg[READ_TIMEOUT])
    ##1
    (!epoch_clr && (mode != GUARD_NORMAL))
) $display("SVA_COVER: REC-04 early acknowledgment could not prematurely clear the failed epoch");

/*
 * REC-05:
 * Once containment has resolved all upstream obligations, the failed epoch is
 * quiescent and the guard must advance into GUARD_RECOVERY.
 */
REC05_QUIESCENCE_ENTERS_RECOVERY_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_CONTAINING) && all_upstream_empty)
    |=> (mode == GUARD_RECOVERY)
) else $error("SVA: guard did not enter RECOVERY after containment reached upstream quiescence");


/*
 * Prove that REC-05 exercised the intended CONTAINING-to-RECOVERY transition.
 */
REC05_CONTAINING_TO_RECOVERY_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_CONTAINING) && all_upstream_empty)
    ##1
    (mode == GUARD_RECOVERY)
) $display("SVA_COVER: REC-05 guard transitioned from CONTAINING to RECOVERY after upstream quiescence");

/*
 * REC-06:
 * epoch_clr may only be asserted when all three recovery authorization
 * conditions are simultaneously satisfied.
 */
REC06_EPOCH_CLEAR_AUTHORIZATION_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    epoch_clr |-> (
        (mode == GUARD_RECOVERY) &&
        all_upstream_empty &&
        (|rcvy_ack)
    )
) else $error("SVA: epoch_clr asserted without recovery mode, quiescence, and acknowledgment");


/*
 * A valid recovery acknowledgment while already in GUARD_RECOVERY and
 * upstream-quiescent must generate epoch_clr.
 */
REC06_VALID_ACK_GENERATES_EPOCH_CLEAR_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_RECOVERY) && all_upstream_empty && (|rcvy_ack))
    |-> epoch_clr
) else $error("SVA: valid recovery acknowledgment did not generate epoch_clr");


/*
 * Prove that the test reached the fully authorized epoch-clear condition.
 */
REC06_AUTHORIZED_EPOCH_CLEAR_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (mode == GUARD_RECOVERY) &&
    all_upstream_empty &&
    (|rcvy_ack) &&
    epoch_clr
) $display("SVA_COVER: REC-06 epoch clear occurred with recovery, quiescence, and acknowledgment");


/*
 * Prove the software clear produced the recovery acknowledgment used by the
 * top-level controller.
 */
REC06_CLEAR_TO_ACK_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    clear_reg[READ_TIMEOUT]
    ##[1:2]
    rcvy_ack[READ_TIMEOUT]
) $display("SVA_COVER: REC-06 READ_TIMEOUT clear produced recovery acknowledgment");

/*
 * REC-07:
 * An authorized epoch clear terminates the recovery epoch. The controller must
 * return to GUARD_NORMAL on the following state-update cycle.
 */
REC07_EPOCH_CLEAR_RETURNS_NORMAL_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_RECOVERY) && epoch_clr)
    |=> (mode == GUARD_NORMAL)
) else $error("SVA: authorized epoch_clr did not return guard to NORMAL");


/*
 * NORMAL operation must remove the containment flush condition.
 */
REC07_NORMAL_RELEASES_FLUSH_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (mode == GUARD_NORMAL) |-> !flush
) else $error("SVA: flush remained asserted while guard was in NORMAL");


/*
 * Prove the complete recovery-to-normal transition.
 */
REC07_RECOVERY_TO_NORMAL_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_RECOVERY) && epoch_clr)
    ##1
    ((mode == GUARD_NORMAL) && !flush)
) $display("SVA_COVER: REC-07 epoch clear returned guard from RECOVERY to NORMAL and released flush");

/*
 * REC-08:
 * A successfully cleared failed epoch must establish a new NORMAL operating
 * epoch. The UVM scoreboard independently verifies that a transaction issued
 * after this point completes normally.
 */
REC08_NEW_EPOCH_AVAILABLE_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    ((mode == GUARD_RECOVERY) && epoch_clr)
    ##1
    ((mode == GUARD_NORMAL) && !flush)
) $display("SVA_COVER: REC-08 completed recovery established a new NORMAL transaction epoch");

endmodule : tp_lvl_recovery_sva


bind tp_lvl tp_lvl_recovery_sva recovery_sva (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .violation_notif(violation_notif),
    .flush(flush),
    .all_upstream_empty(all_upstream_empty),
    .status_reg(status_reg),
    .irq(irq),
    .clear_reg(clear_reg),
    .epoch_clr(epoch_clr),
    .rcvy_ack(rcvy_ack)
);