class axi4l_sub_mem extends uvm_object;

  `uvm_object_utils(axi4l_sub_mem)

  /* 64 KB subordinate memory region */
  logic [DATA_WIDTH - 1:0] mem [0:16383];

  function new(string name = "axi4l_sub_mem");
    super.new(name);
    foreach (mem[i]) mem[i] = '0;
  endfunction


  function logic [DATA_WIDTH - 1:0] read(logic [ADDR_WIDTH - 1:0] addr);
    int unsigned word_idx;
    if (addr < SUB_ADDR_BASE || addr > SUB_ADDR_END) begin
      return '0;
    end
    word_idx = (addr - SUB_ADDR_BASE) >> 2;
    return mem[word_idx];
  endfunction : read


  function void write(
    logic [ADDR_WIDTH - 1:0] addr,
    logic [DATA_WIDTH - 1:0] data,
    logic [STRB_WIDTH - 1:0] strb
  );

    int unsigned word_idx;
    if (addr < SUB_ADDR_BASE || addr > SUB_ADDR_END) begin
      return;
    end
    word_idx = (addr - SUB_ADDR_BASE) >> 2;
    for (int byte_index = 0; byte_index < STRB_WIDTH; byte_index++) begin
      if (strb[byte_index]) begin
        mem[word_idx][8*byte_index +: 8] = data[8*byte_index +: 8];
      end
    end

  endfunction : write

endclass : axi4l_sub_mem