/*
 * CC-07: verify forwarding of a downstream DECERR write response.
 *
 * A normal write is accepted and forwarded to the subordinate. The subordinate
 * deliberately returns RESP_DECERR. The SCC must forward that response upstream
 * without converting or suppressing it.
 */


class cc7_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(cc7_manager_write_seq)

  function new(string name = "cc7_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0E00;
    req.prot = 3'b000;
    req.data  = 32'hDEAD_BEEF;
    req.strb = 4'b1111;
    req.aw_delay = 0;
    req.w_delay = 0;
    req.bready_delay = 0;
    req.suppress_wvalid = 0;
    req.late_wvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : cc7_manager_write_seq


class cc7_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(cc7_subordinate_write_seq)

  function new(string name = "cc7_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay = 0;
    req.wready_delay = 0;
    req.bvalid_delay  = 0;
    req.suppress_bvalid= 0;
    req.late_bvalid_after_timeout = 0;
    req.resp = RESP_DECERR;

  endfunction : randomize_req

endclass : cc7_subordinate_write_seq


class downstream_decerr_test_cc7 extends base_test;

  `uvm_component_utils(downstream_decerr_test_cc7)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  cc7_manager_write_seq manager_write_seq;
  cc7_subordinate_write_seq subordinate_write_seq;


  function new(string name = "downstream_decerr_test_cc7", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq = cc7_manager_write_seq::type_id::create("manager_write_seq");
    subordinate_write_seq = cc7_subordinate_write_seq::type_id::create("subordinate_write_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("CC_07", "Starting downstream-DECERR forwarding coverage-closure test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("CC_07", "Downstream DECERR completed and was forwarded upstream", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : downstream_decerr_test_cc7