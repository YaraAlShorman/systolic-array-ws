// FSM controller for Systolic array

module systolic_ctrl #(
	parameter ARRAY_SIZE=4,
	parameter DATA_WIDTH=8,
	parameter PSUM_WIDTH=32
)(
	input clk_i,
	input rst_i,
	input start,
	input [15:0] num_input_rows,
        input signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_i,
	input signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] psums_staggered_i,
	output logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] activations_skewed_o,
	output logic signed [ARRAY_SIZE-1:0][PSUM_WIDTH-1:0] final_psums_o,
	output logic b_is_weight,
	output logic input_valid_to_pe,
	output logic ready_o,
	output logic output_valid, 
);

localparam int LATENCY = (2 * ARRAY_SIZE) - 1;

typedef enum logic [1:0] {
	IDLE,
	LOAD_WTS,
	COMPUTE,
	DRAIN
} state_t;

state_t state, next_state;

logic [15:0] counter, next_counter, num_input_rows_reg;
logic skew_en, deskew_en, fsm_idle;
logic [LATENCY-1:0] shift_reg;

assign ready_o = fsm_idle;

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		state <= IDLE;
		counter <= 16'b0;
		shift_reg <= {LATENCY{1'b0}};
		num_input_rows_reg <= 16'b0;
	end else begin
		state <= next_state;
		counter <= next_counter;
		shift_reg <= {shift_reg[LATENCY-2:0], input_valid_to_pe};
		if (start)
			num_input_rows_reg <= num_input_rows;
	end
end

assign output_valid = shift_reg[LATENCY-1];

always_comb begin
	next_state = state;
	next_counter = counter;
	b_is_weight = 1'b0;
	skew_en = 1'b0;
	deskew_en = 1'b0;
	input_valid_to_pe = 1'b0;
	fsm_idle = 1'b0;
        
	case (state)
		IDLE: begin
			fsm_idle = 1'b1;
			if (start) begin
				next_state = LOAD_WTS;
				next_counter = 16'b0;
			end
		end
		LOAD_WTS: begin
			b_is_weight = 1'b1;
			if (counter == ARRAY_SIZE - 1) begin
				next_state = COMPUTE;
				next_counter = 16'b0;
			end else
				next_counter = counter + 1'b1;
		end
		COMPUTE: begin
			skew_en = 1'b1;
			deskew_en = 1'b1;
			input_valid_to_pe = 1'b1;
			if (counter == num_input_rows - 16'd1) begin
				next_state = DRAIN;
				next_counter = 16'b0;
			end else
				next_counter = counter + 1'b1;
		end
		DRAIN: begin
			skew_en = 1'b1;
			deskew_en = 1'b1;
			input_valid_to_pe = 1'b0;
			if(counter == (LATENCY - 1)) begin
				next_state = IDLE;
			        next_counter = 16'b0;
			end else
				next_counter = counter + 1'b1;
		end
	endcase
end

//Logic to skew input rows

genvar i;
generate
        for (i=0; i<ARRAY_SIZE; i++) begin
		if (i==0) begin
			assign activations_skewed_o[i] = activations_i[i];
		end else begin
			logic signed [DATA_WIDTH-1:0] shift_input[i];

			always_ff @(posedge clk_i) begin
			       if (rst_i) begin
			             for (int j=0; j<i; j++) shift_input[j] <= '0;
		               end else if (skew_en) begin
		                     shift_input[0] <= activations_i[i];
	                             for (int j=1; j<i; j++) shift_input[j] <= shift_input[j-1];
	                       end
                        end
                        
                        assign activations_skewed_o[i] = shift_input[i-1];
                end
        end
endgenerate

//Logic to de-skew output columns

genvar k;
generate
        for (k=0; k<ARRAY_SIZE; k++) begin
		localparam int DELAY = ARRAY_SIZE - 1 - k;
	        if (DELAY == 0) begin
		        assign final_psums_o[k] = psums_staggered_i[k];
		end else begin
			logic signed [PSUM_WIDTH-1:0] shift_output [DELAY];

			always_ff @(posedge clk_i) begin
				if (rst_i) begin
					for (int m=0; m<DELAY; m++) shift_output[m] <= '0;
			        end else if (deskew_en) begin
					shift_output[0] <= psums_staggered_i[k];
					for (int m=1; m<DELAY; m++) shift_output[m] <= shift_output[m-1];
				end
		        end
		        assign final_psums_o[k] = shift_output[DELAY-1];
		end
	end
endgenerate	

endmodule
