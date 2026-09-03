/* FLT-05 verifies interrupt masking without suppressing fault recording.
   A read timeout is generated while the corresponding enable_reg bit is clear.
   The interrupt controller must still latch READ_TIMEOUT in status_reg, but the
   masked source must not contribute to pending and must therefore never assert
   irq, even after the SCC becomes quiescent. */
   class flt5_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(flt5_manager_read_seq)

  function new(string name = "flt5_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-05 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : flt5_manager_read_seq


class flt5_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(flt5_subordinate_read_seq)

  function new(string name = "flt5_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      arready_delay == 0;
      rvalid_delay == 0;
      suppress_rvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-05 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : flt5_subordinate_read_seq


class flt5_masked_fault_no_irq_test extends base_test;

  `uvm_component_utils(flt5_masked_fault_no_irq_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  flt5_manager_read_seq manager_read_seq;
  flt5_subordinate_read_seq subordinate_read_seq;

  function new(string name = "flt5_masked_fault_no_irq_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = flt5_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = flt5_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    /* Mask every source. The fault must still be recorded in status_reg. */
    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.clear_reg  <= '0;

    env.sb.set_expect_read_timeout(1'b1);

    `uvm_info("FLT_05", "Starting masked-fault interrupt test", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    /* Allow containment to finish so the test exercises the stronger case:
       status is pending internally, the SCC is quiescent, but irq stays low
       because READ_TIMEOUT is masked. */
    repeat (10)
      @(ctrl_vif.cb);

    `uvm_info( "FLT_05", "Masked READ_TIMEOUT remained recorded without asserting irq", UVM_LOW )

    phase.drop_objection(this);

  endtask : run_phase

endclass : flt5_masked_fault_no_irq_test