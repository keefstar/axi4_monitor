class write_data_timeout_manager_seq
  extends axi4l_manager_write_seq;

  `uvm_object_utils(write_data_timeout_manager_seq)

  function new(
    string name = "write_data_timeout_manager_seq"
  );
    super.new(name);
  endfunction : new

  virtual function void randomize_req();

    if (!(req.randomize() with {
      addr            == 32'h0000_0000;
      prot            == 3'b000;
      aw_delay        == 0;
      suppress_wvalid == 1'b1;
    })) begin
      `uvm_fatal(
        get_type_name(),
        "Write-data-timeout manager randomization failed"
      )
    end

  endfunction : randomize_req

endclass : write_data_timeout_manager_seq

/* no sub sequence required*/
/* the Maguard holds the AW and does not forward anything downstream until W exists. Therefore the downstream subordinate should remain completely idle.*/