class axi4l_write_driver extends uvm_driver#(axi4l_write_item); /* this driver consumes axi4l_write_item transactions*/
  /* note on paramaterization: because we passed in axi4l_write_item, parent class uvm_driver ocntains something conceptually like REQ req */
  /* since we supplied our parameter, this becomes axi4l_write_item req;*/
  `uvm_component_utils(axi4l_write_driver)
  
  virtual axi4l_if vif; /* handle to real AXI4-Lite interrace*/
  axi4l_role_e role; /* tell driver which side it is acting as (MANAGER or subordinate?)*/
  axi4l_sub_mem mem_model;
  /* pipelined modes for QUEUE verification.
   Default disabled so all existing tests retain blocking behavior. */
  bit pipelined_manager_writes     = 1'b0;
  bit pipelined_subordinate_writes = 1'b0;
  /* Stores completed downstream AW/W pairs until the subordinate
    response thread is ready to generate their B responses. */
  mailbox #(axi4l_write_item) subordinate_write_rsp_mb;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
    subordinate_write_rsp_mb = new();
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual axi4l_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "axi4l_write_driver could not get virtual interface 'vif'")
    end

    if (!uvm_config_db#(axi4l_role_e)::get(this, "", "role", role)) begin
      `uvm_fatal("NOROLE", "axi4l_write_driver could not get AXI4-Lite role")
    end
    if (role == AXI4L_MANAGER) begin
      void'(uvm_config_db#(bit)::get(this,"","pipelined_manager_writes",pipelined_manager_writes));
    end
    if (role == AXI4L_SUBORDINATE) begin
      void'(uvm_config_db#(bit)::get(this,"","pipelined_subordinate_writes",pipelined_subordinate_writes));
      void'(uvm_config_db#(axi4l_sub_mem)::get(this,"","mem_model",mem_model));
  end

  endfunction

  virtual task run_phase(uvm_phase phase);

    unique case (role)
      AXI4L_MANAGER:
        {vif.awvalid, vif.wvalid, vif.bready, vif.aw, vif.w} <= '0;

      AXI4L_SUBORDINATE:
        {vif.awready, vif.wready, vif.bvalid, vif.b} <= '0;

      default:
        `uvm_fatal("BADROLE","Unknown AXI4-Lite role")
    endcase

    // Do not begin driving transactions while reset is active.
    wait (vif.aresetn === 1'b1);
    if (role == AXI4L_MANAGER && pipelined_manager_writes) begin
      fork
        drive_manager_write_requests();
        accept_manager_write_responses();
      join
    end
    else if (role == AXI4L_SUBORDINATE && pipelined_subordinate_writes) begin
      fork
        accept_subordinate_write_requests();
        drive_subordinate_write_responses();
      join
    end
    else begin
      /*
      * Original blocking behavior retained for all existing tests.
      */
      forever begin
        seq_item_port.get_next_item(req);
        drive_to_dut(req);
        seq_item_port.item_done();
      end
    end
  endtask

  virtual task drive_manager_write_requests();

  axi4l_write_item item;

  forever begin

    seq_item_port.get_next_item(item);

    if (item.suppress_wvalid === 1'b1 || item.late_wvalid_after_timeout === 1'b1)
      `uvm_fatal("MGR_WR_PIPE_BAD_ITEM", "Timeout-specific write item used while pipelined_manager_writes is enabled")

    fork

      begin
        repeat (item.aw_delay)
          @(vif.mon_cb);

        vif.aw.addr <= item.addr;
        vif.aw.prot <= item.prot;
        vif.awvalid <= 1'b1;

        do begin
          @(vif.mon_cb);
        end while (!(vif.mon_cb.awvalid === 1'b1 && vif.mon_cb.awready === 1'b1));

        vif.awvalid <= 1'b0;
      end

      begin
        repeat (item.w_delay)
          @(vif.mon_cb);

        vif.w.data <= item.data;
        vif.w.strb <= item.strb;
        vif.wvalid <= 1'b1;

        do begin
          @(vif.mon_cb);
        end while (!(vif.mon_cb.wvalid === 1'b1 && vif.mon_cb.wready === 1'b1));

        vif.wvalid <= 1'b0;
      end

    join

    `uvm_info("MGR_WR_PIPE", $sformatf("Pipelined AW/W pair accepted: addr=0x%0h data=0x%0h", item.addr, item.data), UVM_LOW)

    seq_item_port.item_done();

  end

endtask : drive_manager_write_requests

virtual task accept_manager_write_responses();

  vif.bready <= 1'b1;

  forever begin

    do begin
      @(vif.mon_cb);
    end while (!(vif.mon_cb.bvalid === 1'b1 && vif.mon_cb.bready === 1'b1));

    `uvm_info("MGR_WR_PIPE", $sformatf("Pipelined B response accepted: resp=%0h", vif.mon_cb.b.resp), UVM_LOW)

  end

