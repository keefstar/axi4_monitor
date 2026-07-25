import uvm_pkg::*;

`include "uvm_macros.svh"
import axi4l_uvm_pkg::*;
/* this is a normal system verilog module.
/* importance; UVM components (drivers, monitors, agens, and tests) are CLASSES*/
/* the DUT and real interfac emust exist in the static module hierarchy so they are instantiated here*/
module tb_top;
  logic clk, aresetn;
  /* real AXI4-Lite interfaces*/
  /* instantiate two interfaces because the actual DUT has two differnet buses*/
  axi4l_if upstream_if(.clk(clk), .areset(aresetn));
  axi4l_if downstream_if(.clk(clk), .areset(aresetn));
  
  /* reset generation*/
  initial begin
    aresetn = 1'b0;
    repeat (5) @(posedge clk);
    aresetn = 1'b1;
  end
  
  /* connect static interface to the uvm classes*/
  initial begin
    uvm_config_db#(virtual axi4l_if)::set(/* Store this real interface in the config DB under the name vif,
  and make it available to my AXI agent hierarchy*/
      null,
      "uvm_test_top.env.upstream_agent*", /* UVM component hierarchy path; not file path*/ /* uvm_test_top = your UVM test instance; */
      /* env is basically the container that holds the major UVM pieces of your testbench.*/
      "vif",
      upstream_if
    );
    
    uvm_config_db#(virtual axi4l_if)::set(
      null,
      "uvm_test_top.env.downstream_agent*",
      "vif",
      downstream_if
    );
    run_test(); /* need */
  end
  
endmodule : tb_top