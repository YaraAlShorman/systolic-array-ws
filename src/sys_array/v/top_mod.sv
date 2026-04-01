// ============================================================
// Top-level 8x8 weight-stationary systolic array
//
// This module connects together:
// 1) The systolic controller (FSM + input skew + output de-skew)
// 2) The 64 PE instances (8 rows x 8 columns)
// 3) The internal horizontal and vertical wires
//
// ------------------------------------------------------------
// DATAFLOW SUMMARY
// ------------------------------------------------------------
// - Activations enter from the LEFT side of the array
// - The controller skews those activations in time
// - Each PE passes activation horizontally to the RIGHT
//
// - Vertical data enters from the TOP of the array
// - During LOAD_WTS, top_data_i carries WEIGHTS
// - During COMPUTE, top_data_i usually carries initial PSUMS
//   (most often zeros)
//
// - Each PE passes vertical data DOWNWARD
// - The bottom row outputs are still time-staggered
// - The controller de-skews them into final_psums_o
//
// ------------------------------------------------------------
// WHY THIS MATCHES YOUR REPORT
// ------------------------------------------------------------
// - PEs store weights locally during weight load
// - Activations move horizontally
// - Weights / psums share vertical datapath
// - Controller has IDLE / LOAD_WTS / COMPUTE / DRAIN
// - Shift registers skew inputs and de-skew outputs
// ------------------------------------------------------------

