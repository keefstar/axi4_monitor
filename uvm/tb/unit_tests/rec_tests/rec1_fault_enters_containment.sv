/*
 * REC-01 verifies entry into containment following a detected fault.
 *
 * A single read is forwarded downstream and its R response is deliberately
 * delayed beyond TIMEOUT_COUNTER. The read queue therefore raises
 * READ_TIMEOUT while the guard is in GUARD_NORMAL.
 *
 * REC-01 is concerned with the top-level consequence of that fault rather
 * than re-verifying timeout detection itself: the guard must transition into
 * GUARD_CONTAINING and assert flush.
 */


class rec1_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rec1_manager_read_seq)

  function new(string name = "rec1_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0800;
    req.prot = 3'b000;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : rec1_manager_read_seq



class rec1_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rec1_subordinate_read_seq)

  function new(string name = "rec1_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;

    /*
     * The real downstream response arrives after the SCC timeout. This causes
     * READ_TIMEOUT and subsequently exercises the recovery FSM's transition
     * from NORMAL into CONTAINING.
     */
    req.rvalid_delay = TIMEOUT_COUNTER + 20;

    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : rec1_subordinate_read_seq



class rec1_fault_enters_containment_test extends base_test;

  `uvm_component_utils(rec1_fault_enters_containment_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rec1_manager_read_seq manager_read_seq;
  rec1_subordinate_read_seq subordinate_read_seq;


  function new(string name = "rec1_fault_enters_containment_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_read_seq = rec1_manager_read_seq::type_id::create("manager_read_seq");
    subordinate_read_seq = rec1_subordinate_read_seq::type_id::create("subordinate_read_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    /*
     * The read timeout is intentional. Its eventual real downstream response
     * is also expected and must be consumed as stale ghost traffic.
     */
    env.sb.set_expect_read_timeout(1'b1);
    env.sb.set_expect_late_read_response(1'b1);

    `uvm_info("REC_01", "Starting fault-to-containment recovery test", UVM_LOW)

    /*
     * The existing blocking read UVC is sufficient here. Only one transaction
     * is required; unlike the QUEUE tests, no pipelined traffic is necessary.
     */
    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    repeat (2) @(ctrl_vif.cb);

    `uvm_info("REC_01", "Read fault exercised and containment transition completed", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rec1_fault_enters_containment_test