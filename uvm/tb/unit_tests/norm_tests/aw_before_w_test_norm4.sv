/* NORM-04: verify supported AW-before-W transaction under write-admission policy */


/* manager sends AW first, then W several cycles later */
class norm4_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(norm4_manager_write_seq)

  function new(string name = "norm4_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      aw_delay == 0;
      w_delay == 5;
      bready_delay == 0;
      suppress_wvalid == 0;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-04 manager write randomization failed")
    end

  endfunction : randomize_req

endclass : norm4_manager_write_seq


/* subordinate responds immediately once downstream AW/W are presented */
class norm4_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(norm4_subordinate_write_seq)

  function new(string name = "norm4_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      awready_delay == 0;
      wready_delay == 0;
      bvalid_delay == 0;
      suppress_bvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "NORM-04 subordinate write randomization failed")
    end

  endfunction : randomize_req

endclass : norm4_subordinate_write_seq



class aw_before_w_test_norm4 extends base_test;

  `uvm_component_utils(aw_before_w_test_norm4)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  norm4_manager_write_seq manager_write_seq;
  norm4_subordinate_write_seq subordinate_write_seq;

  function new(string name = "aw_before_w_test_norm4", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    manager_write_seq = norm4_manager_write_seq::type_id::create("manager_write_seq", this);
    subordinate_write_seq = norm4_subordinate_write_seq::type_id::create("subordinate_write_seq", this);

    super.build_phase(phase);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);

    `uvm_info("NORM_04", "Starting supported AW-before-W write transaction", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    phase.drop_objection(this);

  endtask : run_phase

endclass : aw_before_w_test_norm4