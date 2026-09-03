/* WRT-03 verifies that an injected timeout response obeys AXI backpressure.
   After a write-response timeout, the SCC presents an upstream SLVERR while
   the manager deliberately holds BREADY low. The SCC must keep BVALID asserted
   and BRESP stable until the manager eventually accepts the response. */
   
class wrt3_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(wrt3_manager_write_seq)

  function new(string name = "wrt3_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    /* WRT-03 deliberately exceeds the normal manager BREADY delay range. */
    req.manager_delay_c.constraint_mode(0);

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 0;
      bready_delay == a4lite_pkg::TIMEOUT_COUNTER + 20; /* had to increase from just = 10 because the result showed manager asserted BREADY at only 165ns but SLVERR injection di dnot happen until 2.6 us later. */
      /* so by the time SCC entered WR_INKECTING, BREADY had already been high and there was no backpressure */
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "WRT-03 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : wrt3_manager_write_seq


class wrt3_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(wrt3_subordinate_write_seq)

  function new(string name = "wrt3_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      suppress_bvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "WRT-03 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : wrt3_subordinate_write_seq


class wrt3_slverr_backpressure_test extends base_test;

  `uvm_component_utils(wrt3_slverr_backpressure_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  wrt3_manager_write_seq manager_write_seq;
  wrt3_subordinate_write_seq subordinate_write_seq;

  function new(string name = "wrt3_slverr_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = wrt3_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = wrt3_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

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

    `uvm_info("WRT_03", "Starting SLVERR backpressure stability test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("WRT_03", "Injected SLVERR remained stable under BREADY backpressure", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : wrt3_slverr_backpressure_test