endtask : accept_manager_write_responses

virtual task accept_subordinate_write_requests();

  axi4l_write_item item;
  axi4l_write_item rsp_item;

  forever begin

    seq_item_port.get_next_item(item);

    fork

      begin
        do begin
          @(vif.mon_cb);
        end while (vif.mon_cb.awvalid !== 1'b1);

        repeat (item.awready_delay)
          @(vif.mon_cb);

        vif.awready <= 1'b1;

        do begin
          @(vif.mon_cb);
        end while (!(vif.mon_cb.awvalid === 1'b1 && vif.mon_cb.awready === 1'b1));

        item.addr = vif.mon_cb.aw.addr;
        item.prot = vif.mon_cb.aw.prot;

        vif.awready <= 1'b0;
      end

      begin
        do begin
          @(vif.mon_cb);
        end while (vif.mon_cb.wvalid !== 1'b1);

        repeat (item.wready_delay)
          @(vif.mon_cb);

        vif.wready <= 1'b1;

        do begin
          @(vif.mon_cb);
        end while (!(vif.mon_cb.wvalid === 1'b1 && vif.mon_cb.wready === 1'b1));

        item.data = vif.mon_cb.w.data;
        item.strb = vif.mon_cb.w.strb;

        vif.wready <= 1'b0;
      end

    join

    mem_model.write(item.addr, item.data, item.strb);



    rsp_item = axi4l_write_item::type_id::create("rsp_item");
    rsp_item.addr = item.addr;
    rsp_item.prot = item.prot;
    rsp_item.data = item.data;
    rsp_item.strb = item.strb;
    rsp_item.resp = item.resp;
    rsp_item.bvalid_delay = item.bvalid_delay;
    rsp_item.suppress_bvalid = item.suppress_bvalid;
    rsp_item.late_bvalid_after_timeout = item.late_bvalid_after_timeout;

    subordinate_write_rsp_mb.put(rsp_item);

    `uvm_info("SUB_WR_PIPE", $sformatf("Pipelined AW/W pair accepted: addr=0x%0h data=0x%0h", item.addr, item.data), UVM_LOW)

    seq_item_port.item_done();

  end

endtask : accept_subordinate_write_requests

virtual task drive_subordinate_write_responses();

  axi4l_write_item item;

  forever begin

    subordinate_write_rsp_mb.get(item);

    if (item.suppress_bvalid === 1'b1 || item.late_bvalid_after_timeout === 1'b1)
      `uvm_fatal("SUB_WR_PIPE_BAD_ITEM", "Timeout-specific write item used while pipelined_subordinate_writes is enabled")

    repeat (item.bvalid_delay)
      @(vif.mon_cb);

    vif.b.resp <= item.resp;
    vif.bvalid <= 1'b1;

    do begin
      @(vif.mon_cb);
    end while (!(vif.mon_cb.bvalid === 1'b1 && vif.mon_cb.bready === 1'b1));

    `uvm_info("SUB_WR_PIPE", $sformatf("Pipelined B response completed: addr=0x%0h resp=%0h", item.addr, item.resp), UVM_LOW)

    vif.bvalid <= 1'b0;

  end

endtask : drive_subordinate_write_responses

  
  virtual task drive_to_dut(axi4l_write_item item);

    case (role)
      AXI4L_MANAGER:
        drive_manager_write(item);

      AXI4L_SUBORDINATE:
        drive_subordinate_write(item);

      default:
        `uvm_fatal("BADROLE","Unknown role")
    endcase

    /* define */

  endtask
  
  virtual task drive_manager_write(
      axi4l_write_item item
  );

    /* Manager side:
    drive AWADDR/AWPROT/AWVALID and WDATA/WSTRB/WVALID concurrently (AXI allows
    either channel to lead), wait for both handshakes, then drive BREADY and
    wait for BVALID/BRESP*/


    /* for write-data-timeout test:
       issue AW normally but intentionally never issue WVALID */
    if (item.suppress_wvalid === 1'b1) begin

      /*
      * Send and complete AW normally.
      */
      repeat (item.aw_delay)
        @(vif.mon_cb);

      vif.aw.addr <= item.addr;
      vif.aw.prot <= item.prot;
      vif.awvalid <= 1'b1;

      do begin
        @(vif.mon_cb);
      end while (!(
        vif.mon_cb.awvalid === 1'b1 &&
        vif.mon_cb.awready === 1'b1
      ));

      `uvm_info( "MGR_WR_DATA_TIMEOUT", $sformatf( "AW accepted at addr=0x%0h; intentionally withholding WVALID", item.addr ), UVM_LOW )

      vif.awvalid <= 1'b0;

      /*
      * Ensure W remains absent.
      */
      vif.wvalid <= 1'b0;

      /*
      * Give the DUT enough time to detect the missing W.
      * No BREADY/B response is expected for an incomplete write.
      */
      repeat (TIMEOUT_COUNTER + 10)
        @(vif.mon_cb);

      return;

    end

        /* WDT-05:
      allow AW to timeout, then deliberately present late WVALID */
    if (item.late_wvalid_after_timeout === 1'b1) begin

      repeat (item.aw_delay)
        @(vif.mon_cb);

      vif.aw.addr <= item.addr;
      vif.aw.prot <= item.prot;
      vif.awvalid <= 1'b1;

      do begin
        @(vif.mon_cb);
      end while (!(
        vif.mon_cb.awvalid === 1'b1 &&
        vif.mon_cb.awready === 1'b1
      ));

      `uvm_info( "MGR_WR_LATE_W", $sformatf( "AW accepted at addr=0x%0h; waiting for write-data timeout before presenting late WVALID", item.addr ), UVM_LOW )

      vif.awvalid <= 1'b0;
      vif.wvalid  <= 1'b0;

      /* Allow the SCC to detect the missing W and enter WPAIR_W_FAULT. */
      repeat (TIMEOUT_COUNTER + 10)
        @(vif.mon_cb);

      vif.w.data <= item.data;
      vif.w.strb <= item.strb;
      vif.wvalid <= 1'b1;

      /* Hold late WVALID long enough to verify that it is rejected. */
      repeat (3)
        @(vif.mon_cb);

      vif.wvalid <= 1'b0;

      `uvm_info( "MGR_WR_LATE_W", "Late WVALID presented after timeout and withdrawn without handshake", UVM_LOW )

      return;

    end


    fork

    /* AW channel */
    begin

      repeat (item.aw_delay)
        @(vif.mon_cb);

      vif.aw.addr <= item.addr;
      vif.aw.prot <= item.prot;
      vif.awvalid <= 1'b1;

      do begin
        @(vif.mon_cb);
      end while (!(
        vif.mon_cb.awvalid === 1'b1 &&
        vif.mon_cb.awready === 1'b1
      ));

      `uvm_info( "MGR_WR", $sformatf( "Upstream AW handshake completed at %0t", $time ), UVM_LOW )

      vif.awvalid <= 1'b0;

    end

      /* W channel */
      begin

        repeat (item.w_delay)
          @(vif.mon_cb);

        vif.w.data <= item.data;
        vif.w.strb <= item.strb;
        vif.wvalid <= 1'b1;

        do begin
          @(vif.mon_cb);
        end while (!(
          vif.mon_cb.wvalid === 1'b1 &&
          vif.mon_cb.wready === 1'b1
        ));

        `uvm_info( "MGR_WR", $sformatf( "Upstream W handshake completed at %0t", $time ), UVM_LOW )

        vif.wvalid <= 1'b0;

      end

    join


    `uvm_info( "MGR_WR", $sformatf( "Upstream AW/W completed at %0t; bready_delay=%0d", $time, item.bready_delay ), UVM_LOW )

    /* delay before accepting write response */
    repeat (item.bready_delay)
      @(vif.mon_cb);

    vif.bready <= 1'b1;

    `uvm_info( "MGR_WR", $sformatf( "Now asserting upstream BREADY at %0t", $time ), UVM_LOW )

    do begin
      @(vif.mon_cb);
    end while (!(
      vif.mon_cb.bvalid === 1'b1 &&
      vif.mon_cb.bready === 1'b1
    ));

    /* capture the sampled response */
    item.resp = vif.mon_cb.b.resp;

    vif.bready <= 1'b0;

  endtask


  virtual task drive_subordinate_write(
      axi4l_write_item item
  );

    /*
    Subordinate side:
    wait for AWVALID and WVALID (independently), drive AWREADY/WREADY,
    update the memory model, then drive BVALID/BRESP and wait for BREADY*/

    fork

  /* AW channel */
  begin

    repeat (item.awready_delay)
      @(vif.mon_cb);

    vif.awready <= 1'b1;

    do begin
      @(vif.mon_cb);
    end while (!(
      vif.mon_cb.awvalid === 1'b1 &&
      vif.mon_cb.awready === 1'b1
    ));

    item.addr = vif.mon_cb.aw.addr;
    item.prot = vif.mon_cb.aw.prot;

    vif.awready <= 1'b0;

  end


  /* W channel */
  begin

    repeat (item.wready_delay)
      @(vif.mon_cb);

    vif.wready <= 1'b1;

    do begin
      @(vif.mon_cb);
    end while (!(
      vif.mon_cb.wvalid === 1'b1 &&
      vif.mon_cb.wready === 1'b1
    ));

    item.data = vif.mon_cb.w.data;
    item.strb = vif.mon_cb.w.strb;

    vif.wready <= 1'b0;

  end

join


    `uvm_info( "SUB_WR", "Passed AW/W handshakes", UVM_LOW )
    mem_model.write(item.addr, item.data, item.strb);


    /* WRT-04:
    allow the SCC to timeout waiting for B, then deliberately send the
    real subordinate response late so that the guard must drain it. */
    if (item.late_bvalid_after_timeout === 1'b1) begin
      `uvm_info( "SUB_WR_LATE_B", $sformatf( "Withholding BVALID until after write-response timeout for addr=0x%0h", item.addr ), UVM_LOW )
      vif.bvalid <= 1'b0;
      repeat (TIMEOUT_COUNTER + 10)
        @(vif.mon_cb);
      vif.b.resp <= item.resp;
      vif.bvalid <= 1'b1;
      do begin
        @(vif.mon_cb);
      end while (!(
        vif.mon_cb.bvalid === 1'b1 &&
        vif.mon_cb.bready === 1'b1
      ));
      `uvm_info( "SUB_WR_LATE_B", $sformatf( "Withholding BVALID until after write-response timeout for addr=0x%0h", item.addr ), UVM_LOW )`uvm_info( "SUB_WR_LATE_B", "Late downstream B response drained after timeout", UVM_LOW )
      vif.bvalid <= 1'b0;
      return;
    end


    /* for write-response-timeout test:
       accept the complete request but intentionally withhold BVALID */
    if (item.suppress_bvalid === 1'b1) begin
      `uvm_info( "SUB_WRITE_TIMEOUT", $sformatf( "Withholding BVALID; write request for address 0x%0h and data: 0x%0h", item.addr, item.data ), UVM_LOW )

      repeat (TIMEOUT_COUNTER + 10)
        @(vif.mon_cb);

      return;

    end


    `uvm_info( "SUB_WR", $sformatf( "Waiting bvalid_delay=%0d cycles", item.bvalid_delay ), UVM_LOW )

    repeat (item.bvalid_delay)
      @(vif.mon_cb);

    `uvm_info( "SUB_WR", "Now asserting BVALID", UVM_LOW )


    vif.b.resp <= item.resp;
    vif.bvalid <= 1'b1;

    /* VALID must not depend on READY; otherwise, deadlock */
    do begin
      @(vif.mon_cb);
    end while (!(
      vif.mon_cb.bvalid === 1'b1 &&
      vif.mon_cb.bready === 1'b1
    ));

    /* B handshake completed */
    vif.bvalid <= 1'b0;

  endtask : drive_subordinate_write

endclass : axi4l_write_driver