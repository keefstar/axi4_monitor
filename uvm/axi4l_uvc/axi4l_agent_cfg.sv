class axi4l_agent_cfg extends uvm_object;
  
  /* register with UVM factory */
  `uvm_object_utils(axi4l_agent_cfg)
  
  /*  built-in enumerated type used exclusively to control whether a uvm_agent operates in an active or passive mode. */
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  int unsigned max_ready_delay = 5;
  bit allow_read_stall = 1; /* Allow deliberate read stalls for timeout testing.*/
  bit allow_write_stall = 1; /* Allow deliberate write stalls for timeout testing.*/
  
  function new(string name = "axi4l_agent_cfg");
    super.new(name);
  endfunction
endclass : axi4l_agent_cfg