SCOREBOARD:
It has
1) Transfer function / reference module: given what entered the SCC, what should have come without
For example: Suppose the upstream manager sends:
ARADDR = 0 x1000, ARPROT = 3'b000 Expected: [upstream request] ->[SCC] ->[downstrame request] sub returns RDATA = 0 xDEADBEEF, RRESP = OKAY The SCC should normally forward: RDATA = 0 xDEADBEEF, RRESP = OKAY The scoreboard can predict that.* But my DUT Is more interesting because it has fault behaviour.Suppose -> Upstream: AR request accepted Downstream: request forwarded ↓ NO R RESPONSE ↓ TIMEOUT Expected model says: Expected upstream resopnse: RRESP = SLVERR(plus whatever other externally viisbel behaviour you decid eto verify such as interrupted asserted and fault_source) The scorebaord knows: the sub never respones, thus I expect SCC to fabricate a SLVERR rather than waiitng forever 2) Expected data storage: Queues are good when outputs remain in the same order as inputs(for my design) Conceptually: Expected transaction queue front │ ▼ + -- -- -- -- -- -- -- -- --+|request #1 | ← next expected response + -- -- -- -- -- -- -- -- --+|request #2 | +-- -- -- -- -- -- -- -- --+|request #3 | +-- -- -- -- -- -- -- -- --+The upstream manager would see: AR 0 x1000 AR 0 x2000 AR 0 x3000 Then actual responses arrive: response #1 response #2 response #3 and you compare from the front of the queue.expected = expected_q.pop_front();
if (actual.compare(expected))
  PASS;
else
  ERROR;

3) Checking logic: Self explanotary

Q: What is my scorebaord trying to prove ?
Remmeber my DUT sits between: [upstream AXI4L manager] ->[SCC] ->[downstream AXI4L sub]
So your scoreboard needs to observe both sides and answer questions like:
Did the SCC forward valid traffic correctly ?
Did it preserve addresses / data / responses ?
Did it inject SLVERR when a timeout occurred ?
Did it stop forwarding or drain late responses correctly after a fault ?
Did transactions remain properly ordered ?

Scoreboard arch will conceptually look like:
UPSTREAM SIDE DOWNSTREAM SIDE

upstream monitor downstream monitor
| |
|observed transactions | observed transactions
| |
+-- -- -- -- -- -- -- -- --+-- -- -- -- -- -- -- -- -- -+
|
v
+-- -- -- -- -- -- -+
|SCOREBOARD |
+-- -- -- -- -- -- -+
|
expected vs actual
|
PASS / ERROR

Q: Comparision function: Built - in compare() or user - define comparision ?
Recall, my read transactoin is liek:
UPSTREAM SIDE DOWNSTREAM SIDE

upstream monitor downstream monitor
| |
|observed transactions | observed transactions
| |
+-- -- -- -- -- -- -- -- --+-- -- -- -- -- -- -- -- -- -+
|
v
+-- -- -- -- -- -- -+
|SCOREBOARD |
+-- -- -- -- -- -- -+
|
expected vs actual
|
PASS / ERROR

