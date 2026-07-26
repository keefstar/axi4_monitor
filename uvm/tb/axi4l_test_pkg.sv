package axi4l_test_pkg;
  
  import uvm_pkg::*;
  import a4lite_pkg::*;
  import axi4l_uvm_pkg::*;
  `include "uvm_macros.svh"
  
  `include "axi4l_sb.sv"
  `include "axi4l_coverage.sv"
  `include "axi4l_env.sv"
  
  /*Later add unit test.sv files*/
  `include "basic_read_test.sv"
  
endpackage : axi4l_test_pkg