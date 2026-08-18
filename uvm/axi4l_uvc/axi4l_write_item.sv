import a4lite_pkg::*;
class axi4l_write_item extends uvm_sequence_item;
  
  typedef enum logic[1:0] {
    WRITE_ADDRESS,
    WRITE_DATA,
    WRITE_RESPONSE
  } axi4l_write_kind_e;
  axi4l_write_kind_e kind;
  
  function new(string name = "axi4l_write_item");
    super.new(name);
  endfunction
  
  /* AW */
  rand logic[ADDR_WIDTH - 1:0] addr;
  rand logic[PROT_WIDTH - 1:0] prot;
  /* W ()*/
  rand logic[DATA_WIDTH - 1:0] data; /* randomize data; manager is choosing what to send*/
  rand logic[STRB_WIDTH - 1:0] strb; /* should this be rand?*/
  /* B (response)*/
  axi_resp_e resp;
  
  rand int unsigned aw_delay; /* how many cycles to wait before manager asserts aw_valid*/
  rand int unsigned w_delay; /* how many cycles to wait before manager asserts w_valid*/
  rand int unsigned bready_delay; /* how many cycles to wait before manager asserts readiness to accept resopnse from sub*/
  /* subordinate-side control fields */
  rand int unsigned awready_delay; // cycles before subordinate asserts AWREADY
  rand int unsigned wready_delay; // cycles before subordinate asserts WREADY
  rand int unsigned bvalid_delay; // cycles before subordinate returns BVALID/response

  /* constraints */
  /* soft constraint for write strobe to prevent no active byte lanes*/
  constraint nonzero_strb_c {
    strb != '0;
  }
  /* delay constraints */
  constraint default_delay_c {
    aw_delay inside {[0:5]};
    w_delay inside {[0:5]};
    bready_delay inside {[0:5]};
    awready_delay inside {[0:5]};
    wready_delay inside {[0:5]};
    bvalid_delay inside {[0:5]};
  }

  /* FAULT CONTROL FIELDS */
  rand bit suppress_bvalid; 
  constraint normal_write_behvaiour_c{
    soft suppress_bvalid == 1'b0;
  }

  /* write-data timeout test (AW recieved, but no W)*/
  rand bit suppress_wvalid;
  constraint normal_aw_pass_c{
    soft suppress_wvalid == 1'b0;
  }

  /*
  Manager sequence role configuration.
  */
  function void configure_for_manager();
    awready_delay.rand_mode(0);
    wready_delay.rand_mode(0);
    bvalid_delay.rand_mode(0);
  endfunction : configure_for_manager

  /*
  Subordinate sequence role configuration.
  */
  function void configure_for_subordinate();
    addr.rand_mode(0);
    prot.rand_mode(0);
    data.rand_mode(0);
    strb.rand_mode(0);
    aw_delay.rand_mode(0);
    w_delay.rand_mode(0);
    bready_delay.rand_mode(0);
    nonzero_strb_c.constraint_mode(0);
    suppress_wvalid.rand_mode(0);
  endfunction : configure_for_subordinate

  /* UVM factory macros */
  `uvm_object_utils_begin(axi4l_write_item) /* UVM, this class exists and may be create dthrough the factory */
  /* packed logic vectors and integers*/
  `uvm_field_enum(axi4l_write_kind_e, kind, UVM_ALL_ON)
  `uvm_field_int(addr, UVM_ALL_ON)
  `uvm_field_int(prot, UVM_ALL_ON)
  `uvm_field_int(data, UVM_ALL_ON)
  `uvm_field_int(strb, UVM_ALL_ON)
  `uvm_field_int(aw_delay, UVM_ALL_ON)
  `uvm_field_int(w_delay, UVM_ALL_ON)
  `uvm_field_int(bready_delay, UVM_ALL_ON)
  `uvm_field_int(awready_delay, UVM_ALL_ON)
  `uvm_field_int(wready_delay, UVM_ALL_ON)
  `uvm_field_int(bvalid_delay, UVM_ALL_ON)
  /* fault control uvm registration*/
  `uvm_field_int(suppress_bvalid, UVM_ALL_ON)
  `uvm_field_int(suppress_wvalid, UVM_ALL_ON)
  /* enum field*/
  `uvm_field_enum(axi_resp_e, resp, UVM_ALL_ON)
  
  `uvm_object_utils_end

endclass : axi4l_write_item