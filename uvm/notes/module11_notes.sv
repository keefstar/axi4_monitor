For this UVM module, you do not need to go back and deeply study interfaces.You mainly need to understand how UVM classes gain access to the interface you already made.

Interface Connection to IVM driver and monitor:
UVM components cannot be directly connected to interface instances
*Breaks reusability
*Interface instances are static

Solution: SystemVerilog virtual interface
An interface variable that can be connected to an interface instance
Can be declared as a class property
Access interface signals using virtual interface as a prefix
Needs to be connected to an actual interface.

Syntax:
virtual interface < if_name > < local_name >;

AXI4L example:
virtual axi4l_if vif;
tb_top
├ ─ ─ axi4l_if upstream_if
├ ─ ─ axi4l_if downstream_if
└ ─ ─ DUT
upstream_driver.vif ─ ─ ─ ─ ─ > upstream_if
upstream_monitor.vif ─ ─ ─ ─ ─ > upstream_if
downstream_driver.vif ─ ─ ─ > downstream_if
downstream_monitor.vif ─ ─ ─ > downstream_if
virtual interface < if_name > < local_name >;
virtual interface < if_name > < local_name >;
virtual interface < if_name > < local_name >;

Then, driver can access pins through it:
vif.arvalid <= 1'b1;
vif.araddr <= req.addr;

and monitor can observe:
vif.arvalid <= 1'b1;
vif.araddr <= req.addr;

class axi4l_read_driver extends uvm_driver#(axi4l_read_item);
  
  virtual axi4l_if vif;
  /* vif is NOT another interface instance.
     vif points to an existing interface instance.*/
  
  task get_and_drive();
    @(negedge vif.reset); /* driver access interfeace signals and methdos via virtual interface*/
    
    
endclass

interface axi4l_if (input...)
  
  
  ACTUALLY SETTING UP THE interface
  
  tb_top creates real axi4l_if instance
  ->
  uvm_config_db::set(...)
  ->
  driver / monitor do uvm_config_db::get()
  ->
  they recieve virtual axi4l_if vif
  ->
  driver drives AXI signals through vif
  monitor samples AXI signals through vif
  
  1) SETTING THE VIRTUAL interface
  
  /* "Store this real interface in the config DB under the name vif,
  and make it available to my AXI agent hierarchy."*/
  uvm_config_db#(virtual axi4l_if)::set(
    null, /* context arg is null as we are executing this set in a top level module and not a class*/
    "uvm_test_top.env.axi4l_agent*", /* instance name is a pathname to all UVC sub-comopnents (can set monitor and driver in single set call)*/
    "vif", /* field name */
    axi_if /* (absolute path name to interface instance (interface instnace  is in hw top module (relevant for me?)))*/ * /
  );
  
  WHERE does set() happen ? Usulaly in top - level TV module because that is where the actual if instance exists.
  module tb_top;
    
    logic clk;
    logic aresetn;
    
    axi4l_if axi_if(clk, aresetn);
    
    // DUT instantiation...
    
    initial begin
      
      uvm_config_db#(virtual axi4l_if)::set(
        null,
        "uvm_test_top.env.axi4l_agent*",
        "vif",
        axi_if
      );
      
      run_test();
    end
    
  endmodule
  
  2) Getting the virtual interface
  Then, our driver needs virtual axi4l_if vif;
  
  /* we can do below thing in either connect or build pahse*/ /* reccomend in built_phase (because our comp should obtain if because simulaiton/run behavioru begins)*/
  /* get returns a value: 1 if succesful*/
  /* get has same args as set */
  if (!uvm_config_db#(virtual axi4l_if)::get(
    this, /* context: start searching form me*/
    "", /* I am looking for the setting that applies directly to me. Do not append another child path.*/
    /* thus tgt, Find a vif configuration that applies to this driver.*/
    "vif", /* field name must match set*/
    vif
  ))
    `uvm_fatal("NOVIF", "Missing virtual interface") /* error severiety allows mutliple get fails to be detected*/
  
  3) Convenience Types for interface assignment:
  typedef is a shortcut.
  Instead of always wriritnf: uvm_config_db#(virtual axi4l_if)::get(...)
  You can create a nickname typedef uvm_config_db#(virtual axi4l_if) axi4l_vif_cfg;
  Then write: axi4l_vif_cfg::get(...)
  uvm_config_db#(virtual axi4l_if)::get(...) <= > uvm_config_db#(virtual axi4l_if)::get(...)
  
  Before coding:
  tb_top
  creates real axi4l_if
  ↓
  config_db SET
  ↓
  driver / monitor
  config_db GET
  ↓
  virtual axi4l_if vif
  /*
  Virtual interface flow:

  1. tb_top creates actual axi4l_if instance.

  2. tb_top uses config_db::set() to make that interface available to UVM.

  3. Driver/monitor declare:
     virtual axi4l_if vif;

  4. Driver/monitor use config_db::get() to obtain vif.

  5. Driver:
     transaction object -> actual AXI signals through vif.

  6. Monitor:
     actual AXI handshakes through vif -> reconstructed transaction object.

  AXI monitor detects a transfer only when:
  VALID && READY

  Typedef for config_db is optional convenience only.
  Virtual-interface wire/inout limitations are mostly irrelevant to AXI4-Lite.
  */