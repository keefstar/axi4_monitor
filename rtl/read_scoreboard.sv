
import firewall_pkg::*;
module read_scoreboard (
    parameter int SLOT_W = $clog2(SB_DEPTH);
)(
    input logic clk, reset,
    input logic, ARVALID,
    output logic ARREADY, 
    input logic [ID_WIDTH-1:0] ARID,
    input logic [ADDR_WIDTH-1: 0] ARADDR,
    input logic [LEN_WIDTH-1:0] ARLEN
);

sb_read_entry_t [SB_DEPTH-1:0] read_sb;
logic [SB-DEPTH-1 :0] free_tracker;
always_comb begin
    for (int i = 0; i < SB_DEPTH; i++) begin
        free_tracker = (read_sb[i].state == SB_FREE)
    end
end


endmodule
/* design goals */
