/* RTO-05: verify late downstream response is drained after timeout */


/* manager issues read and accepts injected timeout response */
class rto5_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rto5_manager_read_seq)

  function new(string name = "rto5_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-05 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : rto5_manager_read_seq


/* subordinate responds only after SCC has already timed out */
class rto5_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rto5_subordinate_read_seq)

  function new(string name = "rto5_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    /* normal subordinate delay constraint only permits 0:5 cycles */
    req.subordinate_delay_c.constraint_mode(0);

    if (!req.randomize() with {
      arready_delay == 0;
      rvalid_delay == TIMEOUT_COUNTER + 20;
      suppress_rvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-05 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : rto5_subordinate_read_seq


class rto5_late_response_drain_test extends base_test;

  `uvm_component_utils(rto5_late_response_drain_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rto5_manager_read_seq manager_read_seq;
  rto5_subordinate_read_seq subordinate_read_seq;

  function new(string name = "rto5_late_response_drain_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = rto5_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = rto5_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    /* upstream transaction must terminate with injected SLVERR */
    env.sb.set_expect_read_timeout(1'b1);

    /* one real downstream response is expected after timeout */
    env.sb.set_expect_late_read_response(1'b1);

    `uvm_info("RTO_05", "Starting read with response delayed beyond timeout", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    `uvm_info("RTO_05", "Late downstream response completed without being forwarded upstream", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rto5_late_response_drain_test