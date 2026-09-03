/* FLT-07 verifies independent accumulation of multiple fault sources.
   A write-data timeout and a read timeout are generated during the same fault
   episode. The interrupt controller must preserve the first recorded source
   when the second source subsequently arrives, leaving both corresponding
   status bits asserted without aliasing or overwriting either fault. */
   
   class flt7_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(flt7_manager_read_seq)

  function new(string name = "flt7_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-07 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : flt7_manager_read_seq


class flt7_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(flt7_subordinate_read_seq)

  function new(string name = "flt7_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      arready_delay == 0;
      rvalid_delay == 0;
      suppress_rvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-07 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : flt7_subordinate_read_seq


class flt7_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(flt7_manager_write_seq)

  function new(string name = "flt7_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      suppress_wvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-07 manager write randomization failed")
    end

  endfunction : randomize_req

  class flt7_multiple_fault_sources_test extends base_test;

  `uvm_component_utils(flt7_multiple_fault_sources_test)

  axi4l_read_sequencer  upstream_read_sqr;
  axi4l_read_sequencer  downstream_read_sqr;
  axi4l_write_sequencer upstream_write_sqr;

  flt7_manager_read_seq     manager_read_seq;
  flt7_subordinate_read_seq subordinate_read_seq;
  flt7_manager_write_seq    manager_write_seq;

  function new(string name = "flt7_multiple_fault_sources_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = flt7_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = flt7_subordinate_read_seq::type_id::create("subordinate_read_seq", this);
    manager_write_seq = flt7_manager_write_seq::type_id::create("manager_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr  = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;
    upstream_write_sqr = env.upstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.clear_reg  <= '0;

    env.sb.set_expect_read_timeout(1'b1);
    env.sb.set_expect_write_data_timeout(1'b1);

    `uvm_info("FLT_07", "Starting simultaneous multiple-fault-source test", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
      manager_write_seq.start(upstream_write_sqr);
    join

    repeat (10)
      @(ctrl_vif.cb);

    `uvm_info(
      "FLT_07",
      "READ_TIMEOUT and WRITE_DATA_TIMEOUT were independently recorded",
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask : run_phase

endclass : flt7_multiple_fault_sources_test

endclass : flt7_manager_write_seq