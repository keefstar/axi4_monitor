import firewall_pkg::*;
/* All widths (ADDR_WIDTH, DATA_WIDTH, PROT_WIDTH, ID_WIDTH, LEN_WIDTH)
 * come from firewall_pkg — no local parameter declarations here so this
 * module and the scoreboard can never silently disagree on a field width. */
module a4_baseline (
    input logic ACLK, aRESETn,

    /* ── WRITE ADDRESS CHANNEL ─────────────────────────────────────────
     * CHANGED: added AWID and AWLEN.
     * AWID identifies the transaction; the write scoreboard stores it in
     * trans_id and later matches it against BID on the B channel.
     * AWLEN is the burst length (beats - 1); stored in beats_left so the
     * W Data Tracker knows how many W beats belong to this transaction. */
    input  logic [ID_WIDTH-1:0]   AWID_m,
    input  logic AWVALID_m,
    input  logic [ADDR_WIDTH-1:0] AWADDR_m,
    input  logic [PROT_WIDTH-1:0] AWPROT_m,
    input  logic [LEN_WIDTH-1:0]  AWLEN_m,
    output logic AWREADY_m,

    output logic [ID_WIDTH-1:0]   AWID_s,
    output logic AWVALID_s,
    output logic [ADDR_WIDTH-1:0] AWADDR_s,
    output logic [PROT_WIDTH-1:0] AWPROT_s,
    output logic [LEN_WIDTH-1:0]  AWLEN_s,
    input  logic AWREADY_s,

    /* ── WRITE DATA CHANNEL ────────────────────────────────────────────
     * CHANGED: added WLAST.
     * Full AXI4 has variable-length bursts, so WLAST marks the final
     * beat of a burst — without it the W Data Tracker cannot tell when
     * to pop the W-order FIFO and advance the slot from WAIT_W to WAIT_B.
     * AXI4-Lite always implied WLAST=1; here it is an actual signal. */
    input  logic WVALID_m,
    output logic WREADY_m,
    input  logic [DATA_WIDTH-1:0]   WDATA_m,
    input  logic [DATA_WIDTH/8-1:0] WSTRB_m,
    input  logic WLAST_m,

    output logic WVALID_s,
    input  logic WREADY_s,
    output logic [DATA_WIDTH-1:0]   WDATA_s,
    output logic [DATA_WIDTH/8-1:0] WSTRB_s,
    output logic WLAST_s,

    /* ── WRITE RESPONSE CHANNEL ────────────────────────────────────────
     * CHANGED: added BID.
     * The subordinate echoes the transaction ID on BID so the manager
     * can match a response to an outstanding request out-of-order.
     * The B Match/Absorb CAM compares incoming BID against every
     * non-EMPTY write scoreboard slot to find the right entry. */
    input  logic BREADY_m,
    output logic BVALID_m,
    output logic [ID_WIDTH-1:0] BID_m,
    output logic [1:0] BRESP_m,

    output logic BREADY_s,
    input  logic BVALID_s,
    input  logic [ID_WIDTH-1:0] BID_s,
    input  logic [1:0] BRESP_s,

    /* ── READ ADDRESS CHANNEL ──────────────────────────────────────────
     * CHANGED: added ARID and ARLEN — same reasoning as AWID/AWLEN above
     * but for the read path.  ARID feeds trans_id in the read scoreboard;
     * ARLEN feeds beats_left so the R Match/Absorb block knows how many
     * R beats to expect before the transaction is complete. */
    input  logic [ID_WIDTH-1:0]   ARID_m,
    input  logic ARVALID_m,
    output logic ARREADY_m,
    input  logic [ADDR_WIDTH-1:0] ARADDR_m,
    input  logic [PROT_WIDTH-1:0] ARPROT_m,
    input  logic [LEN_WIDTH-1:0]  ARLEN_m,

    output logic [ID_WIDTH-1:0]   ARID_s,
    output logic ARVALID_s,
    input  logic ARREADY_s,
    output logic [ADDR_WIDTH-1:0] ARADDR_s,
    output logic [PROT_WIDTH-1:0] ARPROT_s,
    output logic [LEN_WIDTH-1:0]  ARLEN_s,

    /* ── READ DATA CHANNEL ─────────────────────────────────────────────
     * CHANGED: added RID and RLAST.
     * RID is the subordinate's response tag — R Match/Absorb compares it
     * against every active read scoreboard slot to find the right entry
     * and decrement beats_left.  RLAST marks the final beat of the burst;
     * when seen alongside a matching RID the slot transitions WAIT_R→EMPTY
     * (normal) or INJECT→DRAINING (injected response complete). */
    output logic RVALID_m,
    input  logic RREADY_m,
    output logic [ID_WIDTH-1:0]   RID_m,
    output logic [DATA_WIDTH-1:0] RDATA_m,
    output logic [1:0] RRESP_m,
    output logic RLAST_m,

    input  logic RVALID_s,
    output logic RREADY_s,
    input  logic [ID_WIDTH-1:0]   RID_s,
    input  logic [DATA_WIDTH-1:0] RDATA_s,
    input  logic [1:0] RRESP_s,
    input  logic RLAST_s
);

