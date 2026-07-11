package watchdog_pkg;
/* Fault source indicies - maps each fault type to its bit postion 
in violation_notif, status_reg, enable_reg, clear_reg, rcvy_ack */
typedef enum int unsigned { 
    WRITE_FAULT = 0,
    READ_FAULT = 1
} fault_src_e;

typedef enum logic [1:0] {
    AXI_RESP_OKAY  = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
} axi_resp_e;

 /* Total number of fault sources — must match NUM_SOURCES parameter */
localparam int NUM_SOURCES = 2;

endpackage