module a4lite_baseline #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32

)(
    input logic ACLK, aRESETn, /* GLOBAL SIGNALS */
    /* MANAGER FACING - WRITE ADDRESS CHANNEL */
    input logic AWVALID_m,
    input logic [ADDR_WIDTH-1: 0] AWADDR_m,
    input logic [2:0] AWPROT_m,
    output logic AWREADY_m,
    /* SUBORDINATE FACING - WRITE ADDRESS CHANNEL */
    output logic AWVALID_s,
    output logic [ADDR_WIDTH-1: 0] AWADDR_s,
    output logic [2:0] AWPROT_s,
    input logic AWREADY_s,
    /* MANAGER FACING - WRITE DATA CHANNEL */
    input logic WVALID_m, 
    output logic WREADY_m,
    input logic [DATA_WIDTH - 1: 0] WDATA_m,
    input logic [DATA_WIDTH/8 - 1: 0] WSTRB_m,
    /* SUBORDINATE FACING - WRITE DATA CHANNEL*/
    output logic WVALID_s, 
    input logic WREADY_s,
    output logic [DATA_WIDTH - 1: 0] WDATA_s,
    output logic [DATA_WIDTH/8 - 1: 0] WSTRB_s,
    /* MANAGER FACING - WRITE RESPONSE CHANNEL */
    input logic BREADY_m,
    output logic BVALID_m,
    output logic [1:0] BRESP_m,
    /* SUBORDINATE FACING - WRITE RESPONSE CHANNEL */
    output logic BREADY_s,
    input logic BVALID_s,
    input logic [1:0] BRESP_s,
    /* MANAGER FACING - READ ADDRESS CHANNEL */
    input logic ARVALID_m, 
    output logic ARREADY_m,
    input logic [ADDR_WIDTH-1: 0] ARADDR_m,
    input logic [2:0] ARPROT_m,
    /* SUBORDINATE FACING - READ ADDRESS CHANNEL */
    output logic ARVALID_s, 
    input logic ARREADY_s,
    output logic [ADDR_WIDTH-1: 0] ARADDR_s,
    output logic [2:0] ARPROT_s,
    /* MANAGER FACING - READ DATA CHANNEL */
    output logic RVALID_m, 
    input logic RREADY_m,
    output logic [DATA_WIDTH - 1: 0] RDATA_m,
    output logic [1:0] RRESP_m,
    /* SUBORDINATE FACING - READ DATA CHANNEL */
    input logic RVALID_s, 
    output logic RREADY_s,
    input logic [DATA_WIDTH - 1: 0] RDATA_s,
    input logic [1:0] RRESP_s
    /* ADDITIONAL SIGNALS FOR FULL AXI4 ADDED BELOW */
);

always_ff @ (posedge ACLK) begin
    if (!aRESETn) begin
        /* WRITE ADDRESS CHANNEL */
        {AWVALID_s, AWADDR_s, AWPROT_s, AWREADY_m} <= '0;
        /* WRITE DATA CHANNEL */
        {WREADY_m, WVALID_s, WDATA_s, WSTRB_s} <= '0;
        /* WRITE RESPONSE CHANNEL */
        {BREADY_s, BVALID_m, BRESP_m} <= '0;
        /* READ ADDRESS CHANNEL */
        {ARREADY_m, ARVALID_s, ARADDR_s, ARPROT_s} <= '0;
        /* READ DATA CHANNEL */
        {RVALID_m, RREADY_s, RDATA_m, RRESP_m} <= '0;
    end
    else begin
        /* WRITE ADDRESS CHANNEL */
        AWVALID_s <= AWVALID_m;
        AWADDR_s <= AWADDR_m;
        AWPROT_s <= AWPROT_m;
        AWREADY_m <= AWREADY_s;
        /* WRITE DATA CHANNEL */
        WREADY_m <= WREADY_s;
        WVALID_s <= WVALID_m;
        WDATA_s <= WDATA_m;
        WSTRB_s <= WSTRB_m;
        /* WRITE RESPONSE CHANNEL */
        BREADY_s <= BREADY_m;
        BVALID_m <= BVALID_s;
        BRESP_m <= BRESP_s;
        /* READ ADDRESS CHANNEL */
        ARREADY_m <= ARREADY_s;
        ARVALID_s <= ARVALID_m;
        ARADDR_s <= ARADDR_m;
        ARPROT_s <= ARPROT_m;
        /* READ DATA CHANNEL */
        RVALID_m <= RVALID_s;
        RREADY_s <= RREADY_m;
        RDATA_m <= RDATA_s;
        RRESP_m <= RRESP_s;
        /*ADDITIONS FOR AXI4 INTERFACE BELOW*/
    end
end
endmodule