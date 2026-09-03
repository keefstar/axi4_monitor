/* FLT-06 verifies interrupt assertion for an enabled pending fault.
   A read timeout is generated with READ_TIMEOUT enabled. The interrupt
   controller must record the fault immediately, keep irq low while the SCC is
   still non-quiescent, and assert irq once the upstream obligations have been
   discharged and quiescent becomes true. */
   class flt6_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(flt6_manager_read_seq)

  function new(string name = "flt6_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-06 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : flt6_manager_read_seq


class flt6_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(flt6_subordinate_read_seq)

  function new(string name = "flt6_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      arready_delay == 0;
      rvalid_delay == 0;
      suppress_rvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-06 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : flt6_subordinate_read_seq


class flt6_enabled_fault_irq_test extends base_test;

  `uvm_component_utils(flt6_enabled_fault_irq_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  flt6_manager_read_seq manager_read_seq;
  flt6_subordinate_read_seq subordinate_read_seq;

  function new(string name = "flt6_enabled_fault_irq_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = flt6_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = flt6_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    /* Enable READ_TIMEOUT interrupt reporting and issue no software clear. */
    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.enable_reg[READ_TIMEOUT] <= 1'b1;
    ctrl_vif.cb.clear_reg <= '0;

    env.sb.set_expect_read_timeout(1'b1);

    `uvm_info("FLT_06", "Starting enabled-fault interrupt test", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    /* Allow containment to complete and quiescence to assert. */
    repeat (10)
      @(ctrl_vif.cb);

    `uvm_info(
      "FLT_06",
      "Enabled READ_TIMEOUT asserted irq after the SCC became quiescent",
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask : run_phase

endclass : flt6_enabled_fault_irq_test