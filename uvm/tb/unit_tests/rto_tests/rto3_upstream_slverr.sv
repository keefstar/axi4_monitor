/* RTO-03: verify read timeout terminates upstream transaction with SLVERR */


/* manager issues read and waits for injected response */
class rto3_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rto3_manager_read_seq)

  function new(string name = "rto3_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-03 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : rto3_manager_read_seq


/* subordinate accepts AR but never returns RVALID */
class rto3_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rto3_subordinate_read_seq)

  function new(string name = "rto3_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      arready_delay == 0;
      suppress_rvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-03 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : rto3_subordinate_read_seq


class rto3_upstream_slverr_test extends base_test;

  `uvm_component_utils(rto3_upstream_slverr_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rto3_manager_read_seq manager_read_seq;
  rto3_subordinate_read_seq subordinate_read_seq;

  function new(string name = "rto3_upstream_slverr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = rto3_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = rto3_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    /* require timeout-generated upstream SLVERR */
    env.sb.set_expect_read_timeout(1'b1);

    `uvm_info("RTO_03", "Starting read timeout for upstream SLVERR verification", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    `uvm_info("RTO_03", "Timed-out upstream read terminated with SLVERR", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rto3_upstream_slverr_test