/*
 * PROT-01 verifies AXI4-Lite read-address stability under downstream
 * backpressure.
 * The manager presents a normal read request immediately. The subordinate
 * deliberately withholds ARREADY for several cycles, forcing the SCC to hold
 * its downstream ARVALID and corresponding ARADDR/ARPROT payload stable.
 *
 * Once ARREADY is asserted, the transaction completes normally with RESP_OKAY.
 */


class prot1_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(prot1_manager_read_seq)

  function new(string name = "prot1_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0900;
    req.prot = 3'b010;
    req.ar_delay  = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : prot1_manager_read_seq



class prot1_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(prot1_subordinate_read_seq)

  function new(string name = "prot1_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    /*
     * Deliberately withhold ARREADY long enough to create a sustained
     * downstream address-channel stall.
     */
    req.arready_delay = 6;
    req.rvalid_delay = 2;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : prot1_subordinate_read_seq



class prot1_read_address_backpressure_test extends base_test;

  `uvm_component_utils(prot1_read_address_backpressure_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  prot1_manager_read_seq manager_read_seq;
  prot1_subordinate_read_seq subordinate_read_seq;


  function new(string name = "prot1_read_address_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_read_seq = prot1_manager_read_seq::type_id::create("manager_read_seq");
    subordinate_read_seq = prot1_subordinate_read_seq::type_id::create("subordinate_read_seq");

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

    `uvm_info("PROT_01", "Starting downstream read-address backpressure stability test", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    repeat (3) @(ctrl_vif.cb);

    `uvm_info("PROT_01", "Read completed after sustained downstream AR backpressure", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : prot1_read_address_backpressure_test