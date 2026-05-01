//
// 2D mesh systolic array processing element (PE) implementing weight  
// stationary signed INT8xINT8 multiplication with INT32 accumulation.
// Activations propagate horizontally, weights and psums share vertical
// datapath.
//
// All outputs are registered inside the PE. No pipeline registers are
// required in the surrounding mesh.
//
// Naming convention: 
//   - v: valid
//   - a: activation
//   - b: weight/psum
//

module PE #(
  parameter DATA_WIDTH_p = 8,
  parameter PSUM_WIDTH_p = 32
)(
  input  logic                           clk_i,
  input  logic                           rst_i,

  // Weight/Psum path - registered inside PE
  input  logic signed [PSUM_WIDTH_p-1:0] b_i,
  input  logic                           b_is_weight_i,
  output logic signed [PSUM_WIDTH_p-1:0] b_o,
  output logic signed [DATA_WIDTH_p-1:0] weight_o, // debug stored weight

  // Activation path - registered inside PE
  input  logic signed [DATA_WIDTH_p-1:0] a_i,
  output logic signed [DATA_WIDTH_p-1:0] a_o,

  // Valid
  input  logic                           v_i,
  output logic                           v_o
);

  // ----------------------------
  // Internal Signals/Registers
  // ----------------------------
  logic signed [DATA_WIDTH_p-1:0]   weight_active_r; // current weight
  logic signed [DATA_WIDTH_p*2-1:0] mult;     // 8b x 8b -> 16b product
  logic signed [PSUM_WIDTH_p:0]     mult_ext; // sign-extended product (33b)
  logic signed [PSUM_WIDTH_p:0]     acc_full; // guarded accumulator (33b)
  logic signed [PSUM_WIDTH_p-1:0]   acc;      // saturated result (32b)

  // Register the outputs INSIDE the PE
  logic signed [DATA_WIDTH_p-1:0]   a_r;
  logic signed [PSUM_WIDTH_p-1:0]   b_r;
  logic                             v_r;

  // ----------------------------
  // Weight Register
  // ----------------------------
  always_ff @(posedge clk_i) begin
    if (rst_i)
      weight_active_r <= '0;
    else if (v_i && b_is_weight_i)
      weight_active_r <= b_i[DATA_WIDTH_p-1:0];
  end

  // ----------------------------
  // MAC Computation
  // ----------------------------
  // Accumulator clamps values to min/max without being truly sticky. For
  // example, a value clamped to max can still be subtracted from.

  // step 1: multiply if valid - 8b signed x 8b signed => 16b signed
  assign mult = v_i ? (weight_active_r * a_i) : '0;  

  // step 2: sign-extend mult to 33b
  assign mult_ext = {{(PSUM_WIDTH_p - DATA_WIDTH_p * 2 + 1){mult[DATA_WIDTH_p*2-1]}}, mult};

  // step 3: sign-extend b_i to 33b, then acc
  assign acc_full = mult_ext + {{1{b_i[PSUM_WIDTH_p-1]}}, b_i};

  // step 4: saturate to INT32 using guard bit
  // Guard bit [32] and sign bit [31] disagreeing means the true result
  // exceeded the 32-bit signed range - clamp to INT32_MAX or INT32_MIN
  // depending on if overflow or underflow
  always_comb begin
    if (acc_full < -signed'(33'(2**(PSUM_WIDTH_p-1))))
      acc = {1'b1, {(PSUM_WIDTH_p-1){1'b0}}}; // saturate min (underflow)
    else if (acc_full > signed'(33'(2**(PSUM_WIDTH_p-1)-1)))
      acc = {1'b0, {(PSUM_WIDTH_p-1){1'b1}}}; // saturate max (overflow)
    else
      acc = acc_full[PSUM_WIDTH_p-1:0];       // normal
  end

  // ----------------------------
  // Output
  // ----------------------------
  // Register the horizontal data/valid hop inside each PE so each PE-to-PE
  // transfer in the mesh is one cycle.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      a_r <= '0;
      b_r <= '0;
      v_r <= 1'b0;
    end else begin
      a_r <= a_i;
      v_r <= v_i;
      if (b_is_weight_i)
        b_r <= b_i;
      else
        b_r <= acc;
    end
  end

  assign a_o = a_r;
  assign b_o = b_r;
  assign v_o = v_r;
  assign weight_o = weight_active_r;

endmodule
