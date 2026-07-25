
class axi4l_monitor extends uvm_monitor;
  `uvm_component_utils(axi4l_monitor)
  virtual axi4l_if vif;
  
  /* to implement scoreboard - analysis port */
  /* A specialized Transaction-Level Modeling (TLM) port used to broadcast transaction data from a component (like a monitor)
  to multiple subscribers (like scoreboards or coverage collectors).*/
  /* declare handles*/
  uvm_analysis_port#(axi4l_read_item) read_ap; /* carry read transactions*/
  uvm_analysis_port#(axi4l_write_item) write_ap; /* carry write transactions*/
  /* port and imp are two ends of the TLM connection*/
  /* port does not check the transaction; only forwards it to anything connected*/
  
  /* constructor*/
  function new(string name, uvm_component parent);
    super.new(name, parent);
    /* instantiate ap objects*/
    read_ap = new("read_ap", this);
    write_ap = new("write_ap", this);
  endfunction
  
  /* build phase; get virtual interface from config DB*/
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4l_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "axi4l_monitor could not get virtual interface 'vif'")
    end
  endfunction : build_phase
  
  /* monitor interface signals*/
  virtual task run_phase(uvm_phase phase);
    axi4l_read_item read_tr;
    axi4l_write_item write_tr;
    
    forever begin
      @(vif.mon_cb);
      
      if (!vif.aresetn) continue;
      
      /* detect and reconstruct AR/R/AW/W/B handshakes*/
      /* AR CHANNEL FOR READ REQUESTS*/
      if (vif.mon_cb.arvalid && vif.mon_cb.arready) begin
        
        read_tr = axi4l_read_item::type_id::create("read_request_tr");
        
        read_tr.addr = vif.mon_cb.ar.addr;
        read_tr.prot = vif.mon_cb.ar.prot;
        read_tr.kind = READ_REQUEST;
        
        read_ap.write(read_tr);
        
      end
      
      /* R CHANNEL FOR READ RESPONSES */
      if (vif.mon_cb.rvalid && vif.mon_cb.rready) begin
        read_tr = axi4l_read_item::type_id::create("read_response_tr");
        
        read_tr.data = vif.mon_cb.r.data;
        read_tr.resp = vif.mon_cb.r.resp;
        read_tr.kind = READ_RESPONSE;
        
        read_ap.write(read_tr);
      end
      
      /* AW CHANNEL FOR WRITE REQUESTS*/
      if (vif.mon_cb.awready && vif.mon_cb.awvalid) begin
        write_tr = axi4l_write_item::type_id::create("write_address_tr");
        
        write_tr.addr = vif.mon_cb.aw.addr;
        write_tr.prot = vif.mon_cb.aw.prot;
        write_tr.kind = WRITE_ADDRESS;
        
        write_ap.write(write_tr);
      end
      
      /* W CHANNEL FOR WRITE DATA*/
      if (vif.mon_cb.wready && vif.mon_cb.wvalid) begin
        
        write_tr = axi4l_write_item::type_id::create("write_data_tr");
        
        write_tr.data = vif.mon_cb.w.data;
        write_tr.strb = vif.mon_cb.w.strb;
        write_tr.kind = WRITE_DATA;
        
        write_ap.write(write_tr);
      end
      
      /* B CHANNEL FOR WRITE RESPONSE */
      if (vif.mon_cb.bready && vif.mon_cb.bvalid) begin
        
        write_tr = axi4l_write_item::type_id::create("write_response_tr");
        
        write_tr.resp = vif.mon_cb.b.resp;
        write_tr.kind = WRITE_RESPONSE;
        
        write_ap.write(write_tr);
        
      end
      
    end
    
  endtask : run_phase
  
endclass : axi4l_monitor

/* flow:
monitor observes AXI signals
monitor builds read_tr
read_ap.write(read_tr) publishes it
connected scoreboard imp recieves it
UVM calls: write_upstream_read(read_tr);
*/