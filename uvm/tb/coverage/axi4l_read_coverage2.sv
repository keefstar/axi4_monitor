class axi4l_read_protocol_coverage extends uvm_subscriber #(axi4l_read_item);

  `uvm_component_utils(axi4l_read_protocol_coverage)

  covergroup read_event_cg with function sample(
    axi4l_role_e role,
    axi4l_read_item::axi4l_read_kind_e kind,
    logic [ADDR_WIDTH-1:0] addr,
    logic [PROT_WIDTH-1:0] prot,
    axi_resp_e resp
  );

    option.per_instance = 1;

    //Which interface generated the transaction?
    /* Covers NORM-05; verify that read traffic is obtained on btoh manager and subordinate interfaces*/
    role_cp : coverpoint role {
      bins manager     = {AXI4L_MANAGER};
      bins subordinate = {AXI4L_SUBORDINATE};
    }

    //Was this a request or a response?
    /* Verify that both read requests and read responses are exercised.*/
    kind_cp : coverpoint kind {
      bins request  = {axi4l_read_item::READ_REQUEST};
      bins response = {axi4l_read_item::READ_RESPONSE};
    }

    //Exercise every ARPROT encoding; NORM-05
    prot_cp : coverpoint prot
      iff (kind == axi4l_read_item::READ_REQUEST)
    {
      bins values[] = {[3'b000:3'b111]};
    }

    //Exercise accesses both inside and outside the protected region; NORM-05
    addr_cp : coverpoint addr
      iff (kind == axi4l_read_item::READ_REQUEST)
    {
      bins subordinate_region =
        {[SUB_ADDR_BASE:SUB_ADDR_END]};

      bins other_region = default;
    }

    //Observe both successful and error read responses; NORM-05
    resp_cp : coverpoint resp
      iff (kind == axi4l_read_item::READ_RESPONSE)
    {
      bins okay   = {RESP_OKAY};
      bins slverr = {RESP_SLVERR};
    }

    //Exercise request and response traffic on both interfaces; NORM-05
    role_kind_cross :
      cross role_cp, kind_cp;

    //Exercise every PROT value on both interfaces; NORM-05
    role_prot_cross :
      cross role_cp, prot_cp;

    //Exercise both OKAY and SLVERR responses on both interfaces; NORM-05
    role_resp_cross :
      cross role_cp, resp_cp;

  endgroup

  function new( string name = "axi4l_read_coverage", uvm_component parent = null);
    super.new(name, parent);
    read_event_cg = new();
  endfunction

  virtual function void write(axi4l_read_item t);
    read_event_cg.sample(t.role, t.kind, t.addr, t.prot, t.resp);
  endfunction

endclass : axi4l_read_protocol_coverage

class axi4l_read_coverage extends uvm_subscriber#(axi4l_read_item);
/* A subscriber is a UVM component designed to receive transactions from another component, usually a monitor.*/

  `uvm_component_utils(axi4l_read_coverage)



  covergroup read_event_cg with function sample (
    axi4l_role_e role,
    axi4l_read_item::axi4l_read_kind_e kind,
    logic [ADDR_WIDTH-1 : 0] addr,
    logic [PROT_WIDTH-1: 0] prot,
    axi_resp_e resp
  );

   option.per_instance = 1;
    /* coverpoint: one specific thing to observe -- one question*/
  //role_cp: coverpoint side; /* side variable could be AXI_SIDE_UPSTREAM or AXI_SIDE_DOWNSTREAM; coverpoint is tracking whether activity was seen on each side of the controller
    role_cp: coverpoint role {
      /* bin = one checkbox: a bin is one speicifc value or group of valeus you want to count*/
      /* two checkboxes; []upstream event observed, []downstream event observed*/
      /* when both bins are hit, coverage for this coverpoint is 100%*/
      bins manager   = {AXI4L_MANAGER};
      bins subordinate = {AXI4L_SUBORDINATE};
    }
    kind_cp: coverpoint kind {
          bins request  = {axi4l_read_item::READ_REQUEST};
          bins response = {axi4l_read_item::READ_RESPONSE};
      }
    prot_cp : coverpoint prot 
      iff (kind == axi4l_read_item::READ_REQUEST)
      {
        bins values[] = {[3'b000:3'b111]};
      }
    resp_cp : coverpoint resp 
      iff (kind == axi4l_read_item::READ_RESPONSE){
        bins okay = {RESP_OKAY};
        bins slverr = {RESP_SLVERR};  
      }
    

    /* a cross = combination of checkboxes*/

    /* creates 'cross product'; 4 total combinations (ups req, resp; dst req, rsp)*/
    role_kind_cross:
      cross role_cp, kind_cp;

  endgroup : read_event_cg

  /* declare actual instance of covergroup*/


  /* e axi4l_read_coverage is a UVM component, its parent constructor requires both name and parent*/
  function new (string name = "axi4l_read_coverage", uvm_component parent = null);
    super.new(name, parent);
    /* constructor covergroup instance*/
    read_event_cg = new();
  endfunction : new

  /*
   * UVM calls this function whenever the connected monitor publishes
   * an axi4l_read_t.
   */
  virtual function void write(axi4l_read_item t);

    read_event_cg.sample(
      t.role,
      t.kind,
      t.addr,
      t.prot,
      t.resp
    );

    `uvm_info(
      "READ_COVERAGE",
      $sformatf(
        "Sampled role=%s kind=%s addr=0x%0h prot=%03b resp=%s",
        t.role.name(),
        t.kind.name(),
        t.addr,
        t.prot,
        t.resp.name()
      ),
      UVM_MEDIUM
    )

  endfunction


endclass : axi4l_read_coverage