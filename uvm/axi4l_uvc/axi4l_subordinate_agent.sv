/*
 * AXI4-Lite Subordinate agent: represnets downstream AXI4-Lite subordinate
 *
 * Ownership of:
 *  1. One read sequencer
 *  2. One read driver
 *  3. One write sequencer
 *  4. One write driver
 *  5. One monitor
 *  6. One shared subordinate memory model (both read and write drivers recieve a handle to the same memory object)
*/

class axi4l_subordinate_agent extends uvm_agent;

  `uvm_component_utils(axi4l_subordinate_agent)


  /* UVM component handles*/
  axi4l_sub_mem mem_model;
  axi4l_monitor monitor;
  axi4l_read_sequencer read_sequencer;
  axi4l_write_sequencer write_sequencer;
  axi4l_read_driver read_driver;
  axi4l_write_driver write_driver;

  /* constructor*/
  function new (string name = "axi4l_subordinate_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build(phase);
    `uvm_info( "SUB_AGENT_BUILD", "Building dedicated AXI4-Lite subordinate agent", UVM_LOW)
    
    /* create memory model*/
    mem_model = axi4l_sub_mem::type_id::create("mem_model");
    if (mem_model == null) `uvm_fatal("NO_MEM_MODEL", "Memory model instatiation failed")

    /* Provide child components with respective roles*/
    uvm_config_db#(axi4l_role_e)::set(this, "read_driver", "role", AXI4L_SUBORDINATE); /* this: start config from this agent, read_driver: give val specifically to child instance named that, "role": this is they key the driver will use in get(), and value is the value stored*/
    uvm_config_db#(axi4l_role_e)::set(this, "write_driver", "role", AXI4L_SUBORDINATE);
    /* provide both drivers with a *handle/pointer* of the (shared) memory model */
    uvm_config_db#(axi4l_sub_mem)::set(this, "read_driver", "mem_model", mem_model);
    uvm_config_db#(axi4l_sub_mem)::set(this, "write_driver", "mem_model", mem_model);

    /* create monitor*/
    monitor = axi4l_monitor::type_id::create("monitor");

    /* create active components*/
    if (is_active == UVM_ACTIVE) begin
      read_sequencer = axi4l_read_sequencer::type_id::create("read_sequencer", this);
      read_driver = axi4l_read_driver::type_id::create("read_driver", this);
      write_sequencer = axi4l_write_sequencer::type_id::create("write_sequencer", this);
      write_driver = axi4l_write_driver::type_id::create("write_driver", this);
    end

  endfunction : build_phase

  virtual function void connect_phase (uvm_phase phase);
    super.connect_phase(phase);
    /* TLM connection; bind sequencers to drivers*/
   read_driver.seq_item_port.connect(read_sequencer.seq_item_export);
   write_driver.seq_item_port.connect(write_sequencer.seq_item_export);

  endfunction : connect_phase

endclass : axi4l_subordinate_agent