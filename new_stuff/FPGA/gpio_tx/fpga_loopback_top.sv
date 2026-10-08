module fpga_loopback_top (LEDR, GPIO_0, GPIO_1);
    output logic [9:0]  LEDR;         // LEDR[0] = done
    inout  logic [35:0] GPIO_0;       // TX drives out
    inout  logic [35:0] GPIO_1;       // RX drives out
	 
//	 fpga_tx_synth tx (
//        .clk_i            (CLOCK_50),
//        .reset_i          (~KEY[0]),
//        .gpio_flit_o      (GPIO_0[31:0]),
//        .gpio_flit_v_o    (GPIO_0[32]),
//        //.gpio_link_yumi_o (GPIO_0[33]),
//		  .gpio_link_yumi_o (TEMP),
//        .gpio_flit_ready_i(GPIO_1[33]),
//        .gpio_link_data_i (GPIO_1[31:0]),
//        .gpio_link_v_i    (GPIO_1[32]),
//        .done_o           (LEDR[0]),
//		  .done_send_o		  (LEDR[1]),
//		  .done_recv_o      (LEDR[2])
//    );

//    fpga_rx_synth rx (
//        .clk_i            (CLOCK_50),
//        .reset_i          (~KEY[0]),
//        .gpio_flit_i      (GPIO_0[31:0]),
//        .gpio_flit_v_i    (GPIO_0[32]),
//        .gpio_link_yumi_i (GPIO_0[33]),
//        .gpio_flit_ready_o(GPIO_1[33]),
//        .gpio_link_data_o (GPIO_1[31:0]),
//        .gpio_link_v_o    (GPIO_1[32])
//    );


	 logic in_flit_par_ok = 1'b1;
	 logic clock, reset;
	 assign GPIO_1[38] 	= clock;
	 assign LEDR[0] 		= clock;
	 assign GPIO_1[39] 	= reset;
	 assign LEDR[1] 		= reset;

	 top_chip top (
		  .clk_i(clock),
		  .reset_i(reset),
		  
		  .in_flit(GPIO_1[31:0]),
		  .in_flit_v(GPIO_1[36]),
		  .in_flit_par_ok(in_flit_par_ok),
		  
		  .in_flit_ready(GPIO_0[36]),
		  
		  .link_out_v_o(GPIO_0[37]),
		  .link_out_data_o(GPIO_0[38]),
		  
		  .link_out_yumi_i(GPIO_1[37])
);

endmodule // fpga_loopback_top