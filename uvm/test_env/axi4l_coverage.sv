what does confirguation mean ?

rough environement right now is:
axi4l_test
└ ─ ─ axi4l_env
├ ─ ─ upstream_agent
│ ├ ─ ─ sequencer
│ ├ ─ ─ driver
│ └ ─ ─ monitor
│
├ ─ ─ downstream_agent
│ ├ ─ ─ sequencer / driver
│ └ ─ ─ monitor
│
└ ─ ─ scoreboard

Confirgation lets the test these comopennts things like:
upstream_agent = ACTIVE downstream_agent = ACTIVE timeout behavior = enabled downstream response delay = 300 cycles without rewriting the agents themsleves.2) What does is_actibe actually mean ? An agent can be UVM_ACTIVE or UVM_PASSIVE ACTIVE agent : generates / drives agent(includes sequencer, driver, monitor) PASSIVE agent(watches traffic only) (just monintor, no sequencer / driver) Context of my project: UVM TB has to emulate both manager and subordinate.So during main DUT verification UPSTREAM agentACTIVE;
generates: AR, AW, W.accepts: R, B
DOWNSTREAM agent ACTIVE;
accepts: AW, AR, W.Generates R, B.

Why woudl we ever make an agent passive ?
Imagine later you integrate your guard into a bigger RTL system with a REAL axi manager and a REAL axi subordinate.
Now you might attach a UVM agent purely to observe traffic.You don ’ t want the UVM driver fighting the real RTL.
So agent become spassive, and topology of our agent can be configured according to property values.
You ’ re literally changing which pieces of the UVM hierarchy exist.

Why must configuration happen BEFORE components are created ?
Properties must be set before components are created.
This parent - to - child configuration is one of the main things Module 8 teaches you.

This will matter beyond is_active;
This is where the module becomes especially useful for the thesis.
You can configure downstream subordinate agent with knobs such as:
int r_response_delay;
int b_response_delay;
bit stall_reads;
bit stall_writes;
Then different tests could configure it differently.

SETTING CONFIG PROPERTIES:
uvm_config_db: think of it as a config mailbox / database where a higher - level component says:
“ When this lower - level component gets built, give it this setting.”
uvm_config_db#(< type >)::set(
  < context >,
  < instance >,
  < field >,
  < value >
);

Thesis example: From this test, configure env.upstream_agent, set its is_active property to UVM_ACTIVE.
uvm_config_db#(uvm_active_passive_enum)::set(
  this,
  "env.upstream_agent",
  "is_active",
  UVM_ACTIVE
);