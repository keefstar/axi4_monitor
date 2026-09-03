/* WRT-02 verifies upstream termination after a write-response timeout.
   After the subordinate withholds BVALID long enough for the response timer
   to expire, the SCC must enter WR_INJECTING and terminate the upstream write
   by presenting BVALID with BRESP = SLVERR. */
   
class wrt2_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(wrt2_manager_write_seq)

  function new(string name = "wrt2_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 0;
      bready_delay == 0;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "WRT-02 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : wrt2_manager_write_seq


class wrt2_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(wrt2_subordinate_write_seq)

  function new(string name = "wrt2_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      suppress_bvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "WRT-02 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : wrt2_subordinate_write_seq


class wrt2_slverr_injection_test extends base_test;

  `uvm_component_utils(wrt2_slverr_injection_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  wrt2_manager_write_seq manager_write_seq;
  wrt2_subordinate_write_seq subordinate_write_seq;

  function new(string name = "wrt2_slverr_injection_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = wrt2_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = wrt2_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

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

    `uvm_info("WRT_02", "Starting write-response SLVERR injection test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("WRT_02", "Write-response timeout produced upstream SLVERR", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : wrt2_slverr_injection_test