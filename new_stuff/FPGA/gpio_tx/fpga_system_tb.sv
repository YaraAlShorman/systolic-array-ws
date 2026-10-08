// testbench combining fpga_rx and fpga_tx, independent clocks

`timescale 1ns / 1ps

module fpga_system_tb;

    import ctrl_pkg::*;
    import scratchpad_pkg::*;
    import PE_pkg::*;

    // --- Independent clocks (same freq, slight phase offset to model real hardware) ---
    logic clk_tx, clk_rx;
    bsg_nonsynth_clock_gen #(.cycle_time_p(10000)) clk_gen_tx (.o(clk_tx));
    bsg_nonsynth_clock_gen #(.cycle_time_p(10001)) clk_gen_rx (.o(clk_rx)); // slightly off to stress test

    // --- Independent resets ---
    logic reset_tx, reset_rx;
    bsg_nonsynth_reset_gen #(.num_clocks_p(1), .reset_cycles_lo_p(5), .reset_cycles_hi_p(5))
        reset_gen_tx (.clk_i(clk_tx), .async_reset_o(reset_tx));
    bsg_nonsynth_reset_gen #(.num_clocks_p(1), .reset_cycles_lo_p(5), .reset_cycles_hi_p(5))
        reset_gen_rx (.clk_i(clk_rx), .async_reset_o(reset_rx));

    // --- GPIO wires between TX and RX ---
    wire [31:0] gpio_flit_w;
    wire        gpio_flit_v_w;
    wire        gpio_flit_ready_w;
    wire [31:0] gpio_link_data_w;
    wire        gpio_link_v_w;
    wire        gpio_link_yumi_w;

    // --- TX FPGA ---
    fpga_tx tx (
        .clk_i             (clk_tx),
        .reset_i           (reset_tx),
        .gpio_flit_o       (gpio_flit_w),
        .gpio_flit_v_o     (gpio_flit_v_w),
        .gpio_flit_ready_i (gpio_flit_ready_w),
        .gpio_link_data_i  (gpio_link_data_w),
        .gpio_link_v_i     (gpio_link_v_w),
        .gpio_link_yumi_o  (gpio_link_yumi_w),
        .done_o            (done_w)
    );

    // --- RX FPGA ---
    fpga_rx rx (
        .clk_i             (clk_rx),
        .reset_i           (reset_rx),
        .gpio_flit_i       (gpio_flit_w),
        .gpio_flit_v_i     (gpio_flit_v_w),
        .gpio_flit_ready_o (gpio_flit_ready_w),
        .gpio_link_data_o  (gpio_link_data_w),
        .gpio_link_v_o     (gpio_link_v_w),
        .gpio_link_yumi_i  (gpio_link_yumi_w)
    );

endmodule
