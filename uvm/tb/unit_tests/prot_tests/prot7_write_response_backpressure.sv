/*
 * PROT-07 verifies AXI4-Lite upstream write-response stability under
 * backpressure.
 *
 * The downstream write is allowed to complete normally and produce RESP_OKAY.
 * The upstream manager deliberately withholds BREADY for several cycles after
 * the SCC presents BVALID.
 *
 * The SCC must retain BVALID and BRESP unchanged until the manager accepts the
 * response.
 */


class prot7_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(prot7_manager_write_seq)

  function new(string name = "prot7_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0960;
    req.prot = 3'b001;
    req.data = 32'h1357_9BDF;
    req.strb = 4'b1111;
    req.aw_delay = 0;
    req.w_delay = 0;

    /*
     * Deliberately delay acceptance of the upstream write response.
     */
    req.bready_delay = 6;
    req.suppress_wvalid = 0;

  endfunction : randomize_req

endclass : prot7_manager_write_seq



class prot7_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(prot7_subordinate_write_seq)

  function new(string name = "prot7_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay = 0;
    req.wready_delay = 0;
    req.bvalid_delay = 2;
    req.suppress_bvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : prot7_subordinate_write_seq



class prot7_write_response_backpressure_test extends base_test;

  `uvm_component_utils(prot7_write_response_backpressure_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  prot7_manager_write_seq manager_write_seq;
  prot7_subordinate_write_seq subordinate_write_seq;


  function new(string name = "prot7_write_response_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq = prot7_manager_write_seq::type_id::create("manager_write_seq");
    subordinate_write_seq = prot7_subordinate_write_seq::type_id::create("subordinate_write_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.clear_reg <= '0;

    `uvm_info("PROT_07", "Starting upstream write-response backpressure stability test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    repeat (3) @(ctrl_vif.cb);

    `uvm_info("PROT_07", "Write response completed after sustained upstream B backpressure", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : prot7_write_response_backpressure_test