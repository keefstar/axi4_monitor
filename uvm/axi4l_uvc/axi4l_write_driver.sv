
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
      AXI4L_MANAGER: {vif.awvalid, vif.wvalid, vif.bready, vif.aw, vif.w} <= '0;
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
    /* Manager side:
    drive AWADDR/AWPROT/AWVALID and WDATA/WSTRB/WVALID concurrently (AXI allows
    either channel to lead), wait for both handshakes, then drive BREADY and
    wait for BVALID/BRESP*/

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
        end while (!(vif.mon_cb.awvalid === 1'b1 && vif.mon_cb.awready === 1'b1));

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
        end while (!(vif.mon_cb.wvalid === 1'b1 && vif.mon_cb.wready === 1'b1));

        vif.wvalid <= 1'b0;
      end
    join

    /* delay before accepting write response */
    repeat (item.bready_delay)
      @(vif.mon_cb);

    vif.bready <= 1'b1;

    do begin
      @(vif.mon_cb);
    end while (!(vif.mon_cb.bvalid === 1'b1 && vif.mon_cb.bready === 1'b1));

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