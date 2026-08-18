class upf_base_test extends base_test;

  `uvm_component_utils(upf_base_test)

  virtual power_ctrl_if pwr_vif;

  function new(string name = "upf_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);

    /* Must be set before super.build_phase creates env/agents */
    downstream_mode = UVM_PASSIVE;
    super.build_phase(phase);

    if (!uvm_config_db#(virtual power_ctrl_if)::get(
      this, "", "pwr_vif", pwr_vif
    )) begin
      `uvm_fatal("NO_PWR_VIF", "upf_base_test could not get power control interface")
    end

  endfunction : build_phase

endclass : upf_base_test