class axi4l_manager_write_seq extends uvm_sequence#(axi4l_manager_write_seq);
  `uvm_object_utils(axi4l_manager_write_seq)

  axi4l_write_item req;
  
  function new(string name = "axi4l_manager_write_seq");
    super.new(name);
  endfunction
  
  virtual task body();
    `uvm_info(
      get_type_name(),
      "Upstream AXI4-Lite write Sequence",
      UVM_LOW
    )
    
    req = axi4l_write_item::type_id::create("req"); /* explicilt creation via UVM factor*/
    start_item(req); /* sequencer, I have AXI trransaction i want to send. tell me when you are writey.*/
    req.configure_for_manager();

    randomize_req();
    finish_item(req); /* This sends the writey transaction to the driver and waits for the driver to complete handling it.*/
  endtask : body

  virtual function void randomize_req();
    if (!req.randomize()) begin
      `uvm_fatal(
        get_type_name(),
        "Manager write item randomization failed"
      )
    end
    `uvm_info( "TIMEOUT_DEBUG", $sformatf( "subordinate item: suppress_bvalid=%0b awready_delay=%0d wready_delay=%0d bvalid_delay=%0d", req.suppress_bvalid, req.awready_delay, req.wready_delay, req.bvalid_delay ), UVM_LOW )
  endfunction : randomize_req

endclass : axi4l_manager_write_seq

class axi4l_subordinate_write_seq extends uvm_sequence#(axi4l_subordinate_write_seq);
`uvm_object_utils(axi4l_subordinate_write_seq)

  axi4l_write_item req;

  function new(string name = "axi4l_subordinate_write_seq");
    super.new(name);
  endfunction
  
  virtual task body();
    `uvm_info(
      get_type_name(),
      "Downstream AXI4-Lite write Sequence",
      UVM_LOW
    )
    
    req = axi4l_write_item::type_id::create("req"); /* explicilt creation via UVM factor*/
    start_item(req); /* sequencer, I have AXI trransaction i want to send. tell me when you are writey.*/
    req.configure_for_subordinate();

    randomize_req();
    finish_item(req); /* This sends the writey transaction to the driver and waits for the driver to complete handling it.*/
  endtask : body

  virtual function void randomize_req();
    if (!req.randomize()) begin
      `uvm_fatal(
        get_type_name(),
        "Subordinate write item randomization failed"
      )

    end
  endfunction : randomize_req

endclass : axi4l_subordinate_write_seq