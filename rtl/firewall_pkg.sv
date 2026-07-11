package firewall_pkg;

/* Design-wide constraints*/
localparam int ID_WIDTH = 4; /* specify how many ID values the firewall can represent*/
localparam int ADDR_WIDTH = 32; /* AXI4 address space width */
localparam int DATA_WIDTH = 32; /* AXI4 data bus width*/
localparam int PROT_WIDTH = 3; /* fixed by AXI4 spec = Protection bus to dictate permissions for each transaction, not configurable */
localparam int LEN_WIDTH = 8;    /* ARLEN/AWLEN field width; protocol enforces a fixed maximum limit of 256 transfers per burst */
localparam int TIMER_WIDTH = 16;
localparam int N_SLOTS = 16; /* scoreboard depth, read and write */
localparam int TIMEOUT_VALUE = 256;  /* cycles before a slot fires a timeout */

/* defines the types of timeout faults the firewall can report to the interrupt/control logic */
typedef enum int unsigned {
    READ_TIMEOUT       = 0,
    WRITE_DATA_TIMEOUT = 1,
    WRITE_RESP_TIMEOUT = 2
} fault_src_e;
localparam int NUM_FAULT_SOURCES = 3;

/* State definitions for read scoreboard*/ 
typedef enum logic [1:0] {
    RD_EMPTY    = 2'b00,
    RD_WAIT_R   = 2'b01,
    RD_INJECT   = 2'b10,
    RD_DRAINING = 2'b11
} rd_slot_state_e;

/* State defintions for write scoreboard */
typedef enum logic [2:0] {
    WR_EMPTY    = 3'b000,
    WR_WAIT_W   = 3'b001,  /* AW accepted; awaiting W beats from manager       */
    WR_WAIT_B   = 3'b010,  /* WLAST seen; awaiting B response from subordinate */
    WR_INJECT   = 3'b011,  /* WAIT_B timer expired; manufacturing SLVERR on B  */
    WR_DRAINING = 3'b100,  /* SLVERR delivered; discarding any late real B      */
    WR_W_FAULT  = 3'b101   /* WAIT_W timer expired; parked awaiting force_free  */
} wr_slot_state_e;

/* Read Scoreboard Entry struct */
typedef struct packed {
    rd_slot_state_e state;
    logic [ID_WIDTH-1:0] trans_id;    /* ARID; matched against incoming RID  */
    logic [LEN_WIDTH-1:0] beats_left;  /* R beats still expected               */
    logic [TIMER_WIDTH-1:0] timer;
    logic [ADDR_WIDTH-1:0] trans_addr;  /* stored for injection context         */
} sb_read_entry_t;

/* Write scoreboard entry strcut */
typedef struct packed {
    wr_slot_state_e state;
    logic [ID_WIDTH-1:0] trans_id; /* AWID; matched against incoming BID  */
    logic [LEN_WIDTH-1:0] beats_left;  /* W beats still expected (WAIT_W only) */
    logic [TIMER_WIDTH-1:0] timer;
    logic [ADDR_WIDTH-1:0] trans_addr;  /* stored for injection context         */
} sb_write_entry_t;

endpackage
