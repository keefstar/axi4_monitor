/*
 * CC-01: verify complete recovery after WRITE_DATA_TIMEOUT.
 *
 * An upstream write address is accepted without its corresponding write data,
 * causing WRITE_DATA_TIMEOUT. After the faulted transaction becomes quiescent,
 * software acknowledges the fault. The resulting epoch clear must complete
 * recovery and clear the fault status and IRQ.
 */


class cc1_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(cc1_manager_write_seq)

  function new(string name = "cc1_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      suppress_wvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "CC-01 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : cc1_manager_write_seq


class recovery_after_wdt_test_cc1 extends base_test;

  `uvm_component_utils(recovery_after_wdt_test_cc1)

  axi4l_write_sequencer upstream_write_sqr;
  cc1_manager_write_seq manager_write_seq;


  function new(string name = "recovery_after_wdt_test_cc1", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq = cc1_manager_write_seq::type_id::create("manager_write_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    /*
     * Enable only WRITE_DATA_TIMEOUT so the resulting fault also exercises
     * the enabled-fault IRQ path.
     */
    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.enable_reg[WRITE_DATA_TIMEOUT] <= 1'b1;
    ctrl_vif.cb.clear_reg <= '0;

    /*
     * The incomplete AW is intentional and no upstream BRESP is expected.
     */
    env.sb.set_expect_write_data_timeout(1'b1);

    `uvm_info("CC_01", "Starting recovery-after-write-data-timeout coverage-closure test", UVM_LOW)

    manager_write_seq.start(upstream_write_sqr);

    /*
     * Wait until WRITE_DATA_TIMEOUT has actually been recorded.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.status_reg[WRITE_DATA_TIMEOUT] !== 1'b1);

    /*
    * WRITE_DATA_TIMEOUT removes the incomplete upstream write before recovery,
    * but internal write fault state may keep guard_busy asserted. Allow the
    * containment-to-recovery transition to complete before acknowledging.
    */
    repeat (4) @(ctrl_vif.cb);


    /*
     * Acknowledge WRITE_DATA_TIMEOUT and authorize the recovery epoch clear.
     */
    ctrl_vif.cb.clear_reg <= '0;
    ctrl_vif.cb.clear_reg[WRITE_DATA_TIMEOUT] <= 1'b1;
    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <= '0;

    /*
     * Allow rcvy_ack, epoch_clr, and the FSM return to normal to complete.
     */
    repeat (4) @(ctrl_vif.cb);

    if (ctrl_vif.cb.status_reg[WRITE_DATA_TIMEOUT] !== 1'b0)
      `uvm_error("CC_01_STATUS", "WRITE_DATA_TIMEOUT status remained set after completed recovery")

    if (ctrl_vif.cb.irq !== 1'b0)
      `uvm_error("CC_01_IRQ", "IRQ remained asserted after completed recovery")

    `uvm_info("CC_01", "WRITE_DATA_TIMEOUT recovery completed successfully", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : recovery_after_wdt_test_cc1