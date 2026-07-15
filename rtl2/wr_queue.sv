import a4lite_pkg::*;
module wr_queue #(
    parameter int unsigned DEPTH = a4lite_pkg::DEPTH,
    parameter int unsigned TIMER_WIDTH = a4lite_pkg::TIMEOUT_WIDTH,
    parameter logic [TIMER_WIDTH-1:0] TIMEOUT_CYCLES = TIMER_WIDTH'(a4lite_pkg::TIMEOUT_COUNTER)
)(
    input logic clk, rst_n,
    /* Interface connections */
    axi4l_if.a4l_mgr m, // Guard acts as manager toward downstream subordinate
    axi4l_if.a4l_sub s, // Guard acts as subordinate toward upstream manager
    /* Signals to top level*/
    output logic timeout_pulse,
    output logic busy,
    output logic upstream_empty,
    input logic epoch_clr, 
    input logic flush,
    output logic w_fault_pulse
);

localparam int unsigned CNT_W = $clog2(DEPTH + 1);
/* Counters; seperate from read, but identical analogue */
logic [CNT_W-1:0] outst_cnt;   // completed writes still owed a B upstream
logic [CNT_W-1:0] drain_cnt;   // ghost Bs still owed by the subordinate
logic [CNT_W-1:0] outst_nxt;
logic full;
assign full = (outst_cnt == CNT_W'(DEPTH));

/* State definitions */
typedef enum logic [1:0] {
    WR_IDLE, /* no writes outstanding */
    WR_TRACKING, /* head pointer alive, B-timer running */
    WR_INJECTING /* B timed out; SLVERR presented */
} wr_state_e;
wr_state_e wr_state, wr_state_nxt;

/* AW/W pair admission; no read analogue */
typedef enum logic [1:0] {
    WPAIR_IDLE, /* neither AW/W accepted */
    WPAIR_AW_ONLY, /* AW accepted; waiting for W */
    WPAIR_W_FAULT /* W never came; manager fault, interrupt only */
} wpair_state_e;
wpair_state_e wpair_state, wpair_state_nxt;

/* Two timers for write */
logic [TIMER_WIDTH - 1: 0] b_timer; /* subordinate owes B - wr_state */
logic [TIMER_WIDTH - 1: 0] w_timer; /* manager owes sub W - wpair_state */

logic aw_perm;
/* AW channel - Part 1 of admission */
logic aw_fire, w_fire, pair_fire;

assign aw_perm = (wpair_state == WPAIR_IDLE) && !full &&!epoch_clr && !flush;

aw_beat_t aw_hold;
always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) aw_hold <= '0;
    else if (aw_fire) aw_hold <= s.aw;
end


/* Guard will hold AW from subordinate until pair completes */
/* reminder, whoever plugs in as a4l_mng will drive awvalid/aw and recieve awready*/
/* confusion comment: s and m name the guards's two faces; so s.awvalid is AWVALID arriving at the subordinate face (somelese else drove it)
and m.awvalid is AWVALID leaving the mangaer face*/
assign m.awvalid = s.awvalid && aw_perm;
assign s.awready = aw_perm;
assign m.aw = aw_hold;
assign aw_fire = s.awvalid && s.awready; 


logic w_perm;
assign w_perm = (wpair_state == WPAIR_AW_ONLY) && !epoch_clr;
/* W channel */
/* Recall constraint: writes are only accepted when in AW_ONLY (AW recieves first) */
assign m.wvalid = s.wvalid && w_perm;
assign s.wready = m.wready && w_perm;
assign m.w = s.w;
assign w_fire = s.wvalid && s.wready;
assign pair_fire = w_fire;

/* W timer: manager side fault. Run in AW only. freezes when th emanager is actually presenting W */
/* note; this is the only timer in the design that doesnt lead to a SLVERR; only a flag */
logic w_timer_run, w_timeout_hit;
assign w_timer_run = (wpair_state == WPAIR_AW_ONLY) && !s.wvalid; /* start timer the second AW is recieved and waiting for W data to complete */
assign w_timeout_hit = w_timer_run && (w_timer == TIMEOUT_CYCLES);
always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) w_timer <= '0;
    /* for TB: assertion (wpair_state != WPAIR_AW_ONLY) |-> (w_timer == '0) */
    else if (epoch_clr || pair_fire || w_timeout_hit) w_timer <= '0;
    else if (w_timer_run) w_timer <= w_timer + TIMER_WIDTH'(1);
end

always_comb begin
    wpair_state_nxt = wpair_state;
    case (wpair_state)
    WPAIR_IDLE: wpair_state_nxt = (aw_fire) ? WPAIR_AW_ONLY : WPAIR_IDLE;
    WPAIR_AW_ONLY: begin
        if (w_fire) wpair_state_nxt = WPAIR_IDLE;
        else if (w_timeout_hit || flush) wpair_state_nxt = WPAIR_W_FAULT;
    end
    WPAIR_W_FAULT: begin /* manager sent AW but never W */
        /* cannot assert SLVERR, must raise interrupt and once epoch_clr comes, clear guard */
        if (epoch_clr) wpair_state_nxt = WPAIR_IDLE;
    end
    default: wpair_state_nxt = WPAIR_IDLE;
    endcase
end

always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) wpair_state <= WPAIR_IDLE;
    else if (epoch_clr) wpair_state <= WPAIR_IDLE;
    else wpair_state <= wpair_state_nxt;
end

/* IMPORTANT FOR INTERRUPT RAISING FOR W TIMEOUTS (AFTER AW RECIEPT)*/
assign w_fault_pulse = w_timeout_hit; /* for top level */

