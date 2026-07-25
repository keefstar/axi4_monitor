
/* REUSABLE UVC PACAKAGE*/
package axi4l_uvm_pkg;
  
  import a4lite_pkg::*;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  /* configuration must appear before agent if agent is to use it*/
  `include "axi4l_agent_cfg.sv"
  /* transactions*/
  `include "axi4l_read_item.sv"
  `include "axi4l_write_item.sv"
  /* sequencers*/
  `include "axi4l_read_sequencer.sv"
  `include "axi4l_write_sequencer.sv"
  /* drivers*/
  `include "axi4l_read_driver.sv"
  `include "axi4l_write_driver.sv"
  /* monitor */
  `include "axi4l_monitor.sv"
  /* agent*/
  `include "axi4l_agent.sv"
  /* sequences (just needs to come after sequencers) */
  `include "sequences/axi4l_read_seq.sv"
  `include "sequences/axi4l_write_seq.sv"
endpackage : axi4l_uvm_pkg