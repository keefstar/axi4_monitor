
class axi4l_write_driver extends uvm_driver#(axi4l_write_item); /* this driver consumes axi4l_write_item transactions*/
  /* note on paramaterization: because we passed in axi4l_write_item, parent class uvm_driver ocntains something conceptually like REQ req */
  /* since we supplied our parameter, this becomes axi4l_write_item req;*/
  `uvm_component_utils(axi4l_write_driver)
  
  virtual axi4l_if vif; /* handle to real AXI4-Lite interrace*/
  axi4l_role_e role; /* tell driver which side it is acting as (MANAGER or subordinate?)*/
  axi4l_sub_mem mem_model;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4l_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "axi4l_write_driver could not get virtual interface 'vif'")
    end
    if (!uvm_config_db#(axi4l_role_e)::get(this, "", "role", role)) begin
      `uvm_fatal("NOROLE", "axi4l_write_driver could not get AXI4-Lite role")
    end
    if (role == AXI4L_SUBORDINATE) uvm_config_db#(axi4l_sub_mem)::get(this,"","mem_model",mem_model);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    unique case (role)
      AXI4L_MANAGER: begin
  vif.mgr_cb.awvalid <= '0;
  vif.mgr_cb.wvalid  <= '0;
  vif.mgr_cb.bready  <= '0;
  vif.mgr_cb.aw      <= '0;
  vif.mgr_cb.w       <= '0;
