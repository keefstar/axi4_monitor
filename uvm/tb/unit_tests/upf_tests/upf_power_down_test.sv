class upf_power_down_test extends upf_base_test;

  `uvm_component_utils(upf_power_down_test)

  function new(string name = "upf_power_down_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
  phase.raise_objection(this);

  `uvm_info("PWR02", "Powering down subordinate domain", UVM_LOW)

  pwr_vif.sub_power_down();
  repeat (5) @(pwr_vif.cb);

  if (pwr_vif.sub_power_en !== 0)
    `uvm_error("PWR02", "Subordinate power did not turn off")

  if (pwr_vif.sub_iso_en !== 1)
    `uvm_error("PWR02", "Isolation was not asserted")

  `uvm_info(
  "PWR02",
  $sformatf(
    "After power-down: ARREADY=%b AWREADY=%b WREADY=%b RVALID=%b BVALID=%b",
    env.downstream_agent.monitor.vif.arready,
    env.downstream_agent.monitor.vif.awready,
    env.downstream_agent.monitor.vif.wready,
    env.downstream_agent.monitor.vif.rvalid,
    env.downstream_agent.monitor.vif.bvalid
  ),
  UVM_LOW
)

if (env.downstream_agent.monitor.vif.arready !== 1'b0)
  `uvm_error("PWR02_ARREADY", "ARREADY was not isolated to 0")

if (env.downstream_agent.monitor.vif.awready !== 1'b0)
  `uvm_error("PWR02_AWREADY", "AWREADY was not isolated to 0")

if (env.downstream_agent.monitor.vif.wready !== 1'b0)
  `uvm_error("PWR02_WREADY", "WREADY was not isolated to 0")

if (env.downstream_agent.monitor.vif.rvalid !== 1'b0)
  `uvm_error("PWR02_RVALID", "RVALID was not isolated to 0")

if (env.downstream_agent.monitor.vif.bvalid !== 1'b0)
  `uvm_error("PWR02_BVALID", "BVALID was not isolated to 0")

  if ($isunknown(ctrl_vif.guard_busy))
    `uvm_error("PWR02", "Always-on guard became unknown")

 // `uvm_info("PWR02", "PASS: subordinate OFF, outputs isolated, guard remains valid", UVM_LOW)

  phase.drop_objection(this);
endtask

endclass