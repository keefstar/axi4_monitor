/*
 * PROT-05 verifies the SCC's deliberate PR-01 upstream write-admission rule.
 *
 * The upstream manager deliberately presents WVALID before AWVALID. Although
 * AXI4-Lite permits independent presentation of AW and W, this implementation
 * intentionally refuses to accept W first. WREADY must therefore remain low
 * until the corresponding AW transfer has been accepted.
 */


class prot5_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(prot5_manager_write_seq)

  function new(string name = "prot5_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0940;
    req.prot = 3'b110;
    req.data = 32'hDEAD_BEEF;
    req.strb = 4'b1111;

    /*
     * W appears first. AW is deliberately delayed so that the SCC must refuse
     * early write-data acceptance.
     */
    req.w_delay = 0;
    req.aw_delay = 6;

    req.bready_delay = 0;
    req.suppress_wvalid = 0;

  endfunction : randomize_req

endclass : prot5_manager_write_seq



class prot5_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(prot5_subordinate_write_seq)

  function new(string name = "prot5_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay = 0;
    req.wready_delay = 0;
    req.bvalid_delay = 2;
    req.suppress_bvalid = 0;
    req.resp  = RESP_OKAY;

  endfunction : randomize_req

endclass : prot5_subordinate_write_seq



class prot5_wready_waits_for_aw_test extends base_test;

  `uvm_component_utils(prot5_wready_waits_for_aw_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  prot5_manager_write_seq manager_write_seq;
  prot5_subordinate_write_seq subordinate_write_seq;


  function new(string name = "prot5_wready_waits_for_aw_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq = prot5_manager_write_seq::type_id::create("manager_write_seq");
    subordinate_write_seq = prot5_subordinate_write_seq::type_id::create("subordinate_write_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.clear_reg <= '0;

    `uvm_info("PROT_05", "Starting PR-01 upstream W-before-AW admission test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    repeat (3) @(ctrl_vif.cb);

    `uvm_info("PROT_05", "Early W was withheld until AW acceptance and the write completed normally", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : prot5_wready_waits_for_aw_test