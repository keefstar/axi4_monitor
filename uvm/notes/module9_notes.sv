Factory / type - overdie:
The UVM factory lets you replace one class with another class without rewriting the rest of the testbench.

suppose we have:
class axi4l_write_item extends uvm_sequence_item;
  Your normal write item might allow addresses across your legal AXI4 - Lite address space.
  Later, you want one test where every write targets a specific address region, or where delays are much larger to stress your stall - containment controller.
  class axi4l_slow_write_item extends axi4l_write_item;
    
    constraint slow_delay_c {
      aw_delay inside {[10:20]};
      w_delay inside {[10:20]};
    }
    
  endclass
  Instead of going through your entire rb and changing axi4l_write_item to axi4l_slow_write_item,
  you tell the factory:
  Whenever somebody asks for an axi4l_write_item, give them an axi4l_slow_write_item instead.
  
  Normal:
  sequence | asks factory:
    |"give me axi4l_write_item"
    v
    axi4l_write_item
    
    With override:
    sequence | asks factory:
      |"give me axi4l_write_item"
      v
      FACTORY sees override
      v
      axi4l_slow_write_item
      
      Your sequence doesn ’ t need to know anything changed.
      
      There are two big things we might override:
      1) Data Objects:
      2) Components
      
      Three examples:
      1) Supporting test requirenents: “ I want specialized versions of my transactions for certain tests.”
      2) Reuse of Verification IP: “ I already wrote a generic AXI4 - Lite driver.I don ’ t want to rewrite the whole environment just because one test needs slightly different behavior.”
      3) Module - to - system reuse
      
      UVM Factory: A mechanism for creating UVM objects / components indirectly, allowing one registered class to be replaced by a derived class using an override without modifying the original testbench code.
      
      1.Constraint Layering
      
      Start with a normal transaction:
      class axi4l_read_item extends uvm_sequence_item;
        
        rand logic[ADDR_WIDTH - 1:0] addr;
        rand int unsigned ar_delay;
        
        constraint default_delay_c {
          ar_delay inside {[0:5]};
        }
        
      endclass
      
      The above is a general - purpose transaction.
      Now suppose, one particular test wants to stress timing:
      class slow_axi4l_read_item extends axi4l_read_item;
        
        constraint slow_delay_c {
          ar_delay inside {[10:20]};
        }
        
      endclass
      
      This is constraint layering.You did not destroy / rewrite original transaction
      Instead, we did:
      axi4l_read_item
      ↓ inherits
      slow_axi4l_read_item
      The child inherits everything but adds more specialized behaviour.
      
      2.But then is a problem.
      Suppose the entire testbench was written expecting axi4l_read_item.without the factory,
      I would have to go aorund changing the code to support slow_axi4l_read_item.addr
      If I decide "For this timeout test, I want a specialized transaction called timeout_read_item.", I don't want to rewrite half of my UVM environment.
      That is teh exact problem the factory solves.
      
      3.The factory puts an intermediary between your code and new()
      Normally:
      your code
      |
      |new()
      v
      axi4l_read_item object
      
      Factory approach:
      your code
      |
      |"Factory, create axi4l_read_item"
      v
      UVM FACTORY
      |
      |checks override table
      v
      creates appropriate object
      
      Normally, the factory might say:
      Requested:
      axi4l_read_item
      
      No override exists.
      
      → create axi4l_read_item
      
      But you can configure:
      FROM TO
      axi4l_read_item → timeout_read_item
      
      Then:
      Requested:
      axi4l_read_item
      
      Factory checks override...
      
      Ah!
      axi4l_read_item → timeout_read_item
      
      → create timeout_read_item
      
      4.This is why UVM keeps making you write type_id::create()
      Compare
      req = new("req") versus req = axi4l_read_item::type_id::create("req");
      new() means: definitely instnatiate exactly axi4l_read_item and factory cannot inetrevene
      type_id::create() means: Ask the UVM factory what object I should instantiate.
      type_id::create()
      ↓
      FACTORY
      ↓
      check override
      / \
      none exists
      ↓ ↓
      original replacement
      
      5.What are those uvm_object_utils macros actually doing ?
      Probably written something like: `uvm_object_utils(axi4l_read_item)
      this registers the class with UVM factory.
      Factory registry:
      
      Registered classes:
      -- -- -- -- -- -- -- -- -- -- -- -- -
      axi4l_read_item
      axi4l_write_item
      some_other_item
      ...
      So later we can do: axi4l_read_item::type_id::create(...) becaude UVM knows that class exists.
      Similar extensino to components
      
      Operation of the factory therefore requires:
      1) Registration of all the UVM types with the factory
      eg: `uvm_object_utils(axi4l_read_item);
      `uvm_component_utils(axi4l_driver)
      2) Create things through the uvm_factory
      Instead of item = new("item");
      , do item = axi4l_read_item::type_id::create("item");
      (to give factory an opportunity to substitute another class)
      3) Configure an override:
      axi4l_read_item::type_id::set_type_override(
        timeout_read_item::get_type()
      );
      Conceptually:
      Factory override table
      FROM TO
      -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      axi4l_read_item → timeout_read_item
      
      
      1) create() in AXI4 - Lite thesis
      
      Suppose we have
      class axi4l_read_item extends uvm_sequence_item;
        
        `uvm_object_utils(axi4l_read_item)
        
        rand logic[ADDR_WIDTH - 1:0] addr;
        rand int unsigned ar_delay;
        rand int unsigned rready_delay;
        
      endclass
      
      somewhere, instead of req = new("req");
      we do req = axi4l_read_item::type_id::create("req");
      for reasons explained above
      
      2) type override: very relevant to transaction
      suppose a normalr ead item is:
      class axi4l_read_item extends uvm_sequence_item;
        rand int unsigned ar_delay;
        rand int unsigned rready_delay;
        
        constraint normal_delay_c {
          ar_delay inside {[0:5]};
          rready_delay inside {[0:5]};
        }
        `uvm_object_utils(axi4l_read_item)
      endclass
      And we also have a subclass:
      class delayed_axi4l_read_item extends axi4l_read_item;
        
        `uvm_object_utils(delayed_axi4l_read_item)
        
        constraint delayed_c {
          rready_delay inside {[4:5]};
        }
        
      endclass
      Then, in a dedicatde test we can say conceptually:
      set_type_override_by_type(
        axi4l_read_item::get_type(),
        delayed_axi4l_read_item::get_type()
      );
      Such that, everywhere the TB does axi4l_read_item::type_id::create(...), thef actory actually creates delayed_axi4l_read_item
      3) 2 is relevant for thesis because of the dedicatde tests
      tests will include:
      normal passthrough
      read timeout
      write - data timeout
      write - response timeout
      flush / recovery
      multiple outstanding accesses
      backpressure
      I can make specialized transaction subclasses:
      axi4l_read_item
      ↑
      ├ ─ ─ high_backpressure_read_item
      └ ─ ─ timeout_stress_read_item
      
      4.changing procedural behaviour is more interesting for downstreama gent.
      Your downstream driver is pretending to be the subordinate behind your stall - containment controller.
      But your thesis specifically needs to test hung subordinate behavior.
      You could have: class axi4l_downstream_driver extends uvm_driver;
      and eventually derive: class hung_read_driver extends axi4l_downstream_driver;
      That forces your DUT ’ s timeout logic to fire.
      Thus, timeout test could do:
      axi4l_downstream_driver
      ↓ type override
      hung_read_driver
      
      5.Why override has to happe before creation:
      Order matters!!!
      1.Tell factory:
      downstream_driver → hung_downstream_driver
      
      2.Build environment
      
      3.Environment asks factory:
      "create downstream_driver"
      
      4.Factory sees override
      
      5.Creates hung_downstream_driver
      
      FOR TESTS:
      function void build_phase(uvm_phase phase);
        // first configure override
        set_type_override_by_type(
          axi4l_downstream_driver::get_type(),
          hung_downstream_driver::get_type()
        );
        
        // then build rest of hierarchy
        super.build_phase(phase);
        
      endfunction
      
      6) Type override vs instance override
      type override:
      set_type_override_by_type(
        original::get_type(),
        replacement::get_type()
      );
      Replace requests for this type broadly.
      For my env:
      ALL axi4l_read_item
      ↓
      timeout_stress_read_item
      
      Instance override: only replace the object / comopnent created at a PARTICULAR hierarchy path.This is much more targeted.
      Imagine, env has two similar suboridnate agents.
      env
      ├ ─ ─ downstream_agent0
      │ └ ─ ─ driver
      │
      └ ─ ─ downstream_agent1
      └ ─ ─ driver
      if we want agent0 to simulate hung subordinate, use instance only.
      
      OVERRIDE RULES:
      Rule A): Instance overrides beat type overrides.
      Instance overrides will win.
      Rule B): Instance override paths can use wildcards
      Rule C): Overrides can chain: Overriding type A to B, and B to C, means type A can become C, not B.Subordinate