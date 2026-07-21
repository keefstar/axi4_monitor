Sequence:
Transaction item is one operation.
axi4l_read_item for example:
Read:
address = 0 x1000 AR delay = 2 RREADY delay = 3 A sequence may sayL Do 20 normal reads then 10 writes then cause a downstream read stall then verify timeout behavior That is exactly what you need for the stall - containment thesis.“ A sequence is a set of transactions that accomplish a defined task for the DUT.” axi4l_read_item │ │ one read transaction ▼ axi4l_normal_read_sequence │ ├ ─ ─ read ├ ─ ─ read ├ ─ ─ read └ ─ ─ read Then we can make specialized sequences: axi4l_read_sequence axi4l_write_sequence axi4l_read_timeout_sequence axi4l_write_data_timeout_sequence axi4l_write_resp_timeout_sequence axi4l_flush_sequence axi4l_backpressure_sequence axi4l_random_traffic_sequence "Single items cannot capture high-level intention" One transaction: addr = 'h1000;
does not express “ Fill the controller with several outstanding requests, stall the subordinate, trigger the timeout, observe fabricated SLVERR responses, then recover.”
That requires an ordered scenario.
Something conceptually like:
Sequence: READ_TIMEOUT_TEST

1.Send read request A
2.Send read request B
3.Downstream refuses to respond
4.Wait for timeout
5.DUT injects SLVERR
6.Allow late downstream response
7.Exercise ghost draining
8.Confirm system returns to usable state

Upcoming UVM verification:
Simple randomized data
random addresses
random data
random strobes
random delays
^^^^is great for coverage.
But directed tests are important for thesis.
specifically trigger READ_TIMEOUT
specifically trigger WRITE_DATA_TIMEOUT
specifically trigger WRITE_RESP_TIMEOUT

Stimulus controlled by properties
req.randomize() with {
  addr == 32'h1000;
  rready_delay == 5;
};
we can constrain a generic transaction for a particular scenario rather than writing a completently new transaction class.Our
Hierarchical stimulus
Later, you might coordinat eboth sides.
Upstream sequence:
issue AXI request

Downstream sequence:
intentionally stall response

What does a basic sequence look like:


/* extend from uvm_sequence*/
class axi4l_read_seq extends uvm_sequence#(axi4l_read_item);
  /* create one axi4l_readitem, randomize it according to its constriants, and send it through the sequcncer to the driver */
  `uvm_object_utils(axi4l_read_seq) /* register sequence with factory*/
  function new(string name = "axi4l_read_seq"); /* standard data constructor*/
    super.new(name);
  endfunction
  
  virtual task body(); /* specify body() task with uvm_do macros */
    `uvm_info(get_type_name(), "Call axi4l_read_seq", UVM_LOW)
    `uvm_do(req)
    `uvm_do_with(axi4l_read_seq, {addr = 32'h0000_1000;}) /* consteriant packet randomizatoin*/
  endtask
endclass

What the hell does uvm_do(req) actually do ?
...
task body();
  `uvm_do_with(reg, {addr == 0;})
endtask
^^Translates into:
*Allocate using the factory(factory to support type overrides for example, outof the box)
*Wait till itemis needed(until driver requests item(reactive genertaion))
*Randomize(with constraints or not; combines procedural(inline) and declarative(layered) constriants for extra flexibility)
*Put on the consumer interface - comptaible with built in TLM connection
*Block code execution until item_done()

`uvm_do Macros: breaks down into seven steps
1) creation;
create instance, set parent and link to sequencer
2) synchronize: wait for sequencer get_next_item() request
3) pre_do hook: eexecutes the pre_do() task of the sequence
4) randomization: randomize the instance.If randomization fails, a warning is issued.
5) mid_do hook: execute the mid_do() function of the sequence
6) send item and wait until done.For items: send item to sequencer, nd wait until item done.For subsequences: execute the sequence body() method
7) post_do hook: execute the post_do() function of the sequence.
`uvm_do(req) == generate and execute one transaction

THE EXPLICIT VERSION IS ACTUALLY EASIER TO UNDERSTAND.
Can use methods instead.Step 1 -> create.Step 2 - 3 -> start_item .4 -> randomize, 5 - 7 -> finish_item
Instead of doing `uvm_do(req)

