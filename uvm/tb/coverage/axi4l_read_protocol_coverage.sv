class axi4l_read_protocol_coverage extends uvm_subscriber #(axi4l_read_item);

  `uvm_component_utils(axi4l_read_protocol_coverage)

  covergroup read_event_cg with function sample(
    axi4l_role_e role,
    axi4l_read_item::axi4l_read_kind_e kind,
    logic [ADDR_WIDTH-1:0] addr,
    logic [PROT_WIDTH-1:0] prot,
    axi_resp_e resp
  );

    option.per_instance = 1;
    //Which interface generated the transaction?
    /* Covers NORM-05; verify that read traffic is obtained on btoh manager and subordinate interfaces*/
    role_cp : coverpoint role {
      bins manager     = {AXI4L_MANAGER};
      bins subordinate = {AXI4L_SUBORDINATE};
    }

    //Was this a request or a response?
    /* Verify that both read requests and read responses are exercised.*/
    kind_cp : coverpoint kind {
      bins request  = {axi4l_read_item::READ_REQUEST};
      bins response = {axi4l_read_item::READ_RESPONSE};
    }

    //Exercise every ARPROT encoding; NORM-05
    prot_cp : coverpoint prot
      iff (kind == axi4l_read_item::READ_REQUEST)
    {
      bins values[] = {[3'b000:3'b111]};
    }

    //Exercise accesses both inside and outside the protected region; NORM-05
    addr_cp : coverpoint addr
      iff (kind == axi4l_read_item::READ_REQUEST)
    {
      bins subordinate_region =
        {[SUB_ADDR_BASE:SUB_ADDR_END]};

      bins other_region = default;
    }

    //Observe both successful and error read responses; NORM-05
    resp_cp : coverpoint resp
      iff (kind == axi4l_read_item::READ_RESPONSE)
    {
      bins okay   = {RESP_OKAY};
      bins slverr = {RESP_SLVERR};
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

  function new( string name = "axi4l_read_coverage", uvm_component parent = null);
    super.new(name, parent);
    read_event_cg = new();
    read_event_cg.set_inst_name({get_full_name(), ".read_event_cg"});
  endfunction


  /* uv, subscriber requires me to implement a function write();
  when a connected monitor publishes a transaction,  UVM automatically calls the subscribers write*/
  /* In the UVM analysis system, a producer “writes” a transaction to an analysis port. Every connected subscriber receives that transaction through its corresponding write() implementation.*/
  virtual function void write(axi4l_read_item t);

    case (t.kind)

      axi4l_read_item::READ_REQUEST: begin
        `uvm_info(
          "READ_COVERAGE",
          $sformatf(
            "Sampled role=%s kind=%s addr=0x%0h prot=%03b",
            t.role.name(), t.kind.name(),t.addr, t.prot
          ),
          UVM_MEDIUM
        )
      end

      axi4l_read_item::READ_RESPONSE: begin
        `uvm_info(
          "READ_COVERAGE",
          $sformatf(
            "Sampled role=%s kind=%s data=0x%0h resp=%s",
            t.role.name(), t.kind.name(), t.data, t.resp.name()
          ),
          UVM_MEDIUM
        )
      end

    endcase
    /* takes fields from transaction t and record coverage sample*/
    read_event_cg.sample(t.role, t.kind, t.addr, t.prot, t.resp);
  endfunction

  virtual function void report_phase(uvm_phase phase);
  super.report_phase(phase);

  `uvm_info(
    "READ_COVERAGE_SUMMARY",
    $sformatf(
      {"AXI4-Lite read protocol coverage:\n",
       "  Overall role/kind/address/protection/response coverage = %.2f%%\n",
       "  Role coverage                 = %.2f%%\n",
       "  Request/response coverage     = %.2f%%\n",
       "  ARPROT coverage               = %.2f%%\n",
      // "  Address-region coverage       = %.2f%%\n",
       "  Response coverage             = %.2f%%\n",
       "  Role x kind coverage          = %.2f%%\n",
       "  Role x protection coverage    = %.2f%%\n",
       "  Role x response coverage      = %.2f%%"},
      read_event_cg.get_inst_coverage(),
      read_event_cg.role_cp.get_inst_coverage(),
      read_event_cg.kind_cp.get_inst_coverage(),
      read_event_cg.prot_cp.get_inst_coverage(),
      //read_event_cg.addr_cp.get_inst_coverage(),
      read_event_cg.resp_cp.get_inst_coverage(),
      read_event_cg.role_kind_cross.get_inst_coverage(),
      read_event_cg.role_prot_cross.get_inst_coverage(),
      read_event_cg.role_resp_cross.get_inst_coverage()
    ),
    UVM_NONE
  )

endfunction


endclass : axi4l_read_protocol_coverage


/* Plan for no Verisium

1) Run each UVM test using xrun
2) At the end of simulation, print:
* Overall fun



*/