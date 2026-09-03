class upf_unexpected_power_loss_test extends upf_base_test;

  `uvm_component_utils(upf_unexpected_power_loss_test)

  function new(
    string name = "upf_unexpected_power_loss_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info( "PWR06", "Starting unexpected subordinate supply-loss fault injection", UVM_LOW )

    /* Confirm normal starting power state */

    if (pwr_vif.sub_power_en !== 1'b1)
      `uvm_error( "PWR06", "PD_SUB was not powered at start of test" )

    if (pwr_vif.sub_iso_en !== 1'b0)
      `uvm_error( "PWR06", "Isolation was unexpectedly asserted at start of test" )

    /* Inject uncontrolled supply loss */
    `uvm_info( "PWR06", "Injecting unexpected PD_SUB supply loss with isolation inactive", UVM_LOW )

    pwr_vif.sub_power_fail();

    repeat (2)
      @(pwr_vif.cb);

    /* Confirm this really was an uncontrolled failure (power, isolation = 0) */

    if (pwr_vif.sub_power_en !== 1'b0)
      `uvm_error( "PWR06", "PD_SUB supply did not turn off during fault injection" )

    if (pwr_vif.sub_iso_en !== 1'b0)
      `uvm_error( "PWR06", "Isolation was asserted during unexpected-failure injection" )

    /*  Observe the unisolated failed-domain outputs (no need for speciifc X pattern) */
    `uvm_info(
      "PWR06",
      $sformatf(
        "Unisolated failure state: ARREADY=%b AWREADY=%b WREADY=%b RVALID=%b BVALID=%b",
        env.downstream_agent.monitor.vif.arready,
        env.downstream_agent.monitor.vif.awready,
        env.downstream_agent.monitor.vif.wready,
        env.downstream_agent.monitor.vif.rvalid,
        env.downstream_agent.monitor.vif.bvalid
      ),
      UVM_LOW
    )

     /* Assert emergency isolation after the failure*/
    `uvm_info( "PWR06", "Asserting emergency isolation around failed PD_SUB", UVM_LOW )

    pwr_vif.isolate_sub();

    repeat (2)
      @(pwr_vif.cb);

    /* Verify safe clamped boundary*/

    if (pwr_vif.sub_iso_en !== 1'b1)
      `uvm_error( "PWR06", "Emergency isolation was not asserted" )

    `uvm_info(
      "PWR06",
      $sformatf(
        "After emergency isolation: ARREADY=%b AWREADY=%b WREADY=%b RVALID=%b BVALID=%b",
        env.downstream_agent.monitor.vif.arready,
        env.downstream_agent.monitor.vif.awready,
        env.downstream_agent.monitor.vif.wready,
        env.downstream_agent.monitor.vif.rvalid,
        env.downstream_agent.monitor.vif.bvalid
      ),
      UVM_LOW
    )

    if (env.downstream_agent.monitor.vif.arready !== 1'b0)
      `uvm_error( "PWR06_ARREADY", "ARREADY was not clamped to 0 after emergency isolation" )

    if (env.downstream_agent.monitor.vif.awready !== 1'b0)
      `uvm_error( "PWR06_AWREADY", "AWREADY was not clamped to 0 after emergency isolation" )

    if (env.downstream_agent.monitor.vif.wready !== 1'b0)
      `uvm_error( "PWR06_WREADY", "WREADY was not clamped to 0 after emergency isolation" )

    if (env.downstream_agent.monitor.vif.rvalid !== 1'b0)
      `uvm_error( "PWR06_RVALID", "RVALID was not clamped to 0 after emergency isolation" )

    if (env.downstream_agent.monitor.vif.bvalid !== 1'b0)
      `uvm_error( "PWR06_BVALID", "BVALID was not clamped to 0 after emergency isolation" )

    /*  Verify always-on SCC did not become unknown. */
    if ($isunknown(ctrl_vif.guard_busy))
      `uvm_error( "PWR06", "Always-on SCC became unknown during unexpected power failure" )

    `uvm_info( "PWR06", $sformatf( "Unexpected supply-loss containment complete: power=%b iso=%b guard_busy=%b", pwr_vif.sub_power_en, pwr_vif.sub_iso_en, ctrl_vif.guard_busy ), UVM_LOW )
    phase.drop_objection(this);
  endtask

endclass : upf_unexpected_power_loss_test