`timescale 1ns/1ps

module top_mod_tb;

    // ========================================================
    // 1) Parameters
    // ========================================================
    localparam int ARRAY_SIZE = 8;
    localparam int DATA_WIDTH = 8;
    localparam int PSUM_WIDTH = 32;

    // ========================================================
    // 2) DUT signals
    // ========================================================
    logic clk_i;
    logic rst_i;
    logic start;
    logic [15:0] num_input_rows;
    logic mac_bypass_i;

    logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_i;
    logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] top_data_i;

    logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] final_psums_o;
    logic ready_o;
    logic output_valid;

    logic signed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][DATA_WIDTH-1:0] weight_debug_o;

    // ========================================================
    // 3) Testbench-only storage
    // ========================================================
    logic signed [DATA_WIDTH-1:0] weight_matrix [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    logic signed [DATA_WIDTH-1:0] activation_vector [0:ARRAY_SIZE-1];
    logic signed [PSUM_WIDTH-1:0] expected_psums [0:ARRAY_SIZE-1];

    logic signed [PSUM_WIDTH-1:0] captured_final_psums [0:ARRAY_SIZE-1];
    logic                         captured_seen        [0:ARRAY_SIZE-1];
    logic                         matched_seen         [0:ARRAY_SIZE-1];

    // ========================================================
    // 4) Instantiate DUT
    // ========================================================
    top_mod #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .ENABLE_MAC_BYPASS(1)
    ) dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .start(start),
        .num_input_rows(num_input_rows),
        .activations_i(activations_i),
        .top_data_i(top_data_i),
        .mac_bypass_i(mac_bypass_i),
        .final_psums_o(final_psums_o),
        .ready_o(ready_o),
        .output_valid(output_valid),
        .weight_debug_o(weight_debug_o)
    );

    // ========================================================
    // 5) Clock
    // ========================================================
    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end

    // ========================================================
    // 6) Optional waveform dump
    // ========================================================
    /*
    initial begin
        $dumpfile("top_mod_tb.vcd");
        $dumpvars(0, top_mod_tb);
    end
    */

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

            repeat (4) @(posedge clk_i);

            rst_i = 1'b0;

            repeat (2) @(posedge clk_i);

            $display("[%0t] Reset released.", $time);
        end
    endtask

    // ========================================================
    // 12) Load weights
    // ========================================================
    task automatic load_weights_into_array;
        begin
            $display("[%0t] Starting weight load...", $time);

            wait (ready_o == 1'b1);
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
    endtask

    // ========================================================
    // 15) Capture results from compute start
    // ========================================================
    task automatic capture_results_from_compute_start;
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
    endtask

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