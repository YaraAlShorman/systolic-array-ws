`timescale 1ns / 1ps

import ctrl_pkg::*;
import scratchpad_pkg::*;
import PE_pkg::*;
 
// SW9 = rst, SW8 toggles custom clk on KEY3
// LEDR displays: 9 = DONE, 8 = done_send, 7 = done_recv, 4 = in_flit_ready
// HEX displays: HEX6:4 = SEND ADDR, HEX2:0 = RECV ADDR 
module top_chip_tb (
     input  logic CLOCK_50
    ,input  logic [9:0] SW 
    ,input  logic [3:0] KEY
    ,output logic [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0
    ,output logic [9:0] LEDR
    ,inout  logic [35:0] GPIO_0 
    ,inout  logic [35:0] GPIO_1

//     // top_chip sigs
//     ,output logic        clk_i
//     ,output logic        reset_i

//     ,output  logic [31:0] in_flit
//     ,output  logic        in_flit_v
//     ,output  logic        in_flit_par_ok
//     ,input   logic        in_flit_ready

//     ,input   logic        link_out_v_o
//     ,input   logic [31:0] link_out_data_o
//     //,input logic        link_out_parity_o
//     ,output  logic        link_out_yumi_i
);

    // // Waveform Dumping
    // initial begin 
    //     $fsdbDumpfile("waveform.fsdb");
    //     $fsdbDumpvars("+all");
    // end

    // --- Parameters ---
    parameter int DIM_p           = 8;
    parameter int NUM_MATRICES_p  = 4;
    parameter int CMDQ_DEPTH_p    = 8;
    
    // Trace Widths based on top_chip IO
    localparam int SEND_WIDTH_lp = 32; // in_flit width
    localparam int RECV_WIDTH_lp = 32; // link_out_data_o width

    logic clk_i;
    //assign clk_i = SW[8] ? KEY[3] : CLOCK_50;
	 assign clk_i = SW[8] ? KEY[3] : clkdiv[20];
    // bsg_nonsynth_clock_gen #(.cycle_time_p(10000)) clk_gen (clk_i);

    logic reset_i, resetter;
    //assign reset_i = SW[9];
	 always_ff @(posedge clk_i) begin
		resetter <= SW[9];
		reset_i <= resetter;
	 end
    // bsg_nonsynth_reset_gen #(.num_clocks_p(1), .reset_cycles_lo_p(5), .reset_cycles_hi_p(5))
    //     reset_gen (.clk_i(clk_i), .async_reset_o(reset_i));
	 
	 // reset synchronizer
	 

    // --- DUT Signals ---
    logic [31:0] in_flit;
    logic        in_flit_v;
    logic        in_flit_par_ok;
    logic        in_flit_ready;

    logic        link_out_v_o;
    logic [31:0] link_out_data_o;
    logic        link_out_parity_o;
    logic        link_out_yumi_i;

    // --- Trace Replay Signals ---
    logic [31:0] tr_data_lo;
    logic        tr_v_lo;
    logic        tr_yumi_li;

    logic [31:0] rom_addr_send, rom_addr_recv;
    logic [SEND_WIDTH_lp+3:0] rom_data_send;
    logic [RECV_WIDTH_lp+3:0] rom_data_recv;
    logic done_send, done_recv;

    // --- DUT Instantiation ---
//    top_chip #(
//         .DIM_p(DIM_p)
//        ,.CMDQ_DEPTH_p(CMDQ_DEPTH_p)
//    ) dut (
//         .clk_i   (clk_i)
//        ,.reset_i (reset_i)
//
//        // Input Path
//        ,.in_flit        (in_flit)
//        ,.in_flit_v      (in_flit_v)
//        ,.in_flit_par_ok (in_flit_par_ok)
//        ,.in_flit_ready  (in_flit_ready)
//
//        // Output Path
//        ,.link_out_v_o      (link_out_v_o)
//        ,.link_out_data_o   (link_out_data_o)
//        //,.link_out_parity_o (link_out_parity_o)
//        ,.link_out_yumi_i   (link_out_yumi_i)
//    );

    // --- Send Trace Replay (Feeds in_flit) ---
    bsg_fsb_node_trace_replay #(
        .ring_width_p(SEND_WIDTH_lp)
       ,.rom_addr_width_p(32)
    ) tracer_send (
         .clk_i  (~clk_i) // Run replay on opposite edge for stability
        ,.reset_i(reset_i)
        ,.en_i   (1'b1)
        
        ,.v_i    (1'b0)
        ,.data_i ('0)
        ,.ready_o()

        ,.v_o    (tr_v_lo)
        ,.data_o (tr_data_lo)
        ,.yumi_i (tr_yumi_li)

        ,.rom_addr_o(rom_addr_send)
        ,.rom_data_i(rom_data_send)
        ,.done_o    (done_send)
        ,.error_o   ()
    );

    // Mapping Trace Replay to Top Level Input
    assign in_flit        = tr_data_lo;
    assign in_flit_v      = tr_v_lo;
    assign in_flit_par_ok = 1'b1; // Assuming parity is always good for functional test
    assign tr_yumi_li     = in_flit_ready & in_flit_v;

    logic tr_ready_lo;
    logic tr_v_li;
    logic[31:0] link_out_data_o_r;

    always_ff @(negedge clk_i) begin 
        link_out_yumi_i <= tr_ready_lo && link_out_v_o;
        tr_v_li <= link_out_v_o;
        link_out_data_o_r <= link_out_data_o;
    end

    // --- Receive Trace Replay (Validates link_out) ---
    bsg_fsb_node_trace_replay #(
        .ring_width_p(RECV_WIDTH_lp)
       ,.rom_addr_width_p(32)
    ) tracer_recv (
         .clk_i  (~clk_i)
        ,.reset_i(reset_i)
        ,.en_i   (1'b1)

        ,.v_i    (tr_v_li)
        ,.data_i (link_out_data_o_r)
        ,.ready_o(tr_ready_lo) // This ready effectively acts as 'yumi' for the DUT

        ,.v_o    ()
        ,.data_o ()
        ,.yumi_i (1'b0)

        ,.rom_addr_o(rom_addr_recv)
        ,.rom_data_i(rom_data_recv)
        ,.done_o    (done_recv)
        ,.error_o   ()
    );

    // --- Trace ROMs ---
    //bram_rom_recv ROM_recv (.clk_i, .addr_i(rom_addr_recv), .data_o(rom_data_recv));
    //bram_rom_send ROM_send (.clk_i, .addr_i(rom_addr_send), .data_o(rom_data_send));
	 
//	 benchmark4_send_trace_rom #(.width_p(SEND_WIDTH_lp+4), .addr_width_p(32)) 
//        ROM_send (.addr_i(rom_addr_send), .data_o(rom_data_send));
//    benchmark4_recv_trace_rom #(.width_p(RECV_WIDTH_lp+4), .addr_width_p(32))
//        ROM_recv (.addr_i(rom_addr_recv), .data_o(rom_data_recv));
		  
	 benchmark1_send_trace_rom #(.width_p(SEND_WIDTH_lp+4), .addr_width_p(32)) 
        ROM_send (.addr_i(rom_addr_send), .data_o(rom_data_send));
    benchmark1_recv_trace_rom #(.width_p(RECV_WIDTH_lp+4), .addr_width_p(32))
        ROM_recv (.addr_i(rom_addr_recv), .data_o(rom_data_recv));

    
    logic [3:0] hex_print0, hex_print1, hex_print2, hex_print3, hex_print4, hex_print5;


    assign {hex_print5, hex_print4, hex_print3} = rom_addr_send;
    assign {hex_print2, hex_print1, hex_print0} = rom_addr_recv;
    seg7 seg7_for_5 (.hex(hex_print5), .leds(HEX5));
    seg7 seg7_for_4 (.hex(hex_print4), .leds(HEX4));
    seg7 seg7_for_3 (.hex(hex_print3), .leds(HEX3));
    seg7 seg7_for_2 (.hex(hex_print2), .leds(HEX2));
    seg7 seg7_for_1 (.hex(hex_print1), .leds(HEX1));
    seg7 seg7_for_0 (.hex(hex_print0), .leds(HEX0));

    assign LEDR[9] = done_send && done_recv;
	 assign LEDR[8] = done_send;
	 assign LEDR[7] = done_recv;
	 assign LEDR[4] = in_flit_ready;
	 
	 logic [31:0] clkdiv;
	 clock_divider clk_div (.clock(CLOCK_50), .divided_clocks(clkdiv));
	 
	 
	 
	 assign GPIO_0[31:0] = in_flit;
	 assign GPIO_0[32] = in_flit_v;
	 assign GPIO_0[33] = link_out_yumi;
	 assign GPIO_0[34] = clk_i;
	 assign GPIO_0[35] = reset_i;
	 
	 logic [35:0] gpio;
    always_ff @(posedge clk_i) begin
        gpio <= GPIO_1;
    end
	 
	 assign link_out_data = gpio[31:0];
	 assign in_flit_ready = gpio[32];
	 assign link_out_v    = gpio[33];
	 assign link_out_data = gpio[34];

endmodule