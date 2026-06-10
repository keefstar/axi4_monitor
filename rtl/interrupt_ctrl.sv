/* DEFINE SPEC */
/* LEVEL-TRIGGERED, SOFTWARE-CLEARED INTERRUPT MECHANISM*/
/* LOGIC DEFINED:
violation_notif has each bit reserved for a specific fault (for AXI4-Lite, bit 0 is for a writeFSM interrupt
status_reg records which fault fired; enable_reg is controlled by software to allow/mask specific faults
pending is simply the answer to whether the processor should be bothered right now.
*/
import watchdog_pkg::*;

module interrupt_ctrl #(
    parameter NUM_SOURCES = 2

)(
    input logic clk, reset,
    input logic [NUM_SOURCES - 1 : 0] violation_notif,
    input logic [NUM_SOURCES -1: 0] enable_reg, clear_reg, 
    output logic [NUM_SOURCES-1:0] rcvy_ack,
    output logic irq 
);

/* status_reg takes N input ires and records which ones fired (it takes violation_notif[N-1:0] and records which bits went high)*/
logic [NUM_SOURCES-1:0] status_reg; /* AXI4-Lite bit 0 = write violation, bit 1 = read*/
logic [NUM_SOURCES-1:0] pending; 
assign pending = status_reg & enable_reg; /* A violation is pending only if it occurred AND software has not masked it.
/* wire for processor; high when any unmasked violation is pending - level sensitive*/
assign irq = |pending; 

/* Sequential logic block */
always_ff @ (posedge clk) begin
    if (reset) begin
        status_reg <= '0;
        rcvy_ack <= '0;
    end else begin
        /* Two parts to status_reg update; 1) erase bits after software updates it in clear_reg and 2) is record part; bring in any new violation bits that may have fired*/
        status_reg <= (status_reg & ~clear_reg) | violation_notif;
        rcvy_ack <= clear_reg;
    end
end
endmodule
