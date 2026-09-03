module axi4l_subordinate_model (
  input logic clk,
  input logic rst_n,
  axi4l_if.a4l_sub s
);

  import a4lite_pkg::*;

  localparam int MEM_WORDS = 16384;
  localparam int READ_DELAY = 4;
  localparam int WRITE_DELAY = 4;

  logic [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];
  logic aw_pending, w_pending;
  logic [ADDR_WIDTH-1:0] awaddr_q;
  logic [DATA_WIDTH-1:0] wdata_q;
  logic [STRB_WIDTH-1:0] wstrb_q;
  int read_count, write_count;
  integer i;

  /* Read path */
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {s.arready, s.rvalid, s.r, read_count} <= '0;
    end else begin
      s.arready <= !s.rvalid && (read_count == 0);

      /* Accept read request and prepare response */
      if (s.arvalid && s.arready) begin
        $display("[SUB_MODEL] AR handshake @ %0t addr=%h", $time, s.ar.addr);
        read_count <= READ_DELAY;

        if ((s.ar.addr >= SUB_ADDR_BASE) &&
            (s.ar.addr <= SUB_ADDR_END))
          s.r.data <= mem[(s.ar.addr - SUB_ADDR_BASE) >> 2];
        else
          s.r.data <= '0;

        s.r.resp <= RESP_OKAY;
      end else if (read_count > 1) begin
        read_count <= read_count - 1;
      end else if (read_count == 1) begin
        $display("[SUB_MODEL] asserting RVALID @ %0t", $time);
        read_count <= 0;
        s.rvalid <= 1;
      end

      /* Hold RVALID until response is accepted */
      if (s.rvalid && s.rready)
        s.rvalid <= 0;
    end
  end

  /* Write path */
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {s.awready, s.wready, s.bvalid, s.b,
       aw_pending, w_pending, write_count} <= '0;
    end else begin
      s.awready <= !aw_pending && !s.bvalid;
      s.wready <= !w_pending && !s.bvalid;

      /* AW and W are accepted independently */
      if (s.awvalid && s.awready) begin
        awaddr_q <= s.aw.addr;
        aw_pending <= 1;
      end

      if (s.wvalid && s.wready) begin
        wdata_q <= s.w.data;
        wstrb_q <= s.w.strb;
        w_pending <= 1;
      end

      /* Complete write after both AW and W are received */
      if (aw_pending && w_pending && write_count == 0 && !s.bvalid) begin
        write_count <= WRITE_DELAY;

        if ((awaddr_q >= SUB_ADDR_BASE) &&
            (awaddr_q <= SUB_ADDR_END)) begin
          for (i = 0; i < STRB_WIDTH; i++)
            if (wstrb_q[i])
              mem[(awaddr_q - SUB_ADDR_BASE) >> 2][8*i +: 8]
                <= wdata_q[8*i +: 8];
        end
      end else if (write_count > 1) begin
        write_count <= write_count - 1;
      end else if (write_count == 1) begin
        write_count <= 0;
        s.b.resp <= RESP_OKAY;
        s.bvalid <= 1;
      end

      /* Hold BVALID until response is accepted */
      if (s.bvalid && s.bready) begin
        s.bvalid <= 0;
        {aw_pending, w_pending} <= '0;
      end
    end
  end

endmodule : axi4l_subordinate_model