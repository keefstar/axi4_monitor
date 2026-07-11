/** Author: Keefee Rahman
 * @brief W-order FIFO for the AXI4 write scoreboard.
 *
 * AXI4 removes WID and forbids write-data interleaving, so W beats can
 * only be attributed to a transaction by AW-acceptance order.  This FIFO
 * stores the scoreboard slot index of each accepted AW transaction in the
 * order it was allocated.  The W Data Tracker reads the head entry to know
 * which slot's beats_left to decrement on each W beat.  On WLAST the head
 * entry is popped and that slot advances from WR_WAIT_W to WR_WAIT_B.
 *
 * Depth = N_SLOTS: at most one FIFO entry per scoreboard slot can be
 * outstanding at any time, so this is the tightest safe bound.
 *
 * The full flag feeds Write Admission as one of its four gate terms —
 * if the FIFO is full no new AW transaction is accepted even if a free
 * scoreboard slot exists.
 *
 * On force_free (WR_W_FAULT recovery): the flush input clears the entire
 * FIFO.  This is safe because write_blocked has already gated all new AW
 * admissions, so the only entry that can be in the FIFO at flush time is
 * the faulted slot's own entry.
 */
import firewall_pkg::*;
module w_order_fifo (
    input logic clk, reset,
    /* Push: driven by the Write Allocator on each AW handshake */
    input logic push,
    input logic [$clog2(N_SLOTS)-1:0]   push_idx,   /* slot index allocated */
    /* Pop: driven by the W Data Tracker on WLAST */
    input logic  pop,
    /* Head: the slot index currently responsible for incoming W beats */
    output logic [$clog2(N_SLOTS)-1:0]  head_idx,
    output logic head_valid, /* FIFO not empty */
    /* Status */
    output logic  full,
    output logic empty,
    /* Flush: asserted by Recovery Control on force_free for WR_W_FAULT.
     * Clears the FIFO in one cycle.  write_blocked guarantees at most
     * one entry is present at flush time. */
    input logic flush
);

/*
In AXI4, a write address has an ID of AWID, and a write resopnse has an ID of BID. But write data is provided with no similar label.
Per AXI4 specifications, W data must arrive in the same order as AW acceptance. This FIFO helps track the ordering using a queue mechanism.
Say the guard accepts AWID: 3,5,9 and allocates to slots 2,7,1. The FIFO likewisre stores slot 2,7,1. When W beats arrive, the W data tracker reads head_idx.
It would read 2. It would hten decrement write_scoreboard[2].beats_left--
When WLAST arrives for that burst, the FIFO pops slot 2, and then slot 7 becomes the front of the queue.
*/
localparam DEPTH = N_SLOTS;
localparam IDX_WIDTH = $clog2(N_SLOTS);
logic [IDX_WIDTH-1:0] mem [DEPTH]; /* Fifo Storage*/
logic [$clog2(DEPTH):0] wr_ptr, rd_ptr; /* one extra bit for full/empty distinction */

assign empty = (wr_ptr == rd_ptr);
assign full = (wr_ptr[IDX_WIDTH] != rd_ptr[IDX_WIDTH]) && (wr_ptr[IDX_WIDTH-1:0] == rd_ptr[IDX_WIDTH-1:0]);
assign head_idx = mem[rd_ptr[IDX_WIDTH-1:0]];
assign head_valid = !empty;
always_ff @(posedge clk) begin
    if (reset || flush) begin
        wr_ptr <= '0;
        rd_ptr <= '0;
    end else begin
        if (push && !full) begin
            mem[wr_ptr[IDX_WIDTH-1:0]] <= push_idx;
            wr_ptr <= wr_ptr + 1'b1;
        end
        if (pop && !empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end
end

endmodule
