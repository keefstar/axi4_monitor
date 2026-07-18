

class axi4l_read_driver extends uvm_driver#(axi4l_read_item); /* this driver consumes axi4l_read_item transactions*/
  /* note on paramaterization: because we passed in axi4l_read_item, parent class uvm_driver ocntains something conceptually like REQ req */
  /* since we supplied our parameter, this becomes axi4l_read_item req;*/
  `uvm_component_utils(axi4l_read_driver)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
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
  endtask
  
endclass : axi4l_read_driver