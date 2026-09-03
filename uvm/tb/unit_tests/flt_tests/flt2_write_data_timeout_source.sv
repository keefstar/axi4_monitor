/* FLT-02 verifies fault-source recording for a write-data timeout.
   An upstream write address is accepted while the corresponding write data is
   deliberately withheld until the SCC reports a write-data timeout. The
   interrupt controller must latch WRITE_DATA_TIMEOUT in its sticky status
   register, and no unrelated fault-source status bit may be set. */
   class flt2_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(flt2_manager_write_seq)

  function new(string name = "flt2_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      suppress_wvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-02 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : flt2_manager_write_seq


class flt2_write_data_timeout_source_test extends base_test;

  `uvm_component_utils(flt2_write_data_timeout_source_test)

  axi4l_write_sequencer upstream_write_sqr;
  flt2_manager_write_seq manager_write_seq;

  function new(string name = "flt2_write_data_timeout_source_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = flt2_manager_write_seq::type_id::create("manager_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    env.sb.set_expect_write_data_timeout(1'b1);

    `uvm_info("FLT_02", "Starting WRITE_DATA_TIMEOUT fault-source recording test", UVM_LOW)

    manager_write_seq.start(upstream_write_sqr);

    `uvm_info("FLT_02", "WRITE_DATA_TIMEOUT fault source recorded", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : flt2_write_data_timeout_source_test