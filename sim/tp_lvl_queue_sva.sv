/*
 * Queue-level assertions requiring simultaneous visibility of the independent
 * read and write paths. These checks are bound at tp_lvl because the read and
 * write queues are separate RTL instances.
 */

module tp_lvl_queue_sva (
    input logic clk,
    input logic rst_n,
    input logic rd_busy,
    input logic wr_busy
);

/* QUEUE-06: prove that read and write obligations coexist simultaneously. */
QUEUE06_READ_WRITE_CONCURRENT_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    rd_busy && wr_busy
) $display("SVA_COVER: QUEUE-06 read and write paths simultaneously busy");


/* Exercise a transition where one path drains while the other remains active. */
QUEUE06_INDEPENDENT_RETIREMENT_COV: cover property (
    @(posedge clk) disable iff (!rst_n)
    (rd_busy && wr_busy)
    ##[1:$]
    ((!rd_busy && wr_busy) || (rd_busy && !wr_busy))
) $display("SVA_COVER: QUEUE-06 one transaction path drained independently of the other");

endmodule : tp_lvl_queue_sva


bind tp_lvl tp_lvl_queue_sva queue_sva (
    .clk(clk),
    .rst_n(rst_n),
    .rd_busy(rd_busy),
    .wr_busy(wr_busy)
);