You can explicitly write(4 lines only)
req = axi4l_read_item::type_id::create("req"); /* explicilt creation via UVM factor*/
start_item(req); /* sequencer, I have AXI trransaction i want to send. tell me when you are ready.*/
assert (req.randomize());
finish_item(req); /* This sends the ready transaction to the driver and waits for the driver to complete handling it.*/

`uvm_do_with is very useful -> generate a transaction normally, but force this constriant for this speciifc transaction.
`uvm_do_with(req, {
    addr == 32'h0000_1000;
})

OR YOU CAN DO:
assert (req.randomize() with {addr == 32'h0000_1000;});


The MACRO TABLE: gives UVM different levels of control over CREATE, RANDOMIZE, SEND.
`uvm_do
`uvm_do_with
`uvm_create
`uvm_send
`uvm_rand_send
`uvm_rand_send_with

`uvm_do == do everything for becomes
`uvm_create + `uvm_send == let me manually modify the item before sending it.
Why do we need uvm_create and uvm_send ?
Sometimes we want:
Create transaction
↓
Randomize it
↓
MANUALLY CHANGE SOMETHING
↓
Send exactly that transaction

/* Randomize a valid transaction first, then override specific fields, then send exactly what I constructed.*/
`uvm_create(req)
assert (req.randomize());
req.addr = 32'h0000_1000;
req.ar_delay = 0;
`uvm_send(req)

SEQUENCE PROPERTIES:
class axi4l_two_read_seq extends uvm_sequence#(axi4l_read_item);
  
  `uvm_object_utils(axi4l_two_read_seq)
  
  /* THIS HERE IS A PROPERTU OF SEQUENCE */
  rand logic[31:0] base_addr; /* belongs to the sequence itself, not transaction*/
  /* our transaction may have addr and ar_delay and those belong to each individual  read item*/
  /* The purpose of base_addr is to make multiple transactions related to one another.*/
  constraint aligned_c {
    base_addr[1:0] == 2'b00;
  }
  
  /* suppose seq itself gets randomized and base_addr = 0x1000*/
  /* the bdoy crates 0x1000 for read 1 and 0x1004 for read 2; That is the whole reason for a sequence property: one randomized value can control the behavior of several transactions.*/
  
  function new(string name = "axi4l_two_read_seq");
    super.new(name);
  endfunction
  
  virtual task body();
    `uvm_do_with(req, {
            addr == base_addr;
        })
    `uvm_do_with(req, {
            addr == base_addr + 4;
        })
  endtask
endclass

useful to me how ? Involving multiple related trasnaction.
rand int unsigned num_reads;
constraint num_reads_c {
  num_reads inside {[1:DEPTH]};
}
this could control repeat (num_reads).
same idea for stalls:
rand int unsigned stall_cycles;
stall_cycles < TIMEOUT_COUNTER
→ subordinate is slow, but no timeout should occur
stall_cycles ≈ TIMEOUT_COUNTER
→ boundary condition
stall_cycles > TIMEOUT_COUNTER
→ timeout should occur and SCC containment should activate
stall_cycles >> TIMEOUT_COUNTER
→ very late downstream response / ghost - drain behavior

Transaction randomization vs sequence randomization.
transaction properties control one AXI transaction.sequence properties control the overall scenario.
TRANSACTION RANDOMIZATION
"What does this individual read look like?"
versus
SEQUENCE RANDOMIZATION
"What does this whole test scenario look like?"

NESTING SEQUENCES: A sequence can call another sequence.
Suppose I write axi4l_two_read_seq which does: READ ADDR X, READ ADDR X + 4
I can then build axi4l_complex_seq.
that does:
random read
↓
run axi4l_two_read_seq
↓
random read
Instead of rewriting the two - read behavioir.
Why matter for me ? Eventually you might have smaller reusable sequences :
normal_read_seq
normal_write_seq
read_stall_seq
write_resp_stall_seq
flush_seq
recovery_seq

LESSON:
1.`uvm_do(req)
→ create + randomize + send

2.`uvm_do_with(req, {...})
→ same, but constrain this particular transaction

3.`uvm_create` + modify + `uvm_send`
→ useful when you want procedural / direct control

4.Sequence properties
→ randomize the overall SCENARIO

5.Nested sequences
→ reuse smaller sequences to build bigger scenarios

EXECUTING SEQUENCES:
How do we conrol which sequences run on a UVC sequencer and when ?
Option A: default sequence;
tell UVM that whenever this sequencer enters run_phase, automatically run this particular sequence.
run_phase() (and every run sub - phase) has a default_sequence.Set default_sequence to a sequence to execute it in that phase.Otherwise
simulation enters run_phase
↓
UVM sees sequencer has default_sequence
↓
automatically starts that sequence

/* when the upstream read seqeucner enters run_phase, automatically run axi4l_read_seq*/
uvm_config_db#(uvm_object_wrapper)::set(
  this,
  "env.upstream_agent.read_sequencer.run_phase",
  "default_sequence",
  axi4l_read_seq::get_type()
);

OPTION B(and better): execute sequecnes directly on a UVC sequencer from a test class.
task run_phase(uvm_phase phase);
  
  axi4l_read_seq seq;
  
  phase.raise_objection(this);
  
  seq = axi4l_read_seq::type_id::create("seq");
  
  seq.start(env.upstream_agent.read_sequencer);
  
  phase.drop_objection(this);
  
endtask
create sequence
↓
start it on THIS sequencer
↓
sequence generates transactions
  ↓
  driver executes them
  
  So what is seq.start(sequencer) really doing ? -.RUN SEQ USING THIS SEQUENCER.
  The sequence's task body();
  then statr sexecuting
  test
  │
  │ seq.start(read_sequencer)
  ▼
  sequence body()
    │
    ├ ─ ─ creates read #1
    ├ ─ ─ creates read #2
    ├ ─ ─ creates read #3
    ├ ─ ─ creates read #4
    └ ─ ─ creates read #5
    │
    ▼
    read_sequencer
    │
    ▼
    read_driver
    │
    ▼
    AXI4 - Lite interface
    
    
    Executing UVC Sequence in test
    
    class mytest extends base_test;
      /* specifically a handle that points to a sequencer and sequence*/
      /* But the actual sequencer object was already constructed down inside their UVM hierarchy:*/
      axi4l_read_sequencer read_sqr; /* handle for every sequencer to be controlled */
      axi4l_read_sequence read_seq; /* handle for every sequence to be exeucted*/
      
      /* create the sequence object in build_phase*/
      /* here things are created*/
      function void build_phase(uvm_phase phase);
        read_seq = axi4l_read_seq::type_id::create("read_seq"); /* create sequence instance via UVM factory*/
        super.build_phase(phase);
      endfunction : build_phase
      
      /* connect the things created*/
      function void create_phase(uvm_phase phase);
        /* “Make my local handle point at the actual sequencer inside the agent.”*/
        read_sqr = read_seqr = env.upstream_agent.read_sequencer;
      endfunction : create_phase
      
      /* generate AXI4 traffic*/
      task run_phase(uvm_phase phase);
        assert (read_seq.randomize()); /* This randomizes the sequence object itself; matters only if our seq has rand properties itself to randomize scenarios*/
        read_seq.start(read_seqr);
      endtask : run_phase
      
    endclass