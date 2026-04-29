// ============================================================
// Top-level 8x8 weight-stationary systolic array
// ------------------------------------------------------------

module top_mod #(
    parameter ARRAY_SIZE  = 8,
    parameter DATA_WIDTH  = 8,
    parameter PSUM_WIDTH  = 32,
    parameter ENABLE_MAC_BYPASS = 0
)(
    input  logic clk_i,
    input  logic rst_i,
    input  logic start,
    input  logic activations_valid_i,

    input  logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_i,

    input  logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] top_data_i,

    input  logic mac_bypass_i,

    output logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] final_psums_o,

    output logic ready_o,
    output logic shadow_weights_active_o,
    output logic output_valid,

    output logic signed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][DATA_WIDTH-1:0] weight_debug_o
);

    logic b_is_weight;
    logic input_valid_to_pe;
    logic load_pulse;
//***AREA EXP START***
/*
    // ------------------------------------------------------------
    // Dummy storage block for area estimation only:
    //   - 10 deep x 80b FIFO
    //   - 2KiB (256 x 64b) data memory
    // Kept active and sunk locally so synthesis cannot prune it.
    // ------------------------------------------------------------
    logic [63:0] area_scratch_addr;
    logic [63:0] area_scratch_data;
    logic        area_push;
    logic        area_pop;
    logic        area_dmem_we;
    logic [63:0] area_dmem_rdata;
    logic [79:0] area_ififo_rdata;
    logic [79:0] area_sink_ff;
    logic signed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][DATA_WIDTH-1:0] weight_debug_raw;
    logic [63:0] area_storage_digest;
    //***AREA EXP END***
*/
    logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_skewed;
    logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] psums_staggered;

    logic signed [DATA_WIDTH-1:0] a_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    logic                         v_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    logic signed [PSUM_WIDTH-1:0] b_link [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

//***AREA EXP START***
/*
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            area_scratch_addr <= 64'h1;
            area_scratch_data <= 64'h1;
            area_push         <= 1'b0;
            area_pop          <= 1'b0;
            area_dmem_we      <= 1'b0;
            area_sink_ff      <= '0;
        end else begin
            // Non-constant toggling keeps the storage paths exercised.
            area_scratch_addr <= area_scratch_addr + 64'h9E37_79B9_7F4A_7C15;
            area_scratch_data <= {area_scratch_data[62:0],
                                  area_scratch_data[63]
                                ^ area_scratch_addr[0]
                                ^ area_scratch_addr[7]
                                ^ top_data_i[0][0]
                                ^ top_data_i[1][0]
                                ^ area_ififo_rdata[0]
                                ^ area_dmem_rdata[0]};  
            area_push         <= area_scratch_addr[0];
            area_pop          <= area_scratch_addr[1];
            area_dmem_we      <= ~area_dmem_we;
            area_sink_ff      <= area_ififo_rdata
                               ^ {16'd0, area_dmem_rdata}
                               ^ {79'd0, area_scratch_addr[0]};
        end
    end

    systolic_area_storage u_area_storage (
        .clk_i         (clk_i),
        .rst_i         (rst_i),
        .scratch_addr_i(area_scratch_addr),
        .scratch_data_i(area_scratch_data),
        .push_i        (area_push),
        .pop_i         (area_pop),
        .dmem_we_i     (area_dmem_we),
        .dmem_rdata_o  (area_dmem_rdata),
        .ififo_rdata_o (area_ififo_rdata),
        .storage_digest_o(area_storage_digest)
    );
    */
//***AREA EXP END***

    systolic_ctrl #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .PSUM_WIDTH (PSUM_WIDTH)
    ) u_systolic_ctrl (
        .clk_i                (clk_i),
        .rst_i                (rst_i),
        .start                (start),
        .activations_valid_i  (activations_valid_i),
        .activations_i        (activations_i),
        .psums_staggered_i    (psums_staggered),
        .activations_skewed_o (activations_skewed),
        .final_psums_o        (final_psums_o),
        .b_is_weight          (b_is_weight),
        .input_valid_to_pe    (input_valid_to_pe),
        .ready_o              (ready_o),
        .shadow_weights_active_o (shadow_weights_active_o),
        .output_valid         (output_valid),
        .load_pulse_o         (load_pulse)
    );

    genvar r, c;
    generate
        for (r = 0; r < ARRAY_SIZE; r++) begin : ROW_GEN
            for (c = 0; c < ARRAY_SIZE; c++) begin : COL_GEN

                logic signed [DATA_WIDTH-1:0] a_in_local;
                logic                         v_in_local;
                logic signed [PSUM_WIDTH-1:0] b_in_local;

                if (c == 0) begin : LEFT_EDGE
                    assign a_in_local = activations_skewed[r];
                    assign v_in_local = (b_is_weight) ? load_pulse : input_valid_to_pe;
                end else begin : INTERNAL_LEFT
                    assign a_in_local = a_link[r][c-1];
                    assign v_in_local = (b_is_weight) ? load_pulse : v_link[r][c-1];
                end

                if (r == 0) begin : TOP_EDGE
                    assign b_in_local = top_data_i[c];
                end else begin : INTERNAL_TOP
                    assign b_in_local = b_link[r-1][c];
                end

                PE #(
                    .ENABLE_MAC_BYPASS (ENABLE_MAC_BYPASS),
                    .DATA_WIDTH        (DATA_WIDTH),
                    .PSUM_WIDTH        (PSUM_WIDTH),
		    .ROW_ID            (r),
                    .COL_ID            (c)
                ) u_pe (
                    .clk_i              (clk_i),
                    .rst_i              (rst_i),
                    .v_i                (v_in_local),
                    .mac_bypass_i       (mac_bypass_i),
                    .a_i                (a_in_local),
                    .b_i                (b_in_local),
                    .b_is_weight_i      (b_is_weight),
                    .v_o                (v_link[r][c]),
                    .a_o                (a_link[r][c]),
                    .b_o                (b_link[r][c]),
     //               .weight_o           (weight_debug_raw[r][c]) //AREA EXP
                    .weight_o           (weight_debug_o[r][c])
        	 );

            end
        end
    endgenerate

    generate
        for (c = 0; c < ARRAY_SIZE; c++) begin : BOTTOM_CAPTURE
            assign psums_staggered[c] = b_link[ARRAY_SIZE-1][c];
        end
    endgenerate

