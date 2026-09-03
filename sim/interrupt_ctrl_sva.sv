import a4lite_pkg::*;

module interrupt_ctrl_sva (
    input logic clk,
    input logic rst_n,

    input logic [NUM_FAULT_SOURCES-1:0] violation_notif,
    input logic [NUM_FAULT_SOURCES-1:0] status_reg,
    input logic [NUM_FAULT_SOURCES-1:0] clear_reg,
    input logic [NUM_FAULT_SOURCES-1:0] enable_reg,
    input logic quiescent,
    input logic irq
);

  /* FLT-01:
     a read-timeout notification must be retained in the sticky status register. */
  FLT01_READ_TIMEOUT_RECORDED_CHK: assert property (
      @(posedge clk) disable iff (!rst_n)
      violation_notif[READ_TIMEOUT]
      |=> status_reg[READ_TIMEOUT]
  ) else $error("SVA: READ_TIMEOUT notification was not recorded in status_reg");

  /* FLT-01:
     with only a read timeout stimulated, unrelated fault-source bits must remain clear. */
     FLT01_CORRECT_SOURCE_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (violation_notif[READ_TIMEOUT] &&
     status_reg == '0)
    |=> (status_reg[READ_TIMEOUT] &&
         !status_reg[WRITE_DATA_TIMEOUT] &&
         !status_reg[WRITE_RESP_TIMEOUT])
    ) else $error("SVA: incorrect fault source recorded for isolated read timeout");

  FLT01_READ_TIMEOUT_STATUS_COV: cover property (
      @(posedge clk) disable iff (!rst_n)
      status_reg[READ_TIMEOUT]
  ) $display("SVA_COVER: FLT-01 READ_TIMEOUT recorded in status register");

  /* FLT-02:
    a write-data-timeout notification must be retained in status_reg. */
    FLT02_WRITE_DATA_TIMEOUT_RECORDED_CHK: assert property (
        @(posedge clk) disable iff (!rst_n)
        violation_notif[WRITE_DATA_TIMEOUT]
        |=> status_reg[WRITE_DATA_TIMEOUT]
    ) else $error("SVA: WRITE_DATA_TIMEOUT notification was not recorded in status_reg");


    /* FLT-02:
    with only a write-data timeout stimulated, unrelated source bits stay clear. */
   FLT02_CORRECT_SOURCE_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (violation_notif[WRITE_DATA_TIMEOUT] &&
     status_reg == '0)
    |=> (!status_reg[READ_TIMEOUT] &&
         status_reg[WRITE_DATA_TIMEOUT] &&
         !status_reg[WRITE_RESP_TIMEOUT])
    ) else $error("SVA: incorrect fault source recorded for isolated write-data timeout");


    FLT02_WRITE_DATA_TIMEOUT_STATUS_COV: cover property (
        @(posedge clk) disable iff (!rst_n)
        status_reg[WRITE_DATA_TIMEOUT]
    ) $display("SVA_COVER: FLT-02 WRITE_DATA_TIMEOUT recorded in status register");

