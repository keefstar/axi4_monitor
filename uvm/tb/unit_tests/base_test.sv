
/* The base test is the shared backbone for all  actual test scenarios. */
class base_test extends uvm_test;
  /* base test contains declerations common to all tests*/
  
  `uvm_component_utils(base_test)
  
  function new(string name = "axi4l_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  /* handle on axi4l test environment*/
  axi4l_env env;
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi4l_env::type_id::create("env", this);
  endfunction : build_phase
endclass : base_test