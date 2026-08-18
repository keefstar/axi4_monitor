/*
 * Simplest complete memory-backed end-to-end test:
 *
 *   1. Manager writes 0x1234_5678 to address 0x10.
 *   2. Downstream subordinate accepts the write.
 *   3. Subordinate write driver updates the shared RAM.
 *   4. B response completes.
 *   5. Manager reads address 0x10.
 *   6. Subordinate read driver reads the same shared RAM.
 *   7. Scoreboard checks that returned data is 0x1234_5678.
 */


/*==============================================================
 * TARGETED MANAGER WRITE SEQUENCE
 *==============================================================*/

class e2e_manager_write_seq
  extends uvm_sequence#(axi4l_write_item);

  `uvm_object_utils(e2e_manager_write_seq)

  function new(string name = "e2e_manager_write_seq");
    super.new(name);
  endfunction


  virtual task body();

    req = axi4l_write_item::type_id::create("req");

    start_item(req);

    /*
     * Keep only the manager-owned write fields randomized.
     *
     * This assumes your axi4l_write_item contains the same helper
     * function you created for the read item.
     */
    req.configure_for_manager();

    /*
     * Generate one deterministic write operation.
     *
     * Address 0x10 is:
     *   - word-aligned
     *   - inside your 1 KB subordinate RAM
     *
     * STRB = 4'b1111 writes all four bytes.
     */
    assert(
      req.randomize() with {
        addr == 32'h0000_0010;
        prot == 3'b000;
        data == 32'h1234_5678;
        strb == 4'b1111;
      }
    )
    else begin
      `uvm_fatal(
        get_type_name(),
        "Failed to randomize targeted manager write item"
      )
    end

    `uvm_info(
      get_type_name(),
      $sformatf(
        "Writing addr=0x%0h data=0x%0h strb=0x%0h",
        req.addr,
        req.data,
        req.strb
      ),
      UVM_LOW
    )

    /*
     * finish_item() does not return until the manager write driver
     * completes AW, W, and the B response.
     */
    finish_item(req);

  endtask : body

endclass : e2e_manager_write_seq


/*==============================================================
 * DOWNSTREAM SUBORDINATE WRITE RESPONSE SEQUENCE
 *==============================================================*/

class e2e_subordinate_write_seq
  extends uvm_sequence#(axi4l_write_item);

  `uvm_object_utils(e2e_subordinate_write_seq)

  function new(string name = "e2e_subordinate_write_seq");
    super.new(name);
  endfunction


  virtual task body();

    req = axi4l_write_item::type_id::create("req");

    start_item(req);

    /*
     * The subordinate does not choose the actual address or data.
     * Its driver captures those values from downstream AW and W.
     *
     * It only controls subordinate-side timing and response behavior.
     */
    req.configure_for_subordinate();

    assert(req.randomize())
    else begin
      `uvm_fatal(
        get_type_name(),
        "Failed to randomize subordinate write response item"
      )
    end

    /*
     * This is a normal successful write.
     *
     * If resp is declared rand in your write item, this assignment
     * may instead be placed inside randomize() as:
     *
     *     resp == RESP_OKAY;
     */
    req.resp = RESP_OKAY;

    finish_item(req);

  endtask : body

endclass : e2e_subordinate_write_seq


/*==============================================================
 * TARGETED MANAGER READ SEQUENCE
 *==============================================================*/

class e2e_manager_read_seq
  extends uvm_sequence#(axi4l_read_item);

  `uvm_object_utils(e2e_manager_read_seq)

  function new(string name = "e2e_manager_read_seq");
    super.new(name);
  endfunction


  virtual task body();

    req = axi4l_read_item::type_id::create("req");

    start_item(req);

    req.configure_for_manager();

    /*
     * Read the exact address written by the earlier write sequence.
     */
    assert(
      req.randomize() with {
        addr == 32'h0000_0010;
        prot == 3'b000;
      }
    )
    else begin
      `uvm_fatal(
        get_type_name(),
        "Failed to randomize targeted manager read item"
      )
    end

    `uvm_info(
      get_type_name(),
      $sformatf(
        "Reading addr=0x%0h",
        req.addr
      ),
      UVM_LOW
    )

    /*
     * This returns only after the upstream manager receives the
     * complete R response.
     */
    finish_item(req);

  endtask : body