/* FLT-03:
    a write-response-timeout notification must be retained in status_reg. */
    FLT03_WRITE_RESP_TIMEOUT_RECORDED_CHK: assert property (
        @(posedge clk) disable iff (!rst_n)
        violation_notif[WRITE_RESP_TIMEOUT]
        |=> status_reg[WRITE_RESP_TIMEOUT]
    ) else $error("SVA: WRITE_RESP_TIMEOUT notification was not recorded in status_reg");


    /* FLT-03:
    with only a write-response timeout stimulated, unrelated source bits stay clear. */
   FLT03_CORRECT_SOURCE_CHK: assert property (
    @(posedge clk) disable iff (!rst_n)
    (violation_notif[WRITE_RESP_TIMEOUT] &&
     status_reg == '0)
    |=> (!status_reg[READ_TIMEOUT] &&
         !status_reg[WRITE_DATA_TIMEOUT] &&
         status_reg[WRITE_RESP_TIMEOUT])
    ) else $error("SVA: incorrect fault source recorded for isolated write-response timeout");


    FLT03_WRITE_RESP_TIMEOUT_STATUS_COV: cover property (
        @(posedge clk) disable iff (!rst_n)
        status_reg[WRITE_RESP_TIMEOUT]
    ) $display("SVA_COVER: FLT-03 WRITE_RESP_TIMEOUT recorded in status register");

    /* FLT-04:
    once READ_TIMEOUT has been recorded, it must remain set while software
    has not requested a clear. */
    FLT04_STATUS_STICKY_CHK: assert property (
        @(posedge clk) disable iff (!rst_n)
        (status_reg[READ_TIMEOUT] && !clear_reg[READ_TIMEOUT])
        |=> status_reg[READ_TIMEOUT]
    ) else $error("SVA: READ_TIMEOUT status bit cleared without software acknowledgement");


    /* Exercise a cycle where the original notification is gone but status remains. */
    FLT04_STICKY_STATUS_COV: cover property (
        @(posedge clk) disable iff (!rst_n)
        status_reg[READ_TIMEOUT] &&
        !violation_notif[READ_TIMEOUT]
    ) $display("SVA_COVER: FLT-04 fault status retained after notification pulse");

    /* FLT-05:
   masking a source must not prevent its status bit from being recorded. */
    FLT05_MASKED_STATUS_RECORDED_CHK: assert property (
        @(posedge clk) disable iff (!rst_n)
        (violation_notif[READ_TIMEOUT] && !enable_reg[READ_TIMEOUT])
        |=> status_reg[READ_TIMEOUT]
    ) else $error("SVA: masked READ_TIMEOUT was not recorded in status_reg");


    /* FLT-05:
    a masked READ_TIMEOUT must not raise irq once the guard is quiescent. */
    FLT05_MASKED_FAULT_NO_IRQ_CHK: assert property (
        @(posedge clk) disable iff (!rst_n)
        (status_reg[READ_TIMEOUT] &&
        !enable_reg[READ_TIMEOUT] &&
        quiescent)
        |-> !irq
    ) else $error("SVA: masked READ_TIMEOUT incorrectly asserted irq");


    FLT05_MASKED_FAULT_COV: cover property (
        @(posedge clk) disable iff (!rst_n)
        status_reg[READ_TIMEOUT] &&
        !enable_reg[READ_TIMEOUT] &&
        quiescent &&
        !irq
    ) $display("SVA_COVER: FLT-05 masked fault recorded without asserting irq");

    /* FLT-06:
   an enabled recorded fault must not interrupt software before quiescence. */
    FLT06_NO_IRQ_BEFORE_QUIESCENCE_CHK: assert property (
        @(posedge clk) disable iff (!rst_n)
        (status_reg[READ_TIMEOUT] &&
        enable_reg[READ_TIMEOUT] &&
        !quiescent)
        |-> !irq
    ) else $error("SVA: enabled READ_TIMEOUT asserted irq before quiescence");


    /* FLT-06:
    once an enabled recorded fault is pending and the guard is quiescent,
    irq must be asserted. */
    FLT06_IRQ_ON_QUIESCENCE_CHK: assert property (
        @(posedge clk) disable iff (!rst_n)
        (status_reg[READ_TIMEOUT] &&
        enable_reg[READ_TIMEOUT] &&
        quiescent)
        |-> irq
    ) else $error("SVA: enabled pending READ_TIMEOUT failed to assert irq");


    FLT06_ENABLED_IRQ_COV: cover property (
        @(posedge clk) disable iff (!rst_n)
        status_reg[READ_TIMEOUT] &&
        enable_reg[READ_TIMEOUT] &&
        quiescent &&
        irq
    ) $display("SVA_COVER: FLT-06 enabled pending fault asserted irq at quiescence");

    /* FLT-07:
   simultaneous independent fault notifications must both be recorded. */
    FLT07_MULTIPLE_FAULTS_RECORDED_CHK: assert property (
        @(posedge clk) disable iff (!rst_n)
        (violation_notif[READ_TIMEOUT] &&
        violation_notif[WRITE_DATA_TIMEOUT])
        |=> (status_reg[READ_TIMEOUT] &&
            status_reg[WRITE_DATA_TIMEOUT])
    ) else $error("SVA: simultaneous fault sources were not both recorded");


    FLT07_MULTIPLE_FAULTS_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    status_reg[READ_TIMEOUT] &&
    status_reg[WRITE_DATA_TIMEOUT]
    ) $display("SVA_COVER: FLT-07 multiple fault sources recorded independently");

    FLT07_SIMULTANEOUS_NOTIF_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    violation_notif[READ_TIMEOUT] &&
    violation_notif[WRITE_DATA_TIMEOUT]
    ) $display("SVA_COVER: FLT-07 simultaneous read and write-data fault notifications exercised");

endmodule : interrupt_ctrl_sva


bind interrupt_ctrl interrupt_ctrl_sva interrupt_ctrl_sva_i (
    .clk (clk),
    .rst_n(rst_n),
    .violation_notif (violation_notif),
    .status_reg (status_reg),
    .enable_reg (enable_reg),
    .quiescent(quiescent),
    .irq(irq),
    .clear_reg(clear_reg)
);