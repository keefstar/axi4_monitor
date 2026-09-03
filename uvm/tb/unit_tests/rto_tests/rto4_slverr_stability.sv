/* RTO-04: verify injected SLVERR remains valid until accepted by upstream manager */


/* manager delays RREADY beyond timeout to backpressure injected SLVERR */
class rto4_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rto4_manager_read_seq)

  function new(string name = "rto4_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    /* normal manager delay constraint only permits 0:5 cycles */
    req.manager_delay_c.constraint_mode(0);

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == TIMEOUT_COUNTER + 20;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-04 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : rto4_manager_read_seq


/* subordinate accepts AR but never returns RVALID */
class rto4_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rto4_subordinate_read_seq)

  function new(string name = "rto4_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      arready_delay == 0;
      suppress_rvalid == 1;
    }) begin
      `uvm_fatal(get_type_name(), "RTO-04 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : rto4_subordinate_read_seq


class rto4_slverr_stability_test extends base_test;

  `uvm_component_utils(rto4_slverr_stability_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rto4_manager_read_seq manager_read_seq;
  rto4_subordinate_read_seq subordinate_read_seq;

  function new(string name = "rto4_slverr_stability_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_read_seq = rto4_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = rto4_subordinate_read_seq::type_id::create("subordinate_read_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    /* timeout response must eventually be accepted as SLVERR */
    env.sb.set_expect_read_timeout(1'b1);

    `uvm_info("RTO_04", "Starting timeout with upstream RREADY backpressure", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    `uvm_info("RTO_04", "Injected SLVERR survived upstream backpressure and was accepted", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rto4_slverr_stability_test