class power_ctrl_smoke_test extends upf_base_test;

  /* regiser with UVM factory*/
  `uvm_component_utils(power_ctrl_smoke_test)

  /* constructor */
  function new(
    string name = "power_ctrl_smoke_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    `uvm_info( "PWR_SMOKE", $sformatf( "Initial: power=%0b iso=%0b reset_n=%0b", pwr_vif.sub_power_en, pwr_vif.sub_iso_en, pwr_vif.sub_reset_n), UVM_LOW )

    /* model controlled power down */
    pwr_vif.sub_power_down();

    @(pwr_vif.cb);
    `uvm_info( "PWR_SMOKE", $sformatf( "After shutdown: power=%0b iso=%0b reset_n=%0b", pwr_vif.sub_power_en, pwr_vif.sub_iso_en, pwr_vif.sub_reset_n), UVM_LOW )

    phase.drop_objection(this);

  endtask : run_phase

endclass