`ifndef SHADOW_LOADING_V1
module PE #(
    parameter int DATA_WIDTH = 8,
    parameter int PSUM_WIDTH = 32
)(
    input  logic clk_i,
    input  logic rst_i,
    input  logic v_i,
    input  logic weight_en,
    input  logic load_active,
    input  logic signed [DATA_WIDTH-1:0] a_i,
    input  logic signed [DATA_WIDTH-1:0] weight_i,
    input  logic signed [PSUM_WIDTH-1:0] psum_i,
    output logic                          v_o,
    output logic signed [DATA_WIDTH-1:0]  a_o,
    output logic signed [PSUM_WIDTH-1:0]  psum_o,
    output logic signed [DATA_WIDTH-1:0]  weight_o
);

    logic signed [DATA_WIDTH-1:0] weight1, weight2;
    logic                         mac_use_bank2; // 0: MAC uses weight1; 1: MAC uses weight2
    logic signed [DATA_WIDTH-1:0] weight_active;
    logic signed [DATA_WIDTH*2-1:0] mult;
    logic signed [PSUM_WIDTH:0]     mult_ext;
    logic signed [PSUM_WIDTH:0]     acc_full;
    logic signed [PSUM_WIDTH-1:0]   acc;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i)
            mac_use_bank2 <= 1'b0;
        else if (load_active)
            mac_use_bank2 <= ~mac_use_bank2;
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            weight1 <= '0;
            weight2 <= '0;
        end else if (weight_en) begin
            if (mac_use_bank2)
                weight1 <= weight_i;
            else
                weight2 <= weight_i;
        end
    end

    assign weight_active = mac_use_bank2 ? weight2 : weight1;

    assign mult     = v_i ? (weight_active * a_i) : 'sd0;
    assign mult_ext = {{(PSUM_WIDTH - DATA_WIDTH*2 + 1){mult[DATA_WIDTH*2-1]}}, mult};

    assign acc_full = mult_ext + {{1{psum_i[PSUM_WIDTH-1]}}, psum_i};

    always_comb begin
        if (acc_full < -signed'(33'(2**(PSUM_WIDTH-1))))
            acc = {1'b1, {(PSUM_WIDTH-1){1'b0}}};
        else if (acc_full > signed'(33'(2**(PSUM_WIDTH-1)-1)))
            acc = {1'b0, {(PSUM_WIDTH-1){1'b1}}};
        else
            acc = acc_full[PSUM_WIDTH-1:0];
    end

    assign v_o      = v_i;
    assign psum_o   = acc;
    assign weight_o = weight_i;

    assign a_o = a_i;

`ifdef SIMULATION
    property p_a_passthrough;
        @(posedge clk_i) disable iff (rst_i) (a_o == a_i);
    endproperty
    A_a_passthrough: assert property (p_a_passthrough);

    property p_v_passthrough;
        @(posedge clk_i) disable iff (rst_i) (v_o == v_i);
    endproperty
    A_v_passthrough: assert property (p_v_passthrough);

    property p_saturate_max;
        @(posedge clk_i) disable iff (rst_i)
        (acc_full > 33'sh0_7FFFFFFF) |-> (psum_o == 32'sh7FFFFFFF);
    endproperty
    A_saturate_max: assert property (p_saturate_max) 
        else $error("[%0t] PE: Failed to saturate on overflow", $time);

    property p_saturate_min;
        @(posedge clk_i) disable iff (rst_i)
        (acc_full < -33'sh0_80000000) |-> (psum_o == 32'sh80000000);
    endproperty
    A_saturate_min: assert property (p_saturate_min)
        else $error("[%0t] PE: Failed to saturate on underflow", $time);

    property p_bank_swap;
        @(posedge clk_i) disable iff (rst_i)
        load_active |=> (mac_use_bank2 == ~$past(mac_use_bank2));
    endproperty
    A_bank_swap: assert property (p_bank_swap)
        else $error("[%0t] PE: load_active failed to toggle bank pointer", $time);

    property p_shadow_load;
        @(posedge clk_i) disable iff (rst_i)
        weight_en |=> (mac_use_bank2 ? (weight1 == $past(weight_i)) : (weight2 == $past(weight_i)));
    endproperty
    A_shadow_load: assert property (p_shadow_load)
        else $error("[%0t] PE: weight_en failed to load into the inactive bank", $time);

    C_load_active_fires: cover property (@(posedge clk_i) load_active);
    C_weight_en_fires:   cover property (@(posedge clk_i) weight_en);
