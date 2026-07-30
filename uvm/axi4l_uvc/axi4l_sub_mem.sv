class axi4l_sub_mem extends uvm_object;

  `uvm_object_utils(axi4l_sub_mem)

  /* 1 KB MEMORY */
  logic [DATA_WIDTH - 1: 0] mem [0:255]; /* each mem element is one complete AXI data word */

  function new (string name = "axi4l_sub_mem");
    super.new(name);
    foreach (mem[i]) mem[i] = '0;
  endfunction 

  function logic [DATA_WIDTH -1 : 0] read (logic [ADDR_WIDTH-1 :0] addr);

    /* AXI4L addresses are byte addresses, but memory array is indexed by words. */
    /* 1 word = 4 bytes; memory word index, given an address, is addr/4*/
    return mem[addr >> 2];

  endfunction : read


  /* recall writes in AXI4L*/
  /* DATA_WIDTH = 32, STRB_WIDTH = 4 bits*/
  /* A 32-bit word has 4 bytes. STRB has 4 bits, one for each byte*/
  /* WSTRB controls which parts of RAM for a given address is overwritten by a write (1 is overwrite, 0 is not)*/
  function void write (
    logic [ADDR_WIDTH-1:0] addr,
    logic [DATA_WIDTH-1:0] data,
    logic [STRB_WIDTH-1:0] strb
  );

  int word_idx = addr >> $clog2(STRB_WIDTH); /* account for 32 vs 64 bit*/
  for (int byte_index = 0; byte_index < STRB_WIDTH; byte_index ++) begin
    if (strb[byte_index]) begin
      mem[word_idx][8*byte_index +:8] = data[8*byte_index +: 8];
    end
  end

  endfunction : write

endclass : axi4l_sub_mem