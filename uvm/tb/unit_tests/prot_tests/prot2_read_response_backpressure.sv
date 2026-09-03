/*
 * PROT-02 verifies AXI4-Lite read-response stability under upstream
 * backpressure.
 * The downstream subordinate returns a normal read response promptly. The
 * upstream manager deliberately withholds RREADY for several cycles, forcing
 * the SCC to hold its upstream RVALID, RDATA, and RRESP stable until the
 * response handshake is permitted to complete.
 */


class prot2_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(prot2_manager_read_seq)

  function new(string name = "prot2_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);
    req.addr = 32'h4000_0910;
    req.prot = 3'b011;
    req.ar_delay = 0;
    /*
     * Deliberately withhold upstream RREADY after the SCC presents the
     * response.
     */
    req.rready_delay = 6;

  endfunction : randomize_req

endclass : prot2_manager_read_seq



class prot2_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(prot2_subordinate_read_seq)

  function new(string name = "prot2_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);
    req.arready_delay = 0;
    req.rvalid_delay = 2;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;
  endfunction : randomize_req

endclass : prot2_subordinate_read_seq



class prot2_read_response_backpressure_test extends base_test;

  `uvm_component_utils(prot2_read_response_backpressure_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  prot2_manager_read_seq manager_read_seq;
  prot2_subordinate_read_seq subordinate_read_seq;


  function new(string name = "prot2_read_response_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_read_seq = prot2_manager_read_seq::type_id::create("manager_read_seq");
    subordinate_read_seq = prot2_subordinate_read_seq::type_id::create("subordinate_read_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.clear_reg <= '0;

    `uvm_info("PROT_02", "Starting upstream read-response backpressure stability test", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    repeat (3) @(ctrl_vif.cb);

    `uvm_info("PROT_02", "Read response completed after sustained upstream R backpressure", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : prot2_read_response_backpressure_test