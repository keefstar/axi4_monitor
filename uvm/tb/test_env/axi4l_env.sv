
/* Your environment contains the verification components */
/* tb_top is the physical/real SystemVerilog world*/
/* tb_top = DUT + wires/interfaces*/
/* axi4l_env = agents + scoreboard + UVM verification stuff*/ /* config_db is essentially the bridge between those two worlds, giving the UVM agents access to the real interfaces in tb_top.*/
class axi4l_env extends uvm_env;
  
  `uvm_component_utils(axi4l_env)
  
  /* instantiate agents */
  axi4l_manager_agent upstream_agent;
  axi4l_subordinate_agent downstream_agent;
  /* add scoreboard*/
  axi4l_sb sb;
  /* add coverage */
  axi4l_read_protocol_coverage read_protocol_cov;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(axi4l_role_e)::set(this,"upstream_agent.monitor","role",AXI4L_MANAGER);
    uvm_config_db#(axi4l_role_e)::set(this,"downstream_agent.monitor","role",AXI4L_SUBORDINATE);
    
    upstream_agent = axi4l_manager_agent::type_id::create("upstream_agent", this);
    downstream_agent = axi4l_subordinate_agent::type_id::create("downstream_agent", this);
    read_protocol_cov = axi4l_read_protocol_coverage::type_id::create("read_protocol_cov",this);
    sb = axi4l_sb::type_id::create("sb", this);
  endfunction : build_phase
  
  /* In testbench connect phase, need to connect each monitor port to each appropraite scoreboard imp instance*/
  /* Connect each monitor's analysis port to the corresponding
  * scoreboard analysis implementation so the scoreboard
  * receives observed upstream and downstream transactions.
  */
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    /* Upstream monitor -> Scoreboard */
    upstream_agent.monitor.read_ap.connect(sb.upstream_read_imp);
    upstream_agent.monitor.write_ap.connect(sb.upstream_write_imp);
    
    /* Downstream monitor -> Scoreboard*/
    downstream_agent.monitor.read_ap.connect(sb.downstream_read_imp);
    downstream_agent.monitor.write_ap.connect(sb.downstream_write_imp);

    /* connect monitor and coverage instances*/
    upstream_agent.monitor.read_ap.connect(read_protocol_cov.analysis_export);
    downstream_agent.monitor.read_ap.connect(read_protocol_cov.analysis_export);
    
  endfunction : connect_phase
  
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
endclass : axi4l_env