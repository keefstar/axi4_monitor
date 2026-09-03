/*
 * CC-09: multiple write ghost-response obligations.
 *
 * Three complete writes are admitted before the first downstream B response
 * is allowed to return. The head write times out and forces containment.
 * Containment then resolves the remaining upstream write obligations using
 * injected SLVERR responses.
 *
 * Because the corresponding real subordinate B responses are still pending,
 * multiple ghost-response obligations accumulate in drain_cnt.
 *
 * Coverage objective:
 *   WRITE_QUEUE drain_cnt >= 2
 *
 * Expected behavior:
 *   - three writes outstanding
 *   - first write-response timeout occurs
 *   - three upstream SLVERR responses are injected
 *   - drain_cnt accumulates multiple ghost obligations
 *   - late downstream B responses are consumed as ghosts
 *   - all ghost debt eventually drains
 */

class cc9_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(cc9_manager_write_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;
  logic [DATA_WIDTH-1:0] fixed_data;

  function new(string name = "cc9_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot  = 3'b000;
    req.data = fixed_data;
    req.strb = 4'b1111;
    req.aw_delay = 0;
    req.w_delay = 0;
    req.bready_delay = 0;
    req.suppress_wvalid = 0;
    req.late_wvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : cc9_manager_write_seq


class cc9_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(cc9_subordinate_write_seq)

  int unsigned fixed_bvalid_delay;

  function new(string name = "cc9_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay = 0;
    req.wready_delay = 0;
    req.bvalid_delay = fixed_bvalid_delay;
    req.suppress_bvalid  = 0;
    req.late_bvalid_after_timeout = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : cc9_subordinate_write_seq


class multiple_write_ghost_test_cc9 extends base_test;

  `uvm_component_utils(multiple_write_ghost_test_cc9)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  cc9_manager_write_seq manager_seq[3];
  cc9_subordinate_write_seq subordinate_seq[3];


  function new(
    string name = "multiple_write_ghost_test_cc9",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    /*
     * Pipelined mode is required so all three write transactions can become
     * outstanding before the first B response is returned.
     */
    uvm_config_db#(bit)::set(this, "env.upstream_agent.write_driver", "pipelined_manager_writes", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.write_driver", "pipelined_subordinate_writes", 1'b1);

    super.build_phase(phase);

    for (int i = 0; i < 3; i++) begin

      manager_seq[i] =
        cc9_manager_write_seq::type_id::create(
          $sformatf("manager_seq_%0d", i)
        );

      subordinate_seq[i] =
        cc9_subordinate_write_seq::type_id::create(
          $sformatf("subordinate_seq_%0d", i)
        );

      manager_seq[i].fixed_addr =
        32'h4000_3000 + (i * 32'h10);

      manager_seq[i].fixed_data =
        32'hC900_0000 + i;

      /*
       * Delay only the first B response beyond the SCC timeout.
       *
       * The pipelined subordinate write driver preserves B-response order.
       * Therefore responses for writes 1 and 2 remain queued behind the first
       * delayed response even though their own delay values are zero.
       *
       * This keeps all three real B responses unavailable while containment
       * injects SLVERRs upstream.
       */
      if (i == 0)
        subordinate_seq[i].fixed_bvalid_delay =
          TIMEOUT_COUNTER + 40;
      else
        subordinate_seq[i].fixed_bvalid_delay = 0;

    end

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    upstream_write_sqr =
      env.upstream_agent.write_sequencer;

    downstream_write_sqr =
      env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    `uvm_info( "CC_09", "Starting multiple-write ghost-response coverage-closure test", UVM_LOW )

    /*
     * All three outstanding writes will be completed upstream by containment
     * using injected SLVERR responses.
     */
    env.sb.set_expected_write_error_responses(3);

    /*
     * Their three real downstream B responses will subsequently arrive after
     * the upstream obligations have already been retired, so the scoreboard
     * must consume them as ghost responses.
     */
    env.sb.set_expected_late_write_responses(3);

    /*
     * Launch three complete writes through both sides of the UVC.
     *
     * Sequence completion only means the pipelined drivers have accepted the
     * requests. B handling continues independently inside the driver response
     * threads.
     */
    fork

      begin
        for (int i = 0; i < 3; i++)
          manager_seq[i].start(upstream_write_sqr);
      end

      begin
        for (int i = 0; i < 3; i++)
          subordinate_seq[i].start(downstream_write_sqr);
      end

    join

    /*
     * Wait until the guard has outstanding work.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b1);

    /*
     * Do not acknowledge the fault here.
     * The existing recovery/testbench infrastructure must leave the guard in
     * containment/recovery long enough for the delayed downstream B responses
     * to return and drain naturally.
     * guard_busy includes drain_cnt, so it remains asserted until all ghost
     * response debt has disappeared.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (3)
      @(ctrl_vif.cb);

    `uvm_info( "CC_09", "Multiple write ghost obligations accumulated and drained", UVM_LOW )

    phase.drop_objection(this);

  endtask : run_phase

endclass : multiple_write_ghost_test_cc9