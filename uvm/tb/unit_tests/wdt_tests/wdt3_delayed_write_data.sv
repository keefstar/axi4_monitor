/* WDT-03: verify delayed legal W data does not cause a false write-data timeout */
class wdt3_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(wdt3_manager_write_seq)

  function new(string name = "wdt3_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();
  /* WDT-03 deliberately exceeds the normal manager delay range to approach the timeout boundary. */
  req.manager_delay_c.constraint_mode(0);
    if (!req.randomize() with {
        aw_delay == 0;
        w_delay == a4lite_pkg::TIMEOUT_COUNTER - 10;
        bready_delay == 0;
        suppress_wvalid == 0;
      }) begin
      `uvm_fatal(get_type_name(), "WDT-03 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : wdt3_manager_write_seq


class wdt3_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(wdt3_subordinate_write_seq)

  function new(string name = "wdt3_subordinate_write_seq");
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
      `uvm_fatal(get_type_name(), "WDT-03 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : wdt3_subordinate_write_seq


class wdt3_delayed_write_data_test extends base_test;

  `uvm_component_utils(wdt3_delayed_write_data_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  wdt3_manager_write_seq manager_write_seq;
  wdt3_subordinate_write_seq subordinate_write_seq;

  function new(string name = "wdt3_delayed_write_data_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = wdt3_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = wdt3_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("WDT_03", "Starting delayed but legal write-data test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    `uvm_info("WDT_03", "Delayed write data completed without write-data timeout", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : wdt3_delayed_write_data_test