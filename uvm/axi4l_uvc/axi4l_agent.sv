class axi4l_agent extends uvm_agent; /* agents cannot be paramaterized*/
  /*
   * uvm_agent provides a built-in is_active switch of type
   * uvm_active_passive_enum. UVM_ACTIVE means this agent creates/drives
   * sequencers and drivers; UVM_PASSIVE means it only observes via monitor.
   * Do not redeclare is_active here -- it is inherited from uvm_agent.
   */
  
  typedef enum {AXI4L_MANAGER, AXI4L_SUBORDINATE} axi4l_role_e;
  axi4l_role_e role = AXI4L_MANAGER;
  
  /* handles for our subcomponents (sequencer, driver, monitor); need to instantaite and connect in build/connect phase methods */
  axi4l_read_driver read_driver;
  axi4l_read_sequencer read_sequencer;
  axi4l_write_driver write_driver;
  axi4l_write_sequencer write_sequencer;
  axi4l_monitor monitor;
  
  `uvm_component_utils_begin(axi4l_agent)
  `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  /* rules for phases: Override a UVM phase only when your component needs to do something during that phase. Otherwise, inherit the default behavior from the parent.*/
  
  /* build phase is to create the UVM component hierarchy: use agent to create our subcomponents*/
  /* this use virtual to override UVM's own build_phase implementation in inheritance hierarchy*/
  virtual function void build_phase(uvm_phase phase);
    /* agent sub components are created in build */
    super.build_phase(phase); /* super.build_phase(phase); calls the parent class's build_phase first so it can do its generic UVM setup; then this child class adds its own component-specific build logic.*/
    /* Try to get this agent’s configured AXI role from the UVM config database and store it in role.”*/
    void'(uvm_config_db#(axi4l_role_e)::get(this, "", "role", role)); /* void because if fail, by default drop to manager*/
    monitor = axi4l_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin /* “Only create traffic-generating machinery if this AXI agent is configured as active.”*/
      rread_sequencer = axi4l_read_sequencer::type_id::create("read_sequencer", this);
      read_driver = axi4l_read_driver::type_id::create("read_driver", this);
      write_sequencer = axi4l_write_sequencer::type_id::create("write_sequencer", this);
      write_driver = axi4l_write_driver::type_id::create("write_driver", this);
    end
  endfunction
  
  /* after building our subcomponents in build_phase, wire them together in connect_phase*/
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    /* The seq_item_port.connect() method in UVM establishes the transaction-level modeling (TLM) connection between a uvm_driver and a uvm_sequencer.
    This allows the driver to pull transactions from the sequencer and return responses. It is executed within the connect_phase of your UVM environment or agent.*/
    if (is_active == UVM_ACTIVE) begin
      /* notes from TLM*/
      /* seq_item_port belongs to the driver; The driver uses it to call methods like get_next_item() and item_done().*/
      /* seq_item_export belongs to the sequencer. It exposes the sequencer’s transaction interface so something can connect to it.*/
      read_driver.seq_item_port.connect(read_sequencer.seq_item_export);
      write_driver.seq_item_port.connect(write_sequencer.seq_item_export);
    end
  endfunction
endclass : axi4l_agent