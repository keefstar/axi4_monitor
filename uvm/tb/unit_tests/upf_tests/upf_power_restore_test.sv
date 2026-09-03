class upf_power_restore_test extends upf_base_test;

  `uvm_component_utils(upf_power_restore_test)

  function new(
    string name = "upf_power_restore_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);

    axi4l_manager_read_seq fault_read_seq;
    axi4l_manager_read_seq recovery_read_seq;

    axi_resp_e fault_resp;
    axi_resp_e recovery_resp;

    phase.raise_objection(this);

    /* Create an outstanding read and then lose PD_SUB power */

    env.sb.set_expect_read_timeout(1'b1);

    fault_read_seq =
      axi4l_manager_read_seq::type_id::create("fault_read_seq");

    fork

      begin
        fault_read_seq.start(
          env.upstream_agent.read_sequencer
        );
      end

      begin
        /* Wait until subordinate has genuinely accepted AR. */
        do begin
          @(env.downstream_agent.monitor.vif.mon_cb);
        end while (!(
          env.downstream_agent.monitor.vif.mon_cb.arvalid === 1'b1 &&
          env.downstream_agent.monitor.vif.mon_cb.arready === 1'b1
        ));

        `uvm_info( "PWR05", "Outstanding read accepted; powering off PD_SUB", UVM_LOW )

        pwr_vif.sub_power_down();
      end

      begin
        /* Observe SCC-generated timeout response upstream. */
        do begin
          @(env.upstream_agent.monitor.vif.mon_cb);
        end while (!(
          env.upstream_agent.monitor.vif.mon_cb.rvalid === 1'b1 &&
          env.upstream_agent.monitor.vif.mon_cb.rready === 1'b1
        ));

        fault_resp =
          env.upstream_agent.monitor.vif.mon_cb.r.resp;
      end

    join


    /* Confirm containment occurred before recovery */

    if (fault_resp !== RESP_SLVERR)
      `uvm_error( "PWR05", $sformatf( "Expected timeout SLVERR before recovery; got %s", fault_resp.name() ) )
    if (ctrl_vif.status_reg[READ_TIMEOUT] !== 1'b1)
      `uvm_error( "PWR05", "READ_TIMEOUT status was not asserted before recovery" )
    if (ctrl_vif.irq !== 1'b1)
      `uvm_error( "PWR05", "IRQ was not asserted before recovery" )

    /*
     * Restore and reset the subordinate.
     * power_sub_on():
     *   keep isolation asserted
     *   restore power
     *   wait for supply settling
     *   assert/deassert subordinate reset
     *   wait for wakeup
     *   remove isolation */

    `uvm_info( "PWR05", "Restoring and reinitializing PD_SUB", UVM_LOW )

    pwr_vif.power_sub_on();


    /* Software acknowledges the fault AFTER the subordinate has been restored/reset.
     * This is the recovery contract: reset before acknowledgement  */

    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <=
      NUM_FAULT_SOURCES'(1 << READ_TIMEOUT);

    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <= '0;


    /*
     * Give: clear_reg -> rcvy_ack -> epoch_clr
     * enough cycles to propagate through interrupt_ctrl/tp_lvl.
     */
    repeat (3)
      @(ctrl_vif.cb);


    /* Check recovery state. */

    if (pwr_vif.sub_power_en !== 1'b1)
      `uvm_error( "PWR05", "PD_SUB power was not restored" )
    if (pwr_vif.sub_reset_n !== 1'b1)
      `uvm_error( "PWR05", "PD_SUB remained in reset" )
    if (pwr_vif.sub_iso_en !== 1'b0)
      `uvm_error( "PWR05", "PD_SUB isolation was not removed after restoration" )

    if (ctrl_vif.status_reg[READ_TIMEOUT] !== 1'b0)
      `uvm_error( "PWR05", "READ_TIMEOUT status did not clear" )

    if (ctrl_vif.irq !== 1'b0)
      `uvm_error( "PWR05", "IRQ did not clear after recovery acknowledgement" )

    if (ctrl_vif.guard_busy !== 1'b0)
      `uvm_error( "PWR05", "SCC remained busy after recovery" )

    /* Issue a completely new transaction (for recovery proof) */

    `uvm_info( "PWR05", "Issuing post-recovery read", UVM_LOW )

    recovery_read_seq =
      axi4l_manager_read_seq::type_id::create(
        "recovery_read_seq"
      );

    fork

      begin
        recovery_read_seq.start(
          env.upstream_agent.read_sequencer
        );
      end

      begin
        do begin
          @(env.upstream_agent.monitor.vif.mon_cb);
        end while (!(
          env.upstream_agent.monitor.vif.mon_cb.rvalid === 1'b1 &&
          env.upstream_agent.monitor.vif.mon_cb.rready === 1'b1
        ));

        recovery_resp =
          env.upstream_agent.monitor.vif.mon_cb.r.resp;
      end

    join

    if (recovery_resp !== RESP_OKAY)
      `uvm_error( "PWR05", $sformatf( "Post-recovery read failed; expected RESP_OKAY, got %s", recovery_resp.name() ) )

    `uvm_info(
      "PWR05",
      $sformatf(
        "Recovery complete: power=%b iso=%b reset_n=%b status=%b irq=%b guard_busy=%b post_recovery_resp=%s",
        pwr_vif.sub_power_en,
        pwr_vif.sub_iso_en,
        pwr_vif.sub_reset_n,
        ctrl_vif.status_reg[READ_TIMEOUT],
        ctrl_vif.irq,
        ctrl_vif.guard_busy,
        recovery_resp.name()
      ),
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask

endclass : upf_power_restore_test