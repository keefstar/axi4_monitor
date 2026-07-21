class axi4l_read_seq extends uvm_sequence#(axi4l_read_item);
  `uvm_object_utils(axi4l_read_seq)
  
  function new(string name = "axi4l_read_seq");
    super.new(name);
  endfunction
  
  virtual task body();
    `uvm_info(
      get_type_name(),
      "Starting AXI4-Lite Read Sequence",
      UVM_LOW
    )
    
    req = axi4l_read_item::type_id::create("req"); /* explicilt creation via UVM factor*/
    start_item(req); /* sequencer, I have AXI trransaction i want to send. tell me when you are ready.*/
    assert (req.randomize())
    else
      `uvm_fatal(
        get_type_name(),
        "axi4l_read_item randomization failed"
      )
    
    finish_item(req); /* This sends the ready transaction to the driver and waits for the driver to complete handling it.*/
  endtask
  
  /* sequence-level rand properties */
  
endclass : axi4l_read_seq