/*
 * QUEUE-07 verifies read-queue retirement and capacity reuse.
 *
 * A first batch of four reads is made outstanding. The test then allows
 * several responses to retire, reducing occupancy without completely draining
 * the queue. A second batch of three reads is subsequently issued.
 *
 * The SCC must correctly decrement its outstanding count as the first batch
 * retires and reuse those released entries for later transactions without
 * underflow, overflow, stale bookkeeping, or loss of transactions.
 */


class queue7_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(queue7_manager_read_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;

  function new(string name = "queue7_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : queue7_manager_read_seq



class queue7_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(queue7_subordinate_read_seq)

  function new(string name = "queue7_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = 10;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : queue7_subordinate_read_seq



class queue7_read_capacity_reuse_test extends base_test;

  `uvm_component_utils(queue7_read_capacity_reuse_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  queue7_manager_read_seq manager_read_seq[7];
  queue7_subordinate_read_seq subordinate_read_seq[7];


  function new(string name = "queue7_read_capacity_reuse_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    uvm_config_db#(bit)::set(this, "env.upstream_agent.read_driver", "pipelined_manager_reads", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.read_driver", "pipelined_subordinate_reads", 1'b1);

    super.build_phase(phase);

    for (int i = 0; i < 7; i++) begin
      manager_read_seq[i] = queue7_manager_read_seq::type_id::create($sformatf("manager_read_seq%0d", i));
      subordinate_read_seq[i] = queue7_subordinate_read_seq::type_id::create($sformatf("subordinate_read_seq%0d", i));
      manager_read_seq[i].fixed_addr = 32'h4000_0600 + (i * 32'h10);
    end

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    `uvm_info("QUEUE_07", "Starting read retirement and capacity-reuse test", UVM_LOW)

    /*
     * First batch: create four simultaneously outstanding read obligations.
     */
    fork

      begin
        for (int i = 0; i < 4; i++)
          manager_read_seq[i].start(upstream_read_sqr);
      end

      begin
        for (int i = 0; i < 4; i++)
          subordinate_read_seq[i].start(downstream_read_sqr);
      end

    join

    /*
     * Each downstream response is delayed by 10 cycles. Allow enough time for
     * multiple entries from the first batch to retire while leaving at least
     * one earlier transaction outstanding.
     */
    repeat (18)
      @(ctrl_vif.cb);

    `uvm_info("QUEUE_07", "Earlier reads partially retired; issuing second batch into released capacity", UVM_LOW)

    /*
     * Second batch: reuse entries released by the earlier retirements.
     */
    fork

      begin
        for (int i = 4; i < 7; i++)
          manager_read_seq[i].start(upstream_read_sqr);
      end

      begin
        for (int i = 4; i < 7; i++)
          subordinate_read_seq[i].start(downstream_read_sqr);
      end

    join

    /*
     * Pipelined sequence completion only means AR was accepted. Wait for every
     * remaining response obligation from both batches to retire.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2)
      @(ctrl_vif.cb);

    `uvm_info("QUEUE_07", "Retired read-queue capacity was successfully reused and all reads completed", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : queue7_read_capacity_reuse_test