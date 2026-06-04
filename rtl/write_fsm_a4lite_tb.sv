'timescale 1ns/1ps
module w_fsm_tb;
/* Inputs to DUT */
logic clk, reset;
logic rcvy_ack, violation_notif, inject_en, regulate_en;
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

/* Interrupt Controller Instantiation */
interrupt_ctrl #(
    .NUM_SOURCES(2)
) intr_ctrl (
    .clk            (clk),
    .reset          (reset),
    .violation_notif({1'b0, violation_notif}), /* bit 0 = write FSM; bit 1 reserved for read FSM */
    .enable_reg     (enable_reg),
    .clear_reg      (clear_reg),
    .sub_reset_done (sub_reset_done),
    .irq            (irq)
);
/* Clock generation*/
initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

task reset_dut();
    reset = 1'b1;
    repeat (5) @(posedge clk);
    reset = 1'b0;
    @(posedge clk);
    assert(dut.state == IDLE)
        else $error("FAILED: Expected state IDLE after reset, but got %s", dut.state.name());
endtask

initial begin

    reset_dut();
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
    assert (dut.state == AW_RECEIVED)
        else $error("FAILED: Expected state AW_RECEIVED, but got %s", dut.state.name());
    {AWVALID, AWREADY} = '0; /* Manager is allowed to deassert after the AW handshake is complete*/
    /* Small delay between AW and W handshakes*/
    repeat (5) @ (posedge clk);
    /* In AXI4-Lite burst length is always 1. There is only ever one data beat. So WLAST is always high on the same cycle as WVALID */
    {WVALID, WLAST, WREADY} = 3'b111; /* Can set all as 1 for AXI4-Lite case*/
    @(posedge clk); // handshake fires here
    @(posedge clk); // W_ACTIVE registers here /Cycle 1*/
    /* Write data is transferred -- TIMER starts now*/
    assert(dut.state == W_ACTIVE); /* CHECK CORRECT STATE*/
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
    assert(dut.state == IDLE);
        else $error("FAILED: Expected state IDLE, but got %s", dut.state.name());
    $display("Test 1: Succesfully finished");
    /**********************************************************************/
    /* RESET DUT FOR TEST 2*/
    reset_dut();
    $display("Performing Test 2 (Stall Detection and Recovery)");
    /* Follow same sequence until threshold where BVALID will not be asserted high by the subordinate*/
    AWVALID = 1'b1;
    @(posedge clk);
    AWREADY = 1'b1;
    @(posedge clk);
    @(posedge clk);
    assert (dut.state == AW_RECEIVED)
        else $error("FAILED: Expected state AW_RECEIVED, but got %s", dut.state.name());
    {AWVALID, AWREADY} = '0; 
    repeat (5) @ (posedge clk);
    {WVALID, WLAST, WREADY} = 3'b111; 
    @(posedge clk); /* handshake fires, next_state = W_ACTIVE */
    @(posedge clk); /* state is actually W_ACTIVE now; timer starts next cycle */
    assert(dut.state == W_ACTIVE); 
        else $error("FAILED: Expected state W_ACTIVE, but got %s", dut.state.name());
    {WVALID, WREADY, WLAST} ='0; 
    repeat (150) @ (posedge clk); 
    BREADY = 1'b1; 
    repeat (50) @ (posedge clk);
    @(posedge clk);
    assert(dut.state == W_VIOLATION); /* should onlt be in vilolation for one state */
        else $error("FAILED: Expected state W_VIOLATION, but got %s", dut.state.name());
    @(posedge clk);
    assert(dut.state == W_RECOVERY); 
        else $error("FAILED: Expected state W_RECOVERY, but got %s", dut.state.name());
 end

endmodule