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
  
  /*three additional queues for response checking: */
  /* pop results into these queues during request checking */
  axi4l_read_item pending_read_q[$];
  axi4l_write_item pending_aw_q[$];
  axi4l_write_item pending_w_q[$];
  
  /* independently calculates what memory should contain based on transactions observed by the scoreboard. */
  logic [DATA_WIDTH - 1:0] exp_mem[0:16383];

  /* for timeout/injections */
  int unsigned expected_read_error_responses;
  int unsigned expected_late_read_responses;

  int unsigned expected_write_error_responses;  /* AW, W but no BVALID*/
  bit expect_write_data_timeout; /* AW but no W*/
  int unsigned expected_late_write_responses; /* adding FOR WRT-04 */

  /* setter functions */
  function void set_expect_read_timeout(bit value);
    expected_read_error_responses = value ? 1 : 0;
  endfunction

  function void set_expect_write_timeout(bit value);
  expected_write_error_responses = value ? 1 : 0;
  endfunction

  function void set_expected_read_error_responses(int unsigned count);
    expected_read_error_responses = count;
  endfunction

  function void set_expected_late_read_responses(int unsigned count);
    expected_late_read_responses = count;
  endfunction

  function void set_expect_write_data_timeout(bit value);
    expect_write_data_timeout = value;
  endfunction

  function void set_expect_late_read_response(bit value);
    expected_late_read_responses = value ? 1 : 0;
  endfunction


  function void set_expect_late_write_response(bit value);
    expected_late_write_responses = value ? 1 : 0;
  endfunction

  function void set_expected_write_error_responses(int unsigned count);
    expected_write_error_responses = count;
  endfunction

  function void set_expected_late_write_responses(int unsigned count);
    expected_late_write_responses = count;
  endfunction
    
  function new(string name, uvm_component parent);
    super.new(name, parent);
    upstream_read_imp = new("upstream_read_imp", this);
    downstream_read_imp = new("downstream_read_imp", this);
    upstream_write_imp = new("upstream_write_imp", this);
    downstream_write_imp = new("downstream_write_imp", this);

    /* INITIALIZE RAM */
    foreach (exp_mem[i]) exp_mem[i] = '0;
    /* INITIALIZE FIELDS IF APPLICABLE*/
    expected_read_error_responses = 0;
    expected_late_read_responses = 0;
    expected_write_error_responses = 0;
    expect_write_data_timeout = 1'b0;
    expected_late_write_responses = 0;

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
      axi4l_read_item::READ_REQUEST: begin 
        upstream_read_req_q.push_back(tr_copy);
        check_read_request();
      end 
      axi4l_read_item::READ_RESPONSE: begin
        upstream_read_resp_q.push_back(tr_copy);
        check_read_response();
      end
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
      axi4l_read_item::READ_RESPONSE: begin
      /* A timeout/containment episode may leave several already-issued downstream
        responses stale. Consume each expected real response as ghost debt rather
        than attempting to match it against a later upstream transaction. */
      if (expected_late_read_responses > 0) begin
        expected_late_read_responses--;
        `uvm_info("READ_GHOST_DRAIN", $sformatf("Expected late downstream read response observed and consumed; remaining=%0d", expected_late_read_responses), UVM_LOW)
      end
      else begin
        downstream_read_resp_q.push_back(tr_copy);
        check_read_response();
      end
    end
      default: `uvm_fatal("SB_ERROR", "Unknown downstream read transaction category")
    endcase
  endfunction : write_downstream_read
  
  function void write_upstream_write(axi4l_write_item tr);
    axi4l_write_item tr_copy;
    assert ($cast(tr_copy, tr.clone())) else `uvm_fatal("CAST FAIL", "Failed to clone upstream write")
    case (tr_copy.kind)
      axi4l_write_item::WRITE_ADDRESS: begin
        upstream_aw_q.push_back(tr_copy);
        check_write_address();
      end 
      axi4l_write_item::WRITE_DATA: begin 
        upstream_w_q.push_back(tr_copy);
        check_write_data();
      end
      axi4l_write_item::WRITE_RESPONSE: begin 
        upstream_b_q.push_back(tr_copy);
        check_write_response();
      end 
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
      axi4l_write_item::WRITE_RESPONSE: begin
        /* A timeout/containment episode may leave multiple stale downstream B
          responses. Consume them as ghost debt because their corresponding
          upstream obligations were already completed with injected SLVERRs. */
        if (expected_late_write_responses > 0) begin
          expected_late_write_responses--;
          `uvm_info("WRITE_GHOST_DRAIN", $sformatf("Expected late downstream write response observed and consumed; remaining=%0d", expected_late_write_responses), UVM_LOW)
        end
        else begin
          downstream_b_q.push_back(tr_copy);
          check_write_response();
        end

      end
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

    /* SAVE FOR RESPONSE CHECKING */
    pending_read_q.push_back(expected);
    
  endfunction : check_read_request



  /* READ response carries: RDATA, RRESP, does not carry ARADDR.*/
  /* have to recover ARADDR from earlier read request */
  function void check_read_response();

    axi4l_read_item request;
    axi4l_read_item downstream_response;
    axi4l_read_item upstream_response;

    int unsigned word_index;
    logic [DATA_WIDTH-1:0] expected_data;

    /* timeout/containment path:
   Every expected injected SLVERR retires one outstanding upstream read
   obligation. In a single-read timeout this count is one. With followers
   already outstanding, containment may inject additional SLVERR responses
   until all upstream obligations from that fault episode are resolved. */
    if (expected_read_error_responses > 0) begin

      if (pending_read_q.size() == 0 || upstream_read_resp_q.size() == 0) return;

      request = pending_read_q.pop_front();
      upstream_response = upstream_read_resp_q.pop_front();

      if (upstream_response.resp !== RESP_SLVERR)
        `uvm_error("READ_TIMEOUT_RESP", $sformatf("Expected injected SLVERR for addr=0x%0h, received resp=0x%0h", request.addr, upstream_response.resp))
      else
        `uvm_info("READ_TIMEOUT_PASS", $sformatf("Expected timeout/containment SLVERR received for addr=0x%0h; remaining=%0d", request.addr, expected_read_error_responses - 1), UVM_LOW)

      expected_read_error_responses--;

      return;

    end

    /* normal path */
    if (pending_read_q.size() == 0 || 
        downstream_read_resp_q.size() == 0 ||
        upstream_read_resp_q.size() == 0) return;
    /* need upstream_read_req_q which contains ARADDR, ARPROT*/
    /* need downstream_read_resp_q which contains RDATA, RRESP */
    /* need upstream_read_resp_q which has RDATA and RRESP but to do equivalency check*/
    request = pending_read_q.pop_front();
    downstream_response = downstream_read_resp_q.pop_front();
    upstream_response = upstream_read_resp_q.pop_front();

    if (request.addr >= SUB_ADDR_BASE && request.addr <= SUB_ADDR_END) begin
      word_index = (request.addr - SUB_ADDR_BASE) >> $clog2(STRB_WIDTH);
      expected_data = exp_mem[word_index];
    end
    else begin
      expected_data = '0;
    end

    if (downstream_response.data !== expected_data) `uvm_error("READ_MEM_DATA", "Downstream returned incorrect memory data")
    if (upstream_response.data !== downstream_response.data) `uvm_error("READ_FWD_DATA", "SCC did not pass correct RDATA")
    if (upstream_response.resp !== downstream_response.resp) `uvm_error("READ_FWD_RESP", "SCC did not pass correct RRESP")

    /* need to verify two things: did sub return correct memory context, did SCC forward resp correctly (downstream resp == upstream resp )*/
  
  endfunction : check_read_response

  
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

      /* SAVE FOR CHECKING */
    pending_aw_q.push_back(expected);
    
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

    /* SAVE FOR CHECKING */
    pending_w_q.push_back(expected);
    
  endfunction : check_write_data

  function void check_write_response();

    axi4l_write_item aw_request;
    axi4l_write_item w_request;
    axi4l_write_item downstream_response;
    axi4l_write_item upstream_response;
    int unsigned word_index;

    /* timeout path */
    if (expected_write_error_responses > 0) begin

      if (upstream_b_q.size() == 0 || pending_aw_q.size() == 0 || pending_w_q.size() == 0) return;

      aw_request = pending_aw_q.pop_front();
      w_request = pending_w_q.pop_front();
      upstream_response = upstream_b_q.pop_front();

      if (upstream_response.resp !== RESP_SLVERR)
        `uvm_error("WRITE_TIMEOUT_RESP", $sformatf("Expected injected SLVERR for write addr=0x%0h, received resp=0x%0h", aw_request.addr, upstream_response.resp))
      else `uvm_info("WRITE_TIMEOUT_PASS", $sformatf("Expected timeout/containment SLVERR received for addr=0x%0h; remaining=%0d", aw_request.addr, expected_write_error_responses - 1), UVM_LOW)

      /*
      * The subordinate accepted and committed the write even though its B response
      * later timed out, so mirror the write into the scoreboard memory model.
      */
      if (aw_request.addr >= SUB_ADDR_BASE && aw_request.addr <= SUB_ADDR_END) begin
        word_index = (aw_request.addr - SUB_ADDR_BASE) >> $clog2(STRB_WIDTH);
        for (int byte_index = 0; byte_index < STRB_WIDTH; byte_index++) begin
          if (w_request.strb[byte_index] === 1'b1)
            exp_mem[word_index][8*byte_index +: 8] =
              w_request.data[8*byte_index +: 8];
        end
      end

      expected_write_error_responses--;

      return;

    end
    /* normal path */
    if (upstream_b_q.size() == 0 || downstream_b_q.size() == 0 || 
       (pending_aw_q.size() == 0 || pending_w_q.size() == 0)) return;

    aw_request = pending_aw_q.pop_front();
    w_request = pending_w_q.pop_front();
    downstream_response = downstream_b_q.pop_front();
    upstream_response = upstream_b_q.pop_front();

    if (upstream_response.resp === RESP_OKAY &&
    downstream_response.resp === RESP_OKAY &&
    aw_request.addr >= SUB_ADDR_BASE &&
    aw_request.addr <= SUB_ADDR_END) begin

  word_index = (aw_request.addr - SUB_ADDR_BASE) >> $clog2(STRB_WIDTH);

  for (int byte_index = 0; byte_index < STRB_WIDTH; byte_index++) begin
    if (w_request.strb[byte_index] === 1'b1) begin
      exp_mem[word_index][8*byte_index +: 8] =
        w_request.data[8*byte_index +: 8];
    end
  end
  end
  endfunction : check_write_response
  
  /*
 * check_phase runs after stimulus has finished.
 *
 * Any remaining queue entries mean that some observed transaction
 * was never matched with its corresponding event.
 */
function void check_phase(uvm_phase phase);

  super.check_phase(phase);

  if (expected_write_error_responses != 0)
  `uvm_error("SB_MISSING_WRITE_ERRORS", $sformatf("Simulation ended with %0d expected timeout/containment write responses not observed", expected_write_error_responses))

  if (expected_late_write_responses != 0)
    `uvm_error("SB_MISSING_WRITE_GHOSTS", $sformatf("Simulation ended with %0d expected late downstream write responses not observed", expected_late_write_responses))


  if (expected_read_error_responses != 0)
  `uvm_error("SB_MISSING_READ_ERRORS", $sformatf("Simulation ended with %0d expected timeout/containment read responses not observed", expected_read_error_responses))
  if (expected_late_read_responses != 0)
    `uvm_error("SB_MISSING_READ_GHOSTS", $sformatf("Simulation ended with %0d expected late downstream read responses not observed", expected_late_read_responses))

        /* WDT is checked here because the missing W/downstream AW are only definitive once stimulus has ended. */
    if (expect_write_data_timeout) begin
      if ( upstream_aw_q.size() == 1 && downstream_aw_q.size() == 0 && upstream_w_q.size() == 0 && downstream_w_q.size() == 0 ) begin
        `uvm_info( "WRITE_DATA_TIMEOUT_PASS", "Expected incomplete upstream AW observed with no downstream write launch", UVM_LOW )
        upstream_aw_q.pop_front();
        expect_write_data_timeout = 1'b0;
      end
      else begin
        `uvm_error( "WRITE_DATA_TIMEOUT_STATE", $sformatf( "Unexpected WDT scoreboard state: upstream_AW=%0d downstream_AW=%0d upstream_W=%0d downstream_W=%0d", upstream_aw_q.size(), downstream_aw_q.size(), upstream_w_q.size(), downstream_w_q.size() ) )
      end
    end
    else if (
      upstream_aw_q.size() !== 0 ||
      downstream_aw_q.size() !== 0
    ) begin
      `uvm_error( "SB_LEFTOVER_AW", $sformatf( "Unmatched AW events remain: upstream=%0d downstream=%0d", upstream_aw_q.size(), downstream_aw_q.size() ) )
    end
  /*
   * AR request existed on only one side, or was never paired.
   */
  if (
    upstream_read_req_q.size() !== 0 ||
    downstream_read_req_q.size() !== 0
  ) begin
    `uvm_error( "SB_LEFTOVER_READ_REQ", $sformatf( "Unmatched read requests remain: upstream=%0d downstream=%0d", upstream_read_req_q.size(), downstream_read_req_q.size() ) )
  end

  /*
   * A read request was forwarded but did not receive both
   * downstream and upstream responses.
   */
  if (
    pending_read_q.size() !== 0 ||
    downstream_read_resp_q.size() !== 0 ||
    upstream_read_resp_q.size() !== 0
  ) begin
    `uvm_error( "SB_LEFTOVER_READ_RESP", $sformatf( "Incomplete reads remain: pending=%0d downstream_R=%0d upstream_R=%0d", pending_read_q.size(), downstream_read_resp_q.size(), upstream_read_resp_q.size() ) )
  end

  /*
   * W events were not matched across the SCC.
   */
  if (
    upstream_w_q.size() !== 0 ||
    downstream_w_q.size() !== 0
  ) begin
    `uvm_error( "SB_LEFTOVER_W", $sformatf( "Unmatched W events remain: upstream=%0d downstream=%0d", upstream_w_q.size(), downstream_w_q.size() ) )
  end

  /*
   * A write was forwarded but did not receive a complete B response,
   * or the saved AW/W information was never consumed.
   */
  if (
    pending_aw_q.size() !== 0 ||
    pending_w_q.size() !== 0 ||
    downstream_b_q.size() !== 0 ||
    upstream_b_q.size() !== 0
  ) begin
    `uvm_error( "SB_LEFTOVER_WRITE_RESP", $sformatf( "Incomplete writes remain: pending_AW=%0d pending_W=%0d downstream_B=%0d upstream_B=%0d", pending_aw_q.size(), pending_w_q.size(), downstream_b_q.size(), upstream_b_q.size() ) )
  end

endfunction : check_phase
  
endclass : axi4l_sb

