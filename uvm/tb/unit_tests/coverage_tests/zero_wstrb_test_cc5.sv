/*
 * CC-05: exercise the zero write-strobe encoding.
 *
 * A normal AXI4-Lite write is completed with WSTRB=4'b0000. The transaction
 * must still complete normally while exercising the previously uncovered
 * zero-strobe bins on both the upstream and downstream interfaces.
 */


class cc5_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(cc5_manager_write_seq)

  function new(string name = "cc5_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0C00;
    req.prot = 3'b000;
    req.data = 32'hA5A5_5A5A;
    req.strb = 4'b0000;
    req.aw_delay  = 0;
    req.w_delay = 0;
    req.bready_delay = 0;
    req.suppress_wvalid = 0;
    req.late_wvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : cc5_manager_write_seq


class cc5_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(cc5_subordinate_write_seq)

  function new(string name = "cc5_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay  = 0;
    req.wready_delay = 0;
    req.bvalid_delay = 0;
    req.suppress_bvalid = 0;
    req.late_bvalid_after_timeout = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : cc5_subordinate_write_seq


class zero_wstrb_test_cc5 extends base_test;

  `uvm_component_utils(zero_wstrb_test_cc5)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  cc5_manager_write_seq manager_write_seq;
  cc5_subordinate_write_seq subordinate_write_seq;


  function new(string name = "zero_wstrb_test_cc5", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq = cc5_manager_write_seq::type_id::create("manager_write_seq");
    subordinate_write_seq = cc5_subordinate_write_seq::type_id::create("subordinate_write_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("CC_05", "Starting zero-WSTRB coverage-closure test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("CC_05", "Zero-WSTRB write completed normally", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : zero_wstrb_test_cc5