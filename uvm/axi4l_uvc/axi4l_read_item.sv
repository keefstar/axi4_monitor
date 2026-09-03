

import a4lite_pkg::*;
/* read request transaction */
class axi4l_read_item extends uvm_sequence_item; /*inherit from uvm_sequence_item */
  /* That includes the UVM object infrastructure needed for sequences, drivers, printing, comparison, factory use, and so on. */
  
  /* a single read_ap carries both kinds of read events (AR handshake = read req, R handshale = read resp)*/
  /* scoreboard needs to know: is this an AR request, or an R response*/
  typedef enum logic {
    READ_REQUEST,
    READ_RESPONSE
  } axi4l_read_kind_e;
  axi4l_read_kind_e kind = READ_REQUEST;

  /* * Identifies which configured AXI agent observed this event. * AXI4L_MANAGER corresponds to the upstream agent. * AXI4L_SUBORDINATE corresponds to the downstream agent. */
  axi4l_role_e role;
  
  /* super specific syntax*/
  function new(string name = "axi4l_read_item"); /* gives object a default name */
    super.new(name); /* calls constructor of the parent class, uvm_sequence_item*/
  endfunction
  
  /* Physical fields; correspond to actual AXI interface signals; driver eventually maps to ARADDR, ADRPROT etc */
  /* request side fields*/
  rand logic[ADDR_WIDTH - 1:0] addr;
  rand logic[PROT_WIDTH - 1:0] prot;
  /* response side fields*/
  logic[DATA_WIDTH - 1:0] data;
  rand axi_resp_e resp;
  
  /* control fields; not part of AXI payload itself but for driver to understand how to execute the operation*/
  //rand write_order_e write_order;
  rand int unsigned ar_delay; /* cycles to wait before asserting ARVALID */
  rand int unsigned rready_delay; /* cycles to wait before asserting RREADY*/
  /* subordinate-side control fields */
  rand int unsigned arready_delay; // cycles before subordinate asserts ARREADY
  rand int unsigned rvalid_delay; // cycles before subordinate returns RVALID/response

  /* FAULT CONTROL FIELD */
  rand bit suppress_rvalid; /* when set, the downtream sub accepts AR but intentionally never returns BVALID*/
  /* this should help create read-response timeout*/
  /* use soft so that ordinary test gets 0, but a timeout sequence can override it*/
  constraint normal_read_behavior_c {
  soft suppress_rvalid == 1'b0;
}

  constraint legal_read_resp_c {
  resp inside {RESP_OKAY, RESP_SLVERR, RESP_DECERR};
}

constraint default_read_resp_c {
  soft resp == RESP_OKAY;
}

  /* default constraints: make the default transaction legal and typical*/
  constraint aligned_addr_c {
    /* for 32-bit word access, this makes default addresses word-aligned*/
    addr[1:0] == 2'b00;
  }
  /* prot legality enforcement; SCC does not touch but rule enforced regardless*/
  constraint legal_prot_c {
    prot inside {[3'b000:3'b111]};
  }
  constraint manager_delay_c {
  ar_delay inside {[0:5]};
  rready_delay inside {[0:5]};
  }

  constraint subordinate_delay_c {
    arready_delay inside {[0:5]};
    rvalid_delay inside {[0:5]};
  }


  /*
  Manager sequence role configuration.
  */

  function void configure_for_manager();

    /* manager does not generate subordinate-side timing */
    arready_delay.rand_mode(0);
    rvalid_delay.rand_mode(0);
    subordinate_delay_c.constraint_mode(0);

    /* manager observes RRESP; does not generate it */
    resp = RESP_OKAY;
    resp.rand_mode(0);
    legal_read_resp_c.constraint_mode(0);
    default_read_resp_c.constraint_mode(0);

    /* manager does not control subordinate response suppression */
    suppress_rvalid.rand_mode(0);
    normal_read_behavior_c.constraint_mode(0);

  endfunction : configure_for_manager
  /*

  Subordinate sequence role configuration.

  */
function void configure_for_subordinate();

  /* subordinate observes request fields; does not generate them */
  addr.rand_mode(0);
  prot.rand_mode(0);
  ar_delay.rand_mode(0);
  rready_delay.rand_mode(0);

  aligned_addr_c.constraint_mode(0);
  legal_prot_c.constraint_mode(0);
  manager_delay_c.constraint_mode(0);

endfunction : configure_for_subordinate

  /* a transactino bject needs operations such as randomize/print/compare/copy/pack/record into transactionw aveforms */
  /* sys verilof provides req.randomize() but ordinary sysverilog deos not know how you want a cusotm class printed/copied/etc*/
  /* for read transctions, UVM shuold eventually be able to do req.print, expected.compare, copy_req.copy etc */
  
  /* UTILITY MACRO BLOCK TO ENABLE AUTOMATION*/
  /* our own class inherits methods from UVM for print copy etc but those methods do not automatically know what fields are inside custom clas either*/
  /* UVM knows that ai4l_read_item is an obect, but it does not inehrenty know that the object contains addr, prot etc*/
  /* the field macros tell inherited UVM methods: those are fields you should process, and this is each field's type*/
  `uvm_object_utils_begin(axi4l_read_item) /* UVM, this class exists and may be create dthrough the factory */
  /* packed logic vectors and integers*/
  `uvm_field_int(addr, UVM_ALL_ON)
  `uvm_field_enum(axi4l_read_kind_e, kind, UVM_ALL_ON)
  `uvm_field_int(prot, UVM_ALL_ON)
  `uvm_field_int(data, UVM_ALL_ON)
  `uvm_field_int(ar_delay, UVM_ALL_ON)
  `uvm_field_int(rready_delay, UVM_ALL_ON)
  `uvm_field_int(arready_delay, UVM_ALL_ON)
  `uvm_field_int(rvalid_delay, UVM_ALL_ON)
  `uvm_field_int(suppress_rvalid, UVM_ALL_ON)
  
  /* enum field*/
  `uvm_field_enum(axi_resp_e, resp, UVM_ALL_ON)
  `uvm_field_enum(axi4l_role_e, role, UVM_ALL_ON)
  
  
  `uvm_object_utils_end
  
endclass : axi4l_read_item
