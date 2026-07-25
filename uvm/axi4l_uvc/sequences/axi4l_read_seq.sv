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
  
  /* sequence-level rand properties 
   rand int unsigned num_reads;
   // Controls how many read transactions the sequence generates.
   // Useful for exercising different queue occupancies from 1 to DEPTH,
   // including near-full and full-capacity behavior.

   rand logic [ADDR_WIDTH-1:0] base_addr;
   // Gives multiple transactions in the sequence a related starting address.
   // Useful for generating patterns such as:
   // base_addr, base_addr + 4, base_addr + 8, etc.

   rand int unsigned stall_cycles;
   // Controls how long the simulated downstream subordinate withholds a response.
   // Useful for testing:
   //   stall < TIMEOUT_COUNTER
   //   stall around the timeout boundary
   //   stall > TIMEOUT_COUNTER
   // This likely belongs in a downstream/response-oriented sequence,
   // depending on the final agent architecture.

   Other possible scenario-level rand properties:
   // - number of outstanding requests to build before intentionally stalling
   // - whether to deliberately target timeout-boundary cases
   // - whether addresses are repeated, random, or sequential across the sequence
*/
  
  
endclass : axi4l_read_seq