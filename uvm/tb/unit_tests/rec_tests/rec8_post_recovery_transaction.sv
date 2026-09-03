/*
 * REC-08 verifies end-to-end usability after recovery.
 *
 * The first read is deliberately stalled beyond TIMEOUT_COUNTER and causes a
 * READ_TIMEOUT. The guard contains the failed transaction, drains the delayed
 * downstream response, enters recovery, and receives a valid software
 * acknowledgment.
 *
 * After epoch_clr returns the controller to GUARD_NORMAL, a second independent
 * read is issued. That new transaction must be forwarded normally and complete
 * with the subordinate's RESP_OKAY response, demonstrating that stale traffic
 * from the failed epoch cannot contaminate subsequent operation.
 */


class rec8_fault_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rec8_fault_manager_read_seq)

  function new(string name = "rec8_fault_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_08D0;
    req.prot = 3'b000;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : rec8_fault_manager_read_seq



class rec8_fault_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rec8_fault_subordinate_read_seq)

  function new(string name = "rec8_fault_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = TIMEOUT_COUNTER + 20;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : rec8_fault_subordinate_read_seq



class rec8_fresh_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rec8_fresh_manager_read_seq)

  function new(string name = "rec8_fresh_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_08E0;
    req.prot = 3'b001;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : rec8_fresh_manager_read_seq



class rec8_fresh_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rec8_fresh_subordinate_read_seq)

  function new(string name = "rec8_fresh_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay   = 0;
    req.rvalid_delay    = 2;
    req.suppress_rvalid = 0;
    req.resp            = RESP_OKAY;

  endfunction : randomize_req

endclass : rec8_fresh_subordinate_read_seq



class rec8_post_recovery_transaction_test extends base_test;

  `uvm_component_utils(rec8_post_recovery_transaction_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rec8_fault_manager_read_seq fault_manager_read_seq;
  rec8_fault_subordinate_read_seq fault_subordinate_read_seq;

  rec8_fresh_manager_read_seq fresh_manager_read_seq;
  rec8_fresh_subordinate_read_seq fresh_subordinate_read_seq;


  function new(string name = "rec8_post_recovery_transaction_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    fault_manager_read_seq = rec8_fault_manager_read_seq::type_id::create("fault_manager_read_seq");
    fault_subordinate_read_seq = rec8_fault_subordinate_read_seq::type_id::create("fault_subordinate_read_seq");

    fresh_manager_read_seq = rec8_fresh_manager_read_seq::type_id::create("fresh_manager_read_seq");
    fresh_subordinate_read_seq = rec8_fresh_subordinate_read_seq::type_id::create("fresh_subordinate_read_seq");

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

    /*
     * Only the first read belongs to the failed epoch.
     */
    env.sb.set_expect_read_timeout(1'b1);
    env.sb.set_expect_late_read_response(1'b1);

    `uvm_info("REC_08", "Starting failed-epoch recovery followed by fresh transaction", UVM_LOW)

    /*
     * First transaction: deliberately fault.
     */
    fork
      fault_manager_read_seq.start(upstream_read_sqr);
      fault_subordinate_read_seq.start(downstream_read_sqr);
    join

    /*
     * Wait for the timeout to be recorded.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.status_reg[READ_TIMEOUT] !== 1'b1);

    /*
     * Wait for the failed transaction and its late downstream response to be
     * completely contained and drained.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2) @(ctrl_vif.cb);

    /*
     * Valid software acknowledgment terminates the failed epoch.
     */
    ctrl_vif.cb.clear_reg <= '0;
    ctrl_vif.cb.clear_reg[READ_TIMEOUT] <= 1'b1;
    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <= '0;

    /*
     * Allow rcvy_ack, epoch_clr, and GUARD_RECOVERY -> GUARD_NORMAL to occur.
     */
    repeat (4) @(ctrl_vif.cb);

    if (ctrl_vif.cb.status_reg[READ_TIMEOUT] !== 1'b0)
      `uvm_error("REC_08_STATUS", "Fault status remained set after completed recovery")

    if (ctrl_vif.cb.irq !== 1'b0)
      `uvm_error("REC_08_IRQ", "IRQ remained asserted after completed recovery")

    `uvm_info("REC_08", "Recovery completed; issuing first transaction of the new epoch", UVM_LOW)

    /*
     * Second transaction: completely normal read in the new epoch.
     *
     * No timeout or ghost expectation is configured for this request. It
     * therefore follows the scoreboard's ordinary request/response path and
     * must match the downstream RESP_OKAY response normally.
     */
    fork
      fresh_manager_read_seq.start(upstream_read_sqr);
      fresh_subordinate_read_seq.start(downstream_read_sqr);
    join

    repeat (3) @(ctrl_vif.cb);

    `uvm_info("REC_08", "Post-recovery read completed normally in the new transaction epoch", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rec8_post_recovery_transaction_test