
module a4lite_tplvl #(
    parameter int DATA_WIDTH     = 32,
    parameter int ADDR_WIDTH     = 32,
    parameter     TIMEOUT_COUNTER = 200,
    parameter     NUM_SOURCES    = 2   /* bit 0 = write FSM, bit 1 = read FSM */
)(
    /* BASELINE SIGNALS */
    input  logic ACLK, aRESETn,
    /* MANAGER FACING - WRITE ADDRESS CHANNEL */
    input  logic AWVALID_m,
    input  logic [ADDR_WIDTH-1:0] AWADDR_m,
    input  logic [2:0] AWPROT_m,
    output logic AWREADY_m,
    /* SUBORDINATE FACING - WRITE ADDRESS CHANNEL */
    output logic AWVALID_s,
    output logic [ADDR_WIDTH-1:0] AWADDR_s,
    output logic [2:0] AWPROT_s,
    input  logic AWREADY_s,
    /* MANAGER FACING - WRITE DATA CHANNEL */
    input  logic WVALID_m,
    output logic WREADY_m,
    input  logic [DATA_WIDTH-1:0] WDATA_m,
    input  logic [DATA_WIDTH/8-1:0] WSTRB_m,
    /* SUBORDINATE FACING - WRITE DATA CHANNEL */
    output logic WVALID_s,
    input  logic WREADY_s,
    output logic [DATA_WIDTH-1:0] WDATA_s,
    output logic [DATA_WIDTH/8-1:0] WSTRB_s,
    /* MANAGER FACING - WRITE RESPONSE CHANNEL */
    input  logic BREADY_m,
    output logic BVALID_m,
    output logic [1:0] BRESP_m,
    /* SUBORDINATE FACING - WRITE RESPONSE CHANNEL */
    output logic BREADY_s,
    input  logic BVALID_s,
    input  logic [1:0] BRESP_s,
    /* MANAGER FACING - READ ADDRESS CHANNEL */
    input  logic ARVALID_m,
    output logic ARREADY_m,
    input  logic [ADDR_WIDTH-1:0] ARADDR_m,
    input  logic [2:0] ARPROT_m,
    /* SUBORDINATE FACING - READ ADDRESS CHANNEL */
    output logic ARVALID_s,
    input  logic ARREADY_s,
    output logic [ADDR_WIDTH-1:0] ARADDR_s,
    output logic [2:0] ARPROT_s,
    /* MANAGER FACING - READ DATA CHANNEL */
    output logic RVALID_m,
    input  logic RREADY_m,
    output logic [DATA_WIDTH-1:0] RDATA_m,
    output logic [1:0] RRESP_m,
    /* SUBORDINATE FACING - READ DATA CHANNEL */
    input  logic RVALID_s,
    output logic RREADY_s,
    input  logic [DATA_WIDTH-1:0] RDATA_s,
    input  logic [1:0] RRESP_s,
    /* Interrupt control */
    output logic irq,
    input  logic [NUM_SOURCES-1:0] enable_reg,
    input  logic [NUM_SOURCES-1:0] clear_reg
);

/* Internal signals  */


/* Baseline outputs that the monitor may override */
logic AWREADY_m_bl;
logic BVALID_m_bl;
logic [1:0] BRESP_m_bl;
logic ARREADY_m_bl;
logic RVALID_m_bl;
logic [DATA_WIDTH-1:0] RDATA_m_bl;
logic [1:0] RRESP_m_bl;

