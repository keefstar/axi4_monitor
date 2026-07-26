class axi4l_sb extends uvm_scoreboard;
  
  `uvm_component_utils(axi4l_sb) /* reg with uVM factor*/
  
  /* IMPORTANT: SCOREBOARD recieves from two monitors -- upstream and downsreamm*/
  /* only one uvm_analysis_imp object can be declared in a component; seperate imp subclasses can be declared fro multiple connectoins using decl macros*/
  /* sb needs seperate recieving functions. */
  
  `uvm_analysis_imp_decl(_upstream_read) /* argument is used as a suffix to create the subclass*/
  `uvm_analysis_imp_decl(_downstream_read)
  `uvm_analysis_imp_decl(_upstream_write)
  `uvm_analysis_imp_decl(_downstream_write)
  /* each new imp subclass must be instantiated and a seperate write method method must be defined*/
  
  uvm_analysis_imp_upstream_read#(axi4l_read_item, axi4l_sb) upstream_read_imp;
  uvm_analysis_imp_downstream_read#(axi4l_read_item, axi4l_sb) downstream_read_imp;
  uvm_analysis_imp_upstream_write#(axi4l_write_item, axi4l_sb) upstream_write_imp;
  uvm_analysis_imp_downstream_write#(axi4l_write_item, axi4l_sb) downstream_write_imp;
  
  /* reference queues */
  /* seperated by channel events*/
  /* AR channel for both upstream and downtream*/
  axi4l_read_item upstream_read_req_q[$];
  axi4l_read_item downstream_read_req_q[$];
  /* R channel */
  axi4l_read_item upstream_read_resp_q[$];
  axi4l_read_item downstream_read_resp_q[$];
  /* AW channel*/
  axi4l_write_item upstream_aw_q[$];
  axi4l_write_item downstream_aw_q[$];
  /* W channel*/
  axi4l_write_item upstream_w_q[$];
  axi4l_write_item downstream_w_q[$];
  /* B channel*/
  axi4l_write_item upstream_b_q[$];
  axi4l_write_item downstream_b_q[$];
  
  /* independently calculates what memory should contain based on transactions observed by the scoreboard. */
  logic[DATA_WIDTH - 1:0] exp_mem[0:255];
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
    upstream_read_imp = new("upstream_read_imp", this);
    downstream_read_imp = new("downstream_read_imp", this);
    upstream_write_imp = new("upstream_write_imp", this);
    downstream_write_imp = new("downstream_write_imp", this);
  endfunction 
  
  /* write only sends a reference - pointer to packet instance */
  /* monitor may use the same instance fro every collected pocket */
  /* this is a problem if the pointers are stored in queues/array*/
  
  /* write functions in sb context -> deliver transaction into the scoreboard*/
  
  
  /* The manager requested this address. Save what response the manager should eventually receive. */
  function void write_upstream_read(axi4l_read_item tr);
    axi4l_read_item tr_copy;
    /* clone() returns a generic uvm_object handle, but queue needs specific type (axi4l_read_item) */
    /* cast treat the returned generic handle as axi4l_read_item*/
    assert ($cast(tr_copy, tr.clone())) else `uvm_fatal("CAST FAIL", "Failed to clone upstream read")
    case (tr_copy.kind)
      axi4l_read_item::READ_REQUEST: upstream_read_req_q.push_back(tr_copy);
      axi4l_read_item::READ_RESPONSE: upstream_read_resp_q.push_back(tr_copy);
      default: `uvm_fatal("SB_ERROR", "Unknown upstream read transaction category")
    endcase
  endfunction : write_upstream_read
  
  function void write_downstream_read(axi4l_read_item tr);
    axi4l_read_item tr_copy;
    assert ($cast(tr_copy, tr.clone())) else `uvm_fatal("CAST FAIL", "Failed to clone downstream read")
    case (tr_copy.kind)
      axi4l_read_item::READ_REQUEST: begin
        downstream_read_req_q.push_back(tr_copy);
        check_read_request(); /* a valid downstream request must originate from an already accepted upstream request. */
      end
      axi4l_read_item::READ_RESPONSE: downstream_read_resp_q.push_back(tr_copy);
      default: `uvm_fatal("SB_ERROR", "Unknown downstream read transaction category")
    endcase
  endfunction : write_downstream_read
  
  function void write_upstream_write(axi4l_write_item tr);
    axi4l_write_item tr_copy;
    assert ($cast(tr_copy, tr.clone())) else `uvm_fatal("CAST FAIL", "Failed to clone upstream write")
    case (tr_copy.kind)
      axi4l_write_item::WRITE_ADDRESS: upstream_aw_q.push_back(tr_copy);
      axi4l_write_item::WRITE_DATA: upstream_w_q.push_back(tr_copy);
      axi4l_write_item::WRITE_RESPONSE: upstream_b_q.push_back(tr_copy);
      default: `uvm_fatal("SB_ERROR", "Unknown upstream write transaction category")
    endcase
  endfunction : write_upstream_write
  
  function void write_downstream_write(axi4l_write_item tr);
    axi4l_write_item tr_copy;
    assert ($cast(tr_copy, tr.clone())) else `uvm_fatal("CAST FAIL", "Failed to clone downstream write")
    case (tr_copy.kind)
      axi4l_write_item::WRITE_ADDRESS: begin
        downstream_aw_q.push_back(tr_copy);
        check_write_address();
      end
      axi4l_write_item::WRITE_DATA: begin
        downstream_w_q.push_back(tr_copy);
        check_write_data();
      end
      axi4l_write_item::WRITE_RESPONSE: downstream_b_q.push_back(tr_copy);
      default: `uvm_fatal("SB_ERROR", "Unknown downsteam write transaction category")
    endcase
  endfunction : write_downstream_write
  
  /* checker functions */
  function void check_read_request();
    
    axi4l_read_item expected;
    axi4l_read_item actual;
    
    /* Queue size check*/
    if (upstream_read_req_q.size() == 0 || downstream_read_req_q.size() == 0) return;
    expected = upstream_read_req_q.pop_front();
    actual = downstream_read_req_q.pop_front();
    
    /* check address field*/
    if (expected.addr !== actual.addr) begin `uvm_error("READ_REQ_ADDR",
    $sformatf("Read address mismatch: expected = 0x%0h; actual = 0x%0h",
    expected.addr, actual.addr)) end
    
    if (expected.prot !== actual.prot) begin `uvm_error("READ_REQ_PROT",
    $sformatf("Read prot mismatch: expected = 0x%0h; actual = 0x%0h",
    expected.prot, actual.prot)) end
    
  endfunction : check_read_request
  
  function void check_write_address();
    
    axi4l_write_item expected;
    axi4l_write_item actual;
    
    if (upstream_aw_q.size() == 0 || downstream_aw_q.size() == 0) return;
    expected = upstream_aw_q.pop_front();
    actual = downstream_aw_q.pop_front();
    
    if (expected.addr !== actual.addr) begin `uvm_error("WRITE_AW_ADDR",
    $sformatf("Write address mismatch: expected = 0x%0h; actual = 0x%0h",
    expected.addr, actual.addr)) end
    
    if (expected.prot !== actual.prot) begin `uvm_error("WRITE_AW_PROT",
    $sformatf("Write prot mismatch: expected = 0x%0h; actual = 0x%0h",
    expected.prot, actual.prot)) end
    
  endfunction : check_write_address
  
  function void check_write_data();
    
    axi4l_write_item expected;
    axi4l_write_item actual;
    
    if (upstream_w_q.size() == 0 || downstream_w_q.size() == 0) return;
    expected = upstream_w_q.pop_front();
    actual = downstream_w_q.pop_front();
    
    if (expected.data !== actual.data) begin `uvm_error("WRITE_W_DATA",
    $sformatf("Write data mismatch: expected = 0x%0h; actual = 0x%0h",
    expected.data, actual.data)) end
    
    if (expected.strb !== actual.strb) begin `uvm_error("WRITE_W_STRB",
    $sformatf("Write strb mismatch: expected = 0x%0h; actual = 0x%0h",
    expected.strb, actual.strb)) end
    
  endfunction : check_write_data
endclass : axi4l_sb

