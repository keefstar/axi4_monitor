/* NORM-06: verify concurrent fault-free read and write transactions complete correctly */

class norm6_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(norm6_manager_read_seq)

  function new(string name = "norm6_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      addr == 32'h0000_0100;
      prot == 3'b000;
      ar_delay == 1;
      rready_delay == 1;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-06 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : norm6_manager_read_seq


class norm6_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(norm6_manager_write_seq)

  function new(string name = "norm6_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      addr == 32'h0000_0200;
      prot == 3'b000;
      data == 32'hA5A5_1234;
      strb == 4'b1111;
      aw_delay == 1;
      w_delay == 1;
      bready_delay == 1;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-06 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : norm6_manager_write_seq


class concurrent_read_write_test_norm6 extends base_test;

  `uvm_component_utils(concurrent_read_write_test_norm6)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  norm6_manager_read_seq manager_read_seq;
  axi4l_subordinate_read_seq subordinate_read_seq;

  norm6_manager_write_seq manager_write_seq;
  axi4l_subordinate_write_seq subordinate_write_seq;

  function new(string name = "concurrent_read_write_test_norm6", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_read_seq = norm6_manager_read_seq::type_id::create("manager_read_seq");
    subordinate_read_seq = axi4l_subordinate_read_seq::type_id::create("subordinate_read_seq");

    manager_write_seq = norm6_manager_write_seq::type_id::create("manager_write_seq");
    subordinate_write_seq = axi4l_subordinate_write_seq::type_id::create("subordinate_write_seq");

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("NORM_06", "Starting concurrent fault-free read and write transactions", UVM_LOW)

    /*
    Read uses address 0x00000100, which maps to word 64 in the 1 KB subordinate memory.
    Because the memory is initialized to zero, the expected read data is 0x00000000.
    Write uses address 0x00000200 with data 0xA5A51234 and all byte strobes enabled.
    */

    fork

      begin
        fork
          manager_read_seq.start(upstream_read_sqr);
          subordinate_read_seq.start(downstream_read_sqr);
        join
      end

      begin
        fork
          manager_write_seq.start(upstream_write_sqr);
          subordinate_write_seq.start(downstream_write_sqr);
        join
      end

    join

    `uvm_info("NORM_06", "Concurrent fault-free read and write transactions completed", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : concurrent_read_write_test_norm6