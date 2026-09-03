import a4lite_pkg::*;

/*
 * Recovery coverage is bound directly to tp_lvl because recovery state is
 * internal SCC architectural behaviour rather than a monitor transaction.
 */
module axi4l_recovery_coverage (
    input logic clk,
    input logic rst_n,
    input guard_mode_e mode,
    input logic [NUM_FAULT_SOURCES-1:0] violation_notif,
    input logic all_upstream_empty,
    input logic [NUM_FAULT_SOURCES-1:0] rcvy_ack,
    input logic epoch_clr,
    input logic irq
);

  int unsigned last_fault_src;
  bit last_fault_valid;
  guard_mode_e previous_mode;

  /* Store unique recovery coverage hits for regression aggregation. */
  bit cov_hit[string];
  string key;

  /*
   * Cover SCC recovery states and transitions.
   */
  covergroup recovery_state_cg @(posedge clk);

    option.per_instance = 1;

    mode_cp: coverpoint mode iff (rst_n) {
      bins normal = {GUARD_NORMAL};
      bins containing = {GUARD_CONTAINING};
      bins recovery = {GUARD_RECOVERY};

      bins normal_to_containing = (GUARD_NORMAL => GUARD_CONTAINING);
      bins containing_to_recovery = (GUARD_CONTAINING => GUARD_RECOVERY);
      bins recovery_to_normal = (GUARD_RECOVERY => GUARD_NORMAL);
    }

    quiescent_cp: coverpoint all_upstream_empty iff (rst_n) {
      bins not_quiescent = {0};
      bins quiescent = {1};
    }

    irq_cp: coverpoint irq iff (rst_n) {
      bins low = {0};
      bins high = {1};
    }

    ack_cp: coverpoint (|rcvy_ack) iff (rst_n) {
      bins absent = {0};
      bins present = {1};
    }

    epoch_clr_cp: coverpoint epoch_clr iff (rst_n) {
      bins absent = {0};
      bins asserted = {1};
    }

    mode_quiescent_cross: cross mode_cp, quiescent_cp;
    mode_irq_cross: cross mode_cp, irq_cp;

  endgroup : recovery_state_cg

  /*
   * Cover which fault source eventually completes recovery.
   */
  covergroup recovered_fault_cg with function sample(int unsigned fault_src);

    option.per_instance = 1;

    recovered_fault_cp: coverpoint fault_src {
      bins read_timeout = {READ_TIMEOUT};
      bins write_data_timeout = {WRITE_DATA_TIMEOUT};
      bins write_resp_timeout = {WRITE_RESP_TIMEOUT};
    }

  endgroup : recovered_fault_cg

  recovery_state_cg recovery_state_cov_inst;
  recovered_fault_cg recovered_fault_cov_inst;

  /*
   * Construct coverage instances.
   */
  initial begin
    recovery_state_cov_inst = new();
    recovered_fault_cov_inst = new();
  end

  /*
   * Track recovery activity and remember unique regression coverage hits.
   */
  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
      last_fault_src <= '0;
      last_fault_valid <= 1'b0;
      previous_mode <= GUARD_NORMAL;
    end
    else begin

      /* Record which recovery mode has been observed. */
      case (mode)
        GUARD_NORMAL: cov_hit["MODE_NORMAL"] = 1'b1;
        GUARD_CONTAINING: cov_hit["MODE_CONTAINING"] = 1'b1;
        GUARD_RECOVERY: cov_hit["MODE_RECOVERY"] = 1'b1;
      endcase

      /* Record whether the SCC is upstream-quiescent during recovery activity. */
      if (all_upstream_empty) cov_hit["QUIESCENT_YES"] = 1'b1;
      else cov_hit["QUIESCENT_NO"] = 1'b1;

      /* Record whether the recovery interrupt is asserted or deasserted. */
      if (irq) cov_hit["IRQ_HIGH"] = 1'b1;
      else cov_hit["IRQ_LOW"] = 1'b1;

      /* Record whether software recovery acknowledgement is present. */
      if (|rcvy_ack) cov_hit["ACK_YES"] = 1'b1;
      else cov_hit["ACK_NO"] = 1'b1;

      /* Record whether an authorized epoch clear occurs. */
      if (epoch_clr) cov_hit["EPOCH_CLEAR_YES"] = 1'b1;
      else cov_hit["EPOCH_CLEAR_NO"] = 1'b1;

      /* Record state x quiescence and state x IRQ cross coverage. */
      case (mode)

        GUARD_NORMAL: begin
          if (all_upstream_empty) cov_hit["CROSS_MODE_NORMAL_QUIESCENT_YES"] = 1'b1;
          else cov_hit["CROSS_MODE_NORMAL_QUIESCENT_NO"] = 1'b1;

          if (irq) cov_hit["CROSS_MODE_NORMAL_IRQ_HIGH"] = 1'b1;
          else cov_hit["CROSS_MODE_NORMAL_IRQ_LOW"] = 1'b1;
        end

        GUARD_CONTAINING: begin
          if (all_upstream_empty) cov_hit["CROSS_MODE_CONTAINING_QUIESCENT_YES"] = 1'b1;
          else cov_hit["CROSS_MODE_CONTAINING_QUIESCENT_NO"] = 1'b1;

          if (irq) cov_hit["CROSS_MODE_CONTAINING_IRQ_HIGH"] = 1'b1;
          else cov_hit["CROSS_MODE_CONTAINING_IRQ_LOW"] = 1'b1;
        end

        GUARD_RECOVERY: begin
          if (all_upstream_empty) cov_hit["CROSS_MODE_RECOVERY_QUIESCENT_YES"] = 1'b1;
          else cov_hit["CROSS_MODE_RECOVERY_QUIESCENT_NO"] = 1'b1;

          if (irq) cov_hit["CROSS_MODE_RECOVERY_IRQ_HIGH"] = 1'b1;
          else cov_hit["CROSS_MODE_RECOVERY_IRQ_LOW"] = 1'b1;
        end

      endcase

      /* Record the NORMAL -> CONTAINING transition and its cross conditions. */
      if (previous_mode == GUARD_NORMAL && mode == GUARD_CONTAINING) begin
        cov_hit["TRANS_NORMAL_TO_CONTAINING"] = 1'b1;

        if (all_upstream_empty) cov_hit["CROSS_TRANS_NORMAL_TO_CONTAINING_QUIESCENT_YES"] = 1'b1;
        else cov_hit["CROSS_TRANS_NORMAL_TO_CONTAINING_QUIESCENT_NO"] = 1'b1;

        if (irq) cov_hit["CROSS_TRANS_NORMAL_TO_CONTAINING_IRQ_HIGH"] = 1'b1;
        else cov_hit["CROSS_TRANS_NORMAL_TO_CONTAINING_IRQ_LOW"] = 1'b1;
      end

      /* Record the CONTAINING -> RECOVERY transition and its cross conditions. */
      if (previous_mode == GUARD_CONTAINING && mode == GUARD_RECOVERY) begin
        cov_hit["TRANS_CONTAINING_TO_RECOVERY"] = 1'b1;

        if (all_upstream_empty) cov_hit["CROSS_TRANS_CONTAINING_TO_RECOVERY_QUIESCENT_YES"] = 1'b1;
        else cov_hit["CROSS_TRANS_CONTAINING_TO_RECOVERY_QUIESCENT_NO"] = 1'b1;

        if (irq) cov_hit["CROSS_TRANS_CONTAINING_TO_RECOVERY_IRQ_HIGH"] = 1'b1;
        else cov_hit["CROSS_TRANS_CONTAINING_TO_RECOVERY_IRQ_LOW"] = 1'b1;
      end

      /* Record the RECOVERY -> NORMAL transition and its cross conditions. */
      if (previous_mode == GUARD_RECOVERY && mode == GUARD_NORMAL) begin
        cov_hit["TRANS_RECOVERY_TO_NORMAL"] = 1'b1;

        if (all_upstream_empty) cov_hit["CROSS_TRANS_RECOVERY_TO_NORMAL_QUIESCENT_YES"] = 1'b1;
        else cov_hit["CROSS_TRANS_RECOVERY_TO_NORMAL_QUIESCENT_NO"] = 1'b1;

        if (irq) cov_hit["CROSS_TRANS_RECOVERY_TO_NORMAL_IRQ_HIGH"] = 1'b1;
        else cov_hit["CROSS_TRANS_RECOVERY_TO_NORMAL_IRQ_LOW"] = 1'b1;
      end

      /* Remember the current mode so transitions can be identified next cycle. */
      previous_mode <= mode;

      /* Remember which fault source initiated the failed epoch. */
      if (violation_notif[READ_TIMEOUT]) begin
        last_fault_src <= READ_TIMEOUT;
        last_fault_valid <= 1'b1;
      end
      else if (violation_notif[WRITE_DATA_TIMEOUT]) begin
        last_fault_src <= WRITE_DATA_TIMEOUT;
        last_fault_valid <= 1'b1;
      end
      else if (violation_notif[WRITE_RESP_TIMEOUT]) begin
        last_fault_src <= WRITE_RESP_TIMEOUT;
        last_fault_valid <= 1'b1;
      end

      /* Record which fault source completed a valid recovery. */
      if (epoch_clr && last_fault_valid) begin
        recovered_fault_cov_inst.sample(last_fault_src);

        case (last_fault_src)
          READ_TIMEOUT: cov_hit["RECOVERED_READ_TIMEOUT"] = 1'b1;
          WRITE_DATA_TIMEOUT: cov_hit["RECOVERED_WRITE_DATA_TIMEOUT"] = 1'b1;
          WRITE_RESP_TIMEOUT: cov_hit["RECOVERED_WRITE_RESP_TIMEOUT"] = 1'b1;
        endcase

        last_fault_valid <= 1'b0;
      end

    end
  end

  /*
   * Print each unique regression hit once, then print native coverage results.
   */
  final begin

    foreach (cov_hit[key])
      $display("COV_HIT RECOVERY %s", key);

    $display("RECOVERY_COVERAGE_SUMMARY");
    $display("Recovery-state coverage = %0.2f%%", recovery_state_cov_inst.get_inst_coverage());
    $display("Mode/state coverage = %0.2f%%", recovery_state_cov_inst.mode_cp.get_inst_coverage());
    $display("Upstream-quiescence coverage = %0.2f%%", recovery_state_cov_inst.quiescent_cp.get_inst_coverage());
    $display("IRQ coverage = %0.2f%%", recovery_state_cov_inst.irq_cp.get_inst_coverage());
    $display("Recovery-ack coverage = %0.2f%%", recovery_state_cov_inst.ack_cp.get_inst_coverage());
    $display("Epoch-clear coverage = %0.2f%%", recovery_state_cov_inst.epoch_clr_cp.get_inst_coverage());
    $display("Mode x quiescence coverage = %0.2f%%", recovery_state_cov_inst.mode_quiescent_cross.get_inst_coverage());
    $display("Mode x IRQ coverage = %0.2f%%", recovery_state_cov_inst.mode_irq_cross.get_inst_coverage());
    $display("Recovered-fault coverage = %0.2f%%", recovered_fault_cov_inst.get_inst_coverage());
    $display("Recovered fault-source coverage = %0.2f%%", recovered_fault_cov_inst.recovered_fault_cp.get_inst_coverage());

  end

endmodule : axi4l_recovery_coverage

/*
 * Attach recovery coverage without adding verification-only DUT ports.
 */
bind tp_lvl axi4l_recovery_coverage recovery_cov (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .violation_notif(violation_notif),
    .all_upstream_empty(all_upstream_empty),
    .rcvy_ack(rcvy_ack),
    .epoch_clr(epoch_clr),
    .irq(irq)
);