//***AREA EXP START***
/*
    // Make area-probe logic observable at a top-level output so synthesis
    // cannot prune the dummy storage cone as "unused".
    always_comb begin
        weight_debug_o = weight_debug_raw;
       // weight_debug_o[0][0][0] = weight_debug_raw[0][0][0] ^ area_sink_ff[0];
        // Route digest + sink into top-level observable output bits so every
        // storage bit is in an externally visible cone.
        weight_debug_o[0][0] = weight_debug_raw[0][0] ^ area_storage_digest[7:0];
        weight_debug_o[0][1] = weight_debug_raw[0][1] ^ area_storage_digest[15:8];
        weight_debug_o[0][2] = weight_debug_raw[0][2] ^ area_storage_digest[23:16];
        weight_debug_o[0][3] = weight_debug_raw[0][3] ^ area_storage_digest[31:24];
        weight_debug_o[0][4] = weight_debug_raw[0][4] ^ area_storage_digest[39:32];
        weight_debug_o[0][5] = weight_debug_raw[0][5] ^ area_storage_digest[47:40];
        weight_debug_o[0][6] = weight_debug_raw[0][6] ^ area_storage_digest[55:48];
        weight_debug_o[0][7] = weight_debug_raw[0][7] ^ area_storage_digest[63:56];
        weight_debug_o[1][0][0] = weight_debug_raw[1][0][0] ^ area_sink_ff[0];
    end
*/
//***AREA EXP END***
endmodule
