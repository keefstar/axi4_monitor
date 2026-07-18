class axi4l_write_sequencer extends uvm_sequencer#(axi4l_write_item)
  
  /* comically low verillof because UVM already impleemnts most of its machinery*/
  /* this file basically says that it wants a standard UVM seqeuncer that handles axi4l_read_items*/
  `uvm_component_utils(axi4l_write_sequencer) /* component macro*/
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  /* note: by default, a sequener does not generate stimulus; the sequence generates transactions*/
  
endclass