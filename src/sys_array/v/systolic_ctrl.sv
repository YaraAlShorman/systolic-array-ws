// FSM controller for Systolic array
//
// Main FSM: IDLE -> LOAD_WTS (N) -> COMPUTE (N accepted beats) -> DRAIN (2N-1) -> WAIT_SHADOW / ...
// From first COMPUTE cycle through end of DRAIN = N + (2N-1) = 3N-1 cycles per matmul.
//
// Weight load protocol (LOAD_WTS / SHADOW_RUN):
//   PE.b_o is registered, so top_data_i propagates one row per cycle down each
//   column. The driver (TB / DMA) pushes weight rows on top_data_i in REVERSE
//   row order over N cycles -- W[N-1] at cycle 0, W[N-2] at cycle 1, ...,
//   W[0] at cycle N-1. At the last load cycle every row k of every column c
//   already has W[k][c] aligned on its b_i, so a single broadcast v_i pulse
//   (load_pulse_o) latches all N*N weights directly into weight_active in one
//   shot. No shadow staging and no per-row walker are needed.
//   Timing safety: v_i (from input_valid_to_pe) propagates horizontally and
//   the last v_i=1 at column c expires at DRAIN cycle c-1. The maximum is
//   column N-1 at DRAIN cycle N-2. SHADOW_RUN opens at DRAIN cycle N-1,
//   strictly one cycle after the last MAC across all 64 PEs, so overwriting
//   weight_active during SHADOW_RUN cannot corrupt any in-flight computation.
//   SHADOW_RUN reuses the exact same protocol as LOAD_WTS.
//
// Parallel shadow loader: starts only in late DRAIN when top_data_i is no
// longer needed for psum input. If DRAIN ends before shadow is ready, main
// waits in WAIT_SHADOW. Next COMPUTE (skip LOAD_WTS) only starts when
// shadow_ready.
//
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

	// 1 disables parallel shadow weight load; drive from CSR / tie here (not a top_mod port).
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
	assign shadow_load_window_open = (main_state == WAIT_SHADOW);

	assign ready_o = (main_state == IDLE) || (main_state == DRAIN);

	assign shadow_weights_active_o = (shadow_state == SHADOW_RUN);

	assign b_is_weight = (main_state == LOAD_WTS) || (shadow_state == SHADOW_RUN);

	assign load_pulse_o = (main_state == LOAD_WTS && counter == 16'(ARRAY_SIZE - 1))
	                   || (shadow_state == SHADOW_RUN && sh_counter == 16'(ARRAY_SIZE - 1));

	// Output rows are valid for exactly N cycles in DRAIN:
	// counter = N-1, N, ... , 2N-2  (inclusive).
	assign output_valid = (main_state == DRAIN)
		&& (counter >= 16'(ARRAY_SIZE - 1))
		&& (counter <= 16'(LATENCY - 1));

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
				input_valid_to_pe = (counter < 16'(ARRAY_SIZE - 1));
				if (counter == 16'(LATENCY - 1)) begin
					if (!start && !start_pending) begin
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
				input_valid_to_pe = 1'b0;
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

	// -------------------------------------------------------------------------
	// Shadow loader FSM (comb)
	// -------------------------------------------------------------------------
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
	
	always_ff @(posedge clk_i) begin
		if (rst_i) begin
			main_state <= IDLE;
			counter <= 16'b0;
			start_pending <= 1'b0;
			start_d <= 1'b0;
		end else begin
			main_state <= main_state_next;
			counter <= next_counter;
			start_d <= start;

			if (shadow_consume)
				start_pending <= 1'b0;
			else if (start_rise && (main_state != IDLE))
				start_pending <= 1'b1;
		end
	end

	always_ff @(posedge clk_i) begin
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

				always_ff @(posedge clk_i) begin
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

				always_ff @(posedge clk_i) begin
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

				always_ff @(posedge clk_i) begin
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

				always_ff @(posedge clk_i) begin
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
