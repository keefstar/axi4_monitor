/* DEFINE SPEC */
/* LEVEL-TRIGGERED, SOFTWARE-CLEARED INTERRUPT MECHANISM*/

/*
Interrupt controller generally satisfying the following constraints:
1) Any number fo interrupt wires (from physical devices) routed to an encoder 
2) The encoder has some priority*
3) The interrupt lines may be edge or level sensitive
4) The controller knows how to put a transaction onto the interconnect (local controller) or bus c(I/O controller) to notify the core of the interrupt number
5) The controller has some protocol whereby the CPU may acknowledge the interrupts, if required
6) The controller may have some protocol for pending an interrupt for delivery to the CPU, in the event that multiple interrupts occur simultaneously
*/
module interrupt_ctrl #(
    parameter NUM_SOURCES = 2

)(
    input logic clk, reset,
    /* SOFTWARE INTERFACE - CPU REGISTER CONTROL */
    input logic [NUM_SOURCES - 1 : 0] violation_notif,
    input logic [NUM_SOURCES -1: 0] enable_reg, clear_reg, /*enable_reg = software says which sources are allowed to trigger an interrupt */
    output logic sub_reset_done,
    output logic irq
);
/* status_reg takes N input ires and records which ones fired (it takes violation_notif[N-1:0] and records which bits went high)*/
logic [NUM_SOURCES-1:0] status_reg; /* AXI4-Lite bit 0 = write violation, bit 1 = read*/
logic [NUM_SOURCES-1:0] pending; /* 2 bits for AXI4-lite case*/
assign pending = status_reg & enable_reg;
/* A violation is pending only if it occurred AND software has not masked it.
 * Separates "did this happen" from "should the processor care right now." */

/* wire for processor; high when any unmasked violation is pending - level sensitive*/
assign irq = |pending;
/* Sequential logic block */
always_ff @ (posedge clk) begin
    if (reset) begin
        status_reg <= '0;
        sub_reset_done <= '0;
    end else begin
        sub_reset_done <= '0;
        if (|violation_notif) begin
            status_reg <= status_reg | violation_notif;
        end
        if (|clear_reg) begin
            /* SOFTWARE ASSERTS HIGH FOR CORRESPONDING INTERRUPT BIT*/
            status_reg <= status_reg & ~clear_reg;
            sub_reset_done <= 1'b1;
        end
    end
end
endmodule
/* An IRQ wire (Interrupt Request) is a line in a system that a hardware device uses to get the attention of the CPU */

/*
FLOW:
Hardware event -> Sticky Pending Register -> IRQ wire -> Software reads status register -> Software writes clear register -> pending bit clears -> IRQ wire goes low

*/