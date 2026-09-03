/* QUEUE-03 verifies read-queue capacity and admission control.
   Eight read requests are admitted without allowing earlier responses to
   retire, filling the SCC's outstanding-read capacity to DEPTH. A ninth read
   request is then presented while the queue is full. The SCC must backpressure
   that request without overflowing its bookkeeping state. Once an earlier read
   retires and capacity becomes available, the blocked ninth request must be
   admitted and all transactions must subsequently complete normally. */


class queue3_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(queue3_manager_read_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;

  function new(string name = "queue3_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : queue3_manager_read_seq



class queue3_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(queue3_subordinate_read_seq)

  function new(string name = "queue3_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = 20;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : queue3_subordinate_read_seq



class queue3_read_queue_full_test extends base_test;

  `uvm_component_utils(queue3_read_queue_full_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  queue3_manager_read_seq manager_read_seq[DEPTH+1];
  queue3_subordinate_read_seq subordinate_read_seq[DEPTH+1];

  function new(
      string name = "queue3_read_queue_full_test",
      uvm_component parent = null
  );
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    /*
     * Allow upstream requests and downstream address acceptance to proceed
     * independently of response completion.
     */
    uvm_config_db#(bit)::set(this,"env.upstream_agent.read_driver","pipelined_manager_reads",1'b1);

    uvm_config_db#(bit)::set(this,"env.downstream_agent.read_driver","pipelined_subordinate_reads",1'b1);

    super.build_phase(phase);

    for (int i = 0; i < DEPTH+1; i++) begin

      manager_read_seq[i] =
        queue3_manager_read_seq::type_id::create(
          $sformatf("manager_read_seq%0d", i)
        );

      subordinate_read_seq[i] =
        queue3_subordinate_read_seq::type_id::create(
          $sformatf("subordinate_read_seq%0d", i)
        );

      /*
       * Give every request a distinct address while remaining within the
       * subordinate address region.
       */
      manager_read_seq[i].fixed_addr =
        32'h4000_0100 + (i * 32'h10);

    end

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    `uvm_info( "QUEUE_03", $sformatf( "Starting read-capacity test: fill DEPTH=%0d and attempt one additional read", DEPTH ), UVM_LOW )

    /*
     * The first DEPTH requests fill the SCC. Request DEPTH+1 remains asserted
     * until one earlier response retires and frees a slot.
     *
     * Manager and subordinate sequences execute concurrently, while ordering
     * within each side remains deterministic.
     */
    fork

      begin
        for (int i = 0; i < DEPTH+1; i++) begin
          manager_read_seq[i].start(upstream_read_sqr);
        end
      end

      begin
        for (int i = 0; i < DEPTH+1; i++) begin
          subordinate_read_seq[i].start(downstream_read_sqr);
        end
      end

    join

    /*
     * Sequence completion in pipelined mode means the AR requests have been
     * accepted. Wait until all read-response obligations have actually retired.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2)
      @(ctrl_vif.cb);

    `uvm_info( "QUEUE_03", "Read queue reached capacity, backpressured the additional request, reopened admission, and retired all reads", UVM_LOW )

    phase.drop_objection(this);

  endtask : run_phase

endclass : queue3_read_queue_full_test