
/* this is a normal system verilog module.
/* importance; UVM components (drivers, monitors, agens, and tests) are CLASSES*/
/* the DUT and real interfac emust exist in the static module hierarchy so they are instantiated here*/
module tb_top;
  import uvm_pkg::*;
  import a4lite_pkg::*;
  import axi4l_uvm_pkg::*;
  import axi4l_test_pkg::*;
  
  logic clk, aresetn;
  logic [NUM_FAULT_SOURCES-1:0] enable_reg;
  logic [NUM_FAULT_SOURCES-1:0] clear_reg;
  logic irq;
  logic [NUM_FAULT_SOURCES-1:0] status_reg;
  logic guard_busy;
  /* real AXI4-Lite interfaces*/
  /* instantiate two interfaces because the actual DUT has two differnet buses*/
  axi4l_if upstream_if(.clk(clk), .aresetn(aresetn));
  axi4l_if downstream_if(.clk(clk), .aresetn(aresetn));

  initial begin
  enable_reg = '1;
  clear_reg  = '0;
  end
  
  /* reset generation*/
  initial begin
    aresetn = 1'b0;
    repeat (5) @(posedge clk);
    aresetn = 1'b1;
  end

  tp_lvl dut (
  .clk        (clk),
  .rst_n      (aresetn),

  /*
   * DUT upstream side acts as an AXI subordinate.
   * Connect it to the interface driven by the upstream manager agent.
   */
  .s          (upstream_if),

  /*
   * DUT downstream side acts as an AXI manager.
   * Connect it to the interface driven by the downstream subordinate agent.
   */
  .m          (downstream_if),

  .enable_reg (enable_reg),
  .clear_reg  (clear_reg),
  .irq        (irq),
  .status_reg (status_reg),
  .guard_busy (guard_busy)
);

  
  /* clock generator*/
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
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
    
    uvm_config_db#(virtual axi4l_if)::set(null, "uvm_test_top.env.downstream_agent*", "vif", downstream_if);
    /* read/write drivers need access to role*/
    /* upstream agent emulates the manager*/
    uvm_config_db#(axi4l_role_e)::set(null, "uvm_test_top.env.upstream_agent*", "role", AXI4L_MANAGER);
    /* downstream agent emulates the subordinate*/
    uvm_config_db#(axi4l_role_e)::set(null, "uvm_test_top.env.downstream_agent*", "role", AXI4L_SUBORDINATE);
    /* configure as active agents*/
    uvm_config_db#(uvm_active_passive_enum)::set(null, "uvm_test_top.env.upstream_agent*", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(null, "uvm_test_top.env.downstream_agent*", "is_active", UVM_ACTIVE);
    run_test(); /* need */
  end
  
  /* notes:
  axi4l_env env would be declared by a unit test (create("env", this))
  -> creates: uvm_test_top.env 
  uvm_test_top is automatic runtume UVM 
  in axi4l_env.sv, i instnatiate upstream_agent and downstream_agent
  */
  
endmodule : tb_top