`endif

endmodule

`else

module PE #(
  parameter int DATA_WIDTH = 8,
  parameter int PSUM_WIDTH = 32,
)(
  input  logic                         clk_i,
  input  logic                         rst_i,

  // Weight/Psum path - registered inside PE
  input  logic signed [PSUM_WIDTH-1:0] b_i,
  input  logic                         b_is_weight_i,
  output logic signed [PSUM_WIDTH-1:0] b_o,
  output logic signed [DATA_WIDTH-1:0] weight_o, // debug stored weight

  // Activation path - registered inside PE
  input  logic signed [DATA_WIDTH-1:0] a_i,
  output logic signed [DATA_WIDTH-1:0] a_o,

  // Valid
  input  logic                         v_i,
  output logic                         v_o
);

  // ----------------------------
  // Internal Signals/Registers
  // ----------------------------
  logic signed [DATA_WIDTH-1:0]   weight_active; // current weight
  logic signed [DATA_WIDTH*2-1:0] mult;     // 8b x 8b -> 16b product
  logic signed [PSUM_WIDTH:0]     mult_ext; // sign-extended product (33b)
  logic signed [PSUM_WIDTH:0]     acc_full; // guarded accumulator (33b)
  logic signed [PSUM_WIDTH-1:0]   acc;      // saturated result (32b)

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
  // MAC Computation
  // ----------------------------
  // Accumulator clamps values to min/max without being truly sticky. For
  // example, a value clamped to max can still be subtracted from.

  // step 1: multiply if valid - 8b signed x 8b signed => 16b signed
  assign mult = v_i ? (weight_active * a_i) : 16'sd0;  

  // step 2: sign-extend mult to 33b
  assign mult_ext = {{(PSUM_WIDTH - DATA_WIDTH * 2 + 1){mult[DATA_WIDTH*2-1]}}, mult};

  // step 3: sign-extend b_i to 33b, then acc
  assign acc_full = mult_ext + {{1{b_i[PSUM_WIDTH-1]}}, b_i};

  // step 4: saturate to INT32 using guard bit
  // Guard bit [32] and sign bit [31] disagreeing means the true result
  // exceeded the 32-bit signed range - clamp to INT32_MAX or INT32_MIN
  // depending on if overflow or underflow
  always_comb begin
    if (acc_full < -signed'(33'(2**(PSUM_WIDTH-1))))
      acc = {1'b1, {(PSUM_WIDTH-1){1'b0}}}; // saturate min (underflow)
    else if (acc_full > signed'(33'(2**(PSUM_WIDTH-1)-1)))
      acc = {1'b0, {(PSUM_WIDTH-1){1'b1}}}; // saturate max (overflow)
    else
      acc = acc_full[PSUM_WIDTH-1:0];       // normal
  end

  // ----------------------------
  // Output
  // ----------------------------
  // Register the horizontal data/valid hop inside each PE so each PE-to-PE
  // transfer in the mesh is one cycle.
  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      a_o <= '0;
      v_o <= 1'b0;
      b_o <= '0;
    end else begin
      a_o <= a_i;
      v_o <= !b_is_weight_i ? v_i : 1'b0;
      if (b_is_weight_i)
              b_o <= b_i;
      else
              b_o <= acc;
    end
  end

  assign weight_o = weight_active;

endmodule

`endif
