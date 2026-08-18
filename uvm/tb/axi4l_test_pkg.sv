package axi4l_test_pkg;
  
  import uvm_pkg::*;
  import a4lite_pkg::*;
  import axi4l_uvm_pkg::*;
  `include "uvm_macros.svh"
  
  `include "axi4l_sb.sv"

  /* Coverage must come before the environment */
  `include "coverage/axi4l_read_protocol_coverage.sv"

  `include "axi4l_env.sv"
  
  `include "base_test.sv"
  `include "upf_base_test.sv"


  `include "basic_read_test.sv"
  `include "write_readback_test.sv"
  `include "unit_tests/read_timeout_test.sv"
  `include "write_response_timeout_test.sv"

   /* Power-aware tests */
  `include "power_ctrl_smoke_test.sv"
  `include "upf_normal_test.sv"
  
endpackage : axi4l_test_pkg