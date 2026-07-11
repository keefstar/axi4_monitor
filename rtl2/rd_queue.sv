import a4lite_pkg::*;
/* Author: Keefee Rahman
 * @brief Read-path liveness guard for AXI4-Lite. Connects to axi4l_if interfaces:
 * s = upstream link (guards acts as subordinate), m = downstream link (guard acts as manager.
 * Drives only the AR/R signals of each; write guard owns AW/W/B on the same interface instances.
 * @param TIMEOUT_COUNTER Maximum number of cycles allowed before a timeout.
 */
module rd_queue #(
    parameter int unsigned DEPTH = a4lite_pkg::DEPTH,
    parameter int unsigned TIMER_WIDTH = a4lite_pkg::TIMER_WIDTH,
    parameter logic [TIMER_WIDTH-1:0] TIMEOUT_CYCLES = a4lite_pkg::TIMEOUT_CYCLES
)(
    input logic clk, rst_n,
    /* Interface connections */
    axi4l_if.a4l_mgr m, // Guard acts as manager toward downstream subordinate
    axi4l_if.a4l_sub s, // Guard acts as subordinate toward upstream manager
    /* Signals to top level*/
    output logic timeout_pulse,
    output logic busy,
    output logic upstream_empty,
    /* Signal from top level */
    /* epoch_clr must happen only when 1) every resopnse owed to manager has completed (upstream_empty == 1 (can be all SLVERR)) and 2) sub has been reset, so no old ghost responses can return */
    input logic epoch_clr, /* rcvry complete - sub was reset. one cycle pulse. epich rile: reset BEFORE ack, always */ 
    input logic flush /* held high trhoughout ocntainment - to signigy fault has occured and to stop accepting new reads and finsih every existing upstream read with SLVRR as quickly as maager will accept them */
);
 
/* Occupancy counter */
// Occupancy ranges from 0 to DEPTH inclusive, so the counter needs 
// enough bits to represent DEPTH itself, not just indices 0 to DEPTH-1.
localparam int unsigned CNT_W = $clog2(DEPTH + 1);
logic [CNT_W - 1 : 0 ] outst_cnt; /* The number of reads for which the guard still owes the upstream manager a response. */
logic [CNT_W -  1 : 0] drain_cnt; /* umber of late real responses that are still expected but have not yet come back, for reads whose manager already accepted an injected SLVERR. */
logic [TIMER_WIDTH - 1: 0] timer;

