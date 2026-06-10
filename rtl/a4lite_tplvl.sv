/** Author: Keefee Rahman
 * @brief AXI4-Lite Watchdog IP Top Level.
 * Sits between AXI4-Lite manager and subordinate. Passes all signals
 * through a register slice. Monitors write and read channels for
 * liveness stalls. On detection: regulates READY signals and injects
 * SLVERR responses. Notifies software via interrupt.
 */

import watchdog_pkg::*;
module a4lite_tplvl #(
    parameter int DATA_WIDTH      = 32,
    parameter int ADDR_WIDTH      = 32,
    parameter     TIMEOUT_COUNTER = 200,   /* bit 0 = write FSM, bit 1 = read FSM */
)(
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
    /* INTERRUPT CONTROL */
    output logic irq,
    input  logic [NUM_SOURCES-1:0] enable_reg,
    input  logic [NUM_SOURCES-1:0] clear_reg
);

/* Internal wires */
/* Registered pass-through values before monitor override */
logic AWREADY_m_reg;
logic  BVALID_m_reg;
logic [1:0] BRESP_m_reg;
logic ARREADY_m_reg;
logic  RVALID_m_reg;
logic [1:0] RRESP_m_reg;
logic [DATA_WIDTH-1:0] RDATA_m_reg;

/* Write FSM control signals */
logic w_violation_notif, w_inject_en, w_regulate_en;
/* Read FSM control signals */
logic r_violation_notif, r_inject_en, r_regulate_en;
/* Interrupt controller -> FSMs */
logic [NUM_SOURCES-1:0] rcvy_ack;
logic [NUM_SOURCES-1:0] violation_vec;
assign violation_vec[WRITE_FAULT] = w_violation_notif;
assign violation_vec[READ_FAULT]  = r_violation_notif;
/* Active-high reset derived from active-low ARESETn */
logic reset;
assign reset = ~aRESETn;

/*  *//
/* Mirrors a4lite_baseline exactly for signals not overridden below.   */
always_ff @(posedge ACLK) begin
    if (!aRESETn) begin
        /* WRITE ADDRESS CHANNEL */
        AWVALID_s    <= '0;
        AWADDR_s     <= '0;
        AWPROT_s     <= '0;
        AWREADY_m_reg <= '0;
        /* WRITE DATA CHANNEL */
        WVALID_s  <= '0;
        WDATA_s   <= '0;
        WSTRB_s   <= '0;
        WREADY_m  <= '0;
        /* WRITE RESPONSE CHANNEL */
        BREADY_s     <= '0;
        BVALID_m_reg <= '0;
        BRESP_m_reg  <= '0;
        /* READ ADDRESS CHANNEL */
        ARVALID_s     <= '0;
        ARADDR_s      <= '0;
        ARPROT_s      <= '0;
        ARREADY_m_reg <= '0;
        /* READ DATA CHANNEL */
        RVALID_m_reg <= '0;
        RREADY_s     <= '0;
        RDATA_m_reg  <= '0;
        RRESP_m_reg  <= '0;
    end else begin
        /* WRITE ADDRESS CHANNEL */
        AWVALID_s     <= AWVALID_m;
        AWADDR_s      <= AWADDR_m;
        AWPROT_s      <= AWPROT_m;
        AWREADY_m_reg <= AWREADY_s;   /* registered — may be gated by regulate_en */
        /* WRITE DATA CHANNEL */
        WVALID_s <= WVALID_m;
        WDATA_s  <= WDATA_m;
        WSTRB_s  <= WSTRB_m;
        WREADY_m <= WREADY_s;
        /* WRITE RESPONSE CHANNEL */
        BREADY_s     <= BREADY_m;
        BVALID_m_reg <= BVALID_s;     /* registered — may be overridden by inject_en */
        BRESP_m_reg  <= BRESP_s;      /* registered — may be overridden by inject_en */
        /* READ ADDRESS CHANNEL */
        ARVALID_s     <= ARVALID_m;
        ARADDR_s      <= ARADDR_m;
        ARPROT_s      <= ARPROT_m;
        ARREADY_m_reg <= ARREADY_s;   /* registered — may be gated by regulate_en */
        /* READ DATA CHANNEL */
        RVALID_m_reg <= RVALID_s;     /* registered — may be overridden by inject_en */
        RREADY_s     <= RREADY_m;
        RDATA_m_reg  <= RDATA_s;      /* registered — may be overridden by inject_en */
        RRESP_m_reg  <= RRESP_s;      /* registered — may be overridden by inject_en */
    end
end

/* Monitor overrides  */
/* When regulate_en: block new transactions by pulling READY low. */
/* When inject_en: substitute SLVERR response for frozen subordinate.*/
/* Write channel overrides */
assign AWREADY_m = w_regulate_en ? 1'b0 : AWREADY_m_reg;
assign BVALID_m = w_inject_en ? 1'b1 : BVALID_m_reg;
assign BRESP_m  = w_inject_en ? 2'b10: BRESP_m_reg; /* 2'b10 = SLVERR */
/* Read channel overrides */
assign ARREADY_m = r_regulate_en ? 1'b0  : ARREADY_m_reg;
assign RVALID_m = r_inject_en ? 1'b1 : RVALID_m_reg;
assign RRESP_m = r_inject_en ? 2'b10 : RRESP_m_reg;   /* 2'b10 = SLVERR */
assign RDATA_m = r_inject_en ? '0 : RDATA_m_reg;   /* zeros on injected read */
/* Module instantiations */
/* Write channel FSM */
write_fsm_a4lite #(
    .TIMEOUT_COUNTER (TIMEOUT_COUNTER)
) write_fsm (
    .clk(ACLK), .reset(reset),
    .AWVALID(AWVALID_m),.AWREADY(AWREADY_m_reg),  /* post-register value */
    .WVALID(WVALID_m),.WREADY(WREADY_s), .WLAST(1'b1), /* AXI4-Lite: always single beat */
    .BREADY(BREADY_m), .BVALID(BVALID_m_reg),  /* post-register subordinate BVALID */
    .rcvy_ack (rcvy_ack[WRITE_FAULT]),
    .violation_notif(w_violation_notif), .inject_en(w_inject_en),
    .regulate_en(w_regulate_en)
);
/* Read channel FSM */
read_fsm_a4lite #(
    .TIMEOUT_COUNTER(TIMEOUT_COUNTER)
) read_fsm (
    .clk(ACLK), .reset(reset),
    .ARVALID(ARVALID_m), .ARREADY(ARREADY_m_reg),
    .RVALID(RVALID_m_reg), .RREADY(RREADY_m),
    .rcvy_ack(rcvy_ack[READ_FAULT]),
    .violation_notif(r_violation_notif),
    .inject_en(r_inject_en),
    .regulate_en(r_regulate_en)
);
/* Interrupt controller */
interrupt_ctrl #(
    .NUM_SOURCES (NUM_SOURCES)
) intr_ctrl (
    .clk(ACLK),
    .reset(reset),
    .violation_notif(violation_vec), /* [1]=read [0]=write */
    .enable_reg(enable_reg),
    .clear_reg(clear_reg),
    .rcvy_ack(rcvy_ack),
    .irq(irq)
);

endmodule