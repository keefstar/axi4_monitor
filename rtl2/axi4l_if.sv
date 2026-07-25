interface axi4l_if (input logic clk, input logic aresetn);
  import a4lite_pkg::*;
  /* Write address channel */
  logic awvalid, awready;
  aw_beat_t aw;
  /* Write data channel*/
  logic wvalid, wready;
  w_beat_t w;
  /* Write response channel*/
  logic bvalid, bready;
  b_beat_t b;
  /* Read address channel */
  logic arvalid, arready;
  ar_beat_t ar;
  /* Read data channel */
  logic rvalid, rready;
  r_beat_t r;
  
  /* DATA FLOWS FROM MANAGER, THROUGH GUARD, THOTOUGH TO THE SUBORDINATE */
  /* UPSTREAM MEANS TOWARDS THE MANAGER. DOWNSTREAM MEANS THROUGH THE SUBORDINATE */
  /* GUARD IS TWO DEVICES IN ONE BOX. ON CABLE S, it appears to be a subordinate. the real amanger plugs in, sees something
  that accepts requests and returns responses */
  /* On cable M, it pretends to be a manager. The SUB plugs in, sees something issuin g requests and cant tell it isnt rela manage r*/
  /* m. names the cable, not the driver. */
  
  /* A port's role tells you the mask your module wears on that link; teh signal name tels you which mask drives it. if they match, you drive. if they don't you read */
  
  /* 
  m.awvalid → mask = manager; AWVALID is manager-driven → match → drive.
  m.bvalid → mask = manager; BVALID is subordinate-driven → mismatch → read.
  s.awvalid → mask = subordinate; AWVALID is manager-driven → mismatch → read.
  s.bvalid → mask = subordinate; BVALID is subordinate-driven → match → drive.
  */
  
  /* Modports here create differnt views of an interface; specify a susbect of interface signals accessible to 1) manager, 2) subordinate, 3) uvm monitor */
  /* Directions are specified accordingly*/
  
  /* A modport defines how a module sees and uses this interface */
  /* the input/output directions are from the perspective of the module connected through the modport */
  
  /* Manager role:
  - Sends requests: AW, W, and AR
  - Recieves responses B and R.
  */
  /* The a4l_mgr modport makes the module connected through that view behave as a manager. In your design, that module is the guard. */
  /* whoever plugs in here as a4l_mgr will drive awvalid/aw, and receive awready." Your guard is that whoever */
  modport a4l_mgr(
    // Requests driven toward the subordinate
    output awvalid, aw,
    output wvalid, w,
    output arvalid, ar,
    // Response acceptance driven by the manager
    output bready,
    output rready,
    // Request acceptance received from the subordinate
    input awready,
    input wready,
    input arready,
    // Responses received from the subordinate (to the guard)
    input bvalid, b,
    input rvalid, r
  );
  /* Suboridnate role:
  - Recieves requests: AW, W, and AR
  - Sends responses: B and R.
  */
  modport a4l_sub(
    /* requests recieved by the manager*/
    input awvalid, aw,
    input wvalid, w,
    input arvalid, ar,
    /* response acceptance recieved from the manager*/
    input bready, rready,
    /* Request acceptance driven towards the manager */
    output awready,
    output wready,
    output arready,
    /* responses driven towards the manager (from the guard)*/
    output bvalid,
    output b,
    output rvalid,
    output r
  );
  /* VALID is driven bu the source of a channel */
  /*READY is driven by the reciever of a channel*/
  /* syntax convention
  A port named 's' using a4l_sb means this module acts as the subordinate on that connection.
  It does not mean that every s.* signal is driven by the suboridnate. For example. s.arvalid is an input driven by the external manager, to the sub,
  while s.arready is an output driven by this sub module.
  Similarly, a port named 'm' using a4l_mng means this module acts as the manager on that connection. For example, this mananger module drives m.arvalid and recieves m.arready
  */
  
  /*  Clocking-block directions describe the testbench’s role, not the DUT’s role.*/
  /* Samples all channel signals at a fixed skew before posedge clk, so a
     class-based monitor never races the DUT for the value at the same edge */
  clocking mon_cb @(posedge clk);
    input awvalid, awready, aw, wvalid, wready, w,
    bvalid, bready, b, arvalid, arready, ar,
    rvalid, rready, r;
  endclocking
  
  modport uvm_mon(
    clocking mon_cb,
      input aresetn
    );
    
endinterface : axi4l_if