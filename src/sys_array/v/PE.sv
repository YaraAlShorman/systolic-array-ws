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
  input  logic               b_is_weight_i,

  output logic               v_o,
  output logic signed [DATA_WIDTH-1:0]  a_o,
  output logic signed [PSUM_WIDTH-1:0] b_o,
  output logic signed [DATA_WIDTH-1:0] weight_o 	// debug stored weight
);

  logic               mac_bypass;
  logic signed [DATA_WIDTH-1:0]  weight_active;
  logic signed [15:0] mult16b;
  logic signed [31:0] mult32b;		// sign extended product
  logic signed [PSUM_WIDTH-1:0] acc;	        // accumulated psum

  // ----------------------------
  // Weight Register
  // ----------------------------

  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i)
      weight_active <= '0;
    else if (v_i && b_is_weight_i)
      weight_active <= b_i[DATA_WIDTH-1:0];
  end

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
    end else begin
      a_o <= a_i;
      v_o <= !b_is_weight_i ? v_i : 1'b0;
      if (mac_bypass | b_is_weight_i)
              b_o <= b_i;
      else
              b_o <= acc;
    end
  end

  assign weight_o = weight_active;

endmodule
