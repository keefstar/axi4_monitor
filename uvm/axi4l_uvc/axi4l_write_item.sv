import a4lite_pkg::*;
class axi4l_write_item extends uvm_sequence_item;
  
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
  }
  
  /* UVM factory macros */
  `uvm_object_utils_begin(axi4l_write_item) /* UVM, this class exists and may be create dthrough the factory */
  /* packed logic vectors and integers*/
  `uvm_field_int(addr, UVM_ALL_ON)
  `uvm_field_int(prot, UVM_ALL_ON)
  `uvm_field_int(data, UVM_ALL_ON)
  `uvm_field_int(strb, UVM_ALL_ON)
  `uvm_field_int(aw_delay, UVM_ALL_ON)
  `uvm_field_int(w_delay, UVM_ALL_ON)
  `uvm_field_int(bready_delay, UVM_ALL_ON)
  /* enum field*/
  `uvm_field_enum(axi_resp_e, resp, UVM_ALL_ON)
  `uvm_object_utils_end
  
endclass : axi4l_write_item