/* below is cloned logic from read queue */
/* garbage was binned; a fabricated reciepted reached the maanger; an honest reciept; retire is for either one of ghost/inkect */
logic ghost_fire, inject_fire, fwd_fire, retire_fire;
assign m.bready = (drain_cnt != '0) || ((wr_state == WR_TRACKING) && s.bready);

assign ghost_fire = m.bvalid && (drain_cnt != '0);
assign inject_fire = (wr_state == WR_INJECTING) && s.bready;
assign fwd_fire = (s.bvalid && s.bready) && (wr_state == WR_TRACKING); /* sub is ready to send, man is ready to take */
assign retire_fire = inject_fire || fwd_fire;


always_comb begin
    outst_nxt = outst_cnt;
    unique case ({pair_fire, retire_fire})
        2'b10:   outst_nxt = outst_cnt + 1'b1;
        2'b01:   outst_nxt = outst_cnt - 1'b1;
        default: outst_nxt = outst_cnt;   
    endcase
end

always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        {outst_cnt, drain_cnt} <= '0;
    end else if (epoch_clr) begin /* new epoch: forget everything owed by the old subbordinate */
        {outst_cnt, drain_cnt} <= '0;
    end else begin
        outst_cnt <= outst_nxt;
        unique case ({inject_fire, ghost_fire}) 
            2'b10: drain_cnt <= drain_cnt + 1'b1;
            2'b01: drain_cnt <= drain_cnt - 1'b1;
            default: drain_cnt <= drain_cnt;
        endcase
    end
end

/* subordinate side fault */
logic b_timer_run, b_timeout_hit;
assign b_timer_run = (wr_state == WR_TRACKING) && ((drain_cnt != '0) || !m.bvalid);
assign b_timeout_hit = b_timer_run && (b_timer == TIMEOUT_CYCLES);
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) b_timer <= '0;
    else if (epoch_clr || retire_fire || b_timeout_hit) b_timer <= '0;
    else if (b_timer_run) b_timer <= b_timer + TIMER_WIDTH'(1);
end


always_comb begin 
    {s.bvalid, s.b} = '0;
    wr_state_nxt = wr_state;
    unique case (wr_state)
    WR_IDLE:  wr_state_nxt = (pair_fire) ? WR_TRACKING : WR_IDLE;
    WR_TRACKING: begin
        s.bvalid = m.bvalid && (drain_cnt == '0);
        s.b = m.b;
        if (b_timeout_hit || flush) wr_state_nxt = WR_INJECTING;
        else if (fwd_fire && outst_nxt == '0) wr_state_nxt = WR_IDLE;
    end
    WR_INJECTING: begin
        s.bvalid = 1'b1;
        s.b.resp = RESP_SLVERR;
        if (inject_fire) wr_state_nxt = (outst_nxt == '0) ? WR_IDLE : WR_TRACKING;
    end
    default: wr_state_nxt = WR_IDLE;
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) wr_state <= WR_IDLE;
    else if (epoch_clr) wr_state <= WR_IDLE;
    else wr_state <= wr_state_nxt;
end

assign timeout_pulse = b_timeout_hit; /* 1 cycle pulse for top level; allows top level to raise interrupt and enter containment/recovery */
assign busy = (outst_cnt != '0) || (drain_cnt != '0) || (wpair_state != WPAIR_IDLE);
assign upstream_empty = (outst_cnt == '0) && (wpair_state == WPAIR_IDLE); /* no drain_cnt as that reprenets debt to guard from sub, not debt to manager by the ugard */
endmodule : wr_queue


/*
If a write times out before we have WLAST (redundant in AXI4-lite), it is a specification violation to inject
BRESP = SLVERR since BVALID is only accepted after the final (and here only) beat. The cleaner, more correct and
conservative design choice is to use the interrupt controller to treat this as a write-data-phase fault.

SLVERR should be reserved, in the case of writes, for when we are waiting for a BREADY response from the manager
and there is a timeout. 

/* As a constriant:
A write is admitted only when BOTH halves (AW, W) have arrived, and we make AW required to come first
Specifically, AW first, always; W only accepted while waiting for it.

module design structure generally follows the precedent laid out in reads.
But add more FSMs to account for AW/W/B handling.

Design choices:

Recall: Flush generally injects SLVERR to everywhere possible, BUT, But a write sitting in WPAIR_AW_ONLY has no B response coming and no legal SLVERR — the manager only sent an address, never the data, 
so the write-response dependency was never satisfied, so injecting B would be the exact spec violation your notes open with. 
Flush's tool doesn't fit this transaction.
It's not that flush chooses to route it to W_FAULT; it's that flush has nothing else it can lawfully do with it.
INSTEAD,

Flush does not reset the guard. Flush makes the guard drain — inject SLVERRs, empty its obligations. 
The guard's books get wiped later, by epoch_clr, not flush. Flush empties; epoch_clr forgets. 
Different signals, different times.

W_FAULT does not tell anyone to reset the subordinate. W_FAULT raises a fault flag that feeds the interrupt. 
The interrupt notifies software. Software — reading the interrupt — is what resets the subordinate. 
The guard has no wire that resets the sub and no authority to; it can only report. 


Say we have recieved AW 

Given the AW/W ordering constraint: do I forward to subordinatye immediately when AW is recieved and usee WSTRB = 0 to 'stall' myself?
Or do I hold the AW until the pair is complete? I lean for this. A W-timeout happens entirely upstream of the subordinate, it never saw anything, nothing to get stuck on. 
The fault is contained on the manager side where it belongs.

a) FSM 1:

 */
