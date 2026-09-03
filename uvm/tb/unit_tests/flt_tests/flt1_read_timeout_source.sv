/* FLT-01 verifies fault-source recording for a read timeout.
   A downstream read response is deliberately withheld until the SCC detects
   a read timeout. The fault-reporting logic must record READ_TIMEOUT as the
   active fault source so that software can identify the cause of containment. */
   class flt1_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(flt1_manager_read_seq)

  function new(string name = "flt1_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-01 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : flt1_manager_read_seq


class flt1_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(flt1_subordinate_read_seq)

  function new(string name = "flt1_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      arready_delay == 0;
      rvalid_delay == 0;
      suppress_rvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-01 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : flt1_subordinate_read_seq


class flt1_read_timeout_source_test extends base_test;

  `uvm_component_utils(flt1_read_timeout_source_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  flt1_manager_read_seq manager_read_seq;
  flt1_subordinate_read_seq subordinate_read_seq;

  function new(string name = "flt1_read_timeout_source_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = flt1_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = flt1_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    env.sb.set_expect_read_timeout(1'b1);

    `uvm_info("FLT_01", "Starting READ_TIMEOUT fault-source recording test", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    `uvm_info("FLT_01", "READ_TIMEOUT fault source recorded", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : flt1_read_timeout_source_test