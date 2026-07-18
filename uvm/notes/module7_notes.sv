1) SEQUENCER - DRIVER TLM CONNECTION

SEQUENCER
↓
SEQUENCER
↓ TLM CONNECTION
DRIVER
↓
AXI INTERFACE SIGNALS
↓
DUT

The important built - in pieces are:
sequencer.seq_item_export(It sits on the boundary of the sequencer, waiting for requests to arrive from the driver.
  When the driver asks for an item via its port, this export routes that request deeper into the sequencer's internal infrastructure, which grabs the next available transaction from your running sequence.)
driver.seq_item_port(The driver uses this port to actively request data from the sequencer.)
driver.seq_item_port.connect(sequencer.seq_item_export);
(glue that connects the two ports together.)
The above connection / glue gives the driver access to methods such as:
seq_item_port.get_next_item(req);
seq_item_port.item_done();

We DO NOT manually invent this communciation emchanism since UVM provides it because our classes extend:
uvm_sequencer
uvm_driver

Thesis link:
suppose we have axi4l_read_item and it contains addr, prot, ar_delay etc
eventually, our driver does(conceptually):

axi4l_read_item req;
seq_item_port.get_next_item(req);
// physically drive AXI using req
drive_read(req);
seq_item_port.item_done();

So req may contain
addr = 0 x00001000 prot = 000 ar_delay = 2 rready_delay = 3 and the driver converts that abstract transaction into actual clk - by - clk axi behaviiour: addr = 0 x00001000 prot = 000 ar_delay = 2 rready_delay = 3 Distinction: Transaction: "What operation do I want?" Driver: "How do I perform that operation electrically/protocol-wise?" 2) Sequencer – Driver Operation Actual sequence of events: Step 1) Driver asks for work seq_item_port.get_next_item(req);
-(sequencer, give me next AXI transaction)
the call will generally wait until an item is avaliable
Step 2) Sequencer supplies an item from a sequence
Sequence may generate:
axi4l_read_item
addr = 0 x1000 prot = 000 The sequencer then passes that item to the driver.build_phase Step 3) Driver performs the actual AXI protocol(driver becomes protocol speciifc) drive_read(req);
might eventually mean:
Drive ARADDR
Drive ARPROT
Assert ARVALID
wait until:
ARVALID && ARREADY
Deassert ARVALID
Handle RREADY timing
Wait for response

Step 4) driver says'finished'
seq_item_port.item_done();
-(i finished processing this trandaction, you can move on).
Then the loop repeats:
forever begin
  seq_item_port.get_next_item(req);
  drive_read(req);
  seq_item_port.item_done();
end
THAT IS BASICALLY HEART OF BASIC UVM DRIVER.
axi4l_read_sequence
│
│ creates
▼
axi4l_read_item
│
▼
axi4l_sequencer
│
│ seq_item_export
│
│ TLM
│
│ seq_item_port
▼
axi4l_upstream_driver
│
▼
s_axi interface
│
▼
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
│ YOUR AXI GUARD │
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘

Example:
Sequence:
creates READ(0 x1000)

↓

Sequencer:
gives READ(0 x1000) to driver

↓

Driver:
ARADDR = 0 x1000 ARVALID = 1 ↓ Your DUT: accepts the AXI transaction 3 roles are different: SEQUENCE decides WHAT transactions to generate SEQUENCER manages WHO gets sent next DRIVER decides HOW that transaction becomes real signal activity TLM is simply the communication plumbing between the sequencer and driver.MAIN POINTS:
// agent connects them
driver.seq_item_port.connect(sequencer.seq_item_export);
// driver gets transaction
seq_item_port.get_next_item(req);
// driver finishes transaction
seq_item_port.item_done();