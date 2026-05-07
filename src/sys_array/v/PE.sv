//
// 2D mesh systolic array processing element (PE) implementing weight  
// stationary signed INT8xINT8 multiplication with INT32 accumulation.
// Activations propagate horizontally, weights and psums share vertical
// datapath.
//
// We assume an initial weight loading stage where it takes N cycles to
// propagate weights to a column of N PEs.
//
// Optional runtime mult bypass control: 
//     mac_bypass_i = 1 -> forward psum unchanged (no computation)
//     mac_bypass_i = 0 -> normal mac operation
//

module PE #(
  parameter int ENABLE_MAC_BYPASS = 0,	// 1 = use mac_bypass_i input
				// 0 = normal mac operation (mac_bypass_i ignored)
  parameter int DATA_WIDTH = 8,
  parameter int PSUM_WIDTH = 32,
  parameter int ROW_ID = 0, // bchang01 - not needed for now
  parameter int COL_ID = 0
)(
  input clk_i,
  input rst_i,
  input v_i,
  input mac_bypass_i, 		// 1 = forward psum unchanged

  input  logic signed [DATA_WIDTH-1:0]  a_i,
  input  logic signed [PSUM_WIDTH-1:0] b_i,
  input  logic               b_is_weight_i,           // WS-PE: now gates d_i load (was: gated b_i load)

  // WS-PE start: separate weight stream + propagate selector (Gemmini double-buffer)
  input  logic signed [DATA_WIDTH-1:0]  d_i,          // WS-PE: weight stream input (was sharing b_i)
  output logic signed [DATA_WIDTH-1:0]  d_o,          // WS-PE: weight stream output (registered, like b_o)
  input  logic                          prop_i,       // WS-PE: 0=c1_r active, 1=c2_r active
  input  logic                          weight_latch_i, // WS-PE V2: 1-cycle pulse, latch d_i into inactive buffer (replaces v_i&&b_is_weight gate)
  // WS-PE end

  output logic               v_o,
  output logic signed [DATA_WIDTH-1:0]  a_o,
  output logic signed [PSUM_WIDTH-1:0] b_o,
  output logic signed [DATA_WIDTH-1:0] weight_o 	// debug stored weight (now: active buffer)
);

  logic               mac_bypass;
  logic signed [DATA_WIDTH-1:0]  weight_active;       // WS-PE: now combinational mux over c1_r/c2_r (was a flip-flop)
  // WS-PE start: ping-pong weight buffers (replaces single weight_active register)
  logic signed [DATA_WIDTH-1:0]  c1_r;                // WS-PE: weight buffer 1 (active when prop_i=0)
  logic signed [DATA_WIDTH-1:0]  c2_r;                // WS-PE: weight buffer 2 (active when prop_i=1)
  // WS-PE end
  logic signed [15:0] mult16b;
  logic signed [31:0] mult32b;		// sign extended product
  logic signed [PSUM_WIDTH-1:0] acc;	        // accumulated psum

  // ----------------------------
  // Weight Register
  // ----------------------------

  // WS-PE start: ping-pong load. Active buffer is held; inactive buffer is the load target.
  //   prop_i = 0 -> c1_r is active for MAC, c2_r receives d_i (when weight_latch_i)
  //   prop_i = 1 -> c2_r is active for MAC, c1_r receives d_i
  //
  // V2 change vs V1: load gate is now `weight_latch_i` (a dedicated 1-cycle pulse
  // from systolic_ctrl), DECOUPLED from `v_i` and `b_is_weight_i`. This is what
  // makes parallel LOAD+COMPUTE possible: during compute the active buffer drives
  // MAC under v_i=1, while a shadow load can simultaneously fire weight_latch_i=1
  // to capture into the inactive buffer without disturbing the compute datapath.
  //
  // Reference: Gemmini PE.scala WS path (lines 118-131). The original Gemmini
  // PE has continuous-load semantics (`c2 := d` when valid), which works because
  // their `d` wire is fully dedicated. We use a single-pulse latch instead since
  // our top-level still streams data continuously — the pulse is the cleanest way
  // to broadcast "latch now" to all PEs at the same cycle.
  //
  // Original single-buffer load (commented out, see modification_log.md):
  // always_ff @(posedge clk_i or posedge rst_i) begin
  //   if (rst_i)
  //     weight_active <= '0;
  //   else if (v_i && b_is_weight_i)
  //     weight_active <= b_i[DATA_WIDTH-1:0];
  // end
  //
  // V1 load gate (commented out, V2 supersedes):
  // end else if (v_i && b_is_weight_i) begin
  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      c1_r <= '0;
      c2_r <= '0;
    end else if (weight_latch_i) begin                                   // WS-PE V2: pulse-driven latch (decoupled from v_i, b_is_weight_i)
      if (prop_i)
        c1_r <= d_i;                                  // prop=1 -> c2 active, load c1 from d_i
      else
        c2_r <= d_i;                                  // prop=0 -> c1 active, load c2 from d_i
    end
  end

  assign weight_active = prop_i ? c2_r : c1_r;
  // WS-PE end

  // ----------------------------
  // MAC Bypass Control
  // ----------------------------

  // mac_bypass_r = 0 forwards psum without mac
  assign mac_bypass = (ENABLE_MAC_BYPASS != 0) & mac_bypass_i;

  // ----------------------------
  // MAC Datapath
  // ----------------------------

  assign mult16b = v_i ? (weight_active * a_i) : 16'sd0; // mult output
  assign mult32b = {{16{mult16b[15]}}, mult16b}; // sign extend mult output
  assign acc = mult32b + b_i;

  // ----------------------------
  // Output
  // ----------------------------
  // Register the horizontal data/valid hop so each PE-to-PE transfer is
  // one cycle, matching systolic timing and reducing long combinational paths.
  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      a_o <= '0;
      v_o <= 1'b0;
      b_o <= '0;
      d_o <= '0;                                                 // WS-PE: register d_o (relay weight stream down)
    end else begin
      a_o <= a_i;
      // WS-PE V2 start: decouple v_o, b_o from b_is_weight_i.
      // V1 used `!b_is_weight_i ? v_i : 1'b0` for v_o and `mac_bypass | b_is_weight_i ? b_i : acc` for b_o.
      // Those gates were correct only when LOAD and COMPUTE were mutually exclusive (single shared wire).
      // With shadow concurrent with compute, b_is_weight_i may be 1 during a compute cycle, but we MUST
      // still propagate v_o=v_i and b_o=acc so the psum chain is unaffected. Removing the gate:
      //   - When v_i=0 (any non-compute cycle): mult=0, acc=b_i, b_o=b_i naturally. Same effect as V1.
      //   - When v_i=1 (compute cycle): b_o=acc. Correct, regardless of shadow status.
      // v_o <= !b_is_weight_i ? v_i : 1'b0;       // V1 (commented)
      // if (mac_bypass | b_is_weight_i)            // V1 (commented)
      //   b_o <= b_i;                              // V1 (commented)
      // else                                       // V1 (commented)
      //   b_o <= acc;                              // V1 (commented)
      v_o <= v_i;
      if (mac_bypass)
              b_o <= b_i;
      else
              b_o <= acc;
      // WS-PE V2 end
      d_o <= d_i;                                                // WS-PE: 1-cycle relay to next PE down (matches b_o timing)
    end
  end

  assign weight_o = weight_active;

endmodule