A compare() function in one I would build in my scoreboard class.
But can also do expliciltl comparision:
if (expected.addr != actual.addr)
`uvm_error(...)

Q: How the hell should / can monitor and scoreboard communicate
This is where TLM analyis ports come in.
I have monitors that observe AXI signals:
ARVALID, ARREADY, ARADDR, ARPROT
And reconstructs a transaction.
Problem is: How does that transaction get from the monitor object into the scoreboard object.
We cannot connect them using Verilog wires.They are classes.
Needs equivalence of Verilog I / O ports for class instances
UVM solves this with TLM.

Think of TLM like virtual wires between UVM objects:
RTL:
module A module B
  output logic x-------- > input logic x
  UVM classes:
  MONITOR SCOREBOARD
  analysis_port-------------- -> analysis_imp
  But instead of transmitting individual bits every cycle, you transmit an entire transaction object.
  Eg: send below all at once
  {
    addr = 0 x1000, prot = 000, data = 0 xDEADBEEF, resp = OKAY} That ’ s why it is called: Transaction - Level Modeling My MONITOR is the PRODUCER.UVC Monitor uvm_analysis_port | |write(transaction) v Scoreboard uvm_analysis_imp
  uvm_analysis_port#(axi4l_read_item) ap; /* “I have an output capable of publishing axi4l_read_item transactions */
  Then your monitor observes a completed transaction:
  axi4l_read_item tr;
  tr.addr = vif.mon_cb.araddr;
  tr.prot = vif.mon_cb.arprot;
  And then publishes it: ap.write(tr) /* IT MEANS SEND TRANAACTIONT HROUGH THE ANALYSIS PORT*/
  The scoreboard is the CONSUMER: The scoreboard receives those transactions.
  uvm_analysis_imp#(axi4l_read_item, axi4l_scoreboard) read_imp;
  The scoreboard needs to implement:
  function void write(axi4l_read_item tr);
    
    // transaction arrived!
    
  endfunction
  
  So when the monitor does: ap.write(tr);
  UVM causes write(tr);
  function to execute.Q: Where are they connected ? This is exactly like your driver / sequencer connection conceptually.rememver : driver.seq_item_port.connect(
      sequencer.seq_item_export
  );
    That happened in the agent ’ s connect_phase().
    Likewise:
    monitor analysis port
    |
    connect
    |
    scoreboard analysis implementation
    happens in a higher - level icomponent, perhaps the test_Env
    Something like:
    upstream_agent.monitor.ap.connect(
      scoreboard.upstream_imp
    );
    
    Q: Broadcast ?
    Transaction can be broadcast to zero, one, or multiple consumers(we have scoreboard, functional coverage, debugger)
    The monitor could not care less.I tjust publishes.So when I impelment funcitonalc oevrage, I do not need to rewrite my monitor.
    
    Q: More complicated because I have multipler monitors.
    UPSTREAM MONITOR
    observes:
    AR going into SCC
    R coming out of SCC
    AW / W going into SCC
    B coming out of SCC
    DOWNSTREAM MONITOR
    
    observes:
    AR coming out of SCC
    R going into SCC
    AW / W coming out of SCC
    B going into SCC
    
    My SCOREBOARD needs to distingush WHERE transactions came from
    This is where you may eventually have multiple analysis implementations.
    Something like:
    upstream monitor AP
    |
    v
    scoreboard upstream IMP
    
    
    downstream monitor AP
    |
    v
    scoreboard downstream IMP
    THen scoreboard can reason:
    I saw upstream AR 0 x1000.
    
    Therefore:
    I expect downstream AR 0 x1000.
    I saw upstream AR 0 x1000.
    
    Therefore:
    I expect downstream AR 0 x1000.
    
    CONCREATE READ EXAMPLE:
    1) Sequence creates: READ addr = 0 x1000 2) Driver drives: a_arvalid = 1, a_araddr = 0 x1000 3) Handshake: s_arvalid && s_arready 4) upstream monitor detects it 5) It builds: tr.addr = 'h1000;
    6) Then, upstream_ap.write(tr);
    7) Scoreboard recieves it: Observed upstream AR = 0 x1000 8) Reference logic predicts: Expected downstream: AR = 0 x1000 9) Stores expected_downstread_ar_q: [0 x1000] 10) SCC forwards that request 11) Downstream monitor sees: m_arvalid && m_arready m_araddr = 0 x1000 12) It publishes: downstream_ap.write(tr);
    13) Scoreboard recieves:
    Actual downstream AR = 0 x1000 14) ** ** Obviously need to check data, use dterminsitic function like rdata = addr ^ 32'hA5A5_A5A5 So, if manage requests ARADDR = 0 x0000_1000 Sub must return: RDATA = 0 x0000_1000 ^ 0 xA5A5_A5A5 = 0 xA5A5_B5A5 Now the scoreboard can independently calculate the expected data.Upstream monitor sees: ARADDR = 0 x1000 | v Scoreboard calculates: expected_data = 0 x1000 XOR 0 xA5A5A5A5 = 0 xA5A5B5A5 | v Downstream subordinate returns: RDATA = 0 xA5A5B5A5 | v SCC forwards response upstream | v Upstream monitor sees: RDATA = 0 xA5A5B5A5 RRESP = OKAY | v Scoreboard compares: expected RDATA = A5A5B5A5 actual RDATA = A5A5B5A5 ✓ expected RRESP = OKAY actual RRESP = OKAY ✓ For WRITE case, I think I should make a small fake RAM / Memory model(cleanest ways to verify writes) Upstream manager | |AWADDR + WDATA + WSTRB v SCC | v Fake subordinate RAM When the SCC forwards a valid write, your subordinate model updates an array.logic[DATA_WIDTH - 1:0] mem[0:255];
      Then a write to address 0 x10 with:
      WDATA = 0 xDEADBEEF WSTRB = 4'b1111 Could result in mem[4] = 0 xDEADBEEF Then your scoreboard can maintain its own reference memory DUT SIDE SCOREBOARD Fake subordinate RAM Reference / expected RAM mem[] exp_mem[] | |actual forwarded write expected upstream write | |+-- -- -- -- -- -- --compare---------- - +1.WRITE 0 xDEADBEEF to address 0 x100 2.Fake RAM stores: mem[0 x40] = 0 xDEADBEEF 3.Later issue READ address 0 x100 4.Fake RAM returns: RDATA = 0 xDEADBEEF 5.SCC forwards it upstream 6.Scoreboard checks: expected = 0 xDEADBEEF actual = 0 xDEADBEEF PASS And WSTRB makes the fake RAM even more useful Suppose memory contains: mem = 0 xAABBCCDD Then you write: WDATA = 0 x11223344 WSTRB = 4'b0011 Only the two lower byte lanes should update: Before: AA BB CC DD Write: 11 22 33 44 ^ ^^^enabled After: AA BB 33 44 fake RAM can model this very easily: for (int i = 0; i < STRB_WIDTH; i++) begin if (wstrb[i]) mem[index][8 * i +: 8] = wdata[8 * i +: 8];
      end
      
      word_index = addr >> 2;
      (divide by 4)
      
      
      ** *
      actually have two different memory concepts:
      1.Subordinate memory model
      Actually responds to AXI reads / writes.
      
      2.Scoreboard reference memory
      Independently tracks what SHOULD be stored.
      the scoreboard should maintain its own expected state based on observed transactions.
      
      
      END TO END TEST IDEA: TEST COMPLETE FLOW.
      1.WRITE 0 xDEADBEEF to address 0 x100
      
      2.Fake RAM stores:
      mem[0 x40] = 0 xDEADBEEF 3.Later issue READ address 0 x100 4.Fake RAM returns: RDATA = 0 xDEADBEEF 5.SCC forwards it upstream 6.Scoreboard checks: expected = 0 xDEADBEEF actual = 0 xDEADBEEF PASS Elegant design idea: READ verification: expected data comes from reference memory WRITE verification: update reference memory Normal operation: compare SCC forwarding and responses Fault operation: predict SLVERR / containment behaviour Recovery: verify transactions resume correctly 3) Kill the XOR idea: A memory - backed subordinate instead remembers writes: WRITE: 0 x100 ← DEADBEEF RAM now remembers: mem[0 x100] = DEADBEEF Later -> READ 0 x100 ↓ RAM looks up what was stored ↓ returns DEADBEEF


      SCOREBOARD TO DO JULY 25 2026:


/* for tmr:
impelement the comparision functions
implement the RAM  model

/* ==================== SCOREBOARD TODO ====================

1. Compile and run one simple smoke test.
   - Verify monitor publishes transactions correctly.
   - Verify scoreboard receives them.
   - Ensure check_read_request(), check_write_address(), and
     check_write_data() all pass for a normal forwarding case.

2. Reference RAM model.
   - Create an independent memory prediction model.
   - This stores what the DUT memory SHOULD contain.
   - Never read the DUT's internal memory.

3. Pair verified AW + W transactions.
   - AW provides address.
   - W provides data + strobes.
   - One AXI write transaction = AW + W.
   - Need both before updating exp_mem[].

4. Update exp_mem[].
   - Compute:
       word_index = aw.addr >> 2;
   - Apply WSTRB correctly (byte enables).
   - Update only enabled bytes.
   - This becomes the expected memory contents.

5. Read response checking.
   - On a downstream read request, remember requested address.
   - When read response arrives:
       expected = exp_mem[word_index]
       actual   = RDATA
   - Compare data (and response when appropriate).

6. Timeout/fault behaviour.
   - Verify injected SLVERR responses.
   - Verify downstream responses are drained correctly.
   - Ensure timeout behaviour matches SCC specification.

7. Functional coverage.
   - Read/write addresses.
   - RESP values.
   - WSTRB patterns.
   - Timeout path.
   - Recovery path.
   - Corner cases.


   /* Implement WSTRB correctly. Don’t simply do exp_mem[word_index] = data;.
    A write may update only some bytes, so each byte should only change if its corresponding WSTRB bit is 1.
    */


*/