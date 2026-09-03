/* NORM-07: verify responses arriving at the timeout boundary do not cause a false fault */


/* manager accepts read response immediately */
class norm7_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(norm7_manager_read_seq)

  function new(string name = "norm7_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-07 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : norm7_manager_read_seq


/* subordinate returns RVALID at the last legal timeout boundary */
class norm7_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(norm7_subordinate_read_seq)

  function new(string name = "norm7_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    /* normal delay constraint only permits 0:5 cycles */
    req.subordinate_delay_c.constraint_mode(0);

    if (!req.randomize() with {
      arready_delay == 0;
      rvalid_delay == TIMEOUT_COUNTER;
      suppress_rvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-07 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : norm7_subordinate_read_seq


/* manager completes write and accepts B immediately */
class norm7_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(norm7_manager_write_seq)

  function new(string name = "norm7_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 0;
      bready_delay == 0;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-07 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : norm7_manager_write_seq


/* subordinate returns BVALID at the last legal timeout boundary */
class norm7_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(norm7_subordinate_write_seq)

  function new(string name = "norm7_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    /* normal delay constraint only permits 0:5 cycles */
    req.subordinate_delay_c.constraint_mode(0);

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      bvalid_delay == TIMEOUT_COUNTER;
      suppress_bvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-07 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : norm7_subordinate_write_seq



class pre_timeout_boundary_test_norm7 extends base_test;

  `uvm_component_utils(pre_timeout_boundary_test_norm7)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  norm7_manager_read_seq manager_read_seq;
  norm7_subordinate_read_seq subordinate_read_seq;

  norm7_manager_write_seq manager_write_seq;
  norm7_subordinate_write_seq subordinate_write_seq;

  function new(string name = "pre_timeout_boundary_test_norm7", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = norm7_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = norm7_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    manager_write_seq = norm7_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = norm7_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("NORM_07", "Starting read at pre-timeout boundary", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    `uvm_info("NORM_07", "Read completed without false timeout", UVM_LOW)
    `uvm_info("NORM_07", "Starting write-response at pre-timeout boundary", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("NORM_07", "Write completed without false timeout", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : pre_timeout_boundary_test_norm7