/* The base test is the shared backbone for all actual test scenarios. */
class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  /* Virtual handle to guard control interface instantiated in tb_top */
  virtual guard_ctrl_if ctrl_vif;
  /* Normal tests use an active downstream UVC; UPF tests override this to passive */
  uvm_active_passive_enum downstream_mode = UVM_ACTIVE;
  /* Handle to AXI4-Lite test environment */
  axi4l_env env;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info( "BASE_CFG", $sformatf("Configuring downstream_mode=%s", downstream_mode.name()), UVM_LOW )
    /* Configure downstream agent before environment is built */
    /* removed * from "env.downstream_agent*" to keep IS_ACTIVE property to agent itself */
    uvm_config_db#(uvm_active_passive_enum)::set( this, "env.downstream_agent", "is_active", downstream_mode);
    env = axi4l_env::type_id::create("env", this);

    if (!uvm_config_db#(virtual guard_ctrl_if)::get(this, "", "ctrl_vif", ctrl_vif)) begin
      `uvm_fatal("NO_CTRL_VIF", "base_test could not get guard control interface")
    end

  endfunction : build_phase

endclass : base_test