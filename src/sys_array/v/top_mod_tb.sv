`timescale 1ns/1ps

// =====================================================================
// 8x8 Matrix multiply + accumulate testbench (back-to-back, shadow load).
// ---------------------------------------------------------------------
//   C = A * B + initial_psums    (computed twice: matmul 1 and matmul 2)
//
//   A           : 8x8 INT8  activation matrix (no zeros)
//   B           : 8x8 INT8  weight matrix     (no zeros)
//   initial_psums (IP)
//               : 8x8 INT32 initial partial sums (no zeros)
//   C           : 8x8 INT32 result, C[i][c] = sum_k A[i][k]*B[k][c] + IP[i][c]
//
// Per matmul flow (as specified):
//   1. Wait for ready_o, then assert start.
//   2. Drive B reverse-row on top_data_i over N consecutive cycles
//      (B[N-1] first, B[0] last; reverse order is what the registered
//      b_o load protocol consumes).
//   3. Drive A row-by-row on activations_i continuously for N cycles
//      (with activations_valid_i held high). At cycle t, drive A[t].
//   4. In parallel with the matmul, drive IP on top_data_i in a wavefront
//      pattern: at relative cycle t, drive ip[t-c][c] on top_data_i[c]
//      for every c with 0 <= t-c < N. Cycle 0 carries IP[0][0]; cycle 1
//      carries IP[1][0] and IP[0][1]; cycle 2 carries IP[2][0], IP[1][1],
//      IP[0][2]; ... cycle 14 carries IP[7][7]. The wavefront spans
//      2N-1 = 15 cycles total -- 8 with activations + 7 trailing in DRAIN.
//
// Matmul 2 reuses the shadow load path:
//   * After IP1 wavefront ends, pulse start (start_pending latches inside
//     the controller during DRAIN).
//   * Drive B2 reverse-row on top_data_i during shadow_weights_active_o.
//   * Once shadow drops, drive A2 + IP2 wavefront the same way.
//
// Sampling: wait for output_valid to first rise, skip one cycle (the
// result is aligned 1 cycle past output_valid for the registered-b_o
// array), then capture 8 consecutive cycles into C_actual. Repeat for
// the second output_valid pulse to capture matmul 2.
//
// All three matrices A, B, IP are displayed at the start so the log shows
// the inputs the comparison is checking against. mac_bypass_i is held low
// (ENABLE_MAC_BYPASS=0). Reset is synchronous active-high. A watchdog
// terminates the sim if anything stalls.
// =====================================================================

module top_mod_tb;
    localparam string TB_BUILD_ID = "top_mod_tb 2026-04-26 posedge-racefix-v2";

    initial begin
`ifndef VERILATOR
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars(0, top_mod_tb, "+mda");
`endif
        $dumpfile("top_mod_tb.vcd");
        $dumpvars(0, top_mod_tb);
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
        .activations_i           (activations_i),
        .top_data_i              (top_data_i),
        .final_psums_o           (final_psums_o),
        .ready_o                 (ready_o),
        .shadow_weights_active_o (shadow_weights_active_o),
        .output_valid            (output_valid),
        .weight_debug_o          (weight_debug_o)
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

    // C[i][c] = sum_k A[i][k] * B[k][c] + IP[i][c]
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

    // ---------------- Display helpers ----------------
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
                M[r][0], M[r][1], M[r][2], M[r][3],
                M[r][4], M[r][5], M[r][6], M[r][7]);
    endtask

    // ---------------- Watchdog ----------------
    initial begin
        repeat (10000) @(posedge clk);
        $display("[%0t] WATCHDOG TIMEOUT", $time);
        $finish;
    end

    // ---------------- Driver tasks ----------------

    // Pulse start for one clock cycle (posedge-only drive style).
    task automatic pulse_start_only();
        @(posedge clk); #1;
        start = 1'b1;
        @(posedge clk); #1;
        start = 1'b0;
    endtask

    // Pulse start AND pre-stage W[N-1]. With posedge-only driving, the edge
    // that sees start_rise transitions IDLE->LOAD_WTS but does not yet consume
    // LOAD_WTS data, so we keep W[N-1] for one additional cycle to align with
    // the FIRST active LOAD_WTS cycle. Then drive W[N-2..0] (reverse-row).
    task automatic drive_load_wts(input logic signed [DATA_WIDTH-1:0] W [0:N-1][0:N-1]);
        @(posedge clk); #1;
        start = 1'b1;
        for (int c = 0; c < N; c++) top_data_i[c] = sext8(W[N-1][c]);
        $display("[%0t] start HIGH, pre-stage W[%0d] (LOAD_WTS first cycle)", $time, N-1);
        @(posedge clk); #1;
        start = 1'b0;
        // Hold W[N-1] through first active LOAD_WTS cycle.
        @(posedge clk); #1;

        for (int t = 1; t < N; t++) begin
            for (int c = 0; c < N; c++) top_data_i[c] = sext8(W[N-1-t][c]);
            $display("[%0t] LOAD_WTS row %0d -> W[%0d]", $time, t, N-1-t);
            @(posedge clk); #1;
        end
    endtask

    // Drive activations + initial-psum wavefront for 2N-1 cycles.
    //  * Cycles 0..N-1 :  activations_valid_i = 1, activations_i = A[t]
    //  * Cycles N..2N-2:  activations_valid_i = 0 (DRAIN tail), activations_i = 0
    // top_data_i[c] = IP[t-c][c] when 0 <= t-c < N, else 0 (wavefront).
    task automatic drive_compute_and_wavefront(
        input logic signed [DATA_WIDTH-1:0] A  [0:N-1][0:N-1],
        input logic signed [PSUM_WIDTH-1:0] IP [0:N-1][0:N-1]
    );
        @(posedge clk); #1;
        for (int t = 0; t < 2*N - 1; t++) begin
            // Activation row
            if (t < N) begin
                activations_valid_i = 1'b1;
                for (int r = 0; r < N; r++) activations_i[r] = A[t][r];
            end else begin
                activations_valid_i = 1'b0;
                activations_i = '0;
            end
            // Initial-psum wavefront on top_data_i
            for (int c = 0; c < N; c++) begin
                int rr;
                rr = t - c;
                if (rr >= 0 && rr < N)
                    top_data_i[c] = IP[rr][c];
                else
                    top_data_i[c] = '0;
            end
            $display("[%0t]   t=%2d  av=%b  acts=[%4d %4d %4d %4d %4d %4d %4d %4d]  ip_wave=[%0d %0d %0d %0d %0d %0d %0d %0d]",
                $time, t, activations_valid_i,
                $signed(activations_i[0]), $signed(activations_i[1]),
                $signed(activations_i[2]), $signed(activations_i[3]),
                $signed(activations_i[4]), $signed(activations_i[5]),
                $signed(activations_i[6]), $signed(activations_i[7]),
                $signed(top_data_i[0]), $signed(top_data_i[1]),
                $signed(top_data_i[2]), $signed(top_data_i[3]),
                $signed(top_data_i[4]), $signed(top_data_i[5]),
                $signed(top_data_i[6]), $signed(top_data_i[7]));
            @(posedge clk); #1;
        end
        // Cleanup -- release the buses so the next phase (shadow load or
        // matmul 2 wavefront) can drive them cleanly.
        activations_valid_i = 1'b0;
        activations_i = '0;
        top_data_i = '0;
    endtask

    // Drive shadow weights in REVERSE row order while shadow_weights_active_o
    // is asserted. Stages W[N-1] until the controller transitions into
    // SHADOW_RUN, then walks W[N-2..0] in lockstep with sh_counter.
    task automatic drive_shadow_weights(input logic signed [DATA_WIDTH-1:0] W [0:N-1][0:N-1]);
        // Pre-stage W[N-1] until shadow goes active. Uses the same
        // posedge-only pattern as drive_load_wts so the broadcast load
        // pulse on the final shadow cycle latches W[k][c] correctly.
        @(posedge clk); #1;
        while (shadow_weights_active_o !== 1'b1) begin
            for (int c = 0; c < N; c++) top_data_i[c] = sext8(W[N-1][c]);
            @(posedge clk); #1;
        end
        $display("[%0t] shadow_weights_active_o asserted -- W[%0d] on top_data_i",
            $time, N-1);
        // As with LOAD_WTS, keep W[N-1] for the first active SHADOW_RUN cycle.
        @(posedge clk); #1;

        // Drive W[N-2..0] for the remaining N-1 shadow cycles.
        for (int t = 1; t < N; t++) begin
            for (int c = 0; c < N; c++) top_data_i[c] = sext8(W[N-1-t][c]);
            $display("[%0t] SHADOW row %0d -> W[%0d]", $time, t, N-1-t);
            @(posedge clk); #1;
        end
        top_data_i = '0;
    endtask

    // Wait for shadow_weights_active_o to drop -- the controller is now
    // in WAIT_SHADOW / about to enter COMPUTE for matmul 2.
    task automatic wait_for_shadow_drop();
        while (shadow_weights_active_o !== 1'b0) @(posedge clk);
        $display("[%0t] shadow_weights_active_o dropped", $time);
    endtask

    // Sample 8 consecutive rows tied to a fresh output_valid rising edge.
    // Capture starts on the same cycle output_valid rises and always spans
    // exactly N cycles, independent of output_valid pulse width.
    task automatic sample_results(ref logic signed [PSUM_WIDTH-1:0] C [0:N-1][0:N-1]);
        logic ov_prev;
        int high_cycles;

        // Wait for a clean rising edge (0 -> 1).
        ov_prev = output_valid;
        while (1) begin
            @(posedge clk);
            if (output_valid === 1'b1 && ov_prev === 1'b0)
                break;
            ov_prev = output_valid;
        end
        $display("[%0t] output_valid rose -- sampling %0d result rows from this cycle", $time, N);

        // Capture 8 consecutive rows starting in the same output_valid cycle.
        for (int i = 0; i < N; i++) begin
            #1;
            for (int c = 0; c < N; c++) C[i][c] = final_psums_o[c];
            $display("[%0t]   sample row %0d : %0d %0d %0d %0d %0d %0d %0d %0d",
                $time, i,
                $signed(final_psums_o[0]), $signed(final_psums_o[1]),
                $signed(final_psums_o[2]), $signed(final_psums_o[3]),
                $signed(final_psums_o[4]), $signed(final_psums_o[5]),
                $signed(final_psums_o[6]), $signed(final_psums_o[7]));
            @(posedge clk);
        end

        // Optional debug: report how long the pulse stayed high.
        high_cycles = 0;
        while (output_valid === 1'b1) begin
            high_cycles++;
            @(posedge clk);
        end
        $display("[%0t] output_valid pulse width observed after capture: %0d cycle(s)", $time, N + high_cycles);
    endtask

    // Compare actual vs. expected; return error count.
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
                        $time, name, i, c, actual[i][c], expected[i][c],
                        actual[i][c] - expected[i][c]);
                    errors++;
                end
            end
        end
        return errors;
    endfunction

    // ---------------- Test-data generator ----------------
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

    // ---------------- Main test ----------------
    initial begin
        int errors;
        errors = 0;
        $display("[%0t] TB_BUILD_ID: %s", $time, TB_BUILD_ID);

        // Defaults
        rst                 = 1'b1;
        start               = 1'b0;
        activations_valid_i = 1'b0;
        mac_bypass_i        = 1'b0;
        activations_i       = '0;
        top_data_i          = '0;

        // Build A1, B1, IP1 (matmul 1) and A2, B2, IP2 (matmul 2). All
        // values are non-zero to exercise the full datapath.
        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin
                A1[r][c]  = nz8(((r + c + 1) % 7) - 3);          // {-3..3} \ {0}
                B1[r][c]  = nz8(((r * 2 + c + 2) % 5) - 2);      // {-2..2} \ {0}
                IP1[r][c] = nz32(((r * 11 + c + 1) * 13) - 50);  // small INT32

                A2[r][c]  = nz8(((r * 3 + c + 5) % 7) - 3);
                B2[r][c]  = nz8(((r + c * 3 + 2) % 5) - 2);
                IP2[r][c] = nz32(((r * 7 + c + 1) * 17) - 25);
            end
        end
        compute_expected(A1, B1, IP1, C1_exp);
        compute_expected(A2, B2, IP2, C2_exp);

        // Display all three input matrices for matmul 1 and matmul 2 (and
        // the expected outputs) at the very start of the run.
        $display("[%0t] ==================== Test data ====================", $time);
        disp_int8 (A1,     "A1  (activations matmul 1)");
        disp_int8 (B1,     "B1  (weights     matmul 1)");
        disp_int32(IP1,    "IP1 (init psums  matmul 1)");
        disp_int32(C1_exp, "C1  (expected    matmul 1)");
        disp_int8 (A2,     "A2  (activations matmul 2)");
        disp_int8 (B2,     "B2  (weights     matmul 2)");
        disp_int32(IP2,    "IP2 (init psums  matmul 2)");
        disp_int32(C2_exp, "C2  (expected    matmul 2)");
        $display("[%0t] ===================================================", $time);

        // Reset (longer hold helps post-PAR/SDF initialization settle).
        repeat (RESET_HOLD_CYCLES) @(posedge clk);
        rst = 1'b0;
        $display("[%0t] reset deasserted", $time);
        repeat (POST_RST_SETTLE_CYCLES) @(posedge clk);

        // Wait for ready_o with timeout and X diagnostics.
        begin
            int ready_wait_cycles;
            ready_wait_cycles = 0;
            while (ready_o !== 1'b1) begin
                @(posedge clk);
                ready_wait_cycles++;
                if (ready_wait_cycles == (READY_WAIT_LIMIT/2))
                    $display("[%0t] WARN: ready_o still not 1 (value=%b)", $time, ready_o);
                if (ready_wait_cycles > READY_WAIT_LIMIT) begin
                    $display("[%0t] ERROR: ready_o timeout (value=%b).", $time, ready_o);
                    $display("[%0t] HINT: for gate-level, try longer reset or +initreg+0.", $time);
                    $fatal(1, "ready_o did not assert");
                end
            end
        end
        $display("[%0t] ready_o asserted -- starting back-to-back matmuls", $time);

        // ---------------------------------------------------------------
        // Drive both matmuls and sample their results in parallel. The
        // sample thread blocks on output_valid edges so its captures line
        // up with whatever the stim thread produces.
        // ---------------------------------------------------------------
        fork
            // -------- Stim thread --------
            begin
                $display("[%0t] -------- Matmul 1 : LOAD_WTS --------", $time);
                drive_load_wts(B1);

                $display("[%0t] -------- Matmul 1 : COMPUTE + IP1 wavefront --------", $time);
                drive_compute_and_wavefront(A1, IP1);

                $display("[%0t] -------- Queue Matmul 2 (start during DRAIN) --------", $time);
                pulse_start_only();

                $display("[%0t] -------- Matmul 2 : SHADOW_RUN with B2 --------", $time);
                drive_shadow_weights(B2);

                wait_for_shadow_drop();
                // After SHADOW_RUN drops, main FSM may still be in WAIT_SHADOW
                // and transitions to COMPUTE on the next posedge. Wait one extra
                // cycle so t=0 activation is guaranteed to be the first accepted beat.
                repeat (2) @(posedge clk);

                $display("[%0t] -------- Matmul 2 : COMPUTE + IP2 wavefront --------", $time);
                drive_compute_and_wavefront(A2, IP2);
            end

            // -------- Sample thread --------
            begin
                sample_results(C1_actual);
                $display("[%0t] Matmul 1 sampling complete", $time);

                sample_results(C2_actual);
                $display("[%0t] Matmul 2 sampling complete", $time);
            end
        join

        // ---------------------------------------------------------------
        // Compare and report.
        // ---------------------------------------------------------------
        $display("[%0t] ============== Matmul 1 results ==============", $time);
        disp_int32(C1_actual, "C1 (actual)");
        errors += compare(C1_actual, C1_exp, "C1");

        $display("[%0t] ============== Matmul 2 results ==============", $time);
        disp_int32(C2_actual, "C2 (actual)");
        errors += compare(C2_actual, C2_exp, "C2");

        $display("[%0t] ====================================================", $time);
        if (errors == 0)
            $display("[%0t] *** ALL PASS *** (matmul 1 + matmul 2 with shadow load)", $time);
        else
            $display("[%0t] *** %0d ERRORS *** (matmul 1 + matmul 2 with shadow load)", $time, errors);
        $display("[%0t] ====================================================", $time);

        repeat (20) @(posedge clk);
        $finish;
    end

endmodule