/* State Defintions */
typedef enum logic [1:0] {
    RD_IDLE = 2'b00, /* no reads outstanding */
    RD_TRACKING = 2'b01,
    RD_INJECTING = 2'b10
} rd_state_e;
rd_state_e rd_state, rd_state_nxt;
logic full;
assign full = (outst_cnt == CNT_W'(DEPTH));

/* AR channel */
/* Queue full lets guard withhold ARREADY */
/* // The upstream manager drives s.arvalid; the guard accepts and forwards that request as m.arvalid only when its tracking queue is not full */
assign m.arvalid = s.arvalid && !full && (!epoch_clr && !flush); /* forward upstream manager's ARVALID to downstread subordinate only when the guard has room to track another read */
assign s.arready = m.arready && !full && (!epoch_clr && !flush); /* forward to upstread manager the sub's ready signal when the guard has room to record transaction */
assign m.ar = s.ar; /* simple wiring */
logic ar_fire; /* read addr transfers happen at handshake (ARVALID (from M) && ARREADY (from S)) */
assign ar_fire = s.arvalid && s.arready; /* note, this is equivalent to s.arvalid && (m.arready && !full)*/

/******************* R CHANNEL ********************/
logic ghost_fire, inject_fire, fwd_fire;
assign m.rready = ((drain_cnt != '0) || ((rd_state == RD_TRACKING) && s.rready));
assign ghost_fire = m.rvalid && (drain_cnt != '0); 
assign inject_fire = (rd_state == RD_INJECTING) && s.rready; /* fabricated SLVERR accepted by upstream mng)*/
/* from grd perspective; guard drives s.rvalid towards upstream mng; grd drives s.rready from that manager */
assign fwd_fire = (s.rvalid && s.rready) && (rd_state == RD_TRACKING); /* real sub response forwarded (and accepted) by upstream manager */

/* calculate number of outstanding reads for next clock cycle */
logic retire_fire;
assign retire_fire = fwd_fire || inject_fire;
logic [CNT_W-1: 0] outst_nxt;
always_comb begin
    outst_nxt = outst_cnt;
    unique case ({ar_fire, retire_fire})
    2'b10: outst_nxt = outst_cnt + 1'b1; /* new read accepted only */
    2'b01: outst_nxt = outst_cnt - 1'b1; /* completed one read only */
    2'b00: outst_nxt = outst_cnt; /* nothing happened*/
    2'b11: outst_nxt = outst_cnt; /* one entered, one complete; no net changed */
    default: outst_nxt = outst_cnt;
    endcase
end

/* Calculate the next outstanding-read count so both the counter register and FSM can use the updated value */
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

/* timer logic*/
/* count only while: 1) a head exists, 2) it has not already timed out, and 3) the subordinate has not presented a resopnse (freeze timer) */
/* restart timer when 1) the head retires (forward or inject) */
logic timer_run; /* timer is active when 1) guard is tracking an outstanding trad, 2) sub has not yet presented real response */
assign timer_run = (rd_state == RD_TRACKING) && ((drain_cnt != '0) || !m.rvalid);
logic timeout_hit;
assign timeout_hit = (timer_run && (timer == TIMEOUT_CYCLES));
always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer <= '0;
    end else if (epoch_clr || retire_fire || timeout_hit) begin
        timer <= '0;
    end else if (timer_run) begin
        timer <= timer + TIMER_WIDTH'(1);
    end
end

always_comb begin
    {s.rvalid, s.r} = '0;
    rd_state_nxt = rd_state;
    unique case (rd_state)
    RD_IDLE: rd_state_nxt = (ar_fire) ? RD_TRACKING : RD_IDLE;
    RD_TRACKING: begin
        s.rvalid = m.rvalid && (drain_cnt == '0);
        s.r = m.r;
        if (timeout_hit || flush) rd_state_nxt = RD_INJECTING;
        else if (fwd_fire && outst_nxt == '0) rd_state_nxt = RD_IDLE;
    end
    RD_INJECTING: begin
        s.rvalid = 1'b1;
        s.r.data = '0;
        s.r.resp = RESP_SLVERR;
        if (inject_fire) rd_state_nxt = (outst_nxt == '0) ? RD_IDLE : RD_TRACKING;
    end
    default: rd_state_nxt = RD_IDLE;
    endcase
end

always_ff @ (posedge clk or negedge rst_n) begin
    if (!rst_n) rd_state <= RD_IDLE;
    else if (epoch_clr) rd_state <= RD_IDLE;
    else rd_state <= rd_state_nxt;
end

assign timeout_pulse = timeout_hit; /* 1 cycle pulse for top level; allows top level to raise interrupt and enter containment/recovery */
assign busy = (outst_cnt != '0) || (drain_cnt != '0);
assign upstream_empty = (outst_cnt == '0);

endmodule : rd_queue


/*
1) head only timer: one timer for the oldest outstanding read, restarted each time the head retires.
A hung subordinate is contained one transaction at a time ('domino' containment) ratehr than mass-SLVERR
2) No entry stroage: AXI4-Lite has no ARID and responses are in-order so the next R always belongs to the oldest outstanding ready. 
The injected SLVERR payload is fabricated. Tracking state collapses t counters plus a 3-phase head FSN,
3) Timer freeze: timer only counts while the subordinate owes a response (m.rvalid low). If subordinate has presnteed R and the
manager is backpressuring (s.rready low), it is not a subordinate fault. The timer freezes.
4) commited injection: once the head times out, its eventual real response is a ghost and will be drained,
even if it arrives before the manager accepts the injected SLVERR. No cancellation race. 


*/


/*
PCIe Completion Timeout: a requester times out a read, synthesizes an error completion upstream (your SLVERR injection, almost literally), raises AER; software performs a Function-Level Reset or secondary-bus reset, and the driver stack retries. The spec explicitly requires the requester to discard late completions for timed-out tags — a drain mechanism in production silicon for two decades. [Certain]
Xilinx/AMD AXI Firewall IP (PG293): the closest existing IP to your project. Detects timeouts/protocol violations on AXI, blocks the interface, returns error responses to the manager, and requires software to verify quiescence and write an unblock register before traffic resumes — your interrupt + rcvy_ack handshake, productized. Read this doc before writing the related-work chapter; a reviewer will expect
*/

/* Just avoid calling the work substantive solely because it uses IEEE 1801. The value comes from the failure scenarios and assertions you verify. If you implement the two-domain setup, isolation, power states, mid-transaction power loss, error containment, and epoch recovery, then yes—it is a strong undergraduate-thesis component.*/
