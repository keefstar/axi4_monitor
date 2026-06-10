`timescale 1ns/1ps
module w_fsm_tb;
import watchdog_pkg::*;

/* Inputs to DUT */
logic clk, reset;
logic [NUM_SOURCES-1:0] rcvy_ack;
logic violation_notif, inject_en, regulate_en;
logic AWREADY, AWVALID, WREADY, WVALID, WLAST, BREADY, BVALID;

/* Interrupt controller signals */
logic [1:0] enable_reg, clear_reg;
logic sub_reset_done, irq;
/* DUT Instantiation*/
write_fsm_a4lite #(
    .TIMEOUT_COUNTER(200)
) dut (
    .clk          (clk),
    .reset        (reset),
    .AWREADY      (AWREADY),
    .AWVALID      (AWVALID),
    .WREADY       (WREADY),
    .WVALID       (WVALID),
    .WLAST        (WLAST),
    .BREADY       (BREADY),
    .BVALID       (BVALID),
    .rcvy_ack     (rcvy_ack),
    .violation_notif (violation_notif),
    .inject_en    (inject_en),
    .regulate_en  (regulate_en)
);

/* Clock generation*/
initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

task initialize_inputs();
    reset = 1'b0;
    rcvy_ack[WRITE_FAULT] = 1'b0;
    AWREADY = 1'b0;
    AWVALID  = 1'b0;
    WREADY  = 1'b0;
    WVALID = 1'b0;
    WLAST = 1'b0;
    BREADY = 1'b0;
    BVALID = 1'b0;
    enable_reg  = '0;
    clear_reg  = '0;
endtask

/* Reset DUT Task*/
task reset_dut();
    reset = 1'b1;
    repeat (5) @(posedge clk);
    reset = 1'b0;
    @(posedge clk);
    assert(dut.state == dut.IDLE)
        else $error("FAILED: Expected state IDLE after reset, but got %s", dut.state.name());
endtask


initial begin
    reset_dut();
    initialize_inputs();
    /**********************************************************************/
    $display("Performing Test 1 (Normal Transaction)");
    /* TEST 1: - Check if a transaction completes normally*/
    /* BEGIN AW HANDSHAKE PROCESS*/
    AWVALID = 1'b1;
    @(posedge clk);
    AWREADY = 1'b1;
    /* Data address is transferred when both AWVALID + AWREADY high @ (posedge clk) */
    @(posedge clk);
    @(posedge clk);
    /* CHECK CORRECT STATE*/
    assert (dut.state == dut.AW_RECEIVED)
        else $error("FAILED: Expected state AW_RECEIVED, but got %s", dut.state.name());
    {AWVALID, AWREADY} = '0; /* Manager is allowed to deassert after the AW handshake is complete*/
    /* Small delay between AW and W handshakes*/
    repeat (5) @ (posedge clk);
    /* In AXI4-Lite burst length is always 1. There is only ever one data beat. So WLAST is always high on the same cycle as WVALID */
    {WVALID, WLAST, WREADY} = 3'b111; /* Can set all as 1 for AXI4-Lite case*/
    @(posedge clk); // handshake fires here
    @(posedge clk); // W_ACTIVE registers here /Cycle 1*/
    /* Write data is transferred -- TIMER starts now*/
    assert(dut.state == dut.W_ACTIVE) /* CHECK CORRECT STATE*/
        else $error("FAILED: Expected state W_ACTIVE, but got %s", dut.state.name());
    {WVALID, WREADY, WLAST} ='0; /* Simple case of AXI4-Lite allows deassertion at once*/
    /* Prepare for transaction completion, at the edge of threshold violation avoidance */
    repeat (150) @ (posedge clk); 
    BREADY = 1'b1; /* Manager readies to recieve valid signal from subordinate*/
    /* Just below timeout threshold */
    repeat (47) @ (posedge clk);
    BVALID = 1'b1;
    @ (posedge clk);
    /* If BREADY && BVALID are high at a rising clock edge, the response handshake
   completes. Both signals may deassert after that edge. */
    {BREADY, BVALID} = '0;
    @ (posedge clk);
    assert(dut.state == dut.IDLE)
        else $error("FAILED: Expected state IDLE, but got %s", dut.state.name());
    $display("Test 1: Succesfully finished");
    /**********************************************************************/
    /* RESET DUT FOR TEST 2 */
    initialize_inputs();
    reset_dut();
    $display("Performing Test 2 (Stall Detection and Recovery)");
    /* AW HANDSHAKE */
    @(negedge clk);
    AWVALID = 1'b1;
    AWREADY = 1'b1;
    @(posedge clk);
    #1;
    assert(dut.state == dut.AW_RECEIVED)
        else $error("FAILED: Expected AW_RECEIVED, got %s",
                    dut.state.name());
    $display("AW_RECEIVED passed in Test 2");

    @(negedge clk);
    AWVALID = 1'b0;
    AWREADY = 1'b0;
    /* Small delay before write-data handshake */
    repeat (5) @(posedge clk);
    /* W HANDSHAKE  */
    @(negedge clk);
    WVALID = 1'b1;
    WREADY = 1'b1;
    WLAST  = 1'b1;

    @(posedge clk);
    #1;
    assert(dut.state == dut.W_ACTIVE)
        else $error("FAILED: Expected W_ACTIVE, got %s",
                    dut.state.name());

    $display("W_ACTIVE passed in Test 2");
    @(negedge clk);
    WVALID = 1'b0;
    WREADY = 1'b0;
    WLAST  = 1'b0;

    /* TIMEOUT  */
    repeat (150) @(posedge clk);
    @(negedge clk);
    BREADY = 1'b1;
    /*
    * Complete the remaining 50 W_ACTIVE cycles.
    * The timer reaches 200 here.
    */
    repeat (50) @(posedge clk);
    /*
    * One more rising edge registers W_VIOLATION,
    * because the FSM checks the already-registered timer value.
    */
    @(posedge clk);
    #1;
    assert(dut.state == dut.W_VIOLATION)
        else $error("FAILED: Expected W_VIOLATION, got %s",
                    dut.state.name());

    $display("W_VIOLATION passed in Test 2");
    /* INJECTION  */
    @(posedge clk);
    #1;

    assert(dut.state == dut.W_INJECT)
        else $error("FAILED: Expected W_INJECT, got %s",
                    dut.state.name());

    $display("W_INJECT passed in Test 2");

    /*
    * Standalone FSM test:
    * simulate the top-level module driving injected BVALID.
    */
    @(negedge clk);
    BVALID = 1'b1;
    @(posedge clk);
    #1;
    assert(dut.state == dut.W_RECOVERY)
        else $error("FAILED: Expected W_RECOVERY, got %s",
                    dut.state.name());

    $display("W_RECOVERY passed in Test 2");
    @(negedge clk);
    BVALID = 1'b0;

    /* RECOVERY ACKNOWLEDGMENT */
    @(negedge clk);
    rcvy_ack[WRITE_FAULT] = 1'b1;

    @(posedge clk);
    #1;
    assert(dut.state == dut.IDLE)
        else $error("FAILED: Expected IDLE after recovery, got %s",
                    dut.state.name());

    @(negedge clk);
    rcvy_ack[WRITE_FAULT] = 1'b0;

    $display("Test 2: Successfully finished");
    end
endmodule