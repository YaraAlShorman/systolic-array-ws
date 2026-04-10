`timescale 1ns/1ps

module top_mod_par_tb;

    localparam int ARRAY_SIZE = 8;
    localparam int DATA_WIDTH = 8;
    localparam int PSUM_WIDTH = 32;

    logic clk_i;
    logic rst_i;
    logic start;
    logic [15:0] num_input_rows;
    logic mac_bypass_i;

    logic [7:0]  activations_i_0;
    logic [7:0]  activations_i_1;
    logic [7:0]  activations_i_2;
    logic [7:0]  activations_i_3;
    logic [7:0]  activations_i_4;
    logic [7:0]  activations_i_5;
    logic [7:0]  activations_i_6;
    logic [7:0]  activations_i_7;

    logic [31:0] top_data_i_0;
    logic [31:0] top_data_i_1;
    logic [31:0] top_data_i_2;
    logic [31:0] top_data_i_3;
    logic [31:0] top_data_i_4;
    logic [31:0] top_data_i_5;
    logic [31:0] top_data_i_6;
    logic [31:0] top_data_i_7;

    logic [31:0] final_psums_o_0;
    logic [31:0] final_psums_o_1;
    logic [31:0] final_psums_o_2;
    logic [31:0] final_psums_o_3;
    logic [31:0] final_psums_o_4;
    logic [31:0] final_psums_o_5;
    logic [31:0] final_psums_o_6;
    logic [31:0] final_psums_o_7;

    logic ready_o;
    logic output_valid;

    // Optional debug outputs
    logic [7:0] weight_debug_o_0_0;
    logic [7:0] weight_debug_o_0_1;
    logic [7:0] weight_debug_o_0_2;
    logic [7:0] weight_debug_o_0_3;
    logic [7:0] weight_debug_o_0_4;
    logic [7:0] weight_debug_o_0_5;
    logic [7:0] weight_debug_o_0_6;
    logic [7:0] weight_debug_o_0_7;

    logic [7:0] weight_debug_o_1_0;
    logic [7:0] weight_debug_o_1_1;
    logic [7:0] weight_debug_o_1_2;
    logic [7:0] weight_debug_o_1_3;
    logic [7:0] weight_debug_o_1_4;
    logic [7:0] weight_debug_o_1_5;
    logic [7:0] weight_debug_o_1_6;
    logic [7:0] weight_debug_o_1_7;

    logic [7:0] weight_debug_o_2_0;
    logic [7:0] weight_debug_o_2_1;
    logic [7:0] weight_debug_o_2_2;
    logic [7:0] weight_debug_o_2_3;
    logic [7:0] weight_debug_o_2_4;
    logic [7:0] weight_debug_o_2_5;
    logic [7:0] weight_debug_o_2_6;
    logic [7:0] weight_debug_o_2_7;

    logic [7:0] weight_debug_o_3_0;
    logic [7:0] weight_debug_o_3_1;
    logic [7:0] weight_debug_o_3_2;
    logic [7:0] weight_debug_o_3_3;
    logic [7:0] weight_debug_o_3_4;
    logic [7:0] weight_debug_o_3_5;
    logic [7:0] weight_debug_o_3_6;
    logic [7:0] weight_debug_o_3_7;

    logic [7:0] weight_debug_o_4_0;
    logic [7:0] weight_debug_o_4_1;
    logic [7:0] weight_debug_o_4_2;
    logic [7:0] weight_debug_o_4_3;
    logic [7:0] weight_debug_o_4_4;
    logic [7:0] weight_debug_o_4_5;
    logic [7:0] weight_debug_o_4_6;
    logic [7:0] weight_debug_o_4_7;

    logic [7:0] weight_debug_o_5_0;
    logic [7:0] weight_debug_o_5_1;
    logic [7:0] weight_debug_o_5_2;
    logic [7:0] weight_debug_o_5_3;
    logic [7:0] weight_debug_o_5_4;
    logic [7:0] weight_debug_o_5_5;
    logic [7:0] weight_debug_o_5_6;
    logic [7:0] weight_debug_o_5_7;

    logic [7:0] weight_debug_o_6_0;
    logic [7:0] weight_debug_o_6_1;
    logic [7:0] weight_debug_o_6_2;
    logic [7:0] weight_debug_o_6_3;
    logic [7:0] weight_debug_o_6_4;
    logic [7:0] weight_debug_o_6_5;
    logic [7:0] weight_debug_o_6_6;
    logic [7:0] weight_debug_o_6_7;

    logic [7:0] weight_debug_o_7_0;
    logic [7:0] weight_debug_o_7_1;
    logic [7:0] weight_debug_o_7_2;
    logic [7:0] weight_debug_o_7_3;
    logic [7:0] weight_debug_o_7_4;
    logic [7:0] weight_debug_o_7_5;
    logic [7:0] weight_debug_o_7_6;
    logic [7:0] weight_debug_o_7_7;

    // Aggregate TB-side signals used by the original RTL-style testbench code
    logic signed [DATA_WIDTH-1:0]                 activations_i        [0:ARRAY_SIZE-1];
    logic signed [PSUM_WIDTH-1:0]                 top_data_i           [0:ARRAY_SIZE-1];
    logic signed [PSUM_WIDTH-1:0]                 final_psums_o        [0:ARRAY_SIZE-1];
    logic signed [DATA_WIDTH-1:0]                 weight_debug_o       [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    logic signed [PSUM_WIDTH-1:0]                 captured_final_psums [0:ARRAY_SIZE-1];
    logic                                         captured_seen        [0:ARRAY_SIZE-1];
    logic                                         matched_seen         [0:ARRAY_SIZE-1];

    logic signed [DATA_WIDTH-1:0]                 weight_matrix        [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    logic signed [DATA_WIDTH-1:0]                 activation_vector    [0:ARRAY_SIZE-1];
    logic signed [PSUM_WIDTH-1:0]                 expected_psums       [0:ARRAY_SIZE-1];

    top_mod dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .start(start),
        .num_input_rows(num_input_rows),

        .\activations_i[0] (activations_i_0),
        .\activations_i[1] (activations_i_1),
        .\activations_i[2] (activations_i_2),
        .\activations_i[3] (activations_i_3),
        .\activations_i[4] (activations_i_4),
        .\activations_i[5] (activations_i_5),
        .\activations_i[6] (activations_i_6),
        .\activations_i[7] (activations_i_7),

        .\top_data_i[0] (top_data_i_0),
        .\top_data_i[1] (top_data_i_1),
        .\top_data_i[2] (top_data_i_2),
        .\top_data_i[3] (top_data_i_3),
        .\top_data_i[4] (top_data_i_4),
        .\top_data_i[5] (top_data_i_5),
        .\top_data_i[6] (top_data_i_6),
        .\top_data_i[7] (top_data_i_7),

        .mac_bypass_i(mac_bypass_i),

        .\final_psums_o[0] (final_psums_o_0),
        .\final_psums_o[1] (final_psums_o_1),
        .\final_psums_o[2] (final_psums_o_2),
        .\final_psums_o[3] (final_psums_o_3),
        .\final_psums_o[4] (final_psums_o_4),
        .\final_psums_o[5] (final_psums_o_5),
        .\final_psums_o[6] (final_psums_o_6),
        .\final_psums_o[7] (final_psums_o_7),

        .ready_o(ready_o),
        .output_valid(output_valid),

        .\weight_debug_o[0][0] (weight_debug_o_0_0),
        .\weight_debug_o[0][1] (weight_debug_o_0_1),
        .\weight_debug_o[0][2] (weight_debug_o_0_2),
        .\weight_debug_o[0][3] (weight_debug_o_0_3),
        .\weight_debug_o[0][4] (weight_debug_o_0_4),
        .\weight_debug_o[0][5] (weight_debug_o_0_5),
        .\weight_debug_o[0][6] (weight_debug_o_0_6),
        .\weight_debug_o[0][7] (weight_debug_o_0_7),

        .\weight_debug_o[1][0] (weight_debug_o_1_0),
        .\weight_debug_o[1][1] (weight_debug_o_1_1),
        .\weight_debug_o[1][2] (weight_debug_o_1_2),
        .\weight_debug_o[1][3] (weight_debug_o_1_3),
        .\weight_debug_o[1][4] (weight_debug_o_1_4),
        .\weight_debug_o[1][5] (weight_debug_o_1_5),
        .\weight_debug_o[1][6] (weight_debug_o_1_6),
        .\weight_debug_o[1][7] (weight_debug_o_1_7),

        .\weight_debug_o[2][0] (weight_debug_o_2_0),
        .\weight_debug_o[2][1] (weight_debug_o_2_1),
        .\weight_debug_o[2][2] (weight_debug_o_2_2),
        .\weight_debug_o[2][3] (weight_debug_o_2_3),
        .\weight_debug_o[2][4] (weight_debug_o_2_4),
        .\weight_debug_o[2][5] (weight_debug_o_2_5),
        .\weight_debug_o[2][6] (weight_debug_o_2_6),
        .\weight_debug_o[2][7] (weight_debug_o_2_7),

        .\weight_debug_o[3][0] (weight_debug_o_3_0),
        .\weight_debug_o[3][1] (weight_debug_o_3_1),
        .\weight_debug_o[3][2] (weight_debug_o_3_2),
        .\weight_debug_o[3][3] (weight_debug_o_3_3),
        .\weight_debug_o[3][4] (weight_debug_o_3_4),
        .\weight_debug_o[3][5] (weight_debug_o_3_5),
        .\weight_debug_o[3][6] (weight_debug_o_3_6),
        .\weight_debug_o[3][7] (weight_debug_o_3_7),

        .\weight_debug_o[4][0] (weight_debug_o_4_0),
        .\weight_debug_o[4][1] (weight_debug_o_4_1),
        .\weight_debug_o[4][2] (weight_debug_o_4_2),
        .\weight_debug_o[4][3] (weight_debug_o_4_3),
        .\weight_debug_o[4][4] (weight_debug_o_4_4),
        .\weight_debug_o[4][5] (weight_debug_o_4_5),
        .\weight_debug_o[4][6] (weight_debug_o_4_6),
        .\weight_debug_o[4][7] (weight_debug_o_4_7),

        .\weight_debug_o[5][0] (weight_debug_o_5_0),
        .\weight_debug_o[5][1] (weight_debug_o_5_1),
        .\weight_debug_o[5][2] (weight_debug_o_5_2),
        .\weight_debug_o[5][3] (weight_debug_o_5_3),
        .\weight_debug_o[5][4] (weight_debug_o_5_4),
        .\weight_debug_o[5][5] (weight_debug_o_5_5),
        .\weight_debug_o[5][6] (weight_debug_o_5_6),
        .\weight_debug_o[5][7] (weight_debug_o_5_7),

        .\weight_debug_o[6][0] (weight_debug_o_6_0),
        .\weight_debug_o[6][1] (weight_debug_o_6_1),
        .\weight_debug_o[6][2] (weight_debug_o_6_2),
        .\weight_debug_o[6][3] (weight_debug_o_6_3),
        .\weight_debug_o[6][4] (weight_debug_o_6_4),
        .\weight_debug_o[6][5] (weight_debug_o_6_5),
        .\weight_debug_o[6][6] (weight_debug_o_6_6),
        .\weight_debug_o[6][7] (weight_debug_o_6_7),

        .\weight_debug_o[7][0] (weight_debug_o_7_0),
        .\weight_debug_o[7][1] (weight_debug_o_7_1),
        .\weight_debug_o[7][2] (weight_debug_o_7_2),
        .\weight_debug_o[7][3] (weight_debug_o_7_3),
        .\weight_debug_o[7][4] (weight_debug_o_7_4),
        .\weight_debug_o[7][5] (weight_debug_o_7_5),
        .\weight_debug_o[7][6] (weight_debug_o_7_6),
        .\weight_debug_o[7][7] (weight_debug_o_7_7)
    );

    // Bridge TB aggregate arrays to flattened PAR ports
    assign activations_i_0 = activations_i[0];
    assign activations_i_1 = activations_i[1];
    assign activations_i_2 = activations_i[2];
    assign activations_i_3 = activations_i[3];
    assign activations_i_4 = activations_i[4];
    assign activations_i_5 = activations_i[5];
    assign activations_i_6 = activations_i[6];
    assign activations_i_7 = activations_i[7];

    assign top_data_i_0 = top_data_i[0];
    assign top_data_i_1 = top_data_i[1];
    assign top_data_i_2 = top_data_i[2];
    assign top_data_i_3 = top_data_i[3];
    assign top_data_i_4 = top_data_i[4];
    assign top_data_i_5 = top_data_i[5];
    assign top_data_i_6 = top_data_i[6];
    assign top_data_i_7 = top_data_i[7];

    assign final_psums_o[0] = final_psums_o_0;
    assign final_psums_o[1] = final_psums_o_1;
    assign final_psums_o[2] = final_psums_o_2;
    assign final_psums_o[3] = final_psums_o_3;
    assign final_psums_o[4] = final_psums_o_4;
    assign final_psums_o[5] = final_psums_o_5;
    assign final_psums_o[6] = final_psums_o_6;
    assign final_psums_o[7] = final_psums_o_7;

    assign weight_debug_o[0][0] = weight_debug_o_0_0;
    assign weight_debug_o[0][1] = weight_debug_o_0_1;
    assign weight_debug_o[0][2] = weight_debug_o_0_2;
    assign weight_debug_o[0][3] = weight_debug_o_0_3;
    assign weight_debug_o[0][4] = weight_debug_o_0_4;
    assign weight_debug_o[0][5] = weight_debug_o_0_5;
    assign weight_debug_o[0][6] = weight_debug_o_0_6;
    assign weight_debug_o[0][7] = weight_debug_o_0_7;

    assign weight_debug_o[1][0] = weight_debug_o_1_0;
    assign weight_debug_o[1][1] = weight_debug_o_1_1;
    assign weight_debug_o[1][2] = weight_debug_o_1_2;
    assign weight_debug_o[1][3] = weight_debug_o_1_3;
    assign weight_debug_o[1][4] = weight_debug_o_1_4;
    assign weight_debug_o[1][5] = weight_debug_o_1_5;
    assign weight_debug_o[1][6] = weight_debug_o_1_6;
    assign weight_debug_o[1][7] = weight_debug_o_1_7;

    assign weight_debug_o[2][0] = weight_debug_o_2_0;
    assign weight_debug_o[2][1] = weight_debug_o_2_1;
    assign weight_debug_o[2][2] = weight_debug_o_2_2;
    assign weight_debug_o[2][3] = weight_debug_o_2_3;
    assign weight_debug_o[2][4] = weight_debug_o_2_4;
    assign weight_debug_o[2][5] = weight_debug_o_2_5;
    assign weight_debug_o[2][6] = weight_debug_o_2_6;
    assign weight_debug_o[2][7] = weight_debug_o_2_7;

    assign weight_debug_o[3][0] = weight_debug_o_3_0;
    assign weight_debug_o[3][1] = weight_debug_o_3_1;
    assign weight_debug_o[3][2] = weight_debug_o_3_2;
    assign weight_debug_o[3][3] = weight_debug_o_3_3;
    assign weight_debug_o[3][4] = weight_debug_o_3_4;
    assign weight_debug_o[3][5] = weight_debug_o_3_5;
    assign weight_debug_o[3][6] = weight_debug_o_3_6;
    assign weight_debug_o[3][7] = weight_debug_o_3_7;

    assign weight_debug_o[4][0] = weight_debug_o_4_0;
    assign weight_debug_o[4][1] = weight_debug_o_4_1;
    assign weight_debug_o[4][2] = weight_debug_o_4_2;
    assign weight_debug_o[4][3] = weight_debug_o_4_3;
    assign weight_debug_o[4][4] = weight_debug_o_4_4;
    assign weight_debug_o[4][5] = weight_debug_o_4_5;
    assign weight_debug_o[4][6] = weight_debug_o_4_6;
    assign weight_debug_o[4][7] = weight_debug_o_4_7;

    assign weight_debug_o[5][0] = weight_debug_o_5_0;
    assign weight_debug_o[5][1] = weight_debug_o_5_1;
    assign weight_debug_o[5][2] = weight_debug_o_5_2;
    assign weight_debug_o[5][3] = weight_debug_o_5_3;
    assign weight_debug_o[5][4] = weight_debug_o_5_4;
    assign weight_debug_o[5][5] = weight_debug_o_5_5;
    assign weight_debug_o[5][6] = weight_debug_o_5_6;
    assign weight_debug_o[5][7] = weight_debug_o_5_7;

    assign weight_debug_o[6][0] = weight_debug_o_6_0;
    assign weight_debug_o[6][1] = weight_debug_o_6_1;
    assign weight_debug_o[6][2] = weight_debug_o_6_2;
    assign weight_debug_o[6][3] = weight_debug_o_6_3;
    assign weight_debug_o[6][4] = weight_debug_o_6_4;
    assign weight_debug_o[6][5] = weight_debug_o_6_5;
    assign weight_debug_o[6][6] = weight_debug_o_6_6;
    assign weight_debug_o[6][7] = weight_debug_o_6_7;

    assign weight_debug_o[7][0] = weight_debug_o_7_0;
    assign weight_debug_o[7][1] = weight_debug_o_7_1;
    assign weight_debug_o[7][2] = weight_debug_o_7_2;
    assign weight_debug_o[7][3] = weight_debug_o_7_3;
    assign weight_debug_o[7][4] = weight_debug_o_7_4;
    assign weight_debug_o[7][5] = weight_debug_o_7_5;
    assign weight_debug_o[7][6] = weight_debug_o_7_6;
    assign weight_debug_o[7][7] = weight_debug_o_7_7;

    always @(posedge clk_i) begin
        if (rst_i || start || output_valid || ready_o !== 1'b0) begin
            $display("[%0t] rst=%b start=%b ready=%b output_valid=%b num_input_rows=%0d",
                    $time, rst_i, start, ready_o, output_valid, num_input_rows);
        end
    end

    // ========================================================
    // 5) clock generation
    // ========================================================
    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end
    // ========================================================
    // 6) Wait helper with timeout
    // ========================================================

    task automatic wait_for_ready_with_timeout(input int max_cycles);
        int cycles;
        begin
            cycles = 0;
            while ((ready_o !== 1'b1) && (cycles < max_cycles)) begin
                @(posedge clk_i);
                cycles++;
            end

            if (ready_o !== 1'b1) begin
                $display("[%0t] ERROR: ready_o never asserted within %0d cycles. ready_o=%b output_valid=%b",
                        $time, max_cycles, ready_o, output_valid);
                $finish;
            end

            $display("[%0t] ready_o asserted after %0d cycles.", $time, cycles);
        end
    endtask

    // ========================================================
    // 7) Clear all inputs and capture storage
    // ========================================================
    task automatic clear_all_inputs;
        begin
            start          = 1'b0;
            num_input_rows = '0;
            mac_bypass_i   = 1'b0;

            for (int i = 0; i < ARRAY_SIZE; i++) begin
                activations_i[i]        = '0;
                top_data_i[i]           = '0;
                captured_final_psums[i] = '0;
                captured_seen[i]        = 1'b0;
                matched_seen[i]         = 1'b0;
            end
        end
    endtask

    // ========================================================
    // 8) Initialize test data
    // ========================================================
    task automatic init_test_data;
        begin
            // Row 0
            weight_matrix[0][0] =  1;  weight_matrix[0][1] =  2;  weight_matrix[0][2] =  3;  weight_matrix[0][3] =  4;
            weight_matrix[0][4] = -1;  weight_matrix[0][5] =  0;  weight_matrix[0][6] =  1;  weight_matrix[0][7] =  2;

            // Row 1
            weight_matrix[1][0] =  0;  weight_matrix[1][1] =  1;  weight_matrix[1][2] =  0;  weight_matrix[1][3] = -1;
            weight_matrix[1][4] =  2;  weight_matrix[1][5] =  3;  weight_matrix[1][6] = -2;  weight_matrix[1][7] =  1;

            // Row 2
            weight_matrix[2][0] =  2;  weight_matrix[2][1] =  0;  weight_matrix[2][2] =  1;  weight_matrix[2][3] =  0;
            weight_matrix[2][4] =  1;  weight_matrix[2][5] = -1;  weight_matrix[2][6] =  2;  weight_matrix[2][7] =  0;

            // Row 3
            weight_matrix[3][0] = -1;  weight_matrix[3][1] =  1;  weight_matrix[3][2] =  2;  weight_matrix[3][3] =  1;
            weight_matrix[3][4] =  0;  weight_matrix[3][5] =  2;  weight_matrix[3][6] =  1;  weight_matrix[3][7] = -1;

            // Row 4
            weight_matrix[4][0] =  3;  weight_matrix[4][1] = -2;  weight_matrix[4][2] =  1;  weight_matrix[4][3] =  2;
            weight_matrix[4][4] =  1;  weight_matrix[4][5] =  0;  weight_matrix[4][6] = -1;  weight_matrix[4][7] =  2;

            // Row 5
            weight_matrix[5][0] =  1;  weight_matrix[5][1] =  1;  weight_matrix[5][2] = -1;  weight_matrix[5][3] =  0;
            weight_matrix[5][4] =  2;  weight_matrix[5][5] =  1;  weight_matrix[5][6] =  0;  weight_matrix[5][7] =  1;

            // Row 6
            weight_matrix[6][0] =  0;  weight_matrix[6][1] =  2;  weight_matrix[6][2] =  1;  weight_matrix[6][3] = -2;
            weight_matrix[6][4] =  1;  weight_matrix[6][5] =  3;  weight_matrix[6][6] =  1;  weight_matrix[6][7] =  0;

            // Row 7
            weight_matrix[7][0] =  2;  weight_matrix[7][1] =  1;  weight_matrix[7][2] =  0;  weight_matrix[7][3] =  1;
            weight_matrix[7][4] = -1;  weight_matrix[7][5] =  2;  weight_matrix[7][6] =  2;  weight_matrix[7][7] =  3;

            // Activation vector
            activation_vector[0] =  1;
            activation_vector[1] =  2;
            activation_vector[2] = -1;
            activation_vector[3] =  3;
            activation_vector[4] =  0;
            activation_vector[5] =  1;
            activation_vector[6] =  2;
            activation_vector[7] = -2;
        end
    endtask

    // ========================================================
    // 9) Compute expected results
    // ========================================================
    task automatic compute_expected_results;
        logic signed [PSUM_WIDTH-1:0] temp_sum;
        begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                temp_sum = '0;
                for (int row = 0; row < ARRAY_SIZE; row++) begin
                    temp_sum = temp_sum
                             + ($signed(activation_vector[row]) * $signed(weight_matrix[row][col]));
                end
                expected_psums[col] = temp_sum;
            end
        end
    endtask

    // ========================================================
    // 10) Pretty-print helpers
    // ========================================================
    task automatic print_weight_matrix;
        begin
            $display("");
            $display("======================================================");
            $display("Weight Matrix (row = PE row, col = PE column)");
            $display("======================================================");
            for (int row = 0; row < ARRAY_SIZE; row++) begin
                $write("Row %0d : ", row);
                for (int col = 0; col < ARRAY_SIZE; col++) begin
                    $write("%4d ", weight_matrix[row][col]);
                end
                $write("\n");
            end
            $display("======================================================");
            $display("");
        end
    endtask

    task automatic print_activation_vector;
        begin
            $display("Activation Vector");
            $display("======================================================");
            for (int row = 0; row < ARRAY_SIZE; row++) begin
                $display("activation_vector[%0d] = %0d", row, activation_vector[row]);
            end
            $display("======================================================");
            $display("");
        end
    endtask

    task automatic print_expected_outputs;
        begin
            $display("Expected Final Outputs");
            $display("======================================================");
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                $display("expected_psums[%0d] = %0d", col, expected_psums[col]);
            end
            $display("======================================================");
            $display("");
        end
    endtask

    // ========================================================
    // 11) Apply reset
    // ========================================================
    task automatic apply_reset;
        begin
            $display("[%0t] Applying reset...", $time);

            rst_i = 1'b1;
            clear_all_inputs();

            repeat (10) @(posedge clk_i);

            rst_i = 1'b0;

            repeat (10) @(posedge clk_i);

            $display("[%0t] Reset released. ready_o=%b output_valid=%b", $time, ready_o, output_valid);
        end
    endtask
    
    
    
    /*task automatic apply_reset;
        begin
            $display("[%0t] Applying reset...", $time);

            rst_i = 1'b1;
            clear_all_inputs();

            repeat (4) @(posedge clk_i);

            rst_i = 1'b0;

            repeat (2) @(posedge clk_i);

            $display("[%0t] Reset released.", $time);
        end
    endtask*/

    // ========================================================
    // 12) Load weights
    // ========================================================
    task automatic load_weights_into_array;
        begin
            $display("[%0t] Starting weight load...", $time);

            //wait (ready_o == 1'b1);
            wait_for_ready_with_timeout(100);
            @(negedge clk_i);

            // One extra compute cycle compensates for the first launch alignment
            num_input_rows = ARRAY_SIZE + 1;

            // Put row 0 on top boundary before start
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                top_data_i[col] = $signed(weight_matrix[0][col]);
            end

            // Start controller
            start = 1'b1;
            @(posedge clk_i);   // IDLE -> LOAD_WTS
            @(negedge clk_i);
            start = 1'b0;

            // Hold row 0 for first real LOAD_WTS capture
            @(posedge clk_i);
            @(negedge clk_i);

            // Stream rows 1..7
            for (int row = 1; row < ARRAY_SIZE; row++) begin
                for (int col = 0; col < ARRAY_SIZE; col++) begin
                    top_data_i[col] = $signed(weight_matrix[row][col]);
                end
                @(posedge clk_i);
                @(negedge clk_i);
            end

            // During compute, top boundary psums start from zero
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                top_data_i[col] = '0;
            end

            $display("[%0t] Weight load finished.", $time);
        end
    endtask

    // ========================================================
    // 13) Check loaded weights
    // ========================================================
    task automatic check_loaded_weights;
        int mismatch_count;
        begin
            mismatch_count = 0;

            $display("");
            $display("Checking stored weights inside the PE array...");
            $display("======================================================");

            for (int row = 0; row < ARRAY_SIZE; row++) begin
                for (int col = 0; col < ARRAY_SIZE; col++) begin
                    if (weight_debug_o[row][col] !== weight_matrix[row][col]) begin
                        $display("WEIGHT MISMATCH at PE(%0d,%0d): expected=%0d got=%0d",
                                 row, col, weight_matrix[row][col], weight_debug_o[row][col]);
                        mismatch_count++;
                    end
                end
            end

            if (mismatch_count == 0) begin
                $display("All PE weights loaded correctly.");
            end
            else begin
                $display("Total weight mismatches = %0d", mismatch_count);
            end

            $display("======================================================");
            $display("");
        end
    endtask

    // ========================================================
    // 14) Drive one activation vector
    // ========================================================
    //
    // Send row7 twice, then row6..row0.
    // This compensates for the first external launch being lost
    // before the PE-side valid fully lines up.
    // ========================================================
    task automatic drive_one_activation_vector;
        begin
            $display("[%0t] Applying one activation vector...", $time);

            // Give the controller a couple of cycles to transition from load to compute
            repeat (2) @(posedge clk_i);

            @(negedge clk_i);
            for (int rr = 0; rr < ARRAY_SIZE; rr++) begin
                activations_i[rr] = '0;
            end
            activations_i[ARRAY_SIZE-1] = activation_vector[ARRAY_SIZE-1];
            @(posedge clk_i);

            @(negedge clk_i);
            for (int rr = 0; rr < ARRAY_SIZE; rr++) begin
                activations_i[rr] = '0;
            end
            activations_i[ARRAY_SIZE-1] = activation_vector[ARRAY_SIZE-1];
            @(posedge clk_i);

            for (int k = ARRAY_SIZE-2; k >= 0; k--) begin
                @(negedge clk_i);
                for (int rr = 0; rr < ARRAY_SIZE; rr++) begin
                    activations_i[rr] = '0;
                end
                activations_i[k] = activation_vector[k];
                @(posedge clk_i);
            end

            @(negedge clk_i);
            for (int rr = 0; rr < ARRAY_SIZE; rr++) begin
                activations_i[rr] = '0;
            end

            $display("[%0t] Activation vector launch complete.", $time);
        end
    endtask
    
    
    
    
    
    
    /*task automatic drive_one_activation_vector;
        begin
            $display("[%0t] Applying one activation vector...", $time);

            wait (dut.u_systolic_ctrl.input_valid_to_pe == 1'b1);

            // Cycle 0: row 7
            @(negedge clk_i);
            for (int rr = 0; rr < ARRAY_SIZE; rr++) begin
                activations_i[rr] = '0;
            end
            activations_i[ARRAY_SIZE-1] = activation_vector[ARRAY_SIZE-1];
            @(posedge clk_i);

            // Cycle 1: row 7 again
            @(negedge clk_i);
            for (int rr = 0; rr < ARRAY_SIZE; rr++) begin
                activations_i[rr] = '0;
            end
            activations_i[ARRAY_SIZE-1] = activation_vector[ARRAY_SIZE-1];
            @(posedge clk_i);

            // Remaining cycles: row 6 down to row 0
            for (int k = ARRAY_SIZE-2; k >= 0; k--) begin
                @(negedge clk_i);

                for (int rr = 0; rr < ARRAY_SIZE; rr++) begin
                    activations_i[rr] = '0;
                end

                activations_i[k] = activation_vector[k];

                @(posedge clk_i);
            end

            @(negedge clk_i);
            for (int rr = 0; rr < ARRAY_SIZE; rr++) begin
                activations_i[rr] = '0;
            end

            $display("[%0t] Activation vector launch complete.", $time);
        end
    endtask */

    // ========================================================
    // 15) Capture results from compute start
    // ========================================================
    task automatic capture_results_from_compute_start;
        localparam int SCAN_CYCLES = 12 * ARRAY_SIZE;
        int start_wait;
        begin
            $display("[%0t] Waiting for output activity and scanning outputs...", $time);

            for (int i = 0; i < ARRAY_SIZE; i++) begin
                captured_final_psums[i] = '0;
                captured_seen[i]        = 1'b0;
                matched_seen[i]         = 1'b0;
            end

            // Wait up to some cycles for output_valid, but don't hang forever
            start_wait = 0;
            while ((output_valid !== 1'b1) && (start_wait < 100)) begin
                @(posedge clk_i);
                start_wait++;
            end

            $display("[%0t] Starting output scan. output_valid=%b after %0d cycles",
                    $time, output_valid, start_wait);

            repeat (SCAN_CYCLES) begin
                @(negedge clk_i);
                for (int i = 0; i < ARRAY_SIZE; i++) begin
                    if (!matched_seen[i] && (final_psums_o[i] === expected_psums[i])) begin
                        captured_final_psums[i] = final_psums_o[i];
                        captured_seen[i]        = 1'b1;
                        matched_seen[i]         = 1'b1;
                    end
                    else if (!matched_seen[i] && (final_psums_o[i] !== '0)) begin
                        captured_final_psums[i] = final_psums_o[i];
                        captured_seen[i]        = 1'b1;
                    end
                end
                @(posedge clk_i);
            end

            $display("[%0t] Output scan finished.", $time);
        end
    endtask
    
    
    
    
    /*task automatic capture_results_from_compute_start;
        localparam int SCAN_CYCLES = 12 * ARRAY_SIZE;
        begin
            $display("[%0t] Waiting for COMPUTE and scanning outputs...", $time);

            for (int i = 0; i < ARRAY_SIZE; i++) begin
                captured_final_psums[i] = '0;
                captured_seen[i]        = 1'b0;
                matched_seen[i]         = 1'b0;
            end

            wait (dut.u_systolic_ctrl.input_valid_to_pe == 1'b1);

            repeat (SCAN_CYCLES) begin
                @(negedge clk_i);
                for (int i = 0; i < ARRAY_SIZE; i++) begin
                    if (!matched_seen[i] && (final_psums_o[i] === expected_psums[i])) begin
                        captured_final_psums[i] = final_psums_o[i];
                        captured_seen[i]        = 1'b1;
                        matched_seen[i]         = 1'b1;
                    end
                    else if (!matched_seen[i] && (final_psums_o[i] !== '0)) begin
                        captured_final_psums[i] = final_psums_o[i];
                        captured_seen[i]        = 1'b1;
                    end
                end
                @(posedge clk_i);
            end

            $display("[%0t] Output scan finished.", $time);
        end
    endtask*/

    // ========================================================
    // 16) Print captured outputs
    // ========================================================
    task automatic print_actual_outputs;
        begin
            $display("");
            $display("Captured Final DUT Outputs");
            $display("======================================================");
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                $display("captured_final_psums[%0d] = %0d  seen=%0b  matched=%0b",
                         col, captured_final_psums[col], captured_seen[col], matched_seen[col]);
            end
            $display("======================================================");
            $display("");
        end
    endtask

    // ========================================================
    // 17) Compare outputs
    // ========================================================
    task automatic check_final_results;
        int mismatch_count;
        begin
            mismatch_count = 0;

            $display("Comparing captured DUT outputs against expected values...");
            $display("======================================================");

            for (int col = 0; col < ARRAY_SIZE; col++) begin
                if (!captured_seen[col]) begin
                    $display("MISMATCH at output[%0d]: expected=%0d got=UNSEEN",
                             col, expected_psums[col]);
                    mismatch_count++;
                end
                else if (captured_final_psums[col] !== expected_psums[col]) begin
                    $display("MISMATCH at output[%0d]: expected=%0d got=%0d",
                             col, expected_psums[col], captured_final_psums[col]);
                    mismatch_count++;
                end
                else begin
                    $display("MATCH at output[%0d]: value=%0d",
                             col, captured_final_psums[col]);
                end
            end

            $display("======================================================");

            if (mismatch_count == 0) begin
                $display("TEST PASSED: all final outputs match expected values.");
            end
            else begin
                $display("TEST FAILED: total output mismatches = %0d", mismatch_count);
            end

            $display("");
        end
    endtask

    // ========================================================
    // 18) Main test sequence
    // ========================================================
    initial begin
        clear_all_inputs();
        init_test_data();
        compute_expected_results();

        print_weight_matrix();
        print_activation_vector();
        print_expected_outputs();

        apply_reset();
        load_weights_into_array();
        check_loaded_weights();

        fork
            drive_one_activation_vector();
            capture_results_from_compute_start();
        join

        print_actual_outputs();
        check_final_results();

        repeat (5) @(posedge clk_i);
        $finish;
    end

endmodule