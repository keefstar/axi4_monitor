/*
 * CC-03: verify masked WRITE_RESP_TIMEOUT fault handling.
 *
 * A complete write is forwarded downstream, but the subordinate withholds
 * BVALID until WRITE_RESP_TIMEOUT occurs. The fault source is disabled in the
 * interrupt-enable register, so status must record the fault while IRQ remains
 * deasserted.
 */


class cc3_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(cc3_manager_write_seq)

  function new(string name = "cc3_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 0;
      bready_delay == 0;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "CC-03 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : cc3_manager_write_seq


class cc3_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(cc3_subordinate_write_seq)

  function new(string name = "cc3_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      bvalid_delay == 0;
      suppress_bvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "CC-03 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : cc3_subordinate_write_seq


class masked_wrt_test_cc3 extends base_test;

  `uvm_component_utils(masked_wrt_test_cc3)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  cc3_manager_write_seq manager_write_seq;
  cc3_subordinate_write_seq subordinate_write_seq;


  function new(string name = "masked_wrt_test_cc3", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq = cc3_manager_write_seq::type_id::create("manager_write_seq");
    subordinate_write_seq = cc3_subordinate_write_seq::type_id::create("subordinate_write_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    /*
     * Mask every fault source. WRITE_RESP_TIMEOUT must still be recorded, but
     * it must not contribute to IRQ.
     */
    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.clear_reg <= '0;

    env.sb.set_expect_write_timeout(1'b1);

    `uvm_info("CC_03", "Starting masked write-response-timeout coverage-closure test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    /*
     * Wait until WRITE_RESP_TIMEOUT has been recorded.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.status_reg[WRITE_RESP_TIMEOUT] !== 1'b1);

    /*
     * A masked fault remains visible in status but must not assert IRQ.
     */
    if (ctrl_vif.cb.irq !== 1'b0)
      `uvm_error("CC_03_IRQ", "IRQ asserted for disabled WRITE_RESP_TIMEOUT")

    if (ctrl_vif.cb.status_reg[WRITE_RESP_TIMEOUT] !== 1'b1)
      `uvm_error("CC_03_STATUS", "WRITE_RESP_TIMEOUT was not recorded while interrupt source was disabled")

    `uvm_info("CC_03", "Masked WRITE_RESP_TIMEOUT was recorded without asserting IRQ", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : masked_wrt_test_cc3