logic reset;
assign reset = ~aRESETn;

/* Each AXI4 channel is registered through one axi_skid_buffer instance.
 * The skid buffer's rule: everything that is not VALID or READY gets
 * concatenated into the flat data_in bus; WIDTH is the total bit count.
 * The concatenation order must match between data_in and data_out —
 * the buffer treats the bits as opaque and preserves them verbatim. */

/* WRITE ADDRESS CHANNEL — manager -> subordinate
 * CHANGED WIDTH: was ADDR_WIDTH+PROT_WIDTH (AXI4-Lite shape).
 * Now adds ID_WIDTH (AWID) + LEN_WIDTH (AWLEN). */
axi_skid_buffer #(.WIDTH(ADDR_WIDTH + PROT_WIDTH + ID_WIDTH + LEN_WIDTH)) aw_skid (
    .clk(ACLK), .reset(reset),
    .valid_in (AWVALID_m), .ready_out(AWREADY_m),
    .data_in  ({AWADDR_m, AWPROT_m, AWID_m, AWLEN_m}),
    .valid_out(AWVALID_s), .ready_in (AWREADY_s),
    .data_out ({AWADDR_s, AWPROT_s, AWID_s, AWLEN_s})
);

/* WRITE DATA CHANNEL — manager -> subordinate
 * CHANGED WIDTH: was DATA_WIDTH + DATA_WIDTH/8.
 * Now adds 1 bit for WLAST. */
axi_skid_buffer #(.WIDTH(DATA_WIDTH + DATA_WIDTH/8 + 1)) w_skid (
    .clk(ACLK), .reset(reset),
    .valid_in (WVALID_m), .ready_out(WREADY_m),
    .data_in  ({WDATA_m, WSTRB_m, WLAST_m}),
    .valid_out(WVALID_s), .ready_in (WREADY_s),
    .data_out ({WDATA_s, WSTRB_s, WLAST_s})
);

/* WRITE RESPONSE CHANNEL — subordinate -> manager
 * CHANGED WIDTH: was 2 (BRESP only).
 * Now adds ID_WIDTH for BID. */
axi_skid_buffer #(.WIDTH(ID_WIDTH + 2)) b_skid (
    .clk(ACLK), .reset(reset),
    .valid_in (BVALID_s), .ready_out(BREADY_s),
    .data_in  ({BID_s,  BRESP_s}),
    .valid_out(BVALID_m), .ready_in (BREADY_m),
    .data_out ({BID_m,  BRESP_m})
);

/* READ ADDRESS CHANNEL — manager -> subordinate
 * CHANGED WIDTH: was ADDR_WIDTH+PROT_WIDTH.
 * Now adds ID_WIDTH (ARID) + LEN_WIDTH (ARLEN). */
axi_skid_buffer #(.WIDTH(ADDR_WIDTH + PROT_WIDTH + ID_WIDTH + LEN_WIDTH)) ar_skid (
    .clk(ACLK), .reset(reset),
    .valid_in (ARVALID_m), .ready_out(ARREADY_m),
    .data_in  ({ARADDR_m, ARPROT_m, ARID_m, ARLEN_m}),
    .valid_out(ARVALID_s), .ready_in (ARREADY_s),
    .data_out ({ARADDR_s, ARPROT_s, ARID_s, ARLEN_s})
);

/* READ DATA CHANNEL — subordinate -> manager
 * CHANGED WIDTH: was DATA_WIDTH+2 (RDATA+RRESP).
 * Now adds ID_WIDTH (RID) + 1 bit (RLAST). */
axi_skid_buffer #(.WIDTH(DATA_WIDTH + 2 + ID_WIDTH + 1)) r_skid (
    .clk(ACLK), .reset(reset),
    .valid_in (RVALID_s), .ready_out(RREADY_s),
    .data_in  ({RDATA_s, RRESP_s, RID_s, RLAST_s}),
    .valid_out(RVALID_m), .ready_in (RREADY_m),
    .data_out ({RDATA_m, RRESP_m, RID_m, RLAST_m})
);

endmodule
