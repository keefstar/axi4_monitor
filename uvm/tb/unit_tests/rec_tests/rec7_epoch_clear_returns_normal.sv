/*
 * REC-07 verifies completion of the recovery state-machine sequence.
 *
 * A read timeout first drives the controller through containment and into
 * GUARD_RECOVERY. Once the failed transaction has become quiescent, software
 * acknowledges READ_TIMEOUT. The resulting authorized epoch_clr must terminate
 * recovery and return the controller to GUARD_NORMAL with flush deasserted.
 */


class rec7_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rec7_manager_read_seq)

  function new(string name = "rec7_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_08C0;
    req.prot = 3'b000;
    req.ar_delay  = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : rec7_manager_read_seq



class rec7_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rec7_subordinate_read_seq)

  function new(string name = "rec7_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay  = TIMEOUT_COUNTER + 20;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : rec7_subordinate_read_seq



class rec7_epoch_clear_returns_normal_test extends base_test;

  `uvm_component_utils(rec7_epoch_clear_returns_normal_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rec7_manager_read_seq manager_read_seq;
  rec7_subordinate_read_seq subordinate_read_seq;


  function new(string name = "rec7_epoch_clear_returns_normal_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_read_seq = rec7_manager_read_seq::type_id::create("manager_read_seq");
    subordinate_read_seq = rec7_subordinate_read_seq::type_id::create("subordinate_read_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.enable_reg[READ_TIMEOUT] <= 1'b1;
    ctrl_vif.cb.clear_reg <= '0;

    env.sb.set_expect_read_timeout(1'b1);
    env.sb.set_expect_late_read_response(1'b1);

    `uvm_info("REC_07", "Starting recovery-to-normal transition test", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    /*
     * Wait until the read fault has actually occurred.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.status_reg[READ_TIMEOUT] !== 1'b1);

    /*
     * Wait for containment and stale downstream traffic to finish. By this
     * point the top-level controller has reached GUARD_RECOVERY.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2) @(ctrl_vif.cb);

    /*
     * Issue the valid recovery acknowledgment. REC-06 already verifies the
     * authorization of epoch_clr; REC-07 verifies the resulting state change.
     */
    ctrl_vif.cb.clear_reg <= '0;
    ctrl_vif.cb.clear_reg[READ_TIMEOUT] <= 1'b1;
    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <= '0;

    /*
     * Allow rcvy_ack, epoch_clr, and the subsequent FSM state update to occur.
     */
    repeat (4) @(ctrl_vif.cb);

    if (ctrl_vif.cb.status_reg[READ_TIMEOUT] !== 1'b0)
      `uvm_error("REC_07_STATUS", "READ_TIMEOUT status remained set after completed recovery")

    if (ctrl_vif.cb.irq !== 1'b0)
      `uvm_error("REC_07_IRQ", "IRQ remained asserted after completed recovery")

    `uvm_info("REC_07", "Authorized epoch clear completed recovery and returned the guard to normal operation", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rec7_epoch_clear_returns_normal_test