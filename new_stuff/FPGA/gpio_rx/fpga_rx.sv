// top_chip wrapper for fpga testing

module fpga_rx #(
    parameter int DIM_p        = 8,
    parameter int CMDQ_DEPTH_p = 8
)(
    input  logic        clk_i,        // local CLOCK_50 on RX board
    input  logic        reset_i,

    // GPIO from TX board
    input  logic [31:0] gpio_flit_i,
    input  logic        gpio_flit_v_i,
    output logic        gpio_flit_ready_o,

    // GPIO to TX board
    output logic [31:0] gpio_link_data_o,
    output logic        gpio_link_v_o,
    input  logic        gpio_link_yumi_i
);

    // --- Register all GPIO inputs to synchronize to local clock ---
    logic [31:0] flit_r;
    logic        flit_v_r;
    logic        link_yumi_r;

    //always_ff @(posedge clk_i) begin
    //    flit_r       <= gpio_flit_i;
    //    flit_v_r     <= gpio_flit_v_i;
    //    link_yumi_r  <= gpio_link_yumi_i;
    //end
	 
	 assign flit_r      = gpio_flit_i;
	 assign flit_v_r    = gpio_flit_v_i;
	 assign link_yumi_r = gpio_link_yumi_i;

    top_chip #(
        .DIM_p       (DIM_p),
        .CMDQ_DEPTH_p(CMDQ_DEPTH_p)
    ) u_top (
        .clk_i          (clk_i),
        .reset_i        (reset_i),
        .in_flit        (flit_r),
        .in_flit_v      (flit_v_r),
        .in_flit_par_ok (1'b1),
        .in_flit_ready  (gpio_flit_ready_o),  // registered on TX side
        .link_out_v_o   (gpio_link_v_o),
        .link_out_data_o(gpio_link_data_o),
        .link_out_yumi_i(link_yumi_r)
    );

endmodule
