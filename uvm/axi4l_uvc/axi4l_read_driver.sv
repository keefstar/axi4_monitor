class axi4l_read_driver extends uvm_driver#(axi4l_read_item); /* this driver consumes axi4l_read_item transactions*/
  /* note on paramaterization: because we passed in axi4l_read_item, parent class uvm_driver ocntains something conceptually like REQ req */
  /* since we supplied our parameter, this becomes axi4l_read_item req;*/
  `uvm_component_utils(axi4l_read_driver)
  
  virtual axi4l_if vif; /* handle to real AXI4-Lite interrace*/
  axi4l_role_e role; /* tell driver which side it is acting as (MANAGER or subordinate?)*/
  axi4l_sub_mem mem_model;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
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

    if (role == AXI4L_SUBORDINATE) begin
      uvm_config_db#(axi4l_sub_mem)::get(this,"","mem_model",mem_model);
    end
  endfunction
  
  /* this syntax is common for all drivers; refer to (my own) notes for TLM connection*/
  /* RUN PHASE RUNS ONCE AT START UP */
  virtual task run_phase(uvm_phase phase);
    unique case (role) /* Put whichever signals this driver owns into an idle state first. */
      AXI4L_MANAGER: begin
        vif.mgr_cb.arvalid <= '0;
        vif.mgr_cb.rready  <= '0;
        vif.mgr_cb.ar      <= '0;
      end
      AXI4L_SUBORDINATE: begin
        vif.sub_cb.arready <= '0;
        vif.sub_cb.rvalid  <= '0;
        vif.sub_cb.r       <= '0;
      end
      default: `uvm_fatal("BADROLE", "Unknown AXI4-Lite role")
    endcase
    // Do not begin driving transactions while reset is active.
    wait (vif.aresetn === 1'b1);
    
    forever begin
      seq_item_port.get_next_item(req);
      drive_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  
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
      @(vif.mgr_cb);

    /* drive the AR payload directly onto the interface*/
    vif.mgr_cb.ar.addr <= item.addr;
    vif.mgr_cb.ar.prot <= item.prot;
    vif.mgr_cb.arvalid <= 1'b1;

    /* ARVALID is driven by us; wait only for DUT/subordinate-owned ARREADY*/
    do begin
      @(vif.mgr_cb);
    end
    while (vif.mgr_cb.arready !== 1'b1); /* Read the value of arready as sampled by the clocking block*/

    /* request was accepted; can deassert ARVALID by manager*/
    vif.mgr_cb.arvalid <= 1'b0;

    /* delay before accepting read resopnse/willingness*/
    repeat (item.rready_delay)
      @(vif.mgr_cb);

    vif.mgr_cb.rready <= 1'b1;

    /* RREADY is driven by us; wait only for DUT/subordinate-owned RVALID*/
    do begin
      @(vif.mgr_cb);
    end while (vif.mgr_cb.rvalid !== 1'b1);

    /* capture the sampled resopnse*/
    item.data = vif.mgr_cb.r.data;
    item.resp = vif.mgr_cb.r.resp;
    /* deassert RREADY to signify resopnse accepted*/
    vif.mgr_cb.rready <= 1'b0;
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
      @(vif.sub_cb);
    end while (vif.sub_cb.arvalid !== 1'b1);

    /* complete specified/randomized delays*/
    repeat (item.arready_delay)
      @(vif.sub_cb);
    vif.sub_cb.arready <= 1'b1; /* drive its willingness to accept AR data; AR handshake complete*/

    /* ARREADY is driven by us; wait only for manager-owned ARVALID*/
    do begin
      @(vif.sub_cb);
    end while (
      vif.sub_cb.arvalid !== 1'b1
    );

    /* observe/obtain the driven data from manager*/
    item.addr = vif.sub_cb.ar.addr;
    item.prot = vif.sub_cb.ar.prot;
    /* subordinate is able to de-assert ARREADY*/
    vif.sub_cb.arready <= 1'b0;
    /* AXI technically allows ARREADY to be asserted before ARVALID*/

    `uvm_info("SUB_RD", "Passed AR handshake", UVM_LOW)
     //item.data = pattern(item.addr);

    /* for timeout test only: */
    if (item.suppress_rvalid == 1'b1) begin
      `uvm_info("SUB_RD_TIMEOUT", $sformatf("Accepted AR for addr = 0x%0h: intentinoally withhold RVALID", item.addr), UVM_LOW)

    repeat (TIMEOUT_COUNTER + 10)
    @(vif.sub_cb);
    return;

  end

    item.data = mem_model.read(item.addr);

    `uvm_info("SUB_RD", $sformatf("Waiting rvalid_delay=%0d cycles", item.rvalid_delay), UVM_LOW)

    repeat (item.rvalid_delay)
      @(vif.sub_cb);

    `uvm_info("SUB_RD", "Now asserting RVALID", UVM_LOW)

    vif.sub_cb.r.data <= item.data;
    vif.sub_cb.r.resp <= item.resp;
    vif.sub_cb.rvalid <= 1'b1;

    /* VALID must not depend on READY; otherwise, deadlock*/
    /* RVALID is driven by us; wait only for manager-owned RREADY*/
    do begin
      @(vif.sub_cb);
    end while (vif.sub_cb.rready !== 1'b1);

    /* R handshake completed */
    vif.sub_cb.rvalid <= 1'b0;
  endtask : drive_subordinate_read
  
  /* do i want/need this here if i have my new RAM idea?*/
  function automatic logic[DATA_WIDTH - 1:0] pattern(input logic[ADDR_WIDTH - 1:0] addr);
    localparam logic[DATA_WIDTH - 1:0] TAG = 32'hA5A5_5A5A;
    return addr ^ TAG;
  endfunction
endclass : axi4l_read_driver