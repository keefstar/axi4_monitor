/* WDT-04: verify W data presented at the final legal boundary does not timeout */

class wdt4_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(wdt4_manager_write_seq)

  function new(string name = "wdt4_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    /* WDT-04 deliberately exceeds the normal manager delay range. */
    req.manager_delay_c.constraint_mode(0);

    /*
    * The manager driver's w_delay begins counting before the SCC write-data
    * timer is active. A diagnostic SVA using $sampled(w_timer) showed that
    * w_delay = TIMEOUT_COUNTER + 1 presented WVALID when w_timer == 255.
    * Therefore +2 aligns WVALID with the DUT boundary w_timer == TIMEOUT_COUNTER.
    */
    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == a4lite_pkg::TIMEOUT_COUNTER + 2;
      bready_delay == 0;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "WDT-04 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : wdt4_manager_write_seq

class wdt4_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(wdt4_subordinate_write_seq)

  function new(string name = "wdt4_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      bvalid_delay == 0;
      resp == RESP_OKAY;
      suppress_bvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "WDT-04 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : wdt4_subordinate_write_seq

class wdt4_final_boundary_test extends base_test;

  `uvm_component_utils(wdt4_final_boundary_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  wdt4_manager_write_seq manager_write_seq;
  wdt4_subordinate_write_seq subordinate_write_seq;

  function new(string name = "wdt4_final_boundary_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = wdt4_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = wdt4_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("WDT_04", "Starting final legal write-data boundary test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("WDT_04", "Write data completed at timeout boundary without false timeout", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : wdt4_final_boundary_test