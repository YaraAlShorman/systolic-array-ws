`ifndef SHADOW_LOADING_V1
module systolic_ctrl #(
    parameter int ARRAY_SIZE = 8,
    parameter int DATA_WIDTH = 8,
    parameter int PSUM_WIDTH = 32
)(
    input  logic clk_i, rst_i,
    input  logic activations_valid_i,
    input  logic activations_stopped,
    input  logic weight_en_i,        
    input  logic cold_start,
    
    input  logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_i,
    input  logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] psum_in,
    input  logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] weight_in,
    
    output logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_skewed_o,
    output logic [ARRAY_SIZE-1:0]                        v_skewed_o,
    output logic [ARRAY_SIZE-1:0]                        load_active_row_o,
    output logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] psums_staggered_o,
    
    output logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] weights_skewed_o,
    output logic [ARRAY_SIZE-1:0]                        weight_en_skewed_o, 
    
    output logic                                         weight_swap_pulse_o,
    input  logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] psums_from_mesh_i,
    output logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] final_psums_o,
    output logic                                         output_valid_o
);

    wire chicken_disable_ping_pong_i;
    assign chicken_disable_ping_pong_i = 1'b0; 
    
    wire ping_pong_en;
    assign ping_pong_en = ~chicken_disable_ping_pong_i;

    logic [$clog2(ARRAY_SIZE)-1:0] act_count;   
    logic                          load_pulse_raw;
    logic                          active_beat;
    
    assign weight_swap_pulse_o = load_pulse_raw;
    assign active_beat = activations_valid_i & ~activations_stopped;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            act_count      <= '0;
            load_pulse_raw <= 1'b0;
        end else begin
            load_pulse_raw <= 1'b0; 

            if (active_beat) begin
                if (act_count == (ARRAY_SIZE - 1)) begin
                    act_count <= '0;
                end else begin
                    act_count <= act_count + 1'b1;
                end
                
                if ((act_count == (ARRAY_SIZE - 2)) && ping_pong_en) begin
                    load_pulse_raw <= 1'b1;   
                end
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < ARRAY_SIZE; i++) begin : gen_skew
            if (i == 0) begin : no_delay
                assign activations_skewed_o[i] = activations_i[i];
                assign v_skewed_o[i]           = active_beat;
                assign load_active_row_o[i]    = load_pulse_raw || cold_start; 
                assign weights_skewed_o[i]     = weight_in[i];
                assign weight_en_skewed_o[i]   = weight_en_i;

            end else begin : pipe_delay
                logic signed [DATA_WIDTH-1:0] a_pipe [0:i-1];
                logic                         v_pipe [0:i-1];
                logic                         l_pipe [0:i-1];  
                logic signed [DATA_WIDTH-1:0] w_pipe [0:i-1];

                always_ff @(posedge clk_i or posedge rst_i) begin
                    if (rst_i) begin
                        for (int j = 0; j < i; j++) begin
                            a_pipe[j] <= '0;
                            v_pipe[j] <= 1'b0;
                            w_pipe[j] <= '0;
			    l_pipe[j] <= 1'b0;
                        end
                    end else begin
                        a_pipe[0]  <= activations_i[i];
                        v_pipe[0]  <= active_beat;
                        l_pipe[0]  <= load_pulse_raw || cold_start; 
                        w_pipe[0]  <= weight_in[i];
                        
                        for (int j = 1; j < i; j++) begin
                            a_pipe[j]  <= a_pipe[j-1];
                            v_pipe[j]  <= v_pipe[j-1];
                            w_pipe[j]  <= w_pipe[j-1];
                            l_pipe[j]  <= l_pipe[j-1];
                        end
                    end
                end

                assign activations_skewed_o[i] = a_pipe[i-1];
                assign v_skewed_o[i]           = v_pipe[i-1];
                assign load_active_row_o[i]    = l_pipe[i-1];
                assign weights_skewed_o[i]     = w_pipe[i-1];
            end
        end
    endgenerate    
    
    generate
        for (i = 0; i < ARRAY_SIZE; i++) begin : GEN_COL_STAGGER
            if (i == 0) begin : col_zero
                assign psums_staggered_o[0] = psum_in[0];
            end else begin : col_pipe
                logic signed [PSUM_WIDTH-1:0] p_pipe [0:i-1];
                always_ff @(posedge clk_i or posedge rst_i) begin
                    if (rst_i) p_pipe <= '{default:0};
		    else begin //if (active_beat) begin
                        p_pipe[0] <= psum_in[i];
                        for (int j = 1; j < i; j++) p_pipe[j] <= p_pipe[j-1];
                    end
                end
                assign psums_staggered_o[i] = p_pipe[i-1];
            end
        end
    endgenerate

    generate
        for (i = 0; i < ARRAY_SIZE; i++) begin : GEN_DESKEW
            localparam int D_DELAY = ARRAY_SIZE - 1 - i;
            if (D_DELAY == 0) begin : deskew_pass
                assign final_psums_o[i] = psums_from_mesh_i[i];
            end else begin : deskew_pipe
                logic signed [PSUM_WIDTH-1:0] d_pipe [0:D_DELAY-1];
                always_ff @(posedge clk_i or posedge rst_i) begin
                    if (rst_i) d_pipe <= '{default:0};
                    else begin
                        d_pipe[0] <= psums_from_mesh_i[i];
                        for (int k = 1; k < D_DELAY; k++) d_pipe[k] <= d_pipe[k-1];
                    end
                end
                assign final_psums_o[i] = d_pipe[D_DELAY-1];
            end
        end
    endgenerate

    logic [14:0] v_sr;
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            v_sr <= '0;
        end else begin
            v_sr[0] <= active_beat;
            for (int p = 1; p < 15; p++) v_sr[p] <= v_sr[p-1];
        end
    end
    assign output_valid_o = v_sr[14];

`ifdef SIMULATION
    property p_act_count_range;
        @(posedge clk_i) disable iff (rst_i)
        act_count < ARRAY_SIZE;
    endproperty
    A_act_count_range: assert property (p_act_count_range);

    property p_pulse_correctness;
        @(posedge clk_i) disable iff (rst_i)
        load_pulse_raw |-> ($past(active_beat) && $past(act_count) == ARRAY_SIZE-2) || $past(cold_start);
    endproperty
    A_pulse_correctness: assert property (p_pulse_correctness)
        else $error("[%0t] SC: load_pulse_raw fired incorrectly", $time);

    property p_15_cycle_latency;
        @(posedge clk_i) disable iff (rst_i)
        output_valid_o |-> $past(active_beat, 15);
    endproperty
    A_15_cycle_latency: assert property (p_15_cycle_latency)
        else $error("[%0t] SC: output_valid_o violates 15-cycle latency rule", $time);

    property p_wavefront_skew;
        @(posedge clk_i) disable iff (rst_i)
        load_active_row_o[ARRAY_SIZE-1] |-> $past(load_active_row_o[0], ARRAY_SIZE-1);
    endproperty
    A_wavefront_skew: assert property (p_wavefront_skew)
        else $error("[%0t] SC: Wavefront skew pipeline is misaligned", $time);

    C_load_pulse_fires:    cover property (@(posedge clk_i) load_pulse_raw);
    C_output_valid:        cover property (@(posedge clk_i) output_valid_o);
    C_backtoback_valid:    cover property (@(posedge clk_i) output_valid_o && $past(output_valid_o));
