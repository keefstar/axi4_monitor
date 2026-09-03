/*
 * PROT-06 verifies the downstream half of PR-01.
 *
 * The upstream write address is presented and accepted first, while WVALID is
 * deliberately delayed. The SCC must retain the accepted address internally
 * and must not launch downstream AWVALID before the corresponding write data
 * has been captured.
 *
 * Once W is accepted, the complete write pair becomes available and the SCC
 * may launch downstream AW and W together.
 */


class prot6_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(prot6_manager_write_seq)

  function new(string name = "prot6_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0950;
    req.prot = 3'b111;
    req.data = 32'hCAFE_BABE;
    req.strb = 4'b1111;

    /*
     * AW arrives immediately, while W is deliberately delayed.
     */
    req.aw_delay = 0;
    req.w_delay = 6;

    req.bready_delay = 0;
    req.suppress_wvalid = 0;

  endfunction : randomize_req

endclass : prot6_manager_write_seq



class prot6_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(prot6_subordinate_write_seq)

  function new(string name = "prot6_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay = 0;
    req.wready_delay = 0;
    req.bvalid_delay  = 2;
    req.suppress_bvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : prot6_subordinate_write_seq



class prot6_downstream_waits_for_write_pair_test extends base_test;

  `uvm_component_utils(prot6_downstream_waits_for_write_pair_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  prot6_manager_write_seq manager_write_seq;
  prot6_subordinate_write_seq subordinate_write_seq;


  function new(string name = "prot6_downstream_waits_for_write_pair_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq = prot6_manager_write_seq::type_id::create("manager_write_seq");
    subordinate_write_seq = prot6_subordinate_write_seq::type_id::create("subordinate_write_seq");

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

    `uvm_info("PROT_06", "Starting PR-01 downstream write-pair admission test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    repeat (3) @(ctrl_vif.cb);

    `uvm_info("PROT_06", "Downstream AW/W launch waited for the complete upstream write pair", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : prot6_downstream_waits_for_write_pair_test