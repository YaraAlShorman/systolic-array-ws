module gpio_tx (
	  input  logic CLOCK_50
    ,input  logic [9:0] SW 
    ,input  logic [3:0] KEY
    ,output logic [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0
    //,output logic [9:0] LEDR,
	 ,inout  logic [35:0] GPIO_0 
    ,inout  logic [35:0] GPIO_1
);

	 
	 logic clk_i;
	 logic [31:0] clkdiv;
	 assign clk_i = SW[8] ? KEY[3] : clkdiv[20];
	 
	 logic reset_i, resetter;
    always_ff @(posedge clk_i) begin
        resetter <= SW[9];
        reset_i <= resetter;
    end
	 
	 clock_divider clk_div (.clock(CLOCK_50), .divided_clocks(clkdiv));
	 
	 logic [3:0] hex_val; // 4b hex value (0 to F)
	 logic [1:0] half_hex_val; // 2b val (0 to 3)
	 logic [3:0] hex_print5, hex_print4, hex_print3, hex_print2, hex_print1, hex_print0;
	 
	 always_ff @(posedge clk_i) begin
		if (reset_i) begin
		  hex_val      <= 4'h0;
		  half_hex_val <= 2'h0;
		end else begin
		  if (!KEY[0]) begin
		    hex_val <= hex_val + 4'h1; 
			 half_hex_val <= half_hex_val + 2'h1;
		  end
		end
	 end

	 assign hex_print5 = hex_val;
	 //assign {hex_print4, hex_print3, hex_print2, hex_print1, hex_print0} = '0;
	 seg7 seg7_for_5 (.hex(hex_print5), .leds(HEX5));
	 seg7 seg7_for_4 (.hex(hex_print4), .leds(HEX4));
    seg7 seg7_for_3 (.hex(hex_print3), .leds(HEX3));
    seg7 seg7_for_2 (.hex(hex_print2), .leds(HEX2));
    seg7 seg7_for_1 (.hex(hex_print1), .leds(HEX1));
    seg7 seg7_for_0 (.hex(hex_print0), .leds(HEX0));
	 
	 
	 assign GPIO_0[31:0]  = {8{hex_val}};
	 assign GPIO_0[33:32] = half_hex_val;
	 assign GPIO_0[34]    = clk_i;
	 assign GPIO_0[35]    = reset_i;
	 
	 logic [35:0] gpio1, gpio1_hold;
    always_ff @(posedge clk_i) begin
		  gpio1_hold <= GPIO_1;
        gpio1 <= gpio1_hold;
    end
	 assign hex_print0 = gpio1[3:0];
	 assign hex_print1 = gpio1[7:4];
	 assign hex_print2 = gpio1[11:8];
	 assign hex_print3 = gpio1[15:12];
	 assign hex_print4 = gpio1[19:16];
	 
endmodule
