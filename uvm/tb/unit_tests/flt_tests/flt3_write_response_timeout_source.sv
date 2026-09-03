/* FLT-03 verifies fault-source recording for a write-response timeout.
   A complete write is accepted and forwarded downstream, but the subordinate
   deliberately withholds BVALID until the SCC reports a write-response timeout.
   The interrupt controller must latch WRITE_RESP_TIMEOUT in its sticky status
   register, and no unrelated fault-source status bit may be set. */
   class flt3_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(flt3_manager_write_seq)

  function new(string name = "flt3_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 0;
      bready_delay == 0;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-03 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : flt3_manager_write_seq


class flt3_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(flt3_subordinate_write_seq)

  function new(string name = "flt3_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      bvalid_delay == 0;
      suppress_bvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "FLT-03 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : flt3_subordinate_write_seq


class flt3_write_response_timeout_source_test extends base_test;

  `uvm_component_utils(flt3_write_response_timeout_source_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  flt3_manager_write_seq manager_write_seq;
  flt3_subordinate_write_seq subordinate_write_seq;

  function new(string name = "flt3_write_response_timeout_source_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = flt3_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = flt3_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    env.sb.set_expect_write_timeout(1'b1);

    `uvm_info("FLT_03", "Starting WRITE_RESP_TIMEOUT fault-source recording test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("FLT_03", "WRITE_RESP_TIMEOUT fault source recorded", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : flt3_write_response_timeout_source_test