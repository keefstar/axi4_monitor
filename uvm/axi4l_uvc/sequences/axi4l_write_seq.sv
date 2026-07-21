
class axi4l_write_seq extends uvm_sequence#(axi4l_write_item);
  `uvm_object_utils(axi4l_write_seq)
  
  function new(string name = "axi4l_write_seq");
    super.new(name);
  endfunction
  
  virtual task body(); /* specify body() task with uvm_do macros */
    `uvm_info(get_type_name(), "Starting AXI4-Lite write Sequence", UVM_LOW)
  endtask
  
  /* explicit version instead of uvm_do*/
  req = axi4l_write_item::type_id::create("req"); /* explicilt creation via UVM factor*/
  start_item(req);
  assert (req.randomize())
  else `uvm_fatal(
      get_type_name(), "axi4l_write_item randomizatoin failed"
    )
  finish_item(req);
  
endclass : axi4l_write_seq