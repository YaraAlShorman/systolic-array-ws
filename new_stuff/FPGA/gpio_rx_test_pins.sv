// This module is for testing the pins
module gpio_rx_test_pins (
	  input  logic CLOCK_50
    ,input  logic [9:0] SW 
//    ,input  logic [3:0] KEY
    ,output logic [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0
    ,output logic [9:0] LEDR
	 ,inout  logic [35:0] GPIO_0 
    ,inout  logic [35:0] GPIO_1
);
	 
	 logic clk_i;
	 assign clk_i = GPIO_1[34];
	 
	 logic [35:0] gpio;
    always_ff @(posedge clk_i) begin
        gpio <= GPIO_1;
		  GPIO_0 <= gpio;
    end
	 
	 logic reset_i;
	 assign reset_i = gpio[35];
	 
	 
	 logic [3:0] hex_print0, hex_print1, hex_print2, hex_print3, hex_print4, hex_print5;

	 assign hex_print0 = gpio[3:0];
	 assign hex_print1 = gpio[7:4];
	 assign hex_print2 = gpio[11:8];
	 assign hex_print3 = gpio[27:24];
	 assign hex_print4 = gpio[31:28];
	 assign hex_print5 = {{2{1'b0}}, gpio[33:32]};

    seg7 seg7_for_5 (.hex(hex_print5), .leds(HEX5));
    seg7 seg7_for_4 (.hex(hex_print4), .leds(HEX4));
    seg7 seg7_for_3 (.hex(hex_print3), .leds(HEX3));
    seg7 seg7_for_2 (.hex(hex_print2), .leds(HEX2));
    seg7 seg7_for_1 (.hex(hex_print1), .leds(HEX1));
    seg7 seg7_for_0 (.hex(hex_print0), .leds(HEX0));
	 
	 always_ff @(posedge clk_i) begin
		if (reset_i)
			LEDR[0] <= 1'b1;
		else
			LEDR[0] <= 1'b0;
	end
	 
	 
endmodule