/* Write FSM <-> top-level */
logic w_violation_notif, w_inject_en, w_regulate_en;
/* Read FSM <-> top-level */
logic r_violation_notif, r_inject_en, r_regulate_en;
/* Interrupt controller -> FSMs (software acknowledged interrupt) */
logic sub_reset_done;
/* Active-high reset for FSMs (baseline uses active-low aRESETn) */
logic reset;
assign reset = ~aRESETn;
/* ------------------------------------------------------------------ */
/* Baseline register slice                                              */
/* ------------------------------------------------------------------ */
a4lite_baseline #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH)
) baseline (
    .ACLK       (ACLK),
    .aRESETn    (aRESETn),
    /* Write address */
    .AWVALID_m  (AWVALID_m),
    .AWADDR_m   (AWADDR_m),
    .AWPROT_m   (AWPROT_m),
    .AWREADY_m  (AWREADY_m_bl),   /* intermediate — gated below */
    .AWVALID_s  (AWVALID_s),
    .AWADDR_s   (AWADDR_s),
    .AWPROT_s   (AWPROT_s),
    .AWREADY_s  (AWREADY_s),
    /* Write data */
    .WVALID_m   (WVALID_m),
    .WREADY_m   (WREADY_m),       /* no override needed */
    .WDATA_m    (WDATA_m),
    .WSTRB_m    (WSTRB_m),
    .WVALID_s   (WVALID_s),
    .WREADY_s   (WREADY_s),
    .WDATA_s    (WDATA_s),
    .WSTRB_s    (WSTRB_s),
    /* Write response */
    .BREADY_m   (BREADY_m),
    .BVALID_m   (BVALID_m_bl),    /* intermediate — may be overridden */
    .BRESP_m    (BRESP_m_bl),     /* intermediate — may be overridden */
    .BREADY_s   (BREADY_s),
    .BVALID_s   (BVALID_s),
    .BRESP_s    (BRESP_s),
    /* Read address */
    .ARVALID_m  (ARVALID_m),
    .ARREADY_m  (ARREADY_m_bl),   /* intermediate — gated below */
    .ARADDR_m   (ARADDR_m),
    .ARPROT_m   (ARPROT_m),
    .ARVALID_s  (ARVALID_s),
    .ARREADY_s  (ARREADY_s),
    .ARADDR_s   (ARADDR_s),
    .ARPROT_s   (ARPROT_s),
    /* Read data */
    .RVALID_m   (RVALID_m_bl),    /* intermediate — may be overridden */
    .RREADY_m   (RREADY_m),
    .RDATA_m    (RDATA_m_bl),     /* intermediate — may be overridden */
    .RRESP_m    (RRESP_m_bl),     /* intermediate — may be overridden */
    .RVALID_s   (RVALID_s),
    .RREADY_s   (RREADY_s),
    .RDATA_s    (RDATA_s),
    .RRESP_s    (RRESP_s)
);

/* Write channel FSM */
write_fsm_a4lite #(
    .TIMEOUT_COUNTER (TIMEOUT_COUNTER)
) write_fsm (
    .clk             (ACLK),
    .reset           (reset),
    .AWVALID         (AWVALID_m),
    .AWREADY         (AWREADY_m_bl),
    .WVALID          (WVALID_m),
    .WREADY          (WREADY_m),
    .WLAST           (1'b1),       /* AXI4-Lite: single beat, WLAST always high */
    .BREADY          (BREADY_m),
    .BVALID          (BVALID_m_bl),
    .rcvy_ack        (sub_reset_done),
    .violation_notif (w_violation_notif),
    .inject_en       (w_inject_en),
    .regulate_en     (w_regulate_en)
);


/* Read channel FSM */
read_fsm_a4lite #(
    .TIMEOUT_COUNTER (TIMEOUT_COUNTER)
) read_fsm (
    .clk             (ACLK),
    .reset           (reset),
    .ARVALID         (ARVALID_m),
    .ARREADY         (ARREADY_m_bl),
    .RVALID          (RVALID_m_bl),
    .RREADY          (RREADY_m),
    .rcvy_ack        (sub_reset_done),
    .violation_notif (r_violation_notif),
    .inject_en       (r_inject_en),
    .regulate_en     (r_regulate_en)
);

/* Interrupt controller   */

interrupt_ctrl #(
    .NUM_SOURCES (NUM_SOURCES)
) intr_ctrl (
    .clk             (ACLK),
    .reset           (reset),
    .violation_notif ({r_violation_notif, w_violation_notif}), /* [1]=read, [0]=write */
    .enable_reg      (enable_reg),
    .clear_reg       (clear_reg),
    .sub_reset_done  (sub_reset_done),
    .irq             (irq)
);

/* Monitor overrides */
/* Write channel: freeze manager when regulating; inject SLVERR when subordinate is stalled */
assign AWREADY_m = w_regulate_en ? 1'b0   : AWREADY_m_bl;
assign BVALID_m  = w_inject_en   ? 1'b1   : BVALID_m_bl;
assign BRESP_m   = w_inject_en   ? 2'b10  : BRESP_m_bl;   /* 2'b10 = SLVERR */
/* Read channel */
assign ARREADY_m = r_regulate_en ? 1'b0   : ARREADY_m_bl;
assign RVALID_m  = r_inject_en   ? 1'b1   : RVALID_m_bl;
assign RRESP_m   = r_inject_en   ? 2'b10  : RRESP_m_bl;   /* 2'b10 = SLVERR */
assign RDATA_m   = r_inject_en   ? '0     : RDATA_m_bl;

endmodule
