/* NORM-05: verify supported address, protection, data, and strobe combinations */


/* manager read: force selected ARPROT while varying legal address */
class norm5_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(norm5_manager_read_seq)

  logic [PROT_WIDTH-1:0] prot_value;

  function new(string name = "norm5_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      prot == prot_value;
      addr inside {[SUB_ADDR_BASE:SUB_ADDR_END]};
      addr[1:0] == 2'b00;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-05 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : norm5_manager_read_seq


/* subordinate read: normal OKAY response */
class norm5_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(norm5_subordinate_read_seq)

  function new(string name = "norm5_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      resp == RESP_OKAY;
      suppress_rvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-05 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : norm5_subordinate_read_seq


/* manager write: force selected AWPROT/WSTRB while varying address/data */
class norm5_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(norm5_manager_write_seq)

  logic [PROT_WIDTH-1:0] prot_value;
  logic [STRB_WIDTH-1:0] strb_value;

  function new(string name = "norm5_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      prot == prot_value;
      strb == strb_value;
      addr inside {[SUB_ADDR_BASE:SUB_ADDR_END]};
      addr[1:0] == 2'b00;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-05 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : norm5_manager_write_seq


/* subordinate write: normal OKAY response */
class norm5_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(norm5_subordinate_write_seq)

  function new(string name = "norm5_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      resp == RESP_OKAY;
      suppress_bvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-05 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : norm5_subordinate_write_seq



class supported_fields_test_norm5 extends base_test;

  `uvm_component_utils(supported_fields_test_norm5)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  function new(string name = "supported_fields_test_norm5", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("NORM_05", "Starting supported field combination test", UVM_LOW)


    /* exercise all 8 legal ARPROT values */
    for (int prot_value = 0; prot_value < 8; prot_value++) begin

      norm5_manager_read_seq manager_read_seq;
      norm5_subordinate_read_seq subordinate_read_seq;

      manager_read_seq = norm5_manager_read_seq::type_id::create("manager_read_seq");
      subordinate_read_seq = norm5_subordinate_read_seq::type_id::create("subordinate_read_seq");

      manager_read_seq.prot_value = prot_value[PROT_WIDTH-1:0];

      fork
        manager_read_seq.start(upstream_read_sqr);
        subordinate_read_seq.start(downstream_read_sqr);
      join

    end


    /* exercise all 8 AWPROT x 15 legal nonzero WSTRB combinations */
    for (int prot_value = 0; prot_value < 8; prot_value++) begin
      for (int strb_value = 1; strb_value < 16; strb_value++) begin
        norm5_manager_write_seq manager_write_seq;
        norm5_subordinate_write_seq subordinate_write_seq;

        manager_write_seq = norm5_manager_write_seq::type_id::create("manager_write_seq");
        subordinate_write_seq = norm5_subordinate_write_seq::type_id::create("subordinate_write_seq");

        manager_write_seq.prot_value = prot_value[PROT_WIDTH-1:0];
        manager_write_seq.strb_value = strb_value[STRB_WIDTH-1:0];

        fork
          manager_write_seq.start(upstream_write_sqr);
          subordinate_write_seq.start(downstream_write_sqr);
        join

      end

    end

    `uvm_info("NORM_05", "Completed 8 reads and 120 write field combinations", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : supported_fields_test_norm5