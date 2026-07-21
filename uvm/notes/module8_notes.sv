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
upstream_agent = ACTIVE downstream_agent = ACTIVE timeout behavior = enabled downstream response delay = 300 cycles without rewriting the agents themsleves .2) What does is_actibe actually mean ? An agent can be UVM_ACTIVE or UVM_PASSIVE ACTIVE agent : generates / drives agent(includes sequencer, driver, monitor) PASSIVE agent(watches traffic only) (just monintor, no sequencer / driver) Context of my project: UVM TB has to emulate both manager and subordinate.So during main DUT verification UPSTREAM agentACTIVE;
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

four important arguments:
1) context: this means usually'interpret this instance path relative to me'
Suppose the code is inside axi4l_test.Then'this, "env.upstream_agent" means
axi4l_test
└ ─ ─ env
└ ─ ─ upstream_agent

2) instance: "env.upstream_agent"
This tells UVM which component the setting applies to.
axi4l_test
└ ─ ─ env
├ ─ ─ upstream_agent
└ ─ ─ downstream_agent
could do up / downstream so you could configure them independently.

3) field: "is_active"
This is basically the name of the property you ’ re configuring.
later we may have:
"max_response_delay"
"stall_enable"
"vif"

4) value: UVM_ACTIVE
This is the actual value you ’ re assigning.
"is_active", UVM_ACTIVE

What is the#(< type >) part ?
uvm_config_db#(uvm_active_passive_enum)
This tells config database: “ The thing I ’ m storing has this type.”
Example:
uvm_config_db#(int) stores an int
uvm_config_db#(bit) stores a bit
uvm_config_db#(virtual axi4l_if) stores a virtual interface handle

A very important use in your AXI4 - Lite testbench: virtual interfaces
Our UVM driver is a class.Our AXI signals exist in a SystemVerilog interface / module world:
class world RTL world
  How does the class get access to those physical signals ?
  Usually through a virtual interface, passed using uvm_config_db.
  uvm_config_db#(virtual axi4l_if)::set(
    null,
    "uvm_test_top.env.upstream_agent.*",
    "vif",
    upstream_if
  );
  So config_db isn ’ t just some abstract UVM bureaucracy.
  
  It is literally often how your UVM class - based testbench gets connected to your real DUT signals.
  
  That will matter a lot when you start implementing your driver.
  Why this giant stupid uvm_config_db thing ?
  
  Because UVM components are built hierarchically, often through the factory, and lower - level components may not even exist yet when the higher - level test wants to configure them.
  config_db lets you essentially leave a note ahead of time:
  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
  │ CONFIG DATABASE │
  │ │
  │ env.upstream_agent │
  │ is_active = UVM_PASSIVE │ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ ↓ later upstream_agent gets constructed ↓ "Ah, I'm supposed to be passive." uvm_config_db allows higher - level UVM components to set configuration values for lower - level components before they are built.set() specifies the property type, target instance, field name, and value.It is commonly used for agent active / passive settings, virtual interfaces, and test - specific behavior / configuration.WHAT IS SET IN UVM CONTEXT: In uvm_config_db#(int)::set(...) set means: store a config value in UVM config database so another componen can retreieve it later with get() uvm_config_db#(int)::set(this, "agent", "num_transactions", 100);
  “ Store the integer 100 under the name num_transactions for the component path agent.”
  Later, a component can retrieve it with:
  int num_transactions;
  uvm_config_db#(int)::get(this, "", "num_transactions", num_transactions);
  set() = put / store configuration get() = retrieve configuration Continuing: uvm_config_int::set(this, "tb.yapp.agent", "is_active", UVM_PASSIVE);
  
  1) set() happens first;
  the child sees it later.
  It writes it into the config database.
  2) Why are the paths strings ? -> You write "env.upstream_agent" instead of directly referencing some object like : env.upstream_agent
  because at the time you call set(), the agent might not exist yet.
  “ When a component eventually appears at this hierarchy path, this setting applies to it.”
  That is why the config database uses strings.
  3) The hierarchy / path must actually match.
  Support hierarchy is:
  uvm_test_top
  └ ─ ─ env
  ├ ─ ─ upstream_agent
  └ ─ ─ downstream_agent
  Then
  uvm_config_db#(...)::set(
    this,
    "env.upstream_agent",
    ...
  );
  makes sense, if'this'is your test.
  But suppose we write "env.upstream" when the instance is really called upstream_agent
  Then the config may simply not match anything.
  debug quetions:
  field name correct ?
  instance path correct ?
  type correct ?
  
  4) Wildcards: useful, but don ’ t overcomplicate them yet
  uvm_config_int::set(this, "tb.env.agent?", "is_active", UVM_PASSIVE) /* ? for 1 character addiitons like tb.env.agent1, tb.env.agent2, etc*/
  uvm_config_int::set(this, "tb.env.agent*", "is_active", UVM_PASSIVE) /* activate all intstances with agent in pathname*/
  uvm_config_int::set(this, "*", "recording_detail", 1) /* enable transaction recording */
  
  5) Precedence: who wins if two settings conflict ?
  Higher scope takes precedence over lower scope.
  For example:
  TEST
  └ ─ ─ ENV
  └ ─ ─ AGENT
  Suppose environment says agent is ACTIVE, but the test says agent is PASSIVE
  The higher - level test configuration generally wins.
  This is useful because your reusable environment can have sensible defaults:
  upstream_agent = ACTIVE downstream_agent = ACTIVE Then a specialized test can override something.BASE ENV: downstream_agent = ACTIVE SPECIAL TEST: downstream_agent = PASSIVE → special test overrides default WITHIN THE SAME SCOPE, last setting wins .6) DEBUGGING CONFIG FAILURES: Config bugs can be silent: uvm_config_db#(int)::set(this, "env.downstream_agent", "response_delay", 300);
  Say we write ^ ^^but inside the agent, we accidentally request: response_delays.PLURAL.
  No match, so our variable stays as default value and we wonder why our timeout test never times out.
  Mental debugging checklist is:
  1.Did I SET it before build ?
  2.Is the INSTANCE PATH correct ?
  3.Is the FIELD NAME identical ?
  4.Is the TYPE identical ?
  5.Did the receiver actually GET / use it ?
  That is far more useful than memorizing the specific check_config_usage() syntax right now.
  
  7) set() and get() are two methods you actually care about.