/* RTO-01: verify missing downstream read response is detected as a timeout */


/* manager issues normal read and waits for response */
class rto1_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rto1_manager_read_seq)

  function new(string name = "rto1_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-01 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : rto1_manager_read_seq


/* subordinate accepts AR but intentionally never returns RVALID */
class rto1_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rto1_subordinate_read_seq)

  function new(string name = "rto1_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      arready_delay == 0;
      suppress_rvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-01 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : rto1_subordinate_read_seq


class rto1_read_response_timeout_test extends base_test;

  `uvm_component_utils(rto1_read_response_timeout_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rto1_manager_read_seq manager_read_seq;
  rto1_subordinate_read_seq subordinate_read_seq;

  function new(string name = "rto1_read_response_timeout_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = rto1_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = rto1_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    /* scoreboard expects timeout-generated upstream SLVERR */
    env.sb.set_expect_read_timeout(1'b1);

    `uvm_info("RTO_01", "Starting read with downstream RVALID suppressed", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    `uvm_info("RTO_01", "Missing downstream read response detected and contained", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rto1_read_response_timeout_test