class axi4l_read_protocol_coverage extends uvm_subscriber #(axi4l_read_item);

  `uvm_component_utils(axi4l_read_protocol_coverage)

  bit cov_hit[string];
  string key;

  covergroup read_event_cg with function sample(
    axi4l_role_e role,
    axi4l_read_item::axi4l_read_kind_e kind,
    logic [ADDR_WIDTH-1:0] addr,
    logic [PROT_WIDTH-1:0] prot,
    axi_resp_e resp
  );

    option.per_instance = 1;

    //Which interface generated the transaction?
    /* Covers NORM-05; verify that read traffic is observed on both manager and subordinate interfaces. */
    role_cp : coverpoint role {
      bins manager = {AXI4L_MANAGER};
      bins subordinate = {AXI4L_SUBORDINATE};
    }

    //Was this a request or a response?
    /* Verify that both read requests and read responses are exercised. */
    kind_cp : coverpoint kind {
      bins request = {axi4l_read_item::READ_REQUEST};
      bins response = {axi4l_read_item::READ_RESPONSE};
    }

    //Exercise every ARPROT encoding; NORM-05
    prot_cp : coverpoint prot
      iff (kind == axi4l_read_item::READ_REQUEST)
    {
      bins values[] = {[3'b000:3'b111]};
    }

    //Exercise accesses both inside and outside the subordinate region; NORM-05
    addr_cp : coverpoint addr
      iff (kind == axi4l_read_item::READ_REQUEST)
    {
      bins subordinate_region = {[SUB_ADDR_BASE:SUB_ADDR_END]};
      bins other_region = default;
    }

    //Observe both successful and error read responses; NORM-05
    resp_cp : coverpoint resp
      iff (kind == axi4l_read_item::READ_RESPONSE)
    {
      bins okay = {RESP_OKAY};
      bins slverr = {RESP_SLVERR};
      bins decerr = {RESP_DECERR};
    }

    //Exercise request and response traffic on both interfaces; NORM-05
    role_kind_cross :
      cross role_cp, kind_cp;

    //Exercise every PROT value on both interfaces; NORM-05
    role_prot_cross :
      cross role_cp, prot_cp;

    //Exercise both OKAY and SLVERR responses on both interfaces; NORM-05
    role_resp_cross :
      cross role_cp, resp_cp;

  endgroup

  function new(string name = "axi4l_read_coverage", uvm_component parent = null);
    super.new(name, parent);
    read_event_cg = new();
    read_event_cg.set_inst_name({get_full_name(), ".read_event_cg"});
  endfunction

  /*
   * UVM subscribers implement write(). Whenever a connected monitor publishes
   * a read transaction, UVM automatically delivers it to this function.
   */
  virtual function void write(axi4l_read_item t);

    case (t.kind)

      axi4l_read_item::READ_REQUEST: begin

        `uvm_info("READ_COVERAGE", $sformatf("Sampled role=%s kind=%s addr=0x%0h prot=%03b", t.role.name(), t.kind.name(), t.addr, t.prot), UVM_MEDIUM)

        /* Record which interface observed the read request. */
        if (t.role == AXI4L_MANAGER) cov_hit["ROLE_MANAGER"] = 1'b1;
        else if (t.role == AXI4L_SUBORDINATE) cov_hit["ROLE_SUBORDINATE"] = 1'b1;

        /* Record that read-request traffic was exercised. */
        cov_hit["KIND_REQUEST"] = 1'b1;

        /* Record which address region was accessed. */
        if (t.addr >= SUB_ADDR_BASE && t.addr <= SUB_ADDR_END) cov_hit["ADDR_SUBORDINATE_REGION"] = 1'b1;
        else cov_hit["ADDR_OTHER_REGION"] = 1'b1;

        /* Record the individual ARPROT encoding. */
        cov_hit[$sformatf("PROT_%03b", t.prot)] = 1'b1;

        /* Record role x request cross coverage. */
        if (t.role == AXI4L_MANAGER) cov_hit["CROSS_ROLE_MANAGER_KIND_REQUEST"] = 1'b1;
        else if (t.role == AXI4L_SUBORDINATE) cov_hit["CROSS_ROLE_SUBORDINATE_KIND_REQUEST"] = 1'b1;

        /* Record role x ARPROT cross coverage. */
        if (t.role == AXI4L_MANAGER)
          cov_hit[$sformatf("CROSS_ROLE_MANAGER_PROT_%03b", t.prot)] = 1'b1;
        else if (t.role == AXI4L_SUBORDINATE)
          cov_hit[$sformatf("CROSS_ROLE_SUBORDINATE_PROT_%03b", t.prot)] = 1'b1;

      end

      axi4l_read_item::READ_RESPONSE: begin

        `uvm_info("READ_COVERAGE", $sformatf("Sampled role=%s kind=%s data=0x%0h resp=%s", t.role.name(), t.kind.name(), t.data, t.resp.name()), UVM_MEDIUM)

        /* Record which interface observed the read response. */
        if (t.role == AXI4L_MANAGER) cov_hit["ROLE_MANAGER"] = 1'b1;
        else if (t.role == AXI4L_SUBORDINATE) cov_hit["ROLE_SUBORDINATE"] = 1'b1;

        /* Record that read-response traffic was exercised. */
        cov_hit["KIND_RESPONSE"] = 1'b1;

        /* Record the observed AXI read response. */
        if (t.resp == RESP_OKAY) cov_hit["RESP_OKAY"] = 1'b1;
        else if (t.resp == RESP_SLVERR) cov_hit["RESP_SLVERR"] = 1'b1;
        else if (t.resp == RESP_DECERR) cov_hit["RESP_DECERR"] = 1'b1;

        /* Record role x response-kind cross coverage. */
        if (t.role == AXI4L_MANAGER) cov_hit["CROSS_ROLE_MANAGER_KIND_RESPONSE"] = 1'b1;
        else if (t.role == AXI4L_SUBORDINATE) cov_hit["CROSS_ROLE_SUBORDINATE_KIND_RESPONSE"] = 1'b1;

        /* Record role x response-code cross coverage. */
        if (t.role == AXI4L_MANAGER && t.resp == RESP_OKAY)
          cov_hit["CROSS_ROLE_MANAGER_RESP_OKAY"] = 1'b1;
        else if (t.role == AXI4L_MANAGER && t.resp == RESP_SLVERR)
          cov_hit["CROSS_ROLE_MANAGER_RESP_SLVERR"] = 1'b1;
        else if (t.role == AXI4L_SUBORDINATE && t.resp == RESP_OKAY)
          cov_hit["CROSS_ROLE_SUBORDINATE_RESP_OKAY"] = 1'b1;
        else if (t.role == AXI4L_SUBORDINATE && t.resp == RESP_SLVERR)
          cov_hit["CROSS_ROLE_SUBORDINATE_RESP_SLVERR"] = 1'b1;
        else if (t.role == AXI4L_MANAGER && t.resp == RESP_DECERR)
          cov_hit["CROSS_ROLE_MANAGER_RESP_DECERR"] = 1'b1;
        else if (t.role == AXI4L_SUBORDINATE && t.resp == RESP_DECERR)
          cov_hit["CROSS_ROLE_SUBORDINATE_RESP_DECERR"] = 1'b1;
      end

    endcase

    /* Sample the native SystemVerilog functional coverage model. */
    read_event_cg.sample(t.role, t.kind, t.addr, t.prot, t.resp);

  endfunction


  /*
   * Print each unique regression hit once, then print native per-test coverage.
   */
  virtual function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    foreach (cov_hit[key])
      $display("COV_HIT READ_PROTOCOL %s", key);

    `uvm_info(
      "READ_COVERAGE_SUMMARY",
      $sformatf(
        {"AXI4-Lite read protocol coverage:\n",
         "  Overall role/kind/address/protection/response coverage = %.2f%%\n",
         "  Role coverage                 = %.2f%%\n",
         "  Request/response coverage     = %.2f%%\n",
         "  ARPROT coverage               = %.2f%%\n",
         "  Address-region coverage       = %.2f%%\n",
         "  Response coverage             = %.2f%%\n",
         "  Role x kind coverage          = %.2f%%\n",
         "  Role x protection coverage    = %.2f%%\n",
         "  Role x response coverage      = %.2f%%"},
        read_event_cg.get_inst_coverage(),
        read_event_cg.role_cp.get_inst_coverage(),
        read_event_cg.kind_cp.get_inst_coverage(),
        read_event_cg.prot_cp.get_inst_coverage(),
        read_event_cg.addr_cp.get_inst_coverage(),
        read_event_cg.resp_cp.get_inst_coverage(),
        read_event_cg.role_kind_cross.get_inst_coverage(),
        read_event_cg.role_prot_cross.get_inst_coverage(),
        read_event_cg.role_resp_cross.get_inst_coverage()
      ),
      UVM_NONE
    )

  endfunction

endclass : axi4l_read_protocol_coverage