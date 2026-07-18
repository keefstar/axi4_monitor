



/*
1) Model the basic unit of activity:

For my DUT, the basic units are AXI4-Lite operations:

Read operation: address, protection attributes, returned data, returned code
Similarly; write operation: address, protection attributes, write data, byte strobes, response code
So instead of thinking of *individiual signals*, think axi_read_item, axi_write item.
These become the main data objects passed around your UVM environment.

2) Generate transactions randomly or specify them directly
Random generation: assert(req.randomize()); - this produces a legal random transaction using default constraints
constraint aligned_c {
    addr[1:0] == 2'b00;
}

Direct specification:
For targetted test, we may want exact addr:
req.addr = 32'h0000_1000;
req.prot = 3'b000;
assert(req.randomize() with {
    addr == 32'h0000_1000;
});

3) Sequence level control:
The transaction object describes ONE operation.
The sequence ocntrols a SERIES of operations and their ordering.
So, for or project the equivalent could be:
Send five normal AXI reads.
Then issue one read whose subordinate never responds.
Wait for the guard to inject SLVERR.
Then issue three more reads and verify recovery.

OR:
Send five normal AXI reads.
Then issue one read whose subordinate never responds.
Wait for the guard to inject SLVERR.
Then issue three more reads and verify recovery.

repeat (5)
    send_normal_read();

send_timeout_read();

repeat (3)
    send_normal_read();


4) oursequence should not need to manually control AXI signals like
arvalid, arready, rvalid, rready etc

The sequence should say:
req.addr = 32'h1000;
start_item(req);
finish_item(req);

The DRIVER handles the actual protocol:
1. Drive ARADDR
2. Assert ARVALID
3. Wait for ARREADY
4. Deassert ARVALID
5. Handle or coordinate response behaviour as appropriate

This separation matters because your tests should express intent, not pin toggling.

Bad abstraction:
vif.arvalid <= 1;
wait(vif.arready);
vif.arvalid <= 0;

Better:
vif.arvalid <= 1;
wait(vif.arready);
vif.arvalid <= 0;

5) data vsiauzliation trhoguh automation
When debugging, you want UVM to print something meaningful:
AXI_READ_ITEM
    addr              0x00001000
    prot              0
    data              0xA5A5A5A5
    resp              RESP_OKAY
    timed_out         0
    response_latency  4

Two differnt types of fields
1) Physical fields: actual interface info like (addr, prot, data, strb, resp)
2) Control fields: affect hwo testbench behaves but not necessarilY AXI signaks: resopnse delay, cuase itmeout, apply backpressure etc



UVM MACRO FACTORY:
logic / bit / int / packed vector
    -> `uvm_field_int

enum
    -> `uvm_field_enum

string
    -> `uvm_field_string

object handle
    -> `uvm_field_object

dynamic array of integral values
    -> `uvm_field_array_int

queue of integral values
    -> `uvm_field_queue_int

*/

import firewall_pkg::*;
/* read request transaction */
class axi4l_read_item extends uvm_sequence_item; /*inherit from uvm_sequence_item */
  /* That includes the UVM object infrastructure needed for sequences, drivers, printing, comparison, factory use, and so on. */
  
  /* super specific syntax*/
  function new(string name = "axi4l_read_item"); /* gives object a default name */
    super.new(name); /* calls constructor of the parent class, uvm_sequence_item*/
  endfunction
  
  /* Physical fields; correspond to actual AXI interface signals; driver eventually maps to ARADDR, ADRPROT etc */
  rand logic[ADDR_WIDTH - 1:0] addr;
  rand logic[PROT_WIDTH - 1:0] prot;
  rand logic[DATA_WIDTH - 1:0] data;
  axi_resp_e resp;
  
  /* control fields; not part of AXI payload itself but for driver to understand how to execute the operation*/
  //rand write_order_e write_order;
  rand int unsigned ar_delay; /* cycles to wait before asserting ARVALID */
  rand int unsigned rready_delay; /* cycles to wait before asserting RREADY*/
  
  /* default constraints: make the default transaction legal and typical*/
  constraint alligned_addr_c {
    /* for 32-bit word access, this makes default addresses word-aligned*/
    addr[1:0] == 2'b00;
  }
  /* prot legality enforcement; SCC does not touch but rule enforced regardless*/
  constraint legal_prot_c {
    prot inside {[3'b000:3'b111]};
  }
  constraint default_delay_c {
    ar_delay inside {[0:5]};
    rready_delay inside {[0:5]};
  }
  
  /* a transactino bject needs operations such as randomize/print/compare/copy/pack/record into transactionw aveforms */
  /* sys verilof provides req.randomize() but ordinary sysverilog deos not know how you want a cusotm class printed/copied/etc*/
  /* for read transctions, UVM shuold eventually be able to do req.print, expected.compare, copy_req.copy etc */
  
  /* UTILITY MACRO BLOCK TO ENABLE AUTOMATION*/
  /* our own class inherits methods from UVM for print copy etc but those methods do not automatically know what fields are inside custom clas either*/
  /* UVM knows that ai4l_read_item is an obect, but it does not inehrenty know that the object contains addr, prot etc*/
  /* the field macros tell inherited UVM methods: those are fields you should process, and this is each field's type*/
  `uvm_object_utils_begins(axi4l_read_item) /* UVM, this class exists and may be create dthrough the factory */
  /* packed logic vectors and integers*/
  `uvm_field_int(addr, UVM_ALL_ON)
  `uvm_field_int(prot, UVM_ALL_ON)
  `uvm_field_int(data, UVM_ALL_ON)
  `uvm_field_int(ar_delay, UVM_ALL_ON)
  `uvm_field_int(rready_delay, UVM_ALL_ON)
  /* enum field*/
  `uvm_field_enum(axi_resp_e, resp, UVM_ALL_ON)
  `uvm_object_utils_end
  
endclass : axi4l_read_item

/* subclasses for speciifc testing plans */
class axi4l_mapped_region_read extends axi4l_read_item;
  constraint mapped_region_c {
    addr inside {[ADDR_MIN:ADDR_MAX]};
  }
endclass



/* note for subclass layering constriants; if we have a constriant in sub class with same name as in parent class, it will override parent constriant */