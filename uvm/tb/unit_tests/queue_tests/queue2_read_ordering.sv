/* QUEUE-02 verifies in-order retirement of multiple outstanding reads.
   Three read requests are admitted before the first response retires. The
   subordinate returns three distinguishable responses in request order. The
   SCC must forward exactly one response per outstanding request and preserve
   their ordering while decrementing the outstanding count one transaction at
   a time. */


class queue2_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(queue2_manager_read_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;

  function new(string name = "queue2_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot  = 3'b000;
    req.ar_delay  = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : queue2_manager_read_seq



class queue2_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(queue2_subordinate_read_seq)

  axi_resp_e fixed_resp;

  function new(string name = "queue2_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = 20;
    req.suppress_rvalid = 0;
    req.resp = fixed_resp;

  endfunction : randomize_req

endclass : queue2_subordinate_read_seq



class queue2_read_ordering_test extends base_test;

  `uvm_component_utils(queue2_read_ordering_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  queue2_manager_read_seq manager_read_seq0;
  queue2_manager_read_seq manager_read_seq1;
  queue2_manager_read_seq manager_read_seq2;

  queue2_subordinate_read_seq subordinate_read_seq0;
  queue2_subordinate_read_seq subordinate_read_seq1;
  queue2_subordinate_read_seq subordinate_read_seq2;

  function new(string name = "queue2_read_ordering_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    /*
     * QUEUE-02 reuses the pipelined read-driver modes introduced for
     * QUEUE-01 so that all three AR requests may be accepted before
     * the first R response retires.
     */
    uvm_config_db#(bit)::set(this,"env.upstream_agent.read_driver","pipelined_manager_reads",1'b1);
    uvm_config_db#(bit)::set(this,"env.downstream_agent.read_driver","pipelined_subordinate_reads",1'b1);

    super.build_phase(phase);

    manager_read_seq0 = queue2_manager_read_seq::type_id::create("manager_read_seq0");
    manager_read_seq1 = queue2_manager_read_seq::type_id::create("manager_read_seq1");
    manager_read_seq2 = queue2_manager_read_seq::type_id::create("manager_read_seq2");

    subordinate_read_seq0 =
      queue2_subordinate_read_seq::type_id::create("subordinate_read_seq0");

    subordinate_read_seq1 =
      queue2_subordinate_read_seq::type_id::create("subordinate_read_seq1");

    subordinate_read_seq2 =
      queue2_subordinate_read_seq::type_id::create("subordinate_read_seq2");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    /*
     * Distinct addresses identify the three accepted requests.
     */
    manager_read_seq0.fixed_addr = 32'h4000_0010;
    manager_read_seq1.fixed_addr = 32'h4000_0020;
    manager_read_seq2.fixed_addr = 32'h4000_0030;

    /*
     * Distinct legal AXI response values make response ordering directly
     * observable without relying on currently uninitialized memory data.
     */
    subordinate_read_seq0.fixed_resp = RESP_OKAY;
    subordinate_read_seq1.fixed_resp = RESP_SLVERR;
    subordinate_read_seq2.fixed_resp = RESP_DECERR;
    `uvm_info( "QUEUE_02", "Starting in-order multiple-outstanding-read retirement test", UVM_LOW )

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
     * Pipelined sequences complete once their AR requests have been accepted.
     * Wait until all three read responses have actually retired.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2)
      @(ctrl_vif.cb);

    `uvm_info( "QUEUE_02", "All outstanding reads retired in order", UVM_LOW )

    phase.drop_objection(this);

  endtask : run_phase

endclass : queue2_read_ordering_test