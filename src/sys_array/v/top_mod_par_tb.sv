`timescale 1ns/1ps

// =====================================================================
// Clean post-PAR TB clone of top_mod_tb (single module only).
// Behavior/stimulus/checking match top_mod_tb; only DUT wiring differs:
// packed-array ports are connected via flattened escape-name pins.
// =====================================================================

module top_mod_par_tb;
    localparam string TB_BUILD_ID = "top_mod_par_tb 2026-04-26 flattened-clean-v1";

    initial begin
`ifndef VERILATOR
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars(0, top_mod_par_tb, "+mda");
`endif
        $dumpfile("top_mod_par_tb.vcd");
        $dumpvars(0, top_mod_par_tb);
    end

    localparam int N          = 8;
    localparam int DATA_WIDTH = 8;
    localparam int PSUM_WIDTH = 32;
    localparam int RESET_HOLD_CYCLES = 50;
    localparam int POST_RST_SETTLE_CYCLES = 8;
    localparam int READY_WAIT_LIMIT = 5000;

    // ---------------- DUT IO ----------------
    logic clk;
    logic rst;
    logic start;
    logic activations_valid_i;
    logic mac_bypass_i;
    logic signed [N-1:0][DATA_WIDTH-1:0]  activations_i;
    logic signed [N-1:0][PSUM_WIDTH-1:0]  top_data_i;
    logic signed [N-1:0][PSUM_WIDTH-1:0]  final_psums_o;
    logic ready_o;
    logic shadow_weights_active_o;
    logic output_valid;
    logic signed [N-1:0][N-1:0][DATA_WIDTH-1:0] weight_debug_o;

    // Flattened bridge signals
    logic signed [N-1:0][DATA_WIDTH-1:0]  tb_activations_i;
    logic signed [N-1:0][PSUM_WIDTH-1:0]  tb_top_data_i;
    logic signed [N-1:0][PSUM_WIDTH-1:0]  tb_final_psums_o;
    assign tb_activations_i = activations_i;
    assign tb_top_data_i    = top_data_i;
    assign final_psums_o    = tb_final_psums_o;

    top_mod #(
        .ARRAY_SIZE       (N),
        .DATA_WIDTH       (DATA_WIDTH),
        .PSUM_WIDTH       (PSUM_WIDTH),
        .ENABLE_MAC_BYPASS(0)
    ) dut (
        .clk_i                   (clk),
        .rst_i                   (rst),
        .start                   (start),
        .activations_valid_i     (activations_valid_i),
        .mac_bypass_i            (mac_bypass_i),
        .ready_o                 (ready_o),
        .shadow_weights_active_o (shadow_weights_active_o),
        .output_valid            (output_valid),
       // .weight_debug_o          (weight_debug_o),

        .\activations_i[0] (tb_activations_i[0]),
        .\activations_i[1] (tb_activations_i[1]),
        .\activations_i[2] (tb_activations_i[2]),
        .\activations_i[3] (tb_activations_i[3]),
        .\activations_i[4] (tb_activations_i[4]),
        .\activations_i[5] (tb_activations_i[5]),
        .\activations_i[6] (tb_activations_i[6]),
        .\activations_i[7] (tb_activations_i[7]),

        .\top_data_i[0] (tb_top_data_i[0]),
        .\top_data_i[1] (tb_top_data_i[1]),
        .\top_data_i[2] (tb_top_data_i[2]),
        .\top_data_i[3] (tb_top_data_i[3]),
        .\top_data_i[4] (tb_top_data_i[4]),
        .\top_data_i[5] (tb_top_data_i[5]),
        .\top_data_i[6] (tb_top_data_i[6]),
        .\top_data_i[7] (tb_top_data_i[7]),

        .\final_psums_o[0] (tb_final_psums_o[0]),
        .\final_psums_o[1] (tb_final_psums_o[1]),
        .\final_psums_o[2] (tb_final_psums_o[2]),
        .\final_psums_o[3] (tb_final_psums_o[3]),
        .\final_psums_o[4] (tb_final_psums_o[4]),
        .\final_psums_o[5] (tb_final_psums_o[5]),
        .\final_psums_o[6] (tb_final_psums_o[6]),
        .\final_psums_o[7] (tb_final_psums_o[7])
    );

    // ---------------- Clock ----------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---------------- Test data ----------------
    logic signed [DATA_WIDTH-1:0] A1   [0:N-1][0:N-1];
    logic signed [DATA_WIDTH-1:0] B1   [0:N-1][0:N-1];
    logic signed [PSUM_WIDTH-1:0] IP1  [0:N-1][0:N-1];
    logic signed [PSUM_WIDTH-1:0] C1_exp    [0:N-1][0:N-1];
    logic signed [PSUM_WIDTH-1:0] C1_actual [0:N-1][0:N-1];

    logic signed [DATA_WIDTH-1:0] A2   [0:N-1][0:N-1];
    logic signed [DATA_WIDTH-1:0] B2   [0:N-1][0:N-1];
    logic signed [PSUM_WIDTH-1:0] IP2  [0:N-1][0:N-1];
    logic signed [PSUM_WIDTH-1:0] C2_exp    [0:N-1][0:N-1];
    logic signed [PSUM_WIDTH-1:0] C2_actual [0:N-1][0:N-1];

    function automatic logic signed [PSUM_WIDTH-1:0] sext8(input logic signed [DATA_WIDTH-1:0] x);
        return $signed({{(PSUM_WIDTH-DATA_WIDTH){x[DATA_WIDTH-1]}}, x});
    endfunction

    task automatic compute_expected(
        input  logic signed [DATA_WIDTH-1:0] A  [0:N-1][0:N-1],
        input  logic signed [DATA_WIDTH-1:0] B  [0:N-1][0:N-1],
        input  logic signed [PSUM_WIDTH-1:0] IP [0:N-1][0:N-1],
        output logic signed [PSUM_WIDTH-1:0] C  [0:N-1][0:N-1]
    );
        for (int i = 0; i < N; i++) begin
            for (int c = 0; c < N; c++) begin
                logic signed [PSUM_WIDTH-1:0] acc;
                acc = IP[i][c];
                for (int k = 0; k < N; k++)
                    acc = acc + sext8(A[i][k]) * sext8(B[k][c]);
                C[i][c] = acc;
            end
        end
    endtask

    task automatic disp_int8(input logic signed [DATA_WIDTH-1:0] M [0:N-1][0:N-1], input string name);
        $display("[%0t] %s (8x8 INT8):", $time, name);
        for (int r = 0; r < N; r++)
            $display("[%0t]   row %0d : %4d %4d %4d %4d %4d %4d %4d %4d", $time, r,
                $signed(M[r][0]), $signed(M[r][1]), $signed(M[r][2]), $signed(M[r][3]),
                $signed(M[r][4]), $signed(M[r][5]), $signed(M[r][6]), $signed(M[r][7]));
    endtask

    task automatic disp_int32(input logic signed [PSUM_WIDTH-1:0] M [0:N-1][0:N-1], input string name);
        $display("[%0t] %s (8x8 INT32):", $time, name);
        for (int r = 0; r < N; r++)
            $display("[%0t]   row %0d : %0d %0d %0d %0d %0d %0d %0d %0d", $time, r,
                M[r][0], M[r][1], M[r][2], M[r][3], M[r][4], M[r][5], M[r][6], M[r][7]);
    endtask

    initial begin
        repeat (10000) @(posedge clk);
        $display("[%0t] WATCHDOG TIMEOUT", $time);
        $finish;
    end

    task automatic pulse_start_only();
        @(posedge clk); #1; start = 1'b1;
        @(posedge clk); #1; start = 1'b0;
    endtask

    task automatic drive_load_wts(input logic signed [DATA_WIDTH-1:0] W [0:N-1][0:N-1]);
        @(posedge clk); #1;
        start = 1'b1;
        for (int c = 0; c < N; c++) top_data_i[c] = sext8(W[N-1][c]);
        $display("[%0t] start HIGH, pre-stage W[%0d] (LOAD_WTS first cycle)", $time, N-1);
        @(posedge clk); #1;
        start = 1'b0;
        @(posedge clk); #1;
        for (int t = 1; t < N; t++) begin
            for (int c = 0; c < N; c++) top_data_i[c] = sext8(W[N-1-t][c]);
            $display("[%0t] LOAD_WTS row %0d -> W[%0d]", $time, t, N-1-t);
            @(posedge clk); #1;
        end
    endtask

    task automatic drive_compute_and_wavefront(
        input logic signed [DATA_WIDTH-1:0] A  [0:N-1][0:N-1],
        input logic signed [PSUM_WIDTH-1:0] IP [0:N-1][0:N-1]
    );
        @(posedge clk); #1;
        for (int t = 0; t < 2*N - 1; t++) begin
            if (t < N) begin
                activations_valid_i = 1'b1;
                for (int r = 0; r < N; r++) activations_i[r] = A[t][r];
            end else begin
                activations_valid_i = 1'b0;
                activations_i = '0;
            end
            for (int c = 0; c < N; c++) begin
                int rr;
                rr = t - c;
                if (rr >= 0 && rr < N) top_data_i[c] = IP[rr][c];
                else top_data_i[c] = '0;
            end
            @(posedge clk); #1;
        end
        activations_valid_i = 1'b0;
        activations_i = '0;
        top_data_i = '0;
    endtask

    task automatic drive_shadow_weights(input logic signed [DATA_WIDTH-1:0] W [0:N-1][0:N-1]);
        @(posedge clk); #1;
        while (shadow_weights_active_o !== 1'b1) begin
            for (int c = 0; c < N; c++) top_data_i[c] = sext8(W[N-1][c]);
            @(posedge clk); #1;
        end
        @(posedge clk); #1;
        for (int t = 1; t < N; t++) begin
            for (int c = 0; c < N; c++) top_data_i[c] = sext8(W[N-1-t][c]);
            @(posedge clk); #1;
        end
        top_data_i = '0;
    endtask

    task automatic wait_for_shadow_drop();
        while (shadow_weights_active_o !== 1'b0) @(posedge clk);
    endtask

    task automatic sample_results(ref logic signed [PSUM_WIDTH-1:0] C [0:N-1][0:N-1]);
        logic ov_prev;
        int high_cycles;
        ov_prev = output_valid;
        while (1) begin
            @(posedge clk);
            if (output_valid === 1'b1 && ov_prev === 1'b0) break;
            ov_prev = output_valid;
        end
        for (int i = 0; i < N; i++) begin
            #1;
            for (int c = 0; c < N; c++) C[i][c] = final_psums_o[c];
            @(posedge clk);
        end
        high_cycles = 0;
        while (output_valid === 1'b1) begin
            high_cycles++;
            @(posedge clk);
        end
        $display("[%0t] output_valid pulse width observed after capture: %0d cycle(s)", $time, N + high_cycles);
    endtask

    function automatic int compare(
        input logic signed [PSUM_WIDTH-1:0] actual   [0:N-1][0:N-1],
        input logic signed [PSUM_WIDTH-1:0] expected [0:N-1][0:N-1],
        input string name
    );
        int errors;
        errors = 0;
        for (int i = 0; i < N; i++) begin
            for (int c = 0; c < N; c++) begin
                if (actual[i][c] !== expected[i][c]) begin
                    $display("[%0t] MISMATCH %s[%0d][%0d] : got %0d  expected %0d  (delta %0d)",
                        $time, name, i, c, actual[i][c], expected[i][c], actual[i][c] - expected[i][c]);
                    errors++;
                end
            end
        end
        return errors;
    endfunction

    function automatic logic signed [DATA_WIDTH-1:0] nz8(input int v);
        logic signed [DATA_WIDTH-1:0] x;
        x = DATA_WIDTH'(v);
        if (x == 0) x = 8'sd1;
        return x;
    endfunction

    function automatic logic signed [PSUM_WIDTH-1:0] nz32(input int v);
        logic signed [PSUM_WIDTH-1:0] x;
        x = v;
        if (x == 0) x = 32'sd1;
        return x;
    endfunction

    initial begin
        int errors;
        errors = 0;
        $display("[%0t] TB_BUILD_ID: %s", $time, TB_BUILD_ID);

        rst                 = 1'b1;
        start               = 1'b0;
        activations_valid_i = 1'b0;
        mac_bypass_i        = 1'b0;
        activations_i       = '0;
        top_data_i          = '0;

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin
                A1[r][c]  = nz8(((r + c + 1) % 7) - 3);
                B1[r][c]  = nz8(((r * 2 + c + 2) % 5) - 2);
                IP1[r][c] = nz32(((r * 11 + c + 1) * 13) - 50);
                A2[r][c]  = nz8(((r * 3 + c + 5) % 7) - 3);
                B2[r][c]  = nz8(((r + c * 3 + 2) % 5) - 2);
                IP2[r][c] = nz32(((r * 7 + c + 1) * 17) - 25);
            end
        end
        compute_expected(A1, B1, IP1, C1_exp);
        compute_expected(A2, B2, IP2, C2_exp);

        disp_int8 (A1,  "A1");
        disp_int8 (B1,  "B1");
        disp_int32(IP1, "IP1");
        disp_int8 (A2,  "A2");
        disp_int8 (B2,  "B2");
        disp_int32(IP2, "IP2");

        repeat (RESET_HOLD_CYCLES) @(posedge clk);
        rst = 1'b0;
        repeat (POST_RST_SETTLE_CYCLES) @(posedge clk);

        begin
            int ready_wait_cycles;
            ready_wait_cycles = 0;
            while (ready_o !== 1'b1) begin
                @(posedge clk);
                ready_wait_cycles++;
                if (ready_wait_cycles > READY_WAIT_LIMIT) begin
                    $display("[%0t] ERROR: ready_o timeout (value=%b).", $time, ready_o);
                    $display("[%0t] HINT: for gate-level, try longer reset or +initreg+0.", $time);
                    $fatal(1, "ready_o did not assert");
                end
            end
        end

        fork
            begin
                drive_load_wts(B1);
                drive_compute_and_wavefront(A1, IP1);
                pulse_start_only();
                drive_shadow_weights(B2);
                wait_for_shadow_drop();
                repeat (2) @(posedge clk);
                drive_compute_and_wavefront(A2, IP2);
            end
            begin
                sample_results(C1_actual);
                sample_results(C2_actual);
            end
        join

        errors += compare(C1_actual, C1_exp, "C1");
        errors += compare(C2_actual, C2_exp, "C2");

        if (errors == 0) $display("[%0t] *** ALL PASS ***", $time);
        else             $display("[%0t] *** %0d ERRORS ***", $time, errors);

        repeat (20) @(posedge clk);
        $finish;
    end

endmodule
