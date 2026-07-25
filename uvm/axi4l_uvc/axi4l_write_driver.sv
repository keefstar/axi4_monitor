
class axi4l_write_driver extends uvm_driver#(axi4l_write_item); /* this driver consumes axi4l_write_item transactions*/
  /* note on paramaterization: because we passed in axi4l_write_item, parent class uvm_driver ocntains something conceptually like REQ req */
  /* since we supplied our parameter, this becomes axi4l_write_item req;*/
  `uvm_component_utils(axi4l_write_driver)
  
  virtual axi4l_if vif; /* handle to real AXI4-Lite interrace*/
  axi4l_role_e role; /* tell driver which side it is acting as (MANAGER or subordinate?)*/
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4l_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "axi4l_write_driver could not get virtual interface 'vif'")
    end
    if (!uvm_config_db#(axi4l_role_e)::get(this, "", "role", role)) begin
      `uvm_fatal("NOROLE", "axi4l_write_driver could not get AXI4-Lite role")
    end
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    unique case (role)
      AXI4L_MANAGER: {vif.awvalid, vif.wvalid, vif.bready, vif.aw, vif.w} <= '0;
      AXI4L_SUBORDINATE: {vif.awready, vif.wready, vif.bvalid, vif.b} <= '0;
      default: `uvm_fatal("BADROLE","Unknown AXI4-Lite role")
    endcase
    // Do not begin driving transactions while reset is active.
    wait (vif.aresetn === 1'b1);
    
    forever begin
      seq_item_port.get_next_item(req);
      drive_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  
  virtual task drive_to_dut(axi4l_write_item item);
    case (role)
      AXI4L_MANAGER: drive_manager_write(item);
      AXI4L_SUBORDINATE: drive_subordinate_write(item);
      default: `uvm_fatal("BADROLE","Unknown role")
    endcase
    /* define */
  endtask
  
  virtual task drive_manager_write(
      axi4l_write_item item
  );
    
  endtask
  
  virtual task drive_subordinate_write(
      axi4l_write_item item
  );
    
  endtask
  
endclass : axi4l_write_driver