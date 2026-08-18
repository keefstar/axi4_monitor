class axi4l_write_protocol_coverage extends uvm_subscriber (#axi4l_write item);

    `uvm_component_utils(axi4l_write_protocol_coverage)

  covergroup write_event_cg with function sample (
    axi4l_role_e role,
    axi4l_write_item::axi4l_read_kind_e kind,
    logic [ADDR_WIDTH-1:0] addr,
    logic [PROT_WIDTH-1:0] prot,
    axi_resp_e resp
  );

  
endclass : axi4l_write_protocol_coverage