package a4lite_pkg;

/*************************************** AXI4 Lite Constraints ***************************************/
localparam int unsigned ADDR_WIDTH = 32;
localparam int unsigned DATA_WIDTH = 32;
localparam int unsigned STRB_WIDTH = DATA_WIDTH/8;
localparam int unsigned PROT_WIDTH = 3;
/*************************************** GUARD  Constraints ***************************************/
localparam int TIMEOUT_COUNTER = 256;
localparam int TIMEOUT_WIDTH = 16;
localparam int DEPTH = 8;


typedef enum int unsigned {
    READ_TIMEOUT       = 0,
    WRITE_DATA_TIMEOUT = 1,
    WRITE_RESP_TIMEOUT = 2
} fault_src_e;
localparam int NUM_FAULT_SOURCES = 3;

/*  AXI response encoding (IHI 0022E, Table A3-4) */
typedef enum logic [1:0] {
    RESP_OKAY = 2'b00, /* Normal access success. Indicates that a normal access has been successful */
    RESP_EXOKAY = 2'b01, /* Exclusive access okay. Indicates that either the read or write portion of an exclusive access has been successful */
    RESP_SLVERR = 2'b10, /* Slave error. Used when the access has reached the slave successfully, but the slave wishes to return an error condition to the originating master */
    RESP_DECERR = 2'b11 /* Decode error. Generated, typically by an interconnect component, to indicate that there is no slave at the transaction address */
} axi_resp_e; /* RRESP and BRESP encoding */

/*************************************** PAYLOAD STRUCTS ***************************************/
/******* Write channel payloads ********/
typedef struct packed{
    logic [ADDR_WIDTH - 1: 0] addr;
    logic [PROT_WIDTH - 1: 0] prot;
} aw_beat_t;

typedef struct packed {
    logic [DATA_WIDTH - 1: 0] data;
    logic [STRB_WIDTH - 1 : 0] strb;
} w_beat_t;

typedef struct packed {
    axi_resp_e resp;
} b_beat_t;

/******* Read channel payloads ********/
typedef struct packed{
    logic [ADDR_WIDTH - 1: 0] addr;
    logic [PROT_WIDTH - 1: 0] prot;
} ar_beat_t;

typedef struct packed {
    logic [DATA_WIDTH - 1: 0] data;
    axi_resp_e resp;
} r_beat_t;

/*************************************** INTERNAL GUARD STRUCTS ***************************************/

/* Per entry tracking state in the ordered queues */
typedef enum logic [1:0] {
    ENTRY_FREE = 2'b00, /* slot unoccupied */
    ENTRY_ACTIVE = 2'b01, /* request forwarded, timer is running (or frozen)*/
    ENTRY_TIMED_OUT = 2'b10, /* timer expired; SLVERR owed when at queue head */
    ENTRY_DRAINED = 2'b11 /* entry is being revoked */
} entry_state_e;

/* AXI4-Lite permits W arriving before AW, but this design disallows admitting it */
/* WREADY is withheld until AW is accepted, so no WPAIR_W_ONLY state is necessary */
typedef enum logic [1:0] {
    WPAIR_IDLE = 2'b00, /* neither AW nor W are accepted */
    WPAIR_AW_ONLY = 2'b01, /* AW accepted, waiting on W */
    WPAIR_W_FAULT = 2'b10 /* W-side tiemout; write data parked/faulted*/
} wpair_state_e;

/* Read-path head FSM (rd_queue). Shared here (rather than declared locally
   in rd_queue.sv) so bind-based SVA checkers can reference the type. */
typedef enum logic [1:0] {
    RD_IDLE = 2'b00, /* no reads outstanding */
    RD_TRACKING = 2'b01,
    RD_INJECTING = 2'b10
} rd_state_e;

/* Write-path head FSM (wr_queue). Shared for the same reason as rd_state_e. */
typedef enum logic [1:0] {
    WR_IDLE, /* no writes outstanding */
    WR_TRACKING, /* head pointer alive, B-timer running */
    WR_INJECTING /* B timed out; SLVERR presented */
} wr_state_e;

/* Top-level guard mode */
typedef enum logic [1:0] {
    GUARD_NORMAL = 2'b00, /* Transparent pass through; timers armed */
    GUARD_CONTAINING = 2'b01, /* Fault detected; injecting SLVERR, draining */
    GUARD_RECOVERY = 2'b10 /* Interrupt raised, awaiting recovery acknowlegdment */
} guard_mode_e;
endpackage : a4lite_pkg
