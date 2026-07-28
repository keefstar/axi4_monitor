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
    req.arready_delay.rand_mode(0); /* would be asserted by SUB*/
    req.rrvalid_delay.rand_mode(0); /* would be asserted by SUB*/

    assert(req.randomize())
    else `uvm_fatal(get_type_name(), "Manager read item randomization failed")

    finish_item(req) /* send sequence item to the driver and waits until driver finishes processing it*/
  endtask : body

endclass : axi4l_manager_read_seq;

class axi4l_subordinate_read_seq extends uvm_sequence#(axi4l_read_item);

  `uvm_object_utils(axi4l_subordinate_read_seq)

  function new(string name = "axi4l_subordinate_read_seq");
    super.new(name);
  endfunction

    virtual task body();

    `uvm_info(get_type_name(), "Downstream AXI4-Lite Read Sequence", UVM_LOW)
    req = axi4l_read_item::type_id::create("req");
    start_item(req);

    req.addr.rand_mode(0);
    req.prot.rand_mode(0);
    req.ar_delay.rand_mode(0);
    req.rready_delay.rand_mode(0);

    assert(req.randomize())
    else `uvm_fatal(get_type_name(), "Subordinate read item randomization failed")

    finish_item(req);

    endtask : body


endclass : axi4l_subordinate_read_seq