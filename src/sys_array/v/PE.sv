//
// 2D mesh systolic array processing element (PE) implementing weight  
// stationary signed INT8xINT8 multiplication with INT32 accumulation.
// Activations propagate horizontally, weights and psums share vertical
// datapath.
//
// We assume an initial weight loading stage where it takes N cycles to
// propagate weights to a column of N PEs.
//
// NOTE: top level FSM must include 1 silent cycle before switching to
// compute mode where v_i = 0 to prevent race condition
//
// Optional runtime mult bypass control: 
//     mac_bypass_i = 1 -> forward psum unchanged (no computation)
//     mac_bypass_i = 0 -> normal mac operation
//

module PE #(
  ENABLE_MAC_BYPASS = 1	// 1 = use mac_bypass_i input
				// 0 = normal mac operation
  // ROW_ID = 0, // bchang01 - not needed for now
  // COL_ID = 0
)(
  input clk_i,
  input rst_i,
  input v_i,
  input mac_bypass_i, 		// 1 = forward psum unchanged

  input  logic signed [7:0]  a_i,
  input  logic signed [31:0] b_i,
  input  logic               b_is_weight_i,

  output logic               v_o,
  output logic signed [7:0]  a_o,
  output logic signed [31:0] b_o,
  output logic signed [7:0]  weight_o 	// debug stored weight
);

  logic               mac_bypass;
  logic signed [7:0]  weight_r;
  logic signed [15:0] mult16b;
  logic signed [31:0] mult32b;		// sign extended product
  logic signed [31:0] acc;	        // accumulated psum

  // ----------------------------
  // Weight Register
  // ----------------------------

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      weight_r <= '0;
    end
    else if (v_i && b_is_weight_i) begin
      weight_r <= b_i[7:0];	// weight stored in lower 8 bits
    end
  end

  // ----------------------------
  // MAC Bypass Control
  // ----------------------------

  // mac_bypass_r = 0 forwards psum without mac
  assign mac_bypass = ENABLE_MAC_BYPASS & mac_bypass_i;

  // ----------------------------
  // MAC Datapath
  // ----------------------------

  assign mult16b = weight_r * a_i; // mult output
  assign mult32b = {{16{mult16b[15]}}, mult16b}; // sign extend mult output
  assign acc = mult32b + b_i;

  // ----------------------------
  // Output 
  // ----------------------------
  
  assign a_o = a_i;
  assign weight_o = weight_r;
  assign v_o = v_i;
  assign b_o = (mac_bypass | b_is_weight_i) ? b_i : acc;

endmodule