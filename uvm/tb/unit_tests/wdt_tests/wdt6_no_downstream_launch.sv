class wdt6_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(wdt6_manager_write_seq)

  function new(string name = "wdt6_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      suppress_wvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "WDT-06 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : wdt6_manager_write_seq


class wdt6_no_downstream_launch_test extends base_test;

  `uvm_component_utils(wdt6_no_downstream_launch_test)

  axi4l_write_sequencer upstream_write_sqr;
  wdt6_manager_write_seq manager_write_seq;

  function new(string name = "wdt6_no_downstream_launch_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = wdt6_manager_write_seq::type_id::create("manager_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    env.sb.set_expect_write_data_timeout(1'b1);

    `uvm_info("WDT_06", "Starting AW-only downstream containment test", UVM_LOW)

    manager_write_seq.start(upstream_write_sqr);

    `uvm_info("WDT_06", "AW-only partial write remained confined upstream", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : wdt6_no_downstream_launch_test