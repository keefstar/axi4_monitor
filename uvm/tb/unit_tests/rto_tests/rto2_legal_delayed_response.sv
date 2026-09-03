/* RTO-02: verify legally delayed downstream read response does not cause false timeout */


/* manager issues normal read and accepts response immediately */
class rto2_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rto2_manager_read_seq)

  function new(string name = "rto2_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-02 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : rto2_manager_read_seq


/* subordinate delays RVALID but still responds well before timeout */
class rto2_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rto2_subordinate_read_seq)

  function new(string name = "rto2_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    /* normal delay constraint only permits 0:5 cycles */
    req.subordinate_delay_c.constraint_mode(0);

    if (!req.randomize() with {
      arready_delay == 0;
      rvalid_delay == 20;
      suppress_rvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-02 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : rto2_subordinate_read_seq


class rto2_legal_delayed_response_test extends base_test;

  `uvm_component_utils(rto2_legal_delayed_response_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rto2_manager_read_seq manager_read_seq;
  rto2_subordinate_read_seq subordinate_read_seq;

  function new(string name = "rto2_legal_delayed_response_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = rto2_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = rto2_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("RTO_02", "Starting legally delayed downstream read response", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    `uvm_info("RTO_02", "Delayed read response completed without false timeout", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rto2_legal_delayed_response_test