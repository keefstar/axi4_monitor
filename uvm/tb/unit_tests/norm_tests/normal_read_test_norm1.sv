/* NORM-01: verify fault-free read forwarding end-to-end */

class normal_read_test_norm1 extends base_test;

  `uvm_component_utils(normal_read_test_norm1)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  axi4l_manager_read_seq manager_read_seq;
  axi4l_subordinate_read_seq subordinate_read_seq;

  function new(string name = "normal_read_test_norm1", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = axi4l_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = axi4l_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  /* generate one fault-free read transaction */
  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("NORM_01", "Starting fault-free read transaction", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    phase.drop_objection(this);

  endtask : run_phase

endclass : normal_read_test_norm1