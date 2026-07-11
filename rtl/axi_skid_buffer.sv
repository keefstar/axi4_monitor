

/** Author: Keefee Rahman
 * @brief: The guard uses skid buffers as minimal elastic pipeline stages on AXI4 ready/valid channels.
 * Each buffer decouples upstream and downstream handshake timing by replacing a long combinational ready path with local storage-based flow control.
 * This allows the guard to stall/inspect/recover a channel without losing/duplicating/reordering beats.
 */

module axi_skid_buffer #(
    parameter int WIDTH = 32
)(
    input  logic clk, reset,
    /* Upstream (source) facing */
    input  logic valid_in, /* AXI4; this is from the manager */
    output logic ready_out, /* AXI4; this is to the manager */
    input  logic [WIDTH-1:0] data_in, /* from manager */
    /* Downstream (destination) facing */
    output logic valid_out, /* AXI4; to subordinate */
    input  logic ready_in, /* AXI4; from subordinate */
    output logic [WIDTH-1:0] data_out /* from manager to sub */
);

/* Backup storage slots */
logic skid_valid;
logic [WIDTH-1:0] skid_data;
 /* determines whether skid buffer can accept another data beat from maanager */
 /* buffer is full, and manager can accept data, but passthrough fails */
assign ready_out = !(valid_out && skid_valid);
always_ff @ (posedge clk) begin
    if (reset) begin
        {valid_out, data_out, skid_valid, skid_data} <= '0;
    end else begin
        // Update the main output slot only when it is empty or the downstream side is accepting its current beat.
        if (ready_in || !valid_out) begin
            if (skid_valid) begin
                valid_out  <= 1'b1;
                data_out   <= skid_data;
                skid_valid <= 1'b0;
            end else begin
                /* invisible case */
                valid_out <= valid_in;
                data_out <= data_in;
            end
        end else if (valid_in) begin /* The main output slot is full, and the subordinate is not taking it.*/
            skid_valid <= 1'b1;
            skid_data  <= data_in;
        end
    end
end
endmodule
