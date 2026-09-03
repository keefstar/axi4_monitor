/*
 * Separate analysis imp suffixes are used here so coverage can identify
 * upstream versus downstream observations without adding new metadata to
 * axi4l_write_item.
 */
`uvm_analysis_imp_decl(_cov_upstream_write)
`uvm_analysis_imp_decl(_cov_downstream_write)


class axi4l_write_protocol_coverage extends uvm_component;

  `uvm_component_utils(axi4l_write_protocol_coverage)

  localparam int COV_MANAGER = 0;
  localparam int COV_SUBORDINATE = 1;

  uvm_analysis_imp_cov_upstream_write#(axi4l_write_item, axi4l_write_protocol_coverage) upstream_write_imp;
  uvm_analysis_imp_cov_downstream_write#(axi4l_write_item, axi4l_write_protocol_coverage) downstream_write_imp;

  bit cov_hit[string];
  string key;

  /*
   * WRITE_ADDRESS samples AWADDR/AWPROT.
   * WRITE_DATA samples WDATA/WSTRB.
   * WRITE_RESPONSE samples BRESP.
   */
  covergroup write_event_cg with function sample(int role, axi4l_write_item tr);

    option.per_instance = 1;

    //Which interface generated the transaction?
    role_cp: coverpoint role {
      bins manager = {COV_MANAGER};
      bins subordinate = {COV_SUBORDINATE};
    }

    //Was this an address, data, or response observation?
    kind_cp: coverpoint tr.kind {
      bins aw = {axi4l_write_item::WRITE_ADDRESS};
      bins w = {axi4l_write_item::WRITE_DATA};
      bins b = {axi4l_write_item::WRITE_RESPONSE};
    }

    //Exercise addresses below, inside, and above the subordinate region.
    addr_region_cp: coverpoint tr.addr iff (tr.kind == axi4l_write_item::WRITE_ADDRESS) {
      bins below_sub = {[32'h0000_0000:SUB_ADDR_BASE-1]};
      bins sub_region = {[SUB_ADDR_BASE:SUB_ADDR_END]};
      bins above_sub = {[SUB_ADDR_END+1:32'hFFFF_FFFF]};
    }

    //Exercise every AWPROT encoding.
    prot_cp: coverpoint tr.prot iff (tr.kind == axi4l_write_item::WRITE_ADDRESS) {
      bins prot[] = {[3'b000:3'b111]};
    }

    //Exercise every legal WSTRB pattern.
    strb_cp: coverpoint tr.strb iff (tr.kind == axi4l_write_item::WRITE_DATA) {
      bins none = {4'b0000};
      bins single_byte[] = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
      bins partial_multi[] = {4'b0011, 4'b0101, 4'b0110, 4'b1001, 4'b1010, 4'b1100, 4'b0111, 4'b1011, 4'b1101, 4'b1110};
      bins full = {4'b1111};
    }

    //Observe all supported write response encodings.
    resp_cp: coverpoint tr.resp iff (tr.kind == axi4l_write_item::WRITE_RESPONSE) {
      bins okay = {RESP_OKAY};
      bins exokay = {RESP_EXOKAY};
      bins slverr = {RESP_SLVERR};
      bins decerr = {RESP_DECERR};
    }

    //Exercise address, data, and response traffic on both interfaces.
    role_kind_cross: cross role_cp, kind_cp;

    //Exercise every AWPROT value on both interfaces.
    role_prot_cross: cross role_cp, prot_cp;

    //Exercise every WSTRB value on both interfaces.
    role_strb_cross: cross role_cp, strb_cp;

    //Exercise every BRESP value on both interfaces.
    role_resp_cross: cross role_cp, resp_cp;

  endgroup : write_event_cg


  function new(string name = "axi4l_write_protocol_coverage", uvm_component parent = null);

    super.new(name, parent);

    upstream_write_imp = new("upstream_write_imp", this);
    downstream_write_imp = new("downstream_write_imp", this);

    write_event_cg = new();
    write_event_cg.set_inst_name({get_full_name(), ".write_event_cg"});

  endfunction : new


  /*
   * Record an upstream manager-side write observation.
   */
  function void write_cov_upstream_write(axi4l_write_item tr);

    write_event_cg.sample(COV_MANAGER, tr);

    /* Record that manager-side write traffic was observed. */
    cov_hit["ROLE_MANAGER"] = 1'b1;

    case (tr.kind)

      axi4l_write_item::WRITE_ADDRESS: begin

        `uvm_info("WRITE_COVERAGE", $sformatf("Sampled role=MANAGER kind=WRITE_ADDRESS addr=0x%0h prot=%03b", tr.addr, tr.prot), UVM_HIGH)

        /* Record that a write-address observation occurred. */
        cov_hit["KIND_AW"] = 1'b1;

        /* Record which address region was accessed. */
        if (tr.addr < SUB_ADDR_BASE) cov_hit["ADDR_BELOW_SUB"] = 1'b1;
        else if (tr.addr <= SUB_ADDR_END) cov_hit["ADDR_SUB_REGION"] = 1'b1;
        else cov_hit["ADDR_ABOVE_SUB"] = 1'b1;

        /* Record the individual AWPROT encoding. */
        cov_hit[$sformatf("PROT_%03b", tr.prot)] = 1'b1;

        /* Record manager x AW kind coverage. */
        cov_hit["CROSS_ROLE_MANAGER_KIND_AW"] = 1'b1;

        /* Record manager x AWPROT coverage. */
        cov_hit[$sformatf("CROSS_ROLE_MANAGER_PROT_%03b", tr.prot)] = 1'b1;

      end

      axi4l_write_item::WRITE_DATA: begin

        `uvm_info("WRITE_COVERAGE", $sformatf("Sampled role=MANAGER kind=WRITE_DATA data=0x%0h strb=%04b", tr.data, tr.strb), UVM_HIGH)

        /* Record that a write-data observation occurred. */
        cov_hit["KIND_W"] = 1'b1;

        /* Record the individual WSTRB encoding. */
        cov_hit[$sformatf("STRB_%04b", tr.strb)] = 1'b1;

        /* Record manager x W kind coverage. */
        cov_hit["CROSS_ROLE_MANAGER_KIND_W"] = 1'b1;

        /* Record manager x WSTRB coverage. */
        cov_hit[$sformatf("CROSS_ROLE_MANAGER_STRB_%04b", tr.strb)] = 1'b1;

      end

      axi4l_write_item::WRITE_RESPONSE: begin

        `uvm_info("WRITE_COVERAGE", $sformatf("Sampled role=MANAGER kind=WRITE_RESPONSE resp=%s", tr.resp.name()), UVM_HIGH)

        /* Record that a write-response observation occurred. */
        cov_hit["KIND_B"] = 1'b1;

        /* Record the observed BRESP encoding. */
        case (tr.resp)
          RESP_OKAY: cov_hit["RESP_OKAY"] = 1'b1;
          RESP_EXOKAY: cov_hit["RESP_EXOKAY"] = 1'b1;
          RESP_SLVERR: cov_hit["RESP_SLVERR"] = 1'b1;
          RESP_DECERR: cov_hit["RESP_DECERR"] = 1'b1;
        endcase

        /* Record manager x B kind coverage. */
        cov_hit["CROSS_ROLE_MANAGER_KIND_B"] = 1'b1;

        /* Record manager x BRESP coverage. */
        case (tr.resp)
          RESP_OKAY: cov_hit["CROSS_ROLE_MANAGER_RESP_OKAY"] = 1'b1;
          RESP_EXOKAY: cov_hit["CROSS_ROLE_MANAGER_RESP_EXOKAY"] = 1'b1;
          RESP_SLVERR: cov_hit["CROSS_ROLE_MANAGER_RESP_SLVERR"] = 1'b1;
          RESP_DECERR: cov_hit["CROSS_ROLE_MANAGER_RESP_DECERR"] = 1'b1;
        endcase

      end

      default: `uvm_warning("WRITE_COVERAGE", "Unknown upstream write transaction category")

    endcase

  endfunction : write_cov_upstream_write


  /*
   * Record a downstream subordinate-side write observation.
   */
  function void write_cov_downstream_write(axi4l_write_item tr);

    write_event_cg.sample(COV_SUBORDINATE, tr);

    /* Record that subordinate-side write traffic was observed. */
    cov_hit["ROLE_SUBORDINATE"] = 1'b1;

    case (tr.kind)

      axi4l_write_item::WRITE_ADDRESS: begin

        `uvm_info("WRITE_COVERAGE", $sformatf("Sampled role=SUBORDINATE kind=WRITE_ADDRESS addr=0x%0h prot=%03b", tr.addr, tr.prot), UVM_HIGH)

        /* Record that a write-address observation occurred. */
        cov_hit["KIND_AW"] = 1'b1;

        /* Record which address region was accessed. */
        if (tr.addr < SUB_ADDR_BASE) cov_hit["ADDR_BELOW_SUB"] = 1'b1;
        else if (tr.addr <= SUB_ADDR_END) cov_hit["ADDR_SUB_REGION"] = 1'b1;
        else cov_hit["ADDR_ABOVE_SUB"] = 1'b1;

        /* Record the individual AWPROT encoding. */
        cov_hit[$sformatf("PROT_%03b", tr.prot)] = 1'b1;

        /* Record subordinate x AW kind coverage. */
        cov_hit["CROSS_ROLE_SUBORDINATE_KIND_AW"] = 1'b1;

        /* Record subordinate x AWPROT coverage. */
        cov_hit[$sformatf("CROSS_ROLE_SUBORDINATE_PROT_%03b", tr.prot)] = 1'b1;

      end

      axi4l_write_item::WRITE_DATA: begin

        `uvm_info("WRITE_COVERAGE", $sformatf("Sampled role=SUBORDINATE kind=WRITE_DATA data=0x%0h strb=%04b", tr.data, tr.strb), UVM_HIGH)

        /* Record that a write-data observation occurred. */
        cov_hit["KIND_W"] = 1'b1;

        /* Record the individual WSTRB encoding. */
        cov_hit[$sformatf("STRB_%04b", tr.strb)] = 1'b1;

        /* Record subordinate x W kind coverage. */
        cov_hit["CROSS_ROLE_SUBORDINATE_KIND_W"] = 1'b1;

        /* Record subordinate x WSTRB coverage. */
        cov_hit[$sformatf("CROSS_ROLE_SUBORDINATE_STRB_%04b", tr.strb)] = 1'b1;

      end

      axi4l_write_item::WRITE_RESPONSE: begin

        `uvm_info("WRITE_COVERAGE", $sformatf("Sampled role=SUBORDINATE kind=WRITE_RESPONSE resp=%s", tr.resp.name()), UVM_HIGH)

        /* Record that a write-response observation occurred. */
        cov_hit["KIND_B"] = 1'b1;

        /* Record the observed BRESP encoding. */
        case (tr.resp)
          RESP_OKAY: cov_hit["RESP_OKAY"] = 1'b1;
          RESP_EXOKAY: cov_hit["RESP_EXOKAY"] = 1'b1;
          RESP_SLVERR: cov_hit["RESP_SLVERR"] = 1'b1;
          RESP_DECERR: cov_hit["RESP_DECERR"] = 1'b1;
        endcase

        /* Record subordinate x B kind coverage. */
        cov_hit["CROSS_ROLE_SUBORDINATE_KIND_B"] = 1'b1;

        /* Record subordinate x BRESP coverage. */
        case (tr.resp)
          RESP_OKAY: cov_hit["CROSS_ROLE_SUBORDINATE_RESP_OKAY"] = 1'b1;
          RESP_EXOKAY: cov_hit["CROSS_ROLE_SUBORDINATE_RESP_EXOKAY"] = 1'b1;
          RESP_SLVERR: cov_hit["CROSS_ROLE_SUBORDINATE_RESP_SLVERR"] = 1'b1;
          RESP_DECERR: cov_hit["CROSS_ROLE_SUBORDINATE_RESP_DECERR"] = 1'b1;
        endcase

      end

      default: `uvm_warning("WRITE_COVERAGE", "Unknown downstream write transaction category")

    endcase

  endfunction : write_cov_downstream_write


  /*
   * Print each unique regression hit once, then print native per-test coverage.
   */
  function void report_phase(uvm_phase phase);

    real overall_cov;

    super.report_phase(phase);

    foreach (cov_hit[key])
      $display("COV_HIT WRITE_PROTOCOL %s", key);

    overall_cov = write_event_cg.get_inst_coverage();

    `uvm_info("WRITE_COVERAGE_SUMMARY", $sformatf("AXI4-Lite write protocol coverage:\n  Overall coverage              = %0.2f%%\n  Role coverage                 = %0.2f%%\n  AW/W/B kind coverage          = %0.2f%%\n  Address-region coverage       = %0.2f%%\n  AWPROT coverage               = %0.2f%%\n  WSTRB coverage                = %0.2f%%\n  BRESP coverage                = %0.2f%%\n  Role x kind coverage          = %0.2f%%\n  Role x protection coverage    = %0.2f%%\n  Role x strobe coverage        = %0.2f%%\n  Role x response coverage      = %0.2f%%", overall_cov, write_event_cg.role_cp.get_inst_coverage(), write_event_cg.kind_cp.get_inst_coverage(), write_event_cg.addr_region_cp.get_inst_coverage(), write_event_cg.prot_cp.get_inst_coverage(), write_event_cg.strb_cp.get_inst_coverage(), write_event_cg.resp_cp.get_inst_coverage(), write_event_cg.role_kind_cross.get_inst_coverage(), write_event_cg.role_prot_cross.get_inst_coverage(), write_event_cg.role_strb_cross.get_inst_coverage(), write_event_cg.role_resp_cross.get_inst_coverage()), UVM_LOW)

  endfunction : report_phase

endclass : axi4l_write_protocol_coverage