endclass : e2e_manager_read_seq


/*==============================================================
 * DOWNSTREAM SUBORDINATE READ RESPONSE SEQUENCE
 *==============================================================*/

class e2e_subordinate_read_seq
  extends uvm_sequence#(axi4l_read_item);

  `uvm_object_utils(e2e_subordinate_read_seq)

  function new(string name = "e2e_subordinate_read_seq");
    super.new(name);
  endfunction


  virtual task body();

    req = axi4l_read_item::type_id::create("req");

    start_item(req);

    /*
     * The subordinate read driver captures the forwarded AR address,
     * reads mem_model at that address, and returns the stored data.
     */
    req.configure_for_subordinate();

    assert(req.randomize())
    else begin
      `uvm_fatal(
        get_type_name(),
        "Failed to randomize subordinate read response item"
      )
    end

    req.resp = RESP_OKAY;

    finish_item(req);

  endtask : body

endclass : e2e_subordinate_read_seq


/*==============================================================
 * WRITE-THEN-READBACK TEST
 *==============================================================*/

class write_readback_test extends base_test;

  `uvm_component_utils(write_readback_test)


  /*
   * Handles to the four sequencer instances already contained in
   * the two agents.
   */
  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;


  /*
   * The four scenario objects used by this test.
   */
  e2e_manager_write_seq     manager_write_seq;
  e2e_subordinate_write_seq subordinate_write_seq;

  e2e_manager_read_seq      manager_read_seq;
  e2e_subordinate_read_seq  subordinate_read_seq;


  function new(
    string name = "write_readback_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction : new


  virtual function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_write_seq =
      e2e_manager_write_seq::type_id::create(
        "manager_write_seq"
      );

    subordinate_write_seq =
      e2e_subordinate_write_seq::type_id::create(
        "subordinate_write_seq"
      );

    manager_read_seq =
      e2e_manager_read_seq::type_id::create(
        "manager_read_seq"
      );

    subordinate_read_seq =
      e2e_subordinate_read_seq::type_id::create(
        "subordinate_read_seq"
      );

  endfunction : build_phase


  virtual function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    /*
     * The upstream manager sequences run on the upstream agent.
     */
    upstream_write_sqr =
      env.upstream_agent.write_sequencer;

    upstream_read_sqr =
      env.upstream_agent.read_sequencer;


    /*
     * The downstream subordinate sequences run on the downstream
     * subordinate agent.
     */
    downstream_write_sqr =
      env.downstream_agent.write_sequencer;

    downstream_read_sqr =
      env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  virtual task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    `uvm_info(
      get_type_name(),
      "Starting deterministic write",
      UVM_LOW
    )

    /*
     * Both sides of the write transaction must run concurrently:
     *
     *   manager sequence:
     *     generates AW/W and accepts B
     *
     *   subordinate sequence:
     *     accepts AW/W, updates RAM, and returns B
     *
     * join means the test does not proceed until the full write,
     * including the B response, has finished on both sides.
     */
    fork
      manager_write_seq.start(
        upstream_write_sqr
      );

      subordinate_write_seq.start(
        downstream_write_sqr
      );
    join


    `uvm_info(
      get_type_name(),
      "Write completed; starting readback",
      UVM_LOW
    )

    /*
     * Only after the write and B response complete do we begin the
     * readback operation.
     *
     * This guarantees the subordinate RAM and scoreboard exp_mem
     * have both been updated before the read response is checked.
     */
    fork
      manager_read_seq.start(
        upstream_read_sqr
      );

      subordinate_read_seq.start(
        downstream_read_sqr
      );
    join


    `uvm_info(
      get_type_name(),
      "Write-readback scenario completed",
      UVM_LOW
    )

    phase.drop_objection(this);

  endtask : run_phase

endclass : write_readback_test