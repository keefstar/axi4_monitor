/* QUEUE-01 verifies tracking of multiple outstanding read transactions.
   Several upstream read requests are accepted before the corresponding
   downstream responses retire. The SCC must track every accepted request,
   maintain a correct outstanding count, and retire exactly one outstanding
   transaction for each completed upstream read response. */

   /* QUEUE-01 verifies tracking of multiple outstanding read transactions.
   Three upstream read requests are issued without waiting for earlier read
   responses to complete. The subordinate delays each response so that multiple
   requests coexist in the SCC. The read queue must track all accepted requests,
   reach an outstanding occupancy of at least three, and subsequently retire
   each transaction normally without overflow or bookkeeping corruption. */


class queue1_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(queue1_manager_read_seq)

  function new(string name = "queue1_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    if (!req.randomize() with {
      ar_delay == 0;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "QUEUE-01 manager read randomization failed")
    end

  endfunction : randomize_req

endclass : queue1_manager_read_seq


class queue1_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(queue1_subordinate_read_seq)

  function new(string name = "queue1_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    if (!req.randomize() with {
      arready_delay == 0;
      rvalid_delay == 20;
      suppress_rvalid == 0;
      resp == RESP_OKAY;
    }) begin
      `uvm_fatal(get_type_name(), "QUEUE-01 subordinate read randomization failed")
    end

  endfunction : randomize_req

endclass : queue1_subordinate_read_seq


class queue1_multiple_outstanding_reads_test extends base_test;

  `uvm_component_utils(queue1_multiple_outstanding_reads_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  queue1_manager_read_seq manager_read_seq0;
  queue1_manager_read_seq manager_read_seq1;
  queue1_manager_read_seq manager_read_seq2;

  queue1_subordinate_read_seq subordinate_read_seq0;
  queue1_subordinate_read_seq subordinate_read_seq1;
  queue1_subordinate_read_seq subordinate_read_seq2;

  function new(string name = "queue1_multiple_outstanding_reads_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    /* QUEUE-01 requires the manager to issue new AR requests without waiting
       for earlier R responses. All existing tests retain blocking behavior. */
    uvm_config_db#(bit)::set(
      this,
      "env.upstream_agent.read_driver",
      "pipelined_manager_reads",
      1'b1
    );

    uvm_config_db#(bit)::set(this, "env.downstream_agent.read_driver", "pipelined_subordinate_reads", 1'b1);

    super.build_phase(phase);

    manager_read_seq0 = queue1_manager_read_seq::type_id::create("manager_read_seq0");
    manager_read_seq1 = queue1_manager_read_seq::type_id::create("manager_read_seq1");
    manager_read_seq2 = queue1_manager_read_seq::type_id::create("manager_read_seq2");

    subordinate_read_seq0 = queue1_subordinate_read_seq::type_id::create("subordinate_read_seq0");
    subordinate_read_seq1 = queue1_subordinate_read_seq::type_id::create("subordinate_read_seq1");
    subordinate_read_seq2 = queue1_subordinate_read_seq::type_id::create("subordinate_read_seq2");

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase

  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    `uvm_info(
      "QUEUE_01",
      "Starting multiple-outstanding-read test",
      UVM_LOW
    )

    fork
   manager_read_seq0.start(upstream_read_sqr);
   manager_read_seq1.start(upstream_read_sqr);
   manager_read_seq2.start(upstream_read_sqr);

   subordinate_read_seq0.start(downstream_read_sqr);
   subordinate_read_seq1.start(downstream_read_sqr);
   subordinate_read_seq2.start(downstream_read_sqr);
   join

   /*
   * The sequences finish once their AR requests have been accepted.
   * Wait until all outstanding SCC read obligations have actually retired.
   */
   do begin
   @(ctrl_vif.cb);
   end while (ctrl_vif.cb.guard_busy !== 1'b0);

   repeat (2)
   @(ctrl_vif.cb);

   `uvm_info( "QUEUE_01", "Multiple outstanding reads completed and retired", UVM_LOW )

   phase.drop_objection(this);

  endtask : run_phase

endclass : queue1_multiple_outstanding_reads_test