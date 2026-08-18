class write_timeout_manager_seq extends axi4l_manager_write_seq;
  
  `uvm_object_utils(write_timeout_manager_seq)

  function new (string name = "write_resp_timeout_manager_seq");
    super.new(name);
  endfunction

  /* override parent randomize_req*/

  virtual function void randomize_req();
  if (!(req.randomize() with {
     /* this is a suboridnate driven test, so set all manager-side delays to 0 and known data/parameter values*/
    addr == 32'h0; /* AW should pass */
    prot == 3'b000;
    data == 32'hBABA_CACA;
    strb == 4'b1111;
    {aw_delay, w_delay, bready_delay} == '0;

  } )
  ) begin
    `uvm_fatal(get_type_name(), $sformatf("Write-response timeout manager item randomization failed"))
  end 

endfunction : randomize_req

endclass : write_timeout_manager_seq

class write_timeout_subordinate_seq extends axi4l_subordinate_write_seq;
   
  `uvm_object_utils(write_timeout_subordinate_seq)
  function new (string name = "write_resp_timeout_subordinate_seq");
    super.new(name);
  endfunction

  /* override parent randomize_req*/
  virtual function void randomize_req();
  if (!(req.randomize() with {
    {awready_delay, wready_delay, bvalid_delay} == '0;
    suppress_bvalid == 1'b1;
  } )
  ) begin
    `uvm_fatal(get_type_name(), $sformatf("Write-response timeout subordinate item randomization failed"))
  end 
  endfunction : randomize_req

endclass : write_timeout_subordinate_seq