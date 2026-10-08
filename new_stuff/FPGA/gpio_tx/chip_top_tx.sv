// -----------------------------------------------------------------------
// chip_top_tb.sv
//
// Combined SPI + bsg_link testbench for chip_top.sv.
//
// Setup:
//   - Drive chip's RX-side pads from a peer bsg_link_ddr_upstream
//     instance acting as the FPGA TX endpoint.
//   - Capture chip's TX-side pads with a peer bsg_link_ddr_downstream
//     instance acting as the FPGA RX endpoint.
//   - SPI master driven from a simple task.
//
// Test sequence:
//   1) Reset all link / token / core resets in stages.
//   2) Wait for the chip's status TX to become valid.
//   3) Send 10 bsg_link RX words ("config write") to set link_cfg_active.
//   4) Verify chip's TX status echoes link_cfg_active=1 and rx_word_count.
//   5) SPI write that asserts spi_reg_enable.
//   6) Verify chip's TX status echoes spi_reg_enable=1.
// -----------------------------------------------------------------------
`timescale 1ps/1ps

// SW9 = rst, SW8 toggles custom clk on KEY3
// LEDR displays: 9 = DONE, 8 = done_send, 7 = done_recv, 4 = fpga_tx_ready
//                0 = trace_enable
// HEX displays: HEX6:4 = SEND ADDR, HEX2:0 = RECV ADDR 
// module chip_top_tb(
module chip_top_tx(
     input  logic CLOCK_50
    ,input  logic [9:0] SW 
    ,input  logic [3:0] KEY
    ,output logic [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0
    ,output logic [9:0] LEDR
);

    localparam int FLIT_WIDTH    = 36;
    localparam int CHANNEL_WIDTH = 18;

    // ----- Clocks + global control -----
    logic core_clk;
    logic dn_io_clk;          // FPGA's TX I/O master clock; bsg_link_oddr_phy ÷2 → 50 MHz forwarded to PAD[8]
    logic hard_reset;

    // ----- Reset stages (mirrors bsg_link reference tb staging) -----
    logic fpga_core_reset;
    logic fpga_tx_io_link_reset;
    logic fpga_tx_async_token_reset;
    logic fpga_rx_io_link_reset;
    logic fpga_rx_io_link_reset_sync;  

    // ----- Pad bus -----
    wire vdd_io = 1'b1;
    wire vss_io = 1'b0;
    tri  [47:0] pad;
    logic [47:0] pad_drv;
    logic [47:0] pad_oe;



    // ----- Clock and reset generation -----
    logic clk;
    logic [31:0] clkdiv;
    logic start_reset_seq; 
    logic reset_from_sw;

    // FPGA clk
    assign clk = CLOCK_50; // 50 MHz
    assign core_clk = SW[8] ? KEY[3] : clkdiv[20]; 
    assign dn_io_clk = SW[8] ? KEY[3] : clkdiv[20];  
    always_ff @(posedge clk) begin
        clkdiv <= start_reset_seq ? 32'b0 : clkdiv + 1;
    end

    // Non-FPGA clk
    // assign clk = core_clk;
    // initial begin
    //     core_clk = 1'b0;
    //     forever #10000 core_clk = ~core_clk;      // 50 MHz
    // end

    // initial begin
    //     dn_io_clk = 1'b0;
    //     forever #10000 dn_io_clk = ~dn_io_clk;    // 50 MHz → bsg_link_oddr_phy ÷2 → 25 MHz forwarded clock at PAD[8]
    // end

    // FPGA reset
    always_ff @(posedge clk) begin
        reset_from_sw <= SW[9];
        start_reset_seq <= reset_from_sw;
    end

    // Non-FPGA reset
    // bsg_nonsynth_reset_gen #(.num_clocks_p(3), .reset_cycles_lo_p(5), .reset_cycles_hi_p(5))
    //     reset_gen (.clk_i(core_clk), .async_reset_o(start_reset_seq));


    function automatic logic kz(input logic v);
        kz = (v === 1'b1) ? 1'b1 : 1'b0;
    endfunction

    genvar pad_idx;
    generate
        for (pad_idx = 0; pad_idx < 48; pad_idx++) begin : gen_pad_drive
            assign pad[pad_idx] = pad_oe[pad_idx] ? pad_drv[pad_idx] : 1'bz;
        end
    endgenerate

	 `ifdef ASIC
		 chip_top uut (
		 // fpga_core uut (
			  .PAD    (pad)
			  ,.VDDPST(vdd_io)
			  ,.VSSPST(vss_io)
			  ,.VDD   (vdd_io)
			  ,.VSS   (vss_io)
		 );
	 `else
		 chip_top uut(
			  .PAD	 (pad)
		 );
	 `endif

    // ----- bsg_link wires shared with chip's PAD bus -----
    logic                       fpga_to_asic_clk;
    logic                       fpga_to_asic_valid;
    logic [CHANNEL_WIDTH-1:0]   fpga_to_asic_data;
    logic                       fpga_to_asic_token;   // FPGA RX -> chip TX token_clk
    logic                       asic_to_fpga_token;   // chip RX -> FPGA TX token
    logic                       asic_to_fpga_clk;
    logic                       asic_to_fpga_valid;
    logic [CHANNEL_WIDTH-1:0]   asic_to_fpga_data;

    // Drive chip's RX-side pads
    assign pad_drv[44] = kz(core_clk);
    assign pad_drv[45] = kz(hard_reset);
    assign pad_drv[8]  = kz(fpga_to_asic_clk);
    assign pad_drv[9]  = kz(fpga_to_asic_valid);

    // dn_data interleave per chip_top.sv's dn_data_pad():
    //   bits[0..7]  -> PAD[0..7]
    //   bit  8 -> PAD[37], bit  9 -> PAD[36],
    //   bit 10 -> PAD[39], bit 11 -> PAD[38],
    //   bit 12 -> PAD[41], bit 13 -> PAD[40],
    //   bit 14 -> PAD[43], bit 15 -> PAD[42]
    assign pad_drv[0]  = kz(fpga_to_asic_data[0]);
    assign pad_drv[1]  = kz(fpga_to_asic_data[1]);
    assign pad_drv[2]  = kz(fpga_to_asic_data[2]);
    assign pad_drv[3]  = kz(fpga_to_asic_data[3]);
    assign pad_drv[4]  = kz(fpga_to_asic_data[4]);
    assign pad_drv[5]  = kz(fpga_to_asic_data[5]);
    assign pad_drv[6]  = kz(fpga_to_asic_data[6]);
    assign pad_drv[7]  = kz(fpga_to_asic_data[7]);
    assign pad_drv[37] = kz(fpga_to_asic_data[8]);
    assign pad_drv[36] = kz(fpga_to_asic_data[9]);
    assign pad_drv[39] = kz(fpga_to_asic_data[10]);
    assign pad_drv[38] = kz(fpga_to_asic_data[11]);
    assign pad_drv[41] = kz(fpga_to_asic_data[12]);
    assign pad_drv[40] = kz(fpga_to_asic_data[13]);
    assign pad_drv[43] = kz(fpga_to_asic_data[14]);
    assign pad_drv[42] = kz(fpga_to_asic_data[15]);
    assign pad_drv[27] = kz(fpga_to_asic_data[16]);

    // chip's token_clk input PAD[12] receives the FPGA RX-side token
    // (the returned-credit signal generated by fpga_rx_link.core_token_r_o).
    assign pad_drv[12] = kz(fpga_to_asic_token);

    // SPI controls
    logic SCLK, MOSI, SS_n;
    wire  MISO;
    //assign pad_drv[13] = kz(SCLK);
    //assign pad_drv[24] = kz(MOSI);
    //assign pad_drv[26] = kz(SS_n);
    //assign MISO         = pad[25];

    // DFT scan inputs tied off in functional sim
    assign pad_drv[11] = 1'b0;
    assign pad_drv[46] = 1'b0;
 // random comment
    // Sample chip's TX-side pads
    assign asic_to_fpga_clk   = pad[15];
    assign asic_to_fpga_valid = pad[14];
    assign asic_to_fpga_token = pad[10];

    // up_data interleave per chip_top.sv's up_data_pad()
    assign asic_to_fpga_data[0]  = pad[22];
    assign asic_to_fpga_data[1]  = pad[23];
    assign asic_to_fpga_data[2]  = pad[20];
    assign asic_to_fpga_data[3]  = pad[21];
    assign asic_to_fpga_data[4]  = pad[18];
    assign asic_to_fpga_data[5]  = pad[19];
    assign asic_to_fpga_data[6]  = pad[16];
    assign asic_to_fpga_data[7]  = pad[17];
    assign asic_to_fpga_data[8]  = pad[28];
    assign asic_to_fpga_data[9]  = pad[29];
    assign asic_to_fpga_data[10] = pad[30];
    assign asic_to_fpga_data[11] = pad[31];
    assign asic_to_fpga_data[12] = pad[32];
    assign asic_to_fpga_data[13] = pad[33];
    assign asic_to_fpga_data[14] = pad[34];
    assign asic_to_fpga_data[15] = pad[35];
    assign asic_to_fpga_data[16] = pad[13];

    // ----- FPGA-side bsg_link instances (peers to chip's wrapper) -----
    logic [FLIT_WIDTH-1:0] fpga_tx_data;
    logic                  fpga_tx_valid;
    logic                  fpga_tx_valid_r;
    logic                  fpga_tx_ready;
    logic [FLIT_WIDTH-1:0] fpga_rx_data;
    logic                  fpga_rx_valid;
    logic                  fpga_rx_yumi;

    logic [31:0] fpga_tx_data_real; // FROM FPGA
    logic [31:0] fpga_rx_data_real; // FROM CHIP
    // logic [17:0] fpga_to_asic_data_real; // FROM FPGA
    // logic [17:0] asic_to_fpga_data_real; // FROM CHIP

    // PARITY BITS SENT BY FPGA
    logic fpga_tx_parity_low, fpga_tx_parity_high;
    // assign fpga_tx_parity_low = 1'b0;
    // assign fpga_tx_parity_high = 1'b0;
    parity_generator #(.WIDTH_p(16)) pg_low (
        .bits_i(fpga_tx_data_real[15:0]),
        .parity_o(fpga_tx_parity_low)
    );
    parity_generator #(.WIDTH_p(16)) pg_high (
        .bits_i(fpga_tx_data_real[31:16]),
        .parity_o(fpga_tx_parity_high)
    );

    logic fpga_rx_parity_low, fpga_rx_parity_high;
    logic fpga_rx_ok_low, fpga_rx_ok_high;
    logic fpga_rx_parity_error;
    parity_checker #(.WIDTH_p(16)) check_low (
        .bits_i(fpga_rx_data[15:0]),
        .parity_i(fpga_rx_parity_low),
        .is_parity_o(fpga_rx_ok_low)
    );
    parity_checker #(.WIDTH_p(16)) check_high (
        .bits_i(fpga_rx_data[33:18]),
        .parity_i(fpga_rx_parity_high),
        .is_parity_o(fpga_rx_ok_high)
    );
    assign fpga_rx_parity_error = fpga_rx_valid && (!fpga_rx_ok_low || !fpga_rx_ok_high);

    assign fpga_tx_data = {1'b0, fpga_tx_parity_high, fpga_tx_data_real[31:16], 1'b0, fpga_tx_parity_low, fpga_tx_data_real[15:0]};
    assign fpga_rx_data_real[31:16] = fpga_rx_data[33:18];
    assign fpga_rx_parity_high      = fpga_rx_data[34];
    assign fpga_rx_data_real[15:0]  = fpga_rx_data[15:0];
    assign fpga_rx_parity_low       = fpga_rx_data[16];
    // assign fpga_to_asic_data = {1'b0, asic_to_fpga_data[16:0]};
    // assign asic_to_fpga_data = asic_to_fpga_data_extended[16:0];
    assign asic_to_fpga_data[17] = 1'b0;
    

    bsg_link_wrapper #(
        .FLIT_WIDTH    (36),
        .CHANNEL_WIDTH (18)
    ) u_bsg_link_wrapper (
        .core_clk_i                (core_clk),
        .reset_i                   (fpga_core_reset),
        .io_master_clk_i           (dn_io_clk),
        .upstream_io_link_reset_i  (fpga_tx_io_link_reset),
        .async_token_reset_i       (fpga_tx_async_token_reset),
        .token_clk_i               (asic_to_fpga_token),
        .downstream_io_link_reset_i(fpga_rx_io_link_reset_sync),
        .downstream_io_clk_i       (asic_to_fpga_clk),
        .downstream_io_data_i      (asic_to_fpga_data), // this is currently 18 bits
        .downstream_io_valid_i     (asic_to_fpga_valid),
        .upstream_io_clk_r_o       (fpga_to_asic_clk),
        .upstream_io_data_r_o      (fpga_to_asic_data), // this is currently 18 bits
        .upstream_io_valid_r_o     (fpga_to_asic_valid),
        .downstream_core_token_r_o (fpga_to_asic_token),
        .rx_data_o                 (fpga_rx_data), // this is currently 36 bits
        .rx_valid_o                (fpga_rx_valid),
        .rx_yumi_i                 (fpga_rx_yumi),
        .tx_data_i                 (fpga_tx_data), // this is currently 36 bits
        .tx_valid_i                (fpga_tx_valid_r),
        .tx_ready_o                (fpga_tx_ready)
    );

    bsg_sync_sync #(.width_p(1)) fpga_rx_reset_sync (
        .oclk_i      (asic_to_fpga_clk),
        .iclk_data_i (fpga_rx_io_link_reset),
        .oclk_data_o (fpga_rx_io_link_reset_sync)
    );

    // assign fpga_rx_yumi = fpga_rx_valid;

    // Track FPGA-side RX from chip
    logic [31:0] fpga_last_rx_data;
    integer                fpga_rx_count;
    always_ff @(posedge core_clk) begin
        if (fpga_core_reset) begin
            fpga_rx_count     <= 0;
            fpga_last_rx_data <= '0;
        end else if (fpga_rx_valid && fpga_rx_yumi) begin
            fpga_rx_count     <= fpga_rx_count + 1;
            fpga_last_rx_data <= fpga_rx_data_real;
        end
    end


    // STRAY TRACE SIGNAL (bc order matters)
    logic trace_enable;

	 
	 // TESTBENCH ONLY, NON-SYNTHESIZABLE
    // ----- Main test sequence -----
    // initial begin
    //     // VCD for legacy/open-source viewers; FSDB for Verdi
    //     // (`make view-sim-rtl`, `make view-sim-syn`, `make view-sim-par`).
    //     // FSDB lives in the run dir alongside simv with the canonical
    //     // name Hammer's vcs-mk view-sim-* targets look for.
    //     $dumpfile("chip_top_tb.vcd");
    //     $dumpvars(0, chip_top_tb);
    //     $fsdbDumpfile("waveform.fsdb");
    //     $fsdbDumpvars(0, chip_top_tb);
    //     $fsdbDumpMDA();   // pack arrays so DDR data buses stay readable

    //     hard_reset                = 1'b1;
    //     fpga_core_reset           = 1'b1;
    //     fpga_tx_io_link_reset     = 1'b1;
    //     fpga_tx_async_token_reset = 1'b0;
    //     fpga_rx_io_link_reset     = 1'b1;
    //     //fpga_tx_valid             = 1'b0;
    //     //fpga_tx_data_real         = '0;
    //     SS_n                      = 1'b1;
    //     MOSI                      = 1'b0;
    //     pad_oe                    = '0;
    //     trace_enable              = 1'b0;

    //     // Let chip_top configure pad directions first.
    //     #1000;
    //     pad_oe[44] = 1'b1; pad_oe[45] = 1'b1;
    //     pad_oe[8]  = 1'b1; pad_oe[9]  = 1'b1;
    //     pad_oe[12] = 1'b1;
    //     //pad_oe[13] = 1'b1; pad_oe[24] = 1'b1; pad_oe[26] = 1'b1;
    //     pad_oe[11] = 1'b1; pad_oe[46] = 1'b1;
    //     for (int dn = 0; dn < 8; dn++) pad_oe[dn] = 1'b1;
    //     pad_oe[37] = 1'b1; pad_oe[36] = 1'b1;
    //     pad_oe[39] = 1'b1; pad_oe[38] = 1'b1;
    //     pad_oe[41] = 1'b1; pad_oe[40] = 1'b1;
    //     pad_oe[43] = 1'b1; pad_oe[42] = 1'b1;
    //     pad_oe[27] = 1'b1;

    //     // Reset bring-up order for our chip:
    //     //  1) Pulse FPGA TX async_token_reset (chip RX side will see tokens
    //     //     once data starts flowing).
    //     //  2) Release FPGA TX I/O link reset (FPGA TX starts driving the
    //     //     chip's RX-side data clock).
    //     //  3) Release chip's hard_reset. The chip's internal reset
    //     //     sequencer takes ~32 core_clks to bring its bsg_link out of
    //     //     reset (async_token pulse, io_link, then core).
    //     //  4) After the chip is running, release FPGA RX I/O link reset
    //     //     so the FPGA RX side sees a valid up_clk from the chip.
    //     //  5) Release FPGA core reset.
    //     repeat (8) @(posedge core_clk);
    //     fpga_tx_async_token_reset = 1'b1;
    //     repeat (2) @(posedge core_clk);
    //     fpga_tx_async_token_reset = 1'b0;

    //     repeat (8) @(posedge dn_io_clk);
    //     fpga_tx_io_link_reset = 1'b0;

    //     // Release chip's hard_reset; wait for its internal sequencer to
    //     // finish (>=32 core_clks).
    //     repeat (8) @(posedge core_clk);
    //     hard_reset = 1'b0;
    //     repeat (64) @(posedge core_clk);

    //     // Now the chip is driving up_clk; safe to bring up FPGA RX.
    //     fpga_rx_io_link_reset = 1'b0;
    //     repeat (8) @(posedge core_clk);
    //     fpga_core_reset = 1'b0;

    //     // Let chip exit reset and start emitting status words
    //     repeat (200) @(posedge core_clk);
    //     trace_enable = 1'b1;
    //     $display("post-reset: rx_count=%0d, last_status=%h",
    //              fpga_rx_count, fpga_last_rx_data);

    //     // Test 1: bsg_link config write (10 words)
    //     $display("Test 1: send 10 bsg_link config words to chip RX");
    //     // send_link_word(32'h0000_0010);
    //     // send_link_word(32'h0102_0304);
    //     // send_link_word(32'h0506_0708);
    //     repeat (200) @(posedge core_clk);

    //     repeat(5000) @(posedge core_clk);
    //     $finish;
    // end

    // TEST SEQUENCE, HARDWARE-BASED (SYNTHESIZABLE)
    enum logic [2:0] {init
							,fpga_tx_async_assert
							,fpga_tx_async_deassert
							,fpga_tx_io_deassert
							,hard_rst_deassert
							,fpga_rx_io_deassert
							,core_reset_deassert
							,start_main
    } reset_seq;

    logic [10:0] wait_amount;
    logic wait_done;


    always_ff @(posedge core_clk) begin
        if (start_reset_seq) begin
            wait_amount      <= 'b0;
            pad_oe           <= '0; 
				wait_done        <= 1'b0;
        end

        if (wait_done) begin
            case (reset_seq)
                init                  : wait_amount               <= 11'h8;
                fpga_tx_async_assert  : wait_amount               <= 11'h2;
                fpga_tx_async_deassert: wait_amount               <= 11'h8;
                fpga_tx_io_deassert   : wait_amount               <= 11'h8;
                hard_rst_deassert     : wait_amount               <= 11'd64;
					 fpga_rx_io_deassert	  : wait_amount					<= 11'd8;
                core_reset_deassert   : wait_amount               <= 11'd200; 
            endcase
        end else if (wait_amount == 1'b0) begin
            wait_done <= 1'b1;
        end else begin
            wait_amount <= wait_amount - 1'b1;
				wait_done <= 1'b0;
        end

        if (reset_seq == fpga_tx_async_assert && wait_amount == 11'h8) begin
            // chip global control
            pad_oe[44] = 1'b1;  // core_clk
            pad_oe[45] = 1'b1;  // hard_reset

            // FPGA upstream -> chip RX-side control pads
            pad_oe[8]  = 1'b1;  // f2c clk
            pad_oe[9]  = 1'b1;  // f2c valid
            pad_oe[12] = 1'b1;  // f2c token

            // DFT scan inputs
            pad_oe[11] = 1'b1;  // scan_en
            pad_oe[46] = 1'b1;  // scan_in

            // FPGA upstream -> chip RX-side data pads (dn_data[0..7])
            pad_oe[7:0] = 8'hFF;
            // FPGA upstream -> chip RX-side data pads (dn_data[8..15])
            pad_oe[43:36] = '1;
            pad_oe[27] = 1'b1; // parity?
        end 

    end


    always_ff @(posedge core_clk) begin 
        if (start_reset_seq) begin
            reset_seq <= init;
        end

        if (wait_done) begin
            case (reset_seq)
                init: begin
                    hard_reset                <= 1'b1;
                    fpga_core_reset           <= 1'b1;
                    fpga_tx_io_link_reset     <= 1'b1;
                    fpga_tx_async_token_reset <= 1'b0;
                    fpga_rx_io_link_reset     <= 1'b1;
                    SS_n                      <= 1'b1;
                    MOSI                      <= 1'b0;
                    trace_enable              <= 1'b0;
                    reset_seq                 <= fpga_tx_async_assert;
                end

                fpga_tx_async_assert: begin
                    reset_seq                 <= fpga_tx_async_deassert;
                    fpga_tx_async_token_reset <= 1'b1;
                end

                fpga_tx_async_deassert: begin
                    reset_seq                 <= fpga_tx_io_deassert;
                    fpga_tx_async_token_reset <= 1'b0;
                end

                fpga_tx_io_deassert: begin
                    reset_seq                 <= hard_rst_deassert;
                    fpga_tx_io_link_reset     <= 1'b0;
                end

                hard_rst_deassert: begin
                    reset_seq                 <= fpga_rx_io_deassert;
                    hard_reset                <= 1'b0;   
                end
					 
					 fpga_rx_io_deassert: begin
                    reset_seq                 <= core_reset_deassert;
                    fpga_rx_io_link_reset     <= 1'b0;   
                end

                core_reset_deassert: begin
                    reset_seq                 <= start_main;
                    fpga_core_reset           <= 1'b0;    
                end

                start_main: begin
                    trace_enable              <= 1'b1;
                end

                default: reset_seq <= init;
            endcase
        end
    end









    // TRACE REPLAY

    // --- Trace Replay Signals ---

    // Addressing
    logic [31:0] rom_addr_send, rom_addr_recv;
    logic [31+4:0] rom_data_send;
    logic [31+4:0] rom_data_recv;
    logic done_send, done_recv;

    // Send side
    logic [31:0] tr_data_lo;
    logic        tr_v_lo;
    logic        tr_yumi_li;

    // Recv side
    logic tr_ready_lo, tr_ready_r;
    logic dut_v_lo, dut_v_r;
    logic[31:0] dut_data_lo, dut_data_r;

    // --- Send Trace Replay (Drives 32 bit flit) ---
    bsg_fsb_node_trace_replay #(
        .ring_width_p(32)
       ,.rom_addr_width_p(32)
    ) tracer_send (
         .clk_i  (~core_clk) // Run replay on opposite edge for stability
        ,.reset_i(hard_reset)
        ,.en_i   (trace_enable)
        
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

    // // Mapping Trace Replay to Top Level Input
    // assign in_flit        = tr_data_lo;
    // assign in_flit_v      = tr_v_lo;
    // assign in_flit_par_ok = 1'b1; // Assuming parity is always good for functional test
    // assign tr_yumi_li     = in_flit_ready & in_flit_v;



    always_ff @(negedge core_clk) begin 
        tr_ready_r <= tr_ready_lo && dut_v_lo; // fpga_rx_yumi, previously link_out_yumi_i
        dut_v_r <= dut_v_lo;
        dut_data_r <= dut_data_lo;
        fpga_tx_valid_r <= fpga_tx_valid;
    end

    assign tr_yumi_li = fpga_tx_ready && fpga_tx_valid_r;

    // --- Receive Trace Replay (Validates link_out) ---
    bsg_fsb_node_trace_replay #(
        .ring_width_p(32)
       ,.rom_addr_width_p(32)
    ) tracer_recv (
         .clk_i  (~core_clk)
        ,.reset_i(hard_reset)
        ,.en_i   (1'b1)

        ,.v_i    (dut_v_r)
        ,.data_i (dut_data_r)
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

    benchmark1_send_trace_rom #(.width_p(32+4), .addr_width_p(32)) 
        ROM_send (.addr_i(rom_addr_send), .data_o(rom_data_send));
    benchmark1_recv_trace_rom #(.width_p(32+4), .addr_width_p(32))
        ROM_recv (.addr_i(rom_addr_recv), .data_o(rom_data_recv));

    // HERE WE WILL CONNECT TRACE REPLAY SIGNALS TO ACTUAL TESTBENCH SIGNALS
    assign fpga_tx_data_real = tr_data_lo;
    assign fpga_tx_valid = tr_v_lo;
    //assign tr_yumi_li = fpga_tx_ready;
    assign fpga_rx_yumi = tr_ready_lo && dut_v_r;
    assign dut_data_lo = fpga_rx_data_real;
    assign dut_v_lo = fpga_rx_valid;


	 logic [3:0] hex_print5, hex_print4, hex_print3, hex_print2, hex_print1, hex_print0;
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
	assign LEDR[4] = fpga_tx_ready;
    assign LEDR[0] = trace_enable;


endmodule