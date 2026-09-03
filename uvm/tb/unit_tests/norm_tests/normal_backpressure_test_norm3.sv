/* NORM-03: verify legal upstream/downstream backpressure does not cause a false fault */


/* read manager: delay RREADY to create upstream backpressure */
class norm3_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(norm3_manager_read_seq)

  function new(string name = "norm3_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 5;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-03 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : norm3_manager_read_seq


/* read subordinate: delay ARREADY and RVALID */
class norm3_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(norm3_subordinate_read_seq)

  function new(string name = "norm3_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      arready_delay == 5;
      rvalid_delay == 5;
      suppress_rvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-03 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : norm3_subordinate_read_seq


/* write manager: delay BREADY to create upstream backpressure */
class norm3_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(norm3_manager_write_seq)

  function new(string name = "norm3_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 0;
      bready_delay == 5;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-03 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : norm3_manager_write_seq


/* write subordinate: delay AWREADY/WREADY and BVALID */
class norm3_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(norm3_subordinate_write_seq)

  function new(string name = "norm3_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      awready_delay == 5;
      wready_delay == 5;
      bvalid_delay == 5;
      suppress_bvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-03 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : norm3_subordinate_write_seq



class normal_backpressure_test_norm3 extends base_test;

  `uvm_component_utils(normal_backpressure_test_norm3)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  norm3_manager_read_seq manager_read_seq;
  norm3_subordinate_read_seq subordinate_read_seq;

  norm3_manager_write_seq manager_write_seq;
  norm3_subordinate_write_seq subordinate_write_seq;


  function new(string name = "normal_backpressure_test_norm3", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    manager_read_seq = norm3_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = norm3_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    manager_write_seq = norm3_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = norm3_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

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

    `uvm_info("NORM_03", "Starting read transaction with legal backpressure", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    `uvm_info("NORM_03", "Starting write transaction with legal backpressure", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    phase.drop_objection(this);

  endtask : run_phase

endclass : normal_backpressure_test_norm3