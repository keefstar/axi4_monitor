/* manager read sequence tells the upstream driver what read request to send */
/* controls request-side fielfs such as ADDR, PROT, RREADY selay*/
class axi4l_manager_read_seq extends uvm_sequence#(axi4l_read_item);
  /* The base uvm_sequence class is written generically so it can handle any type of transaction item. 
  By using #, you tell the base sequence exactly what 
  kind of sequence item (or sequence item type) this specific sequence will generate and process*/

  `uvm_object_utils(axi4l_manager_read_seq) 
  
  function new(string name = "axi4l_manager_read_seq");
    super.new(name);
  endfunction

  virtual task body();

    `uvm_info(get_type_name(), "Upstream AXI4-Lite Read Sequence", UVM_LOW)
    req = axi4l_read_item::type_id::create("req");
    start_item(req); /* initiate a transaction with a driver; blocking call that manages handshake between seqence and sequencer */
  
    /* Manager and subordinate share one axi4l_read_item; disavle fields that do not belong in corresponding role*/
    req.configure_for_manager();

    /* child sequences can override this methdo to apply targetted constraints*/
    randomize_req();
    finish_item(req); /* send sequence item to the driver and waits until driver finishes processing it*/
  endtask

  virtual function void randomize_req();
    if (!req.randomize()) begin
      `uvm_fatal(
        get_type_name(),
        "Manager read item randomization failed"
      )

    end
  endfunction : randomize_req

endclass : axi4l_manager_read_seq

class axi4l_subordinate_read_seq extends uvm_sequence#(axi4l_read_item);

  `uvm_object_utils(axi4l_subordinate_read_seq)

  function new(string name = "axi4l_subordinate_read_seq");
    super.new(name);
  endfunction

    virtual task body();

    `uvm_info(get_type_name(), "Downstream AXI4-Lite Read Sequence", UVM_LOW)
    req = axi4l_read_item::type_id::create("req");
    start_item(req);
    
    req.configure_for_subordinate();

    randomize_req();
    finish_item(req);

    endtask

    virtual function void randomize_req();
    if (!req.randomize()) begin
      `uvm_fatal(
        get_type_name(),
        "Subordinate read item randomization failed"
      )

    end
  endfunction : randomize_req


endclass : axi4l_subordinate_read_seq