`endif

endmodule

`else

module systolic_ctrl #(
        parameter ARRAY_SIZE=8,
        parameter DATA_WIDTH=8,
        parameter PSUM_WIDTH=32
)(
        input clk_i,
        input rst_i,
        input start,
        input logic activations_valid_i,
        input signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_i,
        input signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] psums_staggered_i,
        output logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_skewed_o,
        output logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] final_psums_o,
        output logic b_is_weight,
        output logic input_valid_to_pe,
        output logic ready_o,
        output logic shadow_weights_active_o,
        output logic output_valid,
        output logic load_pulse_o
);

        wire chicken_disable_shadow_weights_i;
        assign chicken_disable_shadow_weights_i = 1'b0;
        wire shadow_feature_en;
        assign shadow_feature_en = !chicken_disable_shadow_weights_i;

        localparam int LATENCY = (2 * ARRAY_SIZE) - 1;

        typedef enum logic [2:0] {
                IDLE,
                LOAD_WTS,
                COMPUTE,
                DRAIN,
                WAIT_SHADOW
        } main_state_t;

        typedef enum logic [0:0] {
                SHADOW_IDLE,
                SHADOW_RUN
        } shadow_state_t;

        main_state_t main_state, main_state_next;
        shadow_state_t shadow_state, shadow_state_next;

        logic [15:0] counter, next_counter;
        logic [15:0] sh_counter, sh_counter_next;

        logic start_pending;
        logic start_d;
        logic shadow_ready;

        logic drain_last_cycle;
        assign drain_last_cycle = (main_state == DRAIN) && (counter == 16'(LATENCY - 1));

        logic start_rise;
        assign start_rise = start & ~start_d;

        logic shadow_load_window_open;
        assign shadow_load_window_open = (main_state == WAIT_SHADOW) || ((main_state == DRAIN) && (counter >= 16'(ARRAY_SIZE-1)) && (counter <= 16'(LATENCY - 1)));

        assign shadow_weights_active_o = (shadow_state == SHADOW_RUN);

        assign b_is_weight = (main_state == LOAD_WTS) || (shadow_state == SHADOW_RUN);

        assign load_pulse_o = (main_state == LOAD_WTS && counter == 16'(ARRAY_SIZE - 1))
                           || (shadow_state == SHADOW_RUN && sh_counter == 16'(ARRAY_SIZE - 1));

        logic shadow_consume;
        assign shadow_consume = shadow_feature_en && (main_state_next == COMPUTE)
                && ((main_state == DRAIN && drain_last_cycle && start_pending && shadow_ready)
                 || (main_state == WAIT_SHADOW && shadow_ready));

        // -------------------------------------------------------------------------
        // Main FSM (comb)
        // -------------------------------------------------------------------------
        logic skew_en, deskew_en;

        always_comb begin
                main_state_next = main_state;
                next_counter = counter;
                skew_en = 1'b0;
                deskew_en = 1'b0;
                input_valid_to_pe = 1'b0;
                case (main_state)
                        IDLE: begin
                                if (start_rise) begin
                                        main_state_next = LOAD_WTS;
                                        next_counter = 16'b0;
                                end
                        end
                        LOAD_WTS: begin
                                skew_en = 1'b0;
                                deskew_en = 1'b0;
                                if (counter == ARRAY_SIZE - 1) begin
                                        main_state_next = COMPUTE;
                                        next_counter = 16'b0;
                                end else
                                        next_counter = counter + 16'd1;
                        end
                        COMPUTE: begin
                                skew_en = activations_valid_i;
                                deskew_en = activations_valid_i;
                                input_valid_to_pe = activations_valid_i;
                                if (activations_valid_i) begin
                                        if (counter == 16'(ARRAY_SIZE - 1)) begin
                                                main_state_next = DRAIN;
                                                next_counter = 16'b0;
                                        end else
                                                next_counter = counter + 16'd1;
                                end
                        end
                        DRAIN: begin
                                skew_en = (counter < 16'(ARRAY_SIZE - 1));
                                deskew_en = 1'b1;
                                if (counter == 16'(LATENCY - 1)) begin
                                        if ((!start && !start_pending) || !shadow_feature_en) begin
                                                main_state_next = IDLE;
                                                next_counter = 16'b0;
                                        end else if (shadow_feature_en && start_pending && shadow_ready) begin
                                                main_state_next = COMPUTE;
                                                next_counter = 16'b0;
                                        end else if (start_pending && !shadow_ready
                                                        && shadow_feature_en) begin
                                                main_state_next = WAIT_SHADOW;
                                                next_counter = 16'b0;
                                        end else begin
                                                main_state_next = LOAD_WTS;
                                                next_counter = 16'b0;
                                        end
                                end else
                                        next_counter = counter + 16'd1;
                        end
                        WAIT_SHADOW: begin
                                skew_en = 1'b0;
                                deskew_en = 1'b1;
                                if (shadow_feature_en && shadow_ready) begin
                                        main_state_next = COMPUTE;
                                        next_counter = 16'b0;
                                end
                        end
                        default: begin
                                main_state_next = IDLE;
                                next_counter = 16'b0;
                        end
                endcase
        end

        always_comb begin
                shadow_state_next = shadow_state;
                sh_counter_next = sh_counter;
                case (shadow_state)
                        SHADOW_IDLE: begin
                                if (shadow_feature_en
                                                && start_pending
                                                && shadow_load_window_open
                                                && !shadow_ready) begin
                                        shadow_state_next = SHADOW_RUN;
                                        sh_counter_next = 16'b0;
                                end
                        end
                        SHADOW_RUN: begin
                                if (sh_counter == 16'(ARRAY_SIZE - 1))
                                        shadow_state_next = SHADOW_IDLE;
                                else
                                        sh_counter_next = sh_counter + 16'd1;
                        end
                        default: shadow_state_next = SHADOW_IDLE;
                endcase
        end

        always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i) begin
                        main_state <= IDLE;
                        counter <= 16'b0;
                        start_pending <= 1'b0;
                        start_d <= 1'b0;
                        ready_o <= 1'b0;
                        output_valid <= 1'b0;
                end else begin
                        main_state <= main_state_next;
                        counter <= next_counter;
                        start_d <= start;
                        ready_o <= (main_state == IDLE) || ((main_state == DRAIN) && shadow_feature_en);
                        output_valid <= (main_state == DRAIN) && (counter >= 16'(ARRAY_SIZE-1)) && (counter <= 16'(LATENCY - 1));
                        if (shadow_consume)
                                start_pending <= 1'b0;
                        else if (start_rise && (main_state != IDLE))
                                start_pending <= 1'b1;
                end
        end

        always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i) begin
                        shadow_state <= SHADOW_IDLE;
                        sh_counter <= 16'b0;
                        shadow_ready <= 1'b0;
                end else begin
                        shadow_state <= shadow_state_next;
                        sh_counter <= sh_counter_next;
                        if (!shadow_feature_en)
                                shadow_ready <= 1'b0;
                        else if (shadow_consume)
                                shadow_ready <= 1'b0;
                        else if (shadow_state == SHADOW_RUN && sh_counter == 16'(ARRAY_SIZE - 1))
                                shadow_ready <= 1'b1;
                end
        end

        // Skew activations
        genvar i;
        generate
                for (i = 0; i < ARRAY_SIZE; i++) begin : gen_skew
                        if (i == 0) begin : no_delay
                                assign activations_skewed_o[i] = activations_i[i];
                        end else if (i == 1) begin : one_delay
                                logic signed [DATA_WIDTH-1:0] shift_input_1;

                                always_ff @(posedge clk_i or posedge rst_i) begin
                                        if (rst_i)
                                                shift_input_1 <= '0;
                                        else if (skew_en)
                                                shift_input_1 <= activations_i[i];
                                        else
                                                shift_input_1 <= shift_input_1;
                                end

                                assign activations_skewed_o[i] = shift_input_1;
                        end else begin : multi_delay
                                logic signed [DATA_WIDTH-1:0] shift_input [0:i-1];

                                always_ff @(posedge clk_i or posedge rst_i) begin
                                        if (rst_i) begin
                                                for (int j = 0; j < i; j++) begin
                                                        shift_input[j] <= '0;
                                                end
                                        end else if (skew_en) begin
                                                shift_input[0] <= activations_i[i];
                                                for (int j = 1; j < i; j++) begin
                                                        shift_input[j] <= shift_input[j-1];
                                                end
                                        end else begin
                                                for (int j = 0; j < i; j++) begin
                                                        shift_input[j] <= shift_input[j];
                                                end
                                        end
                                end

                                assign activations_skewed_o[i] = shift_input[i-1];
                        end
                end
        endgenerate

        // De-skew outputs
        genvar k;
        generate
                for (k = 0; k < ARRAY_SIZE; k++) begin : DESKEW_GEN
                        localparam int DELAY = ARRAY_SIZE - k;

                        if (DELAY == 1) begin : one_stage
                                logic signed [PSUM_WIDTH-1:0] shift_output_1;

                                always_ff @(posedge clk_i or posedge rst_i) begin
                                        if (rst_i)
                                                shift_output_1 <= '0;
                                        else if (deskew_en)
                                                shift_output_1 <= psums_staggered_i[k];
                                        else
                                                shift_output_1 <= shift_output_1;
                                end

                                assign final_psums_o[k] = shift_output_1;
                        end else begin : multi_stage
                                logic signed [PSUM_WIDTH-1:0] shift_output [DELAY];

                                always_ff @(posedge clk_i or posedge rst_i) begin
                                        if (rst_i) begin
                                                for (int m = 0; m < DELAY; m++) begin
                                                        shift_output[m] <= '0;
                                                end
                                        end else if (deskew_en) begin
                                                shift_output[0] <= psums_staggered_i[k];
                                                for (int m = 1; m < DELAY; m++) begin
                                                        shift_output[m] <= shift_output[m-1];
                                                end
                                        end else begin
                                                for (int m = 0; m < DELAY; m++) begin
                                                        shift_output[m] <= shift_output[m];
                                                end
                                        end
                                end

                                assign final_psums_o[k] = shift_output[DELAY-1];
                        end
                end
        endgenerate

endmodule


`endif
