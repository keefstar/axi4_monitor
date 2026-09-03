/*
 * PROT-03 verifies AXI4-Lite downstream write-address stability under
 * backpressure.
 *
 * The upstream manager supplies both AW and W immediately. Under the SCC's
 * PR-01 policy, the corresponding downstream AW and W channels are launched
 * together once the complete pair is available.
 *
 * The downstream subordinate accepts W promptly but deliberately withholds
 * AWREADY for several cycles. The SCC must retain AWVALID, AWADDR, and AWPROT
 * unchanged until the delayed AW handshake completes.
 */


class prot3_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(prot3_manager_write_seq)

  function new(string name = "prot3_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0920;
    req.prot = 3'b100;
    req.data = 32'hA5A5_3C3C;
    req.strb = 4'b1111;
    req.aw_delay = 0;
    req.w_delay  = 0;
    req.bready_delay = 0;
    req.suppress_wvalid = 0;

  endfunction : randomize_req

endclass : prot3_manager_write_seq



class prot3_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(prot3_subordinate_write_seq)

  function new(string name = "prot3_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    /*
     * Accept W immediately but stall the independently completing AW channel.
     */
    req.awready_delay  = 6;
    req.wready_delay = 0;
    req.bvalid_delay = 2;
    req.suppress_bvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : prot3_subordinate_write_seq



class prot3_write_address_backpressure_test extends base_test;

  `uvm_component_utils(prot3_write_address_backpressure_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  prot3_manager_write_seq manager_write_seq;
  prot3_subordinate_write_seq subordinate_write_seq;


  function new(string name = "prot3_write_address_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq = prot3_manager_write_seq::type_id::create("manager_write_seq");
    subordinate_write_seq = prot3_subordinate_write_seq::type_id::create("subordinate_write_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr   = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.clear_reg <= '0;

    `uvm_info("PROT_03", "Starting downstream write-address backpressure stability test", UVM_LOW)

    fork
      manager_write_seq.start(upstream_write_sqr);
      subordinate_write_seq.start(downstream_write_sqr);
    join

    repeat (3) @(ctrl_vif.cb);

    `uvm_info("PROT_03", "Write completed after sustained downstream AW backpressure", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : prot3_write_address_backpressure_test