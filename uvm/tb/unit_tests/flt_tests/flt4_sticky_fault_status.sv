/* FLT-04 verifies sticky fault-status retention.
   A fault notification is generated as a one-cycle pulse and then disappears.
   The interrupt controller must retain the corresponding status_reg bit until
   software explicitly clears it, allowing software to identify the fault after
   the original hardware event is no longer present. */
   class flt4_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(flt4_manager_read_seq)

  function new(string name = "flt4_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-04 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : flt4_manager_read_seq


class flt4_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(flt4_subordinate_read_seq)

  function new(string name = "flt4_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      arready_delay == 0;
      rvalid_delay == 0;
      suppress_rvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-04 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : flt4_subordinate_read_seq


class flt4_sticky_fault_status_test extends base_test;

  `uvm_component_utils(flt4_sticky_fault_status_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  flt4_manager_read_seq manager_read_seq;
  flt4_subordinate_read_seq subordinate_read_seq;

  function new(string name = "flt4_sticky_fault_status_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = flt4_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = flt4_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

  phase.raise_objection(this);
  phase.phase_done.set_drain_time(this, 100ns);

  ctrl_vif.cb.enable_reg <= '1;
  ctrl_vif.cb.clear_reg  <= '0;

  env.sb.set_expect_read_timeout(1'b1);

  `uvm_info("FLT_04", "Starting sticky fault-status retention test", UVM_LOW)

  fork
    manager_read_seq.start(upstream_read_sqr);
    subordinate_read_seq.start(downstream_read_sqr);
  join

  /* Leave time after the one-cycle notification disappears.
     No software clear is issued, so the recorded fault must remain sticky. */
  repeat (10)
    @(ctrl_vif.cb);

  `uvm_info(
    "FLT_04",
    "Fault status remained latched after notification pulse disappeared",
    UVM_LOW
  )

  phase.drop_objection(this);

endtask : run_phase

endclass : flt4_sticky_fault_status_test