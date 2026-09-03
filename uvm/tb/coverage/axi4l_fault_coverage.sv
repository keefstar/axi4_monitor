import a4lite_pkg::*;


/*
 * Bound directly to tp_lvl because fault source pulses are internal RTL events,
 * not AXI transactions published by the UVM monitors.
 */
module axi4l_fault_coverage (
    input logic clk,
    input logic rst_n,
    input logic [NUM_FAULT_SOURCES-1:0] violation_notif,
    input logic [NUM_FAULT_SOURCES-1:0] enable_reg
);

  covergroup fault_event_cg with function sample(int unsigned fault_src, bit enabled);

    option.per_instance = 1;

    fault_src_cp: coverpoint fault_src {
      bins read_timeout = {READ_TIMEOUT};
      bins write_data_timeout = {WRITE_DATA_TIMEOUT};
      bins write_resp_timeout = {WRITE_RESP_TIMEOUT};
    }

    enabled_cp: coverpoint enabled {
      bins disabled = {0};
      bins enabled = {1};
    }

    fault_enable_cross: cross fault_src_cp, enabled_cp;

  endgroup : fault_event_cg


  fault_event_cg fault_cov_inst;


  initial begin
    fault_cov_inst = new();
  end


  always_ff @(posedge clk) begin
    if (rst_n) begin
      for (int i = 0; i < NUM_FAULT_SOURCES; i++) begin
        if (violation_notif[i]) begin
          fault_cov_inst.sample(i, enable_reg[i]);
          case (i)
            READ_TIMEOUT: begin
              $display("COV_HIT FAULT SOURCE_READ_TIMEOUT");

              if (enable_reg[i]) begin
                $display("COV_HIT FAULT ENABLE_ENABLED");
                $display("COV_HIT FAULT CROSS_READ_TIMEOUT_ENABLED");
              end
              else begin
                $display("COV_HIT FAULT ENABLE_DISABLED");
                $display("COV_HIT FAULT CROSS_READ_TIMEOUT_DISABLED");
              end
            end

            WRITE_DATA_TIMEOUT: begin
              $display("COV_HIT FAULT SOURCE_WRITE_DATA_TIMEOUT");

              if (enable_reg[i]) begin
                $display("COV_HIT FAULT ENABLE_ENABLED");
                $display("COV_HIT FAULT CROSS_WRITE_DATA_TIMEOUT_ENABLED");
              end
              else begin
                $display("COV_HIT FAULT ENABLE_DISABLED");
                $display("COV_HIT FAULT CROSS_WRITE_DATA_TIMEOUT_DISABLED");
              end
            end

            WRITE_RESP_TIMEOUT: begin
              $display("COV_HIT FAULT SOURCE_WRITE_RESP_TIMEOUT");

              if (enable_reg[i]) begin
                $display("COV_HIT FAULT ENABLE_ENABLED");
                $display("COV_HIT FAULT CROSS_WRITE_RESP_TIMEOUT_ENABLED");
              end
              else begin
                $display("COV_HIT FAULT ENABLE_DISABLED");
                $display("COV_HIT FAULT CROSS_WRITE_RESP_TIMEOUT_DISABLED");
              end
            end
          endcase
        end
      end
    end
  end

    /*
   * Print functional coverage directly because IMC/vManager is unavailable.
   * These values are collected from the covergroup instance for this run.
   */
  final begin
    $display("FAULT_COVERAGE_SUMMARY");
    $display("Overall fault coverage  = %0.2f%%", fault_cov_inst.get_inst_coverage());
    $display("Fault-source coverage = %0.2f%%", fault_cov_inst.fault_src_cp.get_inst_coverage());
    $display("Fault enable/mask coverage = %0.2f%%", fault_cov_inst.enabled_cp.get_inst_coverage());
    $display("Fault source x enable coverage  %0.2f%%", fault_cov_inst.fault_enable_cross.get_inst_coverage());
  end

endmodule : axi4l_fault_coverage


bind tp_lvl axi4l_fault_coverage fault_cov (
    .clk(clk),
    .rst_n(rst_n),
    .violation_notif(violation_notif),
    .enable_reg(enable_reg)
);