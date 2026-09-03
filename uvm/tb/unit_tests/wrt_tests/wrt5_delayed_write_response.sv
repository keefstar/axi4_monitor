
/* WRT-05 verifies that a delayed but legal downstream write response does not
   cause a false timeout. A complete write is forwarded through AW/W and the
   subordinate deliberately delays BVALID until close to the configured
   write-response timeout threshold. Because the response arrives before expiry,
   the SCC must forward the real response upstream and complete normally without
   entering WR_INJECTING or generating a write-response-timeout fault. */
   class wrt5_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(wrt5_manager_write_seq)

  function new(string name = "wrt5_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 0;
      bready_delay == 0;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "WRT-05 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : wrt5_manager_write_seq


class wrt5_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(wrt5_subordinate_write_seq)

  function new(string name = "wrt5_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    /*
     * WRT-05 intentionally exceeds the normal subordinate delay range
     * so that BVALID arrives close to, but before, timeout expiry.
     */
    req.subordinate_delay_c.constraint_mode(0);

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      bvalid_delay == a4lite_pkg::TIMEOUT_COUNTER - 10;
      suppress_bvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "WRT-05 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : wrt5_subordinate_write_seq


class wrt5_delayed_write_response_test extends base_test;

  `uvm_component_utils(wrt5_delayed_write_response_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  wrt5_manager_write_seq manager_write_seq;
  wrt5_subordinate_write_seq subordinate_write_seq;

  function new(string name = "wrt5_delayed_write_response_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = wrt5_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = wrt5_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("WRT_05", "Starting delayed legal downstream write-response test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("WRT_05", "Delayed downstream B response completed normally before timeout", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : wrt5_delayed_write_response_test