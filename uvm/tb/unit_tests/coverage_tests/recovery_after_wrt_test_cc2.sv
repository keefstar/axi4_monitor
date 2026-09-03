/*
 * CC-02: verify complete recovery after WRITE_RESP_TIMEOUT.
 *
 * A complete write is forwarded downstream, but the subordinate withholds
 * BVALID until the write-response timer expires. After WRITE_RESP_TIMEOUT is
 * recorded and the upstream transaction becomes quiescent, software
 * acknowledges the fault. The resulting epoch clear must complete recovery
 * and clear the fault status and IRQ.
 */


class cc2_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(cc2_manager_write_seq)

  function new(string name = "cc2_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 0;
      bready_delay == 0;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "CC-02 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : cc2_manager_write_seq


class cc2_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(cc2_subordinate_write_seq)

  function new(string name = "cc2_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      bvalid_delay == 0;
      suppress_bvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "CC-02 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : cc2_subordinate_write_seq


class recovery_after_wrt_test_cc2 extends base_test;

  `uvm_component_utils(recovery_after_wrt_test_cc2)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  cc2_manager_write_seq manager_write_seq;
  cc2_subordinate_write_seq subordinate_write_seq;


  function new(string name = "recovery_after_wrt_test_cc2", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq = cc2_manager_write_seq::type_id::create("manager_write_seq");
    subordinate_write_seq = cc2_subordinate_write_seq::type_id::create("subordinate_write_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    /*
     * Enable only WRITE_RESP_TIMEOUT so the resulting fault also exercises
     * the enabled-fault IRQ path.
     */
    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.enable_reg[WRITE_RESP_TIMEOUT] <= 1'b1;
    ctrl_vif.cb.clear_reg <= '0;

    env.sb.set_expect_write_timeout(1'b1);

    `uvm_info("CC_02", "Starting recovery-after-write-response-timeout coverage-closure test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    /*
     * Wait until WRITE_RESP_TIMEOUT has actually been recorded.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.status_reg[WRITE_RESP_TIMEOUT] !== 1'b1);

    /*
     * WRITE_RESP_TIMEOUT retires the failed upstream transaction before
     * recovery, while stale downstream response debt may remain internal.
     * Allow the containment-to-recovery transition to complete.
     */
    repeat (4) @(ctrl_vif.cb);

    /*
     * Acknowledge WRITE_RESP_TIMEOUT and authorize the recovery epoch clear.
     */
    ctrl_vif.cb.clear_reg <= '0;
    ctrl_vif.cb.clear_reg[WRITE_RESP_TIMEOUT] <= 1'b1;
    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <= '0;

    /*
     * Allow rcvy_ack, epoch_clr, and the FSM return to normal to complete.
     */
    repeat (4) @(ctrl_vif.cb);

    if (ctrl_vif.cb.status_reg[WRITE_RESP_TIMEOUT] !== 1'b0)
      `uvm_error("CC_02_STATUS", "WRITE_RESP_TIMEOUT status remained set after completed recovery")

    if (ctrl_vif.cb.irq !== 1'b0)
      `uvm_error("CC_02_IRQ", "IRQ remained asserted after completed recovery")

    `uvm_info("CC_02", "WRITE_RESP_TIMEOUT recovery completed successfully", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : recovery_after_wrt_test_cc2