module top_mod #(
    parameter ARRAY_SIZE  = 8,
    parameter DATA_WIDTH  = 8,
    parameter PSUM_WIDTH  = 32,
    parameter ENABLE_MAC_BYPASS = 1
)(
    input  logic clk_i,
    input  logic rst_i,
    input  logic start,

    // Number of activation rows / valid compute cycles
    input  logic [15:0] num_input_rows,

    // Left boundary activations into the array
    // One activation stream per row
    input  logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_i,

    // Top boundary vertical inputs into the array
    // During LOAD_WTS: these carry weights in b_i[7:0]
    // During COMPUTE : these carry incoming psums (usually zeros at top boundary)
    input  logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] top_data_i,

    // Optional global MAC bypass control
    input  logic mac_bypass_i,

    // Final, de-skewed outputs from the controller
    output logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] final_psums_o,

    // Control/status outputs
    output logic ready_o,
    output logic output_valid,

    // Optional debug: stored weight in every PE
    output logic signed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][DATA_WIDTH-1:0] weight_debug_o
);

    // ========================================================
    // 1) Signals between controller and PE array
    // ========================================================

    // Controller tells PEs whether vertical data is weight or psum
    logic b_is_weight;

    // Controller tells array whether input stream is valid
    logic input_valid_to_pe;

    // Controller outputs skewed activations (already delayed row-by-row)
    logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_skewed;

    // Bottom-row staggered outputs go into controller
    logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] psums_staggered;

    // ========================================================
    // 1A) Row-select valid for weight loading
    // ========================================================
    //
    // During LOAD_WTS, the PE vertical weight path is combinational:
    //    b_o = b_i
    //
    // So all rows in a column see the same top_data_i[c] in the same cycle.
    // To load different weights into different rows, exactly ONE row must
    // be enabled per LOAD_WTS cycle.
    //
    // load_row_idx selects which row captures the current top_data_i values.
    // ========================================================

    logic                                 b_is_weight_d;
    logic [$clog2(ARRAY_SIZE)-1:0]        load_row_idx;
    logic [ARRAY_SIZE-1:0]                load_valid_by_row;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            b_is_weight_d <= 1'b0;
            load_row_idx  <= '0;
        end
        else begin
            // register previous-cycle LOAD_WTS state
            b_is_weight_d <= b_is_weight;

            if (!b_is_weight) begin
                // Outside LOAD_WTS, reset index
                load_row_idx <= '0;
            end
            else if (!b_is_weight_d) begin
                // First real LOAD_WTS cycle uses row 0 now,
                // so prepare row 1 for the next cycle
                if (ARRAY_SIZE > 1)
                    load_row_idx <= 1;
                else
                    load_row_idx <= '0;
            end
            else begin
                // Advance one row per LOAD_WTS cycle
                if (load_row_idx < ARRAY_SIZE-1)
                    load_row_idx <= load_row_idx + 1'b1;
            end
        end
    end

    always_comb begin
        load_valid_by_row = '0;
        if (b_is_weight)
            load_valid_by_row[load_row_idx] = 1'b1;
    end

    // ========================================================
    // 2) Internal interconnect inside the PE mesh
    // ========================================================
    //
    // a_link[r][c] = activation output from PE at row r, col c
    // v_link[r][c] = valid output from PE at row r, col c
    // b_link[r][c] = vertical output from PE at row r, col c
    //
    // These are INTERNAL wires between PEs.
    // ========================================================

    logic signed [DATA_WIDTH-1:0] a_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    logic                         v_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    logic signed [PSUM_WIDTH-1:0] b_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    // ========================================================
    // 3) Instantiate the controller
    // ========================================================

    systolic_ctrl #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .PSUM_WIDTH (PSUM_WIDTH)
    ) u_systolic_ctrl (
        .clk_i               (clk_i),
        .rst_i               (rst_i),
        .start               (start),
        .num_input_rows      (num_input_rows),
        .activations_i       (activations_i),
        .psums_staggered_i   (psums_staggered),
        .activations_skewed_o(activations_skewed),
        .final_psums_o       (final_psums_o),
        .b_is_weight         (b_is_weight),
        .input_valid_to_pe   (input_valid_to_pe),
        .ready_o             (ready_o),
        .output_valid        (output_valid)
    );

    // ========================================================
    // 4) Instantiate the 64 PEs using nested generate loops
    // ========================================================

    genvar r, c;
    generate
        for (r = 0; r < ARRAY_SIZE; r++) begin : ROW_GEN
            for (c = 0; c < ARRAY_SIZE; c++) begin : COL_GEN

                // --------------------------------------------
                // Local wires going INTO this PE
                // --------------------------------------------
                logic signed [DATA_WIDTH-1:0] a_in_local;
                logic                         v_in_local;
                logic signed [PSUM_WIDTH-1:0] b_in_local;

                // --------------------------------------------
                // Activation input selection
                // --------------------------------------------
                // During LOAD_WTS:
                //   use one-hot row load valid
                //
                // During COMPUTE:
                //   first column gets input_valid_to_pe
                //   other columns get valid from PE on the left
                // --------------------------------------------
                if (c == 0) begin : LEFT_EDGE
                    assign a_in_local = activations_skewed[r];
                    assign v_in_local = (b_is_weight) ? load_valid_by_row[r]: input_valid_to_pe;
                end
                else begin : INTERNAL_LEFT
                    assign a_in_local = a_link[r][c-1];
                    assign v_in_local = (b_is_weight) ? load_valid_by_row[r]: v_link[r][c-1];
                end

                // --------------------------------------------
                // Vertical input selection
                // --------------------------------------------
                // First row gets top boundary data from top_data_i
                // Other rows get vertical data from PE above
                // --------------------------------------------
                if (r == 0) begin : TOP_EDGE
                    assign b_in_local = top_data_i[c];
                end
                else begin : INTERNAL_TOP
                    assign b_in_local = b_link[r-1][c];
                end

                // --------------------------------------------
                // Instantiate one PE
                // --------------------------------------------
                PE #(
                    .ENABLE_MAC_BYPASS (ENABLE_MAC_BYPASS),
                    .ROW_ID            (r),
                    .COL_ID            (c)
                ) u_pe (
                    .clk_i         (clk_i),
                    .rst_i         (rst_i),
                    .v_i           (v_in_local),
                    .mac_bypass_i  (mac_bypass_i),
                    .a_i           (a_in_local),
                    .b_i           (b_in_local),
                    .b_is_weight_i (b_is_weight),
                    .v_o           (v_link[r][c]),
                    .a_o           (a_link[r][c]),
                    .b_o           (b_link[r][c]),
                    .weight_o      (weight_debug_o[r][c])
                );

            end
        end
    endgenerate

    // ========================================================
    // 5) Connect bottom row outputs back into the controller
    // ========================================================

    generate
        for (c = 0; c < ARRAY_SIZE; c++) begin : BOTTOM_CAPTURE
            assign psums_staggered[c] = b_link[ARRAY_SIZE-1][c];
        end
    endgenerate

endmodule