end
      AXI4L_SUBORDINATE: {vif.awready, vif.wready, vif.bvalid, vif.b} <= '0;
      default: `uvm_fatal("BADROLE","Unknown AXI4-Lite role")
    endcase
    // Do not begin driving transactions while reset is active.
    wait (vif.aresetn === 1'b1);
    
    forever begin
      seq_item_port.get_next_item(req);
      drive_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  
  virtual task drive_to_dut(axi4l_write_item item);
    case (role)
      AXI4L_MANAGER: drive_manager_write(item);
      AXI4L_SUBORDINATE: drive_subordinate_write(item);
      default: `uvm_fatal("BADROLE","Unknown role")
    endcase
    /* define */
  endtask
  
  virtual task drive_manager_write(
    axi4l_write_item item
);

  /*
   * Manager side:
   * - Drive manager-owned signals through mgr_cb.
   * - Sample subordinate/DUT-owned signals through mgr_cb.
   *
   * Manager owns:
   *   AWVALID/AW, WVALID/W, BREADY
   *
   * DUT/subordinate owns:
   *   AWREADY, WREADY, BVALID/B
   */

  // ----------------------------------------------------------
  // Special case: intentionally withhold WVALID
  // ----------------------------------------------------------
  if (item.suppress_wvalid === 1'b1) begin

    repeat (item.aw_delay)
      @(vif.mgr_cb);

    // Drive AW request
    vif.mgr_cb.aw.addr  <= item.addr;
    vif.mgr_cb.aw.prot  <= item.prot;
    vif.mgr_cb.awvalid  <= 1'b1;

    // We know AWVALID is asserted because WE drive it.
    // Only wait for DUT-owned AWREADY.
    do begin
      @(vif.mgr_cb);
    end while (vif.mgr_cb.awready !== 1'b1);

    `uvm_info(
      "MGR_WR_DATA_TIMEOUT",
      $sformatf(
        "AW accepted at addr=0x%0h; intentionally withholding WVALID",
        item.addr
      ),
      UVM_LOW
    )

    vif.mgr_cb.awvalid <= 1'b0;
    vif.mgr_cb.wvalid  <= 1'b0;

    // Allow DUT timeout detector to expire
    repeat (TIMEOUT_COUNTER + 10)
      @(vif.mgr_cb);

    return;
  end


  // ----------------------------------------------------------
  // Normal AW + W request
  // ----------------------------------------------------------
  fork

    // AW channel
    begin
      repeat (item.aw_delay)
        @(vif.mgr_cb);

      vif.mgr_cb.aw.addr <= item.addr;
      vif.mgr_cb.aw.prot <= item.prot;
      vif.mgr_cb.awvalid <= 1'b1;

      // AWVALID is already known to be asserted.
      // Wait only for DUT-owned AWREADY.
      do begin
        @(vif.mgr_cb);
      end while (vif.mgr_cb.awready !== 1'b1);

      `uvm_info(
        "MGR_WR",
        $sformatf(
          "Upstream AW handshake completed at %0t",
          $time
        ),
        UVM_LOW
      )

      vif.mgr_cb.awvalid <= 1'b0;
    end


    // W channel
    begin
      repeat (item.w_delay)
        @(vif.mgr_cb);

      vif.mgr_cb.w.data <= item.data;
      vif.mgr_cb.w.strb <= item.strb;
      vif.mgr_cb.wvalid <= 1'b1;

      // WVALID is driven by us.
      // Wait only for DUT-owned WREADY.
      do begin
        @(vif.mgr_cb);
      end while (vif.mgr_cb.wready !== 1'b1);

      `uvm_info(
        "MGR_WR",
        $sformatf(
          "Upstream W handshake completed at %0t",
          $time
        ),
        UVM_LOW
      )

      vif.mgr_cb.wvalid <= 1'b0;
    end

  join


  `uvm_info(
    "MGR_WR",
    $sformatf(
      "Upstream AW/W completed at %0t; bready_delay=%0d",
      $time,
      item.bready_delay
    ),
    UVM_LOW
  )


  // ----------------------------------------------------------
  // Write response channel
  // ----------------------------------------------------------

  repeat (item.bready_delay)
    @(vif.mgr_cb);

  vif.mgr_cb.bready <= 1'b1;

  `uvm_info(
    "MGR_WR",
    $sformatf(
      "Now asserting upstream BREADY at %0t",
      $time
    ),
    UVM_LOW
  )

  // BREADY is driven by us.
  // Wait only for DUT-owned BVALID.
  do begin
  @(vif.mgr_cb);

  $display(
    "B DEBUG @ %0t raw_bvalid=%b raw_bready=%b mgr_bvalid=%b",
    $time,
    vif.bvalid,
    vif.bready,
    vif.mgr_cb.bvalid
  );

end while (vif.mgr_cb.bvalid !== 1'b1);

  // Capture DUT response
  item.resp = vif.mgr_cb.b.resp;

  vif.mgr_cb.bready <= 1'b0;

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
      /* W channel */
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

    `uvm_info("SUB_WR", "Passed AW/W handshakes", UVM_LOW)

    mem_model.write(item.addr, item.data, item.strb);
    item.resp = RESP_OKAY;

    if (item.suppress_bvalid === 1'b1) begin
      `uvm_info("SUB_WRITE_TIMEOUT", $sformatf("Withholding BVALID; write request for address 0x%0h and data: 0x%0h", item.addr, item.data), UVM_LOW)
      repeat (TIMEOUT_COUNTER + 10)
        @(vif.mon_cb);
      return;
    end

    `uvm_info(
      "SUB_WR",
      $sformatf(
        "Waiting bvalid_delay=%0d cycles",
        item.bvalid_delay
      ),
      UVM_LOW
    )

    repeat (item.bvalid_delay)
      @(vif.mon_cb);

    `uvm_info("SUB_WR", "Now asserting BVALID", UVM_LOW)

    vif.b.resp <= item.resp;
    vif.bvalid <= 1'b1;

    /* VALID must not depend on READY; otherwise, deadlock */
    do begin
      @(vif.mon_cb);
    end while (!(vif.mon_cb.bvalid === 1'b1 && vif.mon_cb.bready === 1'b1));

    /* B handshake completed */
    vif.bvalid <= 1'b0;
  endtask : drive_subordinate_write

endclass : axi4l_write_driver
