package axi4l_uvm_pkg;
  
  import a4lite_pkg::*;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  /* transactions first*/
  `include "axi4l_read_item.sv"
  `include "axi4l_write_item.sv"
  //Then sequencers
  `include "axi4l_read_sequencer.sv"
  `include "axi4l_write_sequencer.sv"
  //Then drivers
  `include "axi4l_read_driver.sv"
  `include "axi4l_write_driver.sv"
  // Then monitor
  `include "axi4l_monitor.sv"
  // Agent comes after the classes it references
  `include "axi4l_agent.sv"
  
endpackage : axi4l_uvm_pkg