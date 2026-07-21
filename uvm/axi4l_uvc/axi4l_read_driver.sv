class axi4l_read_driver extends uvm_driver#(axi4l_read_item); /* this driver consumes axi4l_read_item transactions*/
  /* note on paramaterization: because we passed in axi4l_read_item, parent class uvm_driver ocntains something conceptually like REQ req */
  /* since we supplied our parameter, this becomes axi4l_read_item req;*/
  `uvm_component_utils(axi4l_read_driver)
  
  virtual axi4l_if vif; /* handle to real AXI4-Lite interrace*/
  axi4l_role_e role; /* tell driver which side it is acting as (MANAGER or subordinate?)*/
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  /* getting the virtual interface (need both for driver and monitor)*/
  /* do so in build_phase (but can do in connect_phase)*/
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4l_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "axi4l_read_driver could not get virtual interface 'vif'")
    end
    if (!uvm_config_db#(axi4l_role_e)::get(this, "", "role", role)) begin
      `uvm_fatal("NOROLE", "axi4l_read_driver could not get AXI4-Lite role")
    end
  endfunction
  
  /* this syntax is common for all drivers; refer to (my own) notes for TLM connection*/
  virtual task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      drive_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  
  virtual task drive_to_dut(axi4l_read_item item);
    /* define */
    case (role)
      AXI4L_MANAGER: drive_manager_read(item);
      AXI4L_SUBORDINATE: drive_subordinate_read(item);
      `uvm_fatal("BADROLE", "unknown role")
      default:
    endcase
  endtask
  
endclass : axi4l_read_driver