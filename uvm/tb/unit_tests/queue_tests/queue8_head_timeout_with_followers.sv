/*
 * QUEUE-08 verifies head-of-queue timeout behavior while follower reads remain
 * outstanding.
 *
 * Three reads are admitted before any response returns. The first downstream
 * response is delayed beyond TIMEOUT_COUNTER, causing the head transaction to
 * time out while two follower transactions remain outstanding.
 *
 * The SCC must inject the required upstream error response without corrupting
 * its outstanding bookkeeping. Containment subsequently resolves the remaining
 * upstream obligations, while the delayed real subordinate responses are
 * treated as ghosts and drained rather than forwarded into a later epoch.
 */


class queue8_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(queue8_manager_read_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;

  function new(string name = "queue8_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : queue8_manager_read_seq



class queue8_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(queue8_subordinate_read_seq)

  int unsigned fixed_rvalid_delay;

  function new(string name = "queue8_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay  = fixed_rvalid_delay;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : queue8_subordinate_read_seq



class queue8_head_timeout_with_followers_test extends base_test;

  `uvm_component_utils(queue8_head_timeout_with_followers_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  queue8_manager_read_seq manager_read_seq0;
  queue8_manager_read_seq manager_read_seq1;
  queue8_manager_read_seq manager_read_seq2;

  queue8_subordinate_read_seq subordinate_read_seq0;
  queue8_subordinate_read_seq subordinate_read_seq1;
  queue8_subordinate_read_seq subordinate_read_seq2;


  function new(string name = "queue8_head_timeout_with_followers_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    uvm_config_db#(bit)::set(this, "env.upstream_agent.read_driver", "pipelined_manager_reads", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.read_driver", "pipelined_subordinate_reads", 1'b1);

    super.build_phase(phase);

    manager_read_seq0 = queue8_manager_read_seq::type_id::create("manager_read_seq0");
    manager_read_seq1 = queue8_manager_read_seq::type_id::create("manager_read_seq1");
    manager_read_seq2 = queue8_manager_read_seq::type_id::create("manager_read_seq2");

    subordinate_read_seq0 = queue8_subordinate_read_seq::type_id::create("subordinate_read_seq0");
    subordinate_read_seq1 = queue8_subordinate_read_seq::type_id::create("subordinate_read_seq1");
    subordinate_read_seq2 = queue8_subordinate_read_seq::type_id::create("subordinate_read_seq2");

    manager_read_seq0.fixed_addr = 32'h4000_0700;
    manager_read_seq1.fixed_addr = 32'h4000_0710;
    manager_read_seq2.fixed_addr = 32'h4000_0720;

    /*
     * Only the head response needs the long delay. Since the pipelined
     * subordinate response thread services its mailbox in FIFO order, the
     * follower responses naturally remain behind the delayed head.
     */
    subordinate_read_seq0.fixed_rvalid_delay = TIMEOUT_COUNTER + 20;
    subordinate_read_seq1.fixed_rvalid_delay = 0;
    subordinate_read_seq2.fixed_rvalid_delay = 0;

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);
    /*
    * Three reads are outstanding when the head times out. The first receives the
    * timeout SLVERR and containment resolves the two followers with additional
    * injected SLVERR responses. Since all three requests were already forwarded
    * downstream, their eventual real responses are stale and must all be drained
    * as ghosts.
    */
    env.sb.set_expected_read_error_responses(3);
    env.sb.set_expected_late_read_responses(3);

    `uvm_info("QUEUE_08", "Starting head-timeout test with two follower reads outstanding", UVM_LOW)

    /*
     * Three AR requests are admitted quickly. The first downstream response is
     * deliberately delayed beyond TIMEOUT_COUNTER, so the head expires while
     * the two later requests are still represented by outst_cnt.
     */
    fork

      begin
        manager_read_seq0.start(upstream_read_sqr);
        manager_read_seq1.start(upstream_read_sqr);
        manager_read_seq2.start(upstream_read_sqr);
      end

      begin
        subordinate_read_seq0.start(downstream_read_sqr);
        subordinate_read_seq1.start(downstream_read_sqr);
        subordinate_read_seq2.start(downstream_read_sqr);
      end

    join

    /*
     * Sequence completion only proves that the AR requests were accepted.
     * Continue running until every upstream obligation has been resolved and
     * every late downstream response has been drained.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2)
      @(ctrl_vif.cb);

    `uvm_info("QUEUE_08", "Head timeout occurred with followers outstanding and all late response debt was drained", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : queue8_head_timeout_with_followers_test