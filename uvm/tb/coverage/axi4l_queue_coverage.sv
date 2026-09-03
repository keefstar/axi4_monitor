import a4lite_pkg::*;


/*
 * Read queue coverage is bound directly to rd_queue so internal occupancy,
 * retirement, timeout injection, and ghost-drain activity can be sampled.
 */
module axi4l_read_queue_coverage #(
    parameter int unsigned DEPTH = a4lite_pkg::DEPTH,
    parameter int unsigned CNT_W = $clog2(DEPTH + 1)
)(
    input logic clk,
    input logic rst_n,
    input logic [CNT_W-1:0] outst_cnt,
    input logic [CNT_W-1:0] drain_cnt,
    input logic ar_fire,
    input logic retire_fire,
    input logic inject_fire,
    input logic ghost_fire,
    input logic full
);

  bit cov_hit[string];
  string key;

  covergroup read_queue_cg @(posedge clk);

    option.per_instance = 1;

    /*
     * Distinguish empty, single-entry, intermediate, and full occupancy.
     */
    outst_cp: coverpoint outst_cnt iff (rst_n) {
      bins empty = {0};
      bins one = {1};
      bins partial[] = {[2:DEPTH-1]};
      bins full = {DEPTH};
    }

    /*
     * drain_cnt records downstream responses still owed after upstream timeout
     * responses have already retired transactions.
     */
    drain_cp: coverpoint drain_cnt iff (rst_n) {
      bins zero = {0};
      bins one = {1};
      bins multiple[] = {[2:DEPTH]};
    }

    /*
     * Exercise enqueue-only, retire-only, and simultaneous queue movement.
     */
    queue_op_cp: coverpoint {ar_fire, retire_fire} iff (rst_n) {
      bins idle = {2'b00};
      bins enqueue_only = {2'b10};
      bins retire_only = {2'b01};
      bins enqueue_and_retire = {2'b11};
    }

    /*
     * Timeout injection retires an upstream transaction with synthetic SLVERR.
     */
    inject_cp: coverpoint inject_fire iff (rst_n) {
      bins no = {0};
      bins yes = {1};
    }

    /*
     * Ghost responses are late downstream responses consumed after timeout.
     */
    ghost_cp: coverpoint ghost_fire iff (rst_n) {
      bins no = {0};
      bins yes = {1};
    }

    full_cp: coverpoint full iff (rst_n) {
      bins not_full = {0};
      bins full = {1};
    }

    occupancy_op_cross: cross outst_cp, queue_op_cp;

  endgroup : read_queue_cg

  read_queue_cg read_queue_cov_inst;

  initial begin
    read_queue_cov_inst = new();
  end

  /*
   * Record unique read queue coverage hits for regression aggregation.
   */
  always_ff @(posedge clk) begin

    if (rst_n) begin

      /* Record outstanding read occupancy. */
      if (outst_cnt == 0) cov_hit["OUTST_EMPTY"] = 1'b1;
      else if (outst_cnt == 1) cov_hit["OUTST_ONE"] = 1'b1;
      else if (outst_cnt == DEPTH) cov_hit["OUTST_FULL"] = 1'b1;
      else if (outst_cnt >= 2 && outst_cnt < DEPTH)
        cov_hit[$sformatf("OUTST_PARTIAL_%0d", outst_cnt)] = 1'b1;

      /* Record ghost-drain occupancy. */
      if (drain_cnt == 0) cov_hit["DRAIN_ZERO"] = 1'b1;
      else if (drain_cnt == 1) cov_hit["DRAIN_ONE"] = 1'b1;
      else if (drain_cnt >= 2 && drain_cnt <= DEPTH)
        cov_hit[$sformatf("DRAIN_MULTIPLE_%0d", drain_cnt)] = 1'b1;

      /* Record read queue movement. */
      case ({ar_fire, retire_fire})
        2'b00: cov_hit["OP_IDLE"] = 1'b1;
        2'b10: cov_hit["OP_ENQUEUE_ONLY"] = 1'b1;
        2'b01: cov_hit["OP_RETIRE_ONLY"] = 1'b1;
        2'b11: cov_hit["OP_ENQUEUE_AND_RETIRE"] = 1'b1;
      endcase

      /* Record whether timeout injection has occurred. */
      if (inject_fire) cov_hit["INJECT_YES"] = 1'b1;
      else cov_hit["INJECT_NO"] = 1'b1;

      /* Record whether a ghost response has been drained. */
      if (ghost_fire) cov_hit["GHOST_YES"] = 1'b1;
      else cov_hit["GHOST_NO"] = 1'b1;

      /* Record whether read queue backpressure reached full occupancy. */
      if (full) cov_hit["FULL_YES"] = 1'b1;
      else cov_hit["FULL_NO"] = 1'b1;

      /* Record outstanding occupancy x queue-operation cross coverage. */
      if (outst_cnt == 0)
        cov_hit[$sformatf("CROSS_OUTST_EMPTY_OP_%02b", {ar_fire, retire_fire})] = 1'b1;
      else if (outst_cnt == 1)
        cov_hit[$sformatf("CROSS_OUTST_ONE_OP_%02b", {ar_fire, retire_fire})] = 1'b1;
      else if (outst_cnt == DEPTH)
        cov_hit[$sformatf("CROSS_OUTST_FULL_OP_%02b", {ar_fire, retire_fire})] = 1'b1;
      else if (outst_cnt >= 2 && outst_cnt < DEPTH)
        cov_hit[$sformatf("CROSS_OUTST_PARTIAL_%0d_OP_%02b", outst_cnt, {ar_fire, retire_fire})] = 1'b1;

    end
  end

  /*
   * Print each unique regression hit once, then print native coverage results.
   */
  final begin

    foreach (cov_hit[key])
    $display("COV_HIT READ_QUEUE %s", key);
    $display("READ_QUEUE_COVERAGE_SUMMARY");
    $display("Overall read-queue coverage = %0.2f%%", read_queue_cov_inst.get_inst_coverage());
    $display("Outstanding occupancy coverage = %0.2f%%", read_queue_cov_inst.outst_cp.get_inst_coverage());
    $display("Ghost-drain occupancy coverage = %0.2f%%", read_queue_cov_inst.drain_cp.get_inst_coverage());
    $display("Queue operation coverage = %0.2f%%", read_queue_cov_inst.queue_op_cp.get_inst_coverage());
    $display("Timeout injection coverage = %0.2f%%", read_queue_cov_inst.inject_cp.get_inst_coverage());
    $display("Ghost response coverage = %0.2f%%", read_queue_cov_inst.ghost_cp.get_inst_coverage());
    $display("Full/backpressure coverage = %0.2f%%", read_queue_cov_inst.full_cp.get_inst_coverage());
    $display("Occupancy x operation coverage = %0.2f%%", read_queue_cov_inst.occupancy_op_cross.get_inst_coverage());
  end

endmodule : axi4l_read_queue_coverage


/*
 * Attach read queue coverage directly to rd_queue internal state.
 */
bind rd_queue axi4l_read_queue_coverage #(
    .DEPTH(DEPTH)
) read_queue_cov (
    .clk(clk),
    .rst_n(rst_n),
    .outst_cnt(outst_cnt),
    .drain_cnt(drain_cnt),
    .ar_fire(ar_fire),
    .retire_fire(retire_fire),
    .inject_fire(inject_fire),
    .ghost_fire(ghost_fire),
    .full(full)
);


/*
 * Write queue coverage is bound directly to wr_queue so outstanding-response
 * occupancy, drain debt, queue movement, and PR-01 write-pair state are visible.
 */
module axi4l_write_queue_coverage #(
    parameter int unsigned DEPTH = a4lite_pkg::DEPTH,
    parameter int unsigned CNT_W = $clog2(DEPTH + 1)
)(
    input logic clk,
    input logic rst_n,
    input logic [CNT_W-1:0] outst_cnt,
    input logic [CNT_W-1:0] drain_cnt,
    input logic pair_fire,
    input logic retire_fire,
    input logic inject_fire,
    input logic ghost_fire,
    input logic full,
    input wpair_state_e wpair_state
);

  bit cov_hit[string];
  string key;

  covergroup write_queue_cg @(posedge clk);

    option.per_instance = 1;

    /*
     * Distinguish empty, single-entry, intermediate, and full write occupancy.
     */
    outst_cp: coverpoint outst_cnt iff (rst_n) {
      bins empty = {0};
      bins one = {1};
      bins partial[] = {[2:DEPTH-1]};
      bins full = {DEPTH};
    }

    /*
     * drain_cnt records late downstream B responses still owed after synthetic
     * upstream timeout responses have already retired transactions.
     */
    drain_cp: coverpoint drain_cnt iff (rst_n) {
      bins zero = {0};
      bins one = {1};
      bins multiple[] = {[2:DEPTH]};
    }

    /*
     * Exercise write enqueue-only, response-retire-only, and simultaneous
     * queue movement.
     */
    queue_op_cp: coverpoint {pair_fire, retire_fire} iff (rst_n) {
      bins idle = {2'b00};
      bins enqueue_only = {2'b10};
      bins retire_only = {2'b01};
      bins enqueue_and_retire = {2'b11};
    }

    /*
     * Cover the write-pair admission states used by PR-01 and write-data fault
     * handling.
     */
    pair_state_cp: coverpoint wpair_state iff (rst_n) {
      bins idle = {WPAIR_IDLE};
      bins aw_only = {WPAIR_AW_ONLY};
      bins w_fault = {WPAIR_W_FAULT};
    }

    /*
     * Synthetic B-response injection retires a timed-out write upstream.
     */
    inject_cp: coverpoint inject_fire iff (rst_n) {
      bins no = {0};
      bins yes = {1};
    }

    /*
     * Ghost responses are late downstream B responses drained after timeout.
     */
    ghost_cp: coverpoint ghost_fire iff (rst_n) {
      bins no = {0};
      bins yes = {1};
    }

    full_cp: coverpoint full iff (rst_n) {
      bins not_full = {0};
      bins full = {1};
    }

    occupancy_op_cross: cross outst_cp, queue_op_cp;

  endgroup : write_queue_cg

  write_queue_cg write_queue_cov_inst;

  initial begin
    write_queue_cov_inst = new();
  end

  /*
   * Record unique write queue coverage hits for regression aggregation.
   */
  always_ff @(posedge clk) begin

    if (rst_n) begin

      /* Record outstanding write occupancy. */
      if (outst_cnt == 0) cov_hit["OUTST_EMPTY"] = 1'b1;
      else if (outst_cnt == 1) cov_hit["OUTST_ONE"] = 1'b1;
      else if (outst_cnt == DEPTH) cov_hit["OUTST_FULL"] = 1'b1;
      else if (outst_cnt >= 2 && outst_cnt < DEPTH)
        cov_hit[$sformatf("OUTST_PARTIAL_%0d", outst_cnt)] = 1'b1;

      /* Record ghost-drain occupancy. */
      if (drain_cnt == 0) cov_hit["DRAIN_ZERO"] = 1'b1;
      else if (drain_cnt == 1) cov_hit["DRAIN_ONE"] = 1'b1;
      else if (drain_cnt >= 2 && drain_cnt <= DEPTH)
        cov_hit[$sformatf("DRAIN_MULTIPLE_%0d", drain_cnt)] = 1'b1;

      /* Record write queue movement. */
      case ({pair_fire, retire_fire})
        2'b00: cov_hit["OP_IDLE"] = 1'b1;
        2'b10: cov_hit["OP_ENQUEUE_ONLY"] = 1'b1;
        2'b01: cov_hit["OP_RETIRE_ONLY"] = 1'b1;
        2'b11: cov_hit["OP_ENQUEUE_AND_RETIRE"] = 1'b1;
      endcase

      /* Record write-pair admission state. */
      case (wpair_state)
        WPAIR_IDLE: cov_hit["PAIR_STATE_IDLE"] = 1'b1;
        WPAIR_AW_ONLY: cov_hit["PAIR_STATE_AW_ONLY"] = 1'b1;
        WPAIR_W_FAULT: cov_hit["PAIR_STATE_W_FAULT"] = 1'b1;
      endcase

      /* Record whether timeout injection has occurred. */
      if (inject_fire) cov_hit["INJECT_YES"] = 1'b1;
      else cov_hit["INJECT_NO"] = 1'b1;

      /* Record whether a ghost B response has been drained. */
      if (ghost_fire) cov_hit["GHOST_YES"] = 1'b1;
      else cov_hit["GHOST_NO"] = 1'b1;

      /* Record whether write queue backpressure reached full occupancy. */
      if (full) cov_hit["FULL_YES"] = 1'b1;
      else cov_hit["FULL_NO"] = 1'b1;

      /* Record outstanding occupancy x queue-operation cross coverage. */
      if (outst_cnt == 0)
        cov_hit[$sformatf("CROSS_OUTST_EMPTY_OP_%02b", {pair_fire, retire_fire})] = 1'b1;
      else if (outst_cnt == 1)
        cov_hit[$sformatf("CROSS_OUTST_ONE_OP_%02b", {pair_fire, retire_fire})] = 1'b1;
      else if (outst_cnt == DEPTH)
        cov_hit[$sformatf("CROSS_OUTST_FULL_OP_%02b", {pair_fire, retire_fire})] = 1'b1;
      else if (outst_cnt >= 2 && outst_cnt < DEPTH)
        cov_hit[$sformatf("CROSS_OUTST_PARTIAL_%0d_OP_%02b", outst_cnt, {pair_fire, retire_fire})] = 1'b1;

    end
  end

  /*
   * Print each unique regression hit once, then print native coverage results.
   */
  final begin

    foreach (cov_hit[key])
      $display("COV_HIT WRITE_QUEUE %s", key);

    $display("WRITE_QUEUE_COVERAGE_SUMMARY");
    $display("Overall write-queue coverage = %0.2f%%", write_queue_cov_inst.get_inst_coverage());
    $display("Outstanding occupancy coverage = %0.2f%%", write_queue_cov_inst.outst_cp.get_inst_coverage());
    $display("Ghost-drain occupancy coverage = %0.2f%%", write_queue_cov_inst.drain_cp.get_inst_coverage());
    $display("Queue operation coverage = %0.2f%%", write_queue_cov_inst.queue_op_cp.get_inst_coverage());
    $display("Write-pair state coverage = %0.2f%%", write_queue_cov_inst.pair_state_cp.get_inst_coverage());
    $display("Timeout injection coverage = %0.2f%%", write_queue_cov_inst.inject_cp.get_inst_coverage());
    $display("Ghost response coverage = %0.2f%%", write_queue_cov_inst.ghost_cp.get_inst_coverage());
    $display("Full/backpressure coverage = %0.2f%%", write_queue_cov_inst.full_cp.get_inst_coverage());
    $display("Occupancy x operation coverage = %0.2f%%", write_queue_cov_inst.occupancy_op_cross.get_inst_coverage());

  end

endmodule : axi4l_write_queue_coverage


/*
 * Attach write queue coverage directly to wr_queue internal state.
 */
bind wr_queue axi4l_write_queue_coverage #(
    .DEPTH(DEPTH)
) write_queue_cov (
    .clk(clk),
    .rst_n(rst_n),
    .outst_cnt(outst_cnt),
    .drain_cnt(drain_cnt),
    .pair_fire(pair_fire),
    .retire_fire(retire_fire),
    .inject_fire(inject_fire),
    .ghost_fire(ghost_fire),
    .full(full),
    .wpair_state(wpair_state)
);