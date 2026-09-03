/* NORM-02: verify fault-free write forwarding end-to-end */

class normal_write_test_norm2 extends base_test;

  `uvm_component_utils(normal_write_test_norm2)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  axi4l_manager_write_seq manager_write_seq;
  axi4l_subordinate_write_seq subordinate_write_seq;

  function new(string name = "normal_write_test_norm2", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = axi4l_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = axi4l_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase

  /* generate one fault-free write transaction */
  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("NORM_02", "Starting fault-free write transaction", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    phase.drop_objection(this);

  endtask : run_phase

endclass : normal_write_test_norm2