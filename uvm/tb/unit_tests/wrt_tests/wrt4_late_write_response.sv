
/* WRT-04 verifies late-response draining after a write-response timeout. 
A write is completed through AW/W, but the subordinate withholds BVALID long enough for the SCC to time out and terminate the upstream transaction with an injected SLVERR. 
The subordinate then presents its real B response late, before epoch recovery. 
The SCC must recognize that response as stale, consume it internally through the ghost-drain mechanism, and prevent it from being forwarded upstream as a second response.
*/
class wrt4_manager_write_seq extends axi4l_manager_write_seq;

    /* WRT-04: the SCC has already terminated the upstream write with an injected SLVERR, but it has not necessarily performed epoch_clr / full recovery yet. */

  `uvm_object_utils(wrt4_manager_write_seq)

  function new(string name = "wrt4_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 0;
      bready_delay == 0;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "WRT-04 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : wrt4_manager_write_seq


class wrt4_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(wrt4_subordinate_write_seq)

  function new(string name = "wrt4_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      bvalid_delay == 0;
      suppress_bvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "WRT-04 subordinate write randomization failed")
    end

    req.late_bvalid_after_timeout = 1'b1;

  endfunction : randomize_req

endclass : wrt4_subordinate_write_seq


class wrt4_late_write_response_test extends base_test;

  `uvm_component_utils(wrt4_late_write_response_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  wrt4_manager_write_seq manager_write_seq;
  wrt4_subordinate_write_seq subordinate_write_seq;

  function new(string name = "wrt4_late_write_response_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = wrt4_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = wrt4_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

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
    env.sb.set_expect_late_write_response(1'b1);

    `uvm_info("WRT_04", "Starting late downstream write-response drain test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("WRT_04", "Late downstream B response was drained after timeout", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : wrt4_late_write_response_test