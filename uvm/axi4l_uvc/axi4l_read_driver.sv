class axi4l_read_driver extends uvm_driver#(axi4l_read_item); /* this driver consumes axi4l_read_item transactions*/
  /* note on paramaterization: because we passed in axi4l_read_item, parent class uvm_driver ocntains something conceptually like REQ req */
  /* since we supplied our parameter, this becomes axi4l_read_item req;*/
  `uvm_component_utils(axi4l_read_driver)
  
  virtual axi4l_if vif; /* handle to real AXI4-Lite interrace*/
  axi4l_role_e role; /* tell driver which side it is acting as (MANAGER or subordinate?)*/
  axi4l_sub_mem mem_model;

  /* To support QUEUE test */
  bit pipelined_manager_reads = 1'b0;
  bit pipelined_subordinate_reads = 1'b0;
  mailbox #(axi4l_read_item) subordinate_read_rsp_mb;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
    subordinate_read_rsp_mb = new();
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

    if (role == AXI4L_MANAGER) begin
      void'(uvm_config_db#(bit)::get(this, "", "pipelined_manager_reads", pipelined_manager_reads));
    end

    if (role == AXI4L_SUBORDINATE) begin
      void'(uvm_config_db#(bit)::get(this, "", "pipelined_subordinate_reads", pipelined_subordinate_reads));
      void'(uvm_config_db#(axi4l_sub_mem)::get(this, "", "mem_model", mem_model));
    end
  endfunction
  
  /* this syntax is common for all drivers; refer to (my own) notes for TLM connection*/
  /* RUN PHASE RUNS ONCE AT START UP */
  virtual task run_phase(uvm_phase phase);
    unique case (role) /* Put whichever signals this driver owns into an idle state first. */
      AXI4L_MANAGER: {vif.arvalid, vif.rready, vif.ar} <= '0;
      AXI4L_SUBORDINATE: {vif.arready, vif.rvalid, vif.r} <= '0;
      default: `uvm_fatal("BADROLE", "Unknown AXI4-Lite role")
    endcase
    // Do not begin driving transactions while reset is active.
    wait (vif.aresetn === 1'b1);

    /* TO SUPPORT QUEUE TESTS */
    if (role == AXI4L_MANAGER && pipelined_manager_reads) begin
      fork
        drive_manager_read_requests();
        accept_manager_read_responses();
      join
    end
    else if (role == AXI4L_SUBORDINATE && pipelined_subordinate_reads) begin
      fork
        accept_subordinate_read_requests();
        drive_subordinate_read_responses();
      join
    end
    else begin
      forever begin
        seq_item_port.get_next_item(req);
        drive_to_dut(req);
        seq_item_port.item_done();
      end
    end
  endtask

  virtual task drive_manager_read_requests();

  axi4l_read_item item;

  forever begin

    seq_item_port.get_next_item(item);

    repeat (item.ar_delay)
      @(vif.mon_cb);

    vif.ar.addr  <= item.addr;
    vif.ar.prot  <= item.prot;
    vif.arvalid  <= 1'b1;

    do begin
      @(vif.mon_cb);
    end while (!(
      vif.mon_cb.arvalid === 1'b1 &&
      vif.mon_cb.arready === 1'b1
    ));

    `uvm_info( "MGR_RD_PIPE", $sformatf( "Pipelined AR accepted for addr=0x%0h", item.addr ), UVM_LOW )

    vif.arvalid <= 1'b0;

    /*
     * The request has now been accepted. Do not wait for R before allowing
     * the sequencer to provide another read request.
     */
    seq_item_port.item_done();

  end

  endtask : drive_manager_read_requests

  virtual task accept_manager_read_responses();

  vif.rready <= 1'b1;

  forever begin

    do begin
      @(vif.mon_cb);
    end while (!(
      vif.mon_cb.rvalid === 1'b1 &&
      vif.mon_cb.rready === 1'b1
    ));
    `uvm_info( "MGR_RD_PIPE", $sformatf( "Pipelined R response accepted: data=0x%0h resp=%0h", vif.mon_cb.r.data, vif.mon_cb.r.resp ), UVM_LOW )

  end

endtask : accept_manager_read_responses

virtual task accept_subordinate_read_requests();

  axi4l_read_item item;
  axi4l_read_item rsp_item;

  forever begin

    seq_item_port.get_next_item(item);

    do begin
      @(vif.mon_cb);
    end while (vif.mon_cb.arvalid !== 1'b1);

    repeat (item.arready_delay)
      @(vif.mon_cb);

    vif.arready <= 1'b1;

    do begin
      @(vif.mon_cb);
    end while (!(
      vif.mon_cb.arvalid === 1'b1 &&
      vif.mon_cb.arready === 1'b1
    ));

    item.addr = vif.mon_cb.ar.addr;
    item.prot = vif.mon_cb.ar.prot;
    item.data = mem_model.read(item.addr);

    rsp_item = axi4l_read_item::type_id::create("rsp_item");
    rsp_item.copy(item);

    subordinate_read_rsp_mb.put(rsp_item);
    `uvm_info( "SUB_RD_PIPE", $sformatf("Pipelined AR accepted for addr=0x%0h", item.addr), UVM_LOW )
    vif.arready <= 1'b0;
    /*
     * The request has been accepted and its eventual response is queued.
     * The subordinate driver may now accept the next AR request.
     */
    seq_item_port.item_done();
  end

  endtask : accept_subordinate_read_requests

  virtual task drive_subordinate_read_responses();

  axi4l_read_item item;

  forever begin

    subordinate_read_rsp_mb.get(item);

    repeat (item.rvalid_delay)
      @(vif.mon_cb);

    vif.r.data <= item.data;
    vif.r.resp <= item.resp;
    vif.rvalid <= 1'b1;

    do begin
      @(vif.mon_cb);
    end while (!(
      vif.mon_cb.rvalid === 1'b1 &&
      vif.mon_cb.rready === 1'b1
    ));

    `uvm_info( "SUB_RD_PIPE", $sformatf( "Pipelined R completed for addr=0x%0h data=0x%0h resp=%0h", item.addr, item.data, item.resp ), UVM_LOW )

    vif.rvalid <= 1'b0;

  end

endtask : drive_subordinate_read_responses



  virtual task drive_to_dut(axi4l_read_item item);
    /* define */
    case (role)
      AXI4L_MANAGER: drive_manager_read(item);
      AXI4L_SUBORDINATE: drive_subordinate_read(item);
      default: `uvm_fatal("BADROLE", "unknown role")
    endcase
  endtask
  
  virtual task drive_manager_read(axi4l_read_item item);
    /* Manager side:
    drive ARADDR/ARPROT/ARVALID
    wait for ARREADY
    then drive RREADY
    wait for RVALID/RDATA/RRESP*/
    /* wait before issuing read (address) request*/
    repeat (item.ar_delay)
      @(vif.mon_cb);
    
    /* drive the AR payload directly onto the interface*/
    vif.ar.addr <= item.addr;
    vif.ar.prot <= item.prot;
    vif.arvalid <= 1'b1;
    
    /* wait until an AR handshake is observed (from sub)*/
    do begin
      @(vif.mon_cb);
    end
    /* KEEP WAITING UNTL BOTH VALID AND READY ARE DEFINITELY 1 (AVOID 0 and X CASES)*/
    while (!(vif.mon_cb.arvalid === 1'b1 && vif.mon_cb.arready === 1'b1)); /* Read the value of arready as sampled by the clocking block*/
    
    /* request was accepted; can deassert ARVALID by manager*/
    vif.arvalid <= 1'b0;
    
    /* delay before accepting read resopnse/willingness*/
    repeat (item.rready_delay)
      @(vif.mon_cb);
    
    vif.rready <= 1'b1;
    
    /* wait until R handhsake occurs*/
    do begin
      @(vif.mon_cb);
    end while (!(vif.mon_cb.rvalid === 1'b1 &&  vif.mon_cb.rready === 1'b1));
    
    /* capture the sampled resopnse*/
    item.data = vif.mon_cb.r.data;
    item.resp = vif.mon_cb.r.resp;
    /* deassert RREADY to signify resopnse accepted*/
    vif.rready <= 1'b0;
  endtask
  
  
  virtual task drive_subordinate_read(axi4l_read_item item);
    /*
    Subordinate side:
    wait for ARVALID
    drive ARREADY
    then drive RDATA/RRESP/RVALID
    wait for RREADY*/
    
    /* wait to recieve valid AR signal from manager*/
    do begin
      @(vif.mon_cb);
    end while (vif.mon_cb.arvalid !== 1'b1);
    
    /* complete specified/randomized delays*/
    repeat (item.arready_delay)
      @(vif.mon_cb);
    vif.arready <= 1'b1; /* drive its willingness to accept AR data; AR handshake complete*/

    do begin
      @(vif.mon_cb);
    end while (
      !(vif.mon_cb.arvalid === 1'b1 && vif.mon_cb.arready === 1'b1)
    );
    
    /* observe/obtain the driven data from manager*/
    item.addr = vif.mon_cb.ar.addr;
    item.prot = vif.mon_cb.ar.prot;
    /* subordinate is able to de-assert ARREADY*/
    vif.arready <= 1'b0;
    /* AXI technically allows ARREADY to be asserted before ARVALID*/

    `uvm_info("SUB_RD", "Passed AR handshake", UVM_LOW)
     //item.data = pattern(item.addr);
    
    /* for timeout test only: */
    if (item.suppress_rvalid == 1'b1) begin
      `uvm_info("SUB_RD_TIMEOUT", $sformatf("Accepted AR for addr = 0x%0h: intentinoally withhold RVALID", item.addr), UVM_LOW)
    
    repeat (TIMEOUT_COUNTER + 10) 
    @(vif.mon_cb);
    return;

  end

    item.data = mem_model.read(item.addr);

    `uvm_info("SUB_RD", $sformatf("Waiting rvalid_delay=%0d cycles", item.rvalid_delay), UVM_LOW)

    repeat (item.rvalid_delay)
      @(vif.mon_cb);

    `uvm_info("SUB_RD", "Now asserting RVALID", UVM_LOW)

    vif.r.data <= item.data;
    vif.r.resp <= item.resp;
    vif.rvalid <= 1'b1;
    
    /* VALID must not depend on READY; otherwise, deadlock*/
    do begin
      @(vif.mon_cb);
    end while (!(vif.mon_cb.rvalid === 1'b1 && vif.mon_cb.rready === 1'b1));
    
    /* R handshake completed */
    vif.rvalid <= 1'b0;
  endtask : drive_subordinate_read
  
  /* do i want/need this here if i have my new RAM idea?*/
  function automatic logic[DATA_WIDTH - 1:0] pattern(input logic[ADDR_WIDTH - 1:0] addr);
    localparam logic[DATA_WIDTH - 1:0] TAG = 32'hA5A5_5A5A;
    return addr ^ TAG;
  endfunction
endclass : axi4l_read_driver
