
/* REUSABLE UVC PACAKAGE*/
package axi4l_uvm_pkg;
  
  import a4lite_pkg::*;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

   typedef enum {
    AXI4L_MANAGER,
    AXI4L_SUBORDINATE
  } axi4l_role_e;
  
  /* configuration must appear before agent if agent is to use it*/
  `include "axi4l_agent_cfg.sv"
  /* transactions*/
  `include "axi4l_read_item.sv"
  `include "axi4l_write_item.sv"
  /* memory model */
  `include "axi4l_sub_mem.sv"
  /* sequencers*/
  `include "axi4l_read_sequencer.sv"
  `include "axi4l_write_sequencer.sv"
  /* drivers*/
  `include "axi4l_read_driver.sv"
  `include "axi4l_write_driver.sv"
  /* monitor */
  `include "axi4l_monitor.sv"
  /* agent*/
  `include "axi4l_manager_agent.sv"
  `include "axi4l_subordinate_agent.sv"
  /* coverage*/
  //`include "axi4l_read_coverage.sv"
  /* sequences (just needs to come after sequencers) */
  `include "sequences/axi4l_read_seq.sv"
  `include "sequences/axi4l_write_seq.sv"
  `include "sequences/write_resp_timeout_sequences.sv"

endpackage : axi4l_uvm_pkg