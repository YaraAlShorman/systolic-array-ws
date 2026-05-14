// chip_tester.sv
//
// Loopback testbench for bsg_link_wrapper.
//
// Two bsg_link_wrapper instances (FPGA_link and CHIP_link) are
// cross-connected at the IO pad level.  On the chip side, a simple
// one-cycle loopback register echoes received data back toward the
// FPGA.  In the future this register will be replaced by the actual
// chip design under test.
//
// Architecture:
//
//   fpga_sender_trace_replay --> FPGA_link.f2c --> CHIP_link.rx
//                                                      |
//                                               [1-cycle reg / chip]
//                                                      |
//   fpga_receiver_trace_replay <-- FPGA_link.c2f <-- CHIP_link.tx / chip
//
// Two independent trace-replay / ROM pairs drive and check the test:
//   fpga_sender_trace_replay   + TX_ROM  – injects data into FPGA_link (f2c path)
//   fpga_receiver_trace_replay + RX_ROM  – checks data returning on FPGA_link (c2f path)

module chip_tester;

    parameter FLIT_WIDTH        = 32;
    parameter CHANNEL_WIDTH     = 16;
    parameter ROM_DATA_WIDTH_P  = 36;   // ring_width + 4 command bits
    parameter ROM_ADDR_WIDTH_P  = 64;


    // =============================================================
    //  Waveform dump
    // =============================================================

    initial begin
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars();
    end


    // =============================================================
    //  Clock generators
    // =============================================================

    logic core_clk;
    bsg_nonsynth_clock_gen #(1000) core_clk_gen (core_clk);

    logic io_clk;
    bsg_nonsynth_clock_gen #(500) io_clk_gen (io_clk);


    // =============================================================
    //  Reset generators
    //
    //  Deassertion order:
    //    1. async_token_reset     (token counters init first)
    //    2. upstream_io_reset     (both upstreams start generating IO clocks)
    //    3. downstream_io_reset   (both downstreams now have valid IO clocks)
    //    4. core_reset            (core domains of link wrappers + loopback)
    //    5. tb_io_reset           (trace replays start sending/receiving)
    //
    //  Data path:
    //    FPGA upstream → CHIP downstream → [chip] → CHIP upstream → FPGA downstream
    // =============================================================

    logic async_token_reset;
    bsg_nonsynth_reset_gen #(
        .num_clocks_p      (1),
        .reset_cycles_lo_p (2),
        .reset_cycles_hi_p (8)
    ) token_reset_gen (
        .clk_i         (io_clk)
       ,.async_reset_o (async_token_reset)
    );
    always @(posedge async_token_reset) $display("[async_token_reset] asserted");

    logic upstream_io_reset;
    bsg_nonsynth_reset_gen #(
        .num_clocks_p      (1),
        .reset_cycles_lo_p (10),
        .reset_cycles_hi_p (40)
    ) upstream_io_reset_gen (
        .clk_i         (io_clk)
       ,.async_reset_o (upstream_io_reset)
    );
    always @(posedge upstream_io_reset) $display("[upstream_io_reset] asserted");

    logic downstream_io_reset;
    bsg_nonsynth_reset_gen #(
        .num_clocks_p      (1),
        .reset_cycles_lo_p (10),
        .reset_cycles_hi_p (120)
    ) downstream_io_reset_gen (
        .clk_i         (io_clk)
       ,.async_reset_o (downstream_io_reset)
    );
    always @(posedge downstream_io_reset) $display("[downstream_io_reset] asserted");

    logic core_reset;
    bsg_nonsynth_reset_gen #(
        .num_clocks_p      (1),
        .reset_cycles_lo_p (5),
        .reset_cycles_hi_p (200)
    ) core_reset_gen (
        .clk_i         (io_clk)
       ,.async_reset_o (core_reset)
    );
    always @(posedge core_reset) $display("[core_reset] asserted");

    logic tb_io_reset;
    bsg_nonsynth_reset_gen #(
        .num_clocks_p      (1),
        .reset_cycles_lo_p (10),
        .reset_cycles_hi_p (300)
    ) tb_io_reset_gen (
        .clk_i         (io_clk)
       ,.async_reset_o (tb_io_reset)
    );
    always @(posedge tb_io_reset) $display("[tb_io_reset] asserted");


    // =============================================================
    //  Signal declarations
    // =============================================================

    // fpga -> chip wires -------------------------
    logic                        f2c_io_clk;
    logic [CHANNEL_WIDTH-1:0]    f2c_io_data;
    logic                        f2c_io_valid;
    logic                        f2c_token;
    logic                        f2c_data_parity;

    // chip -> fpga wires -------------------------
    logic                        c2f_io_clk;
    logic [CHANNEL_WIDTH-1:0]    c2f_io_data;
    logic                        c2f_io_valid;
    logic                        c2f_token;
    logic                        c2f_data_parity;

    // chip port aliases (ds = f2c, us = c2f)
    logic                        ds_clk;
    logic [CHANNEL_WIDTH-1:0]    ds_data;
    logic                        ds_valid;
    logic                        ds_token;
    logic                        ds_data_parity;

    logic                        us_clk;
    logic [CHANNEL_WIDTH-1:0]    us_data;
    logic                        us_valid;
    logic                        us_token;
    logic                        us_data_parity;

    assign ds_clk          = f2c_io_clk;
    assign ds_data         = f2c_io_data;
    assign ds_valid        = f2c_io_valid;
    assign ds_token        = f2c_token;
    assign ds_data_parity  = f2c_data_parity;

    assign us_clk          = c2f_io_clk;
    assign us_data         = c2f_io_data;
    assign us_valid        = c2f_io_valid;
    assign us_token        = c2f_token;
    assign us_data_parity  = c2f_data_parity;

    // fpga core-side signals ---------------------
    logic [FLIT_WIDTH-1:0]       f2c_data;
    logic                        f2c_valid;
    logic                        f2c_ready;

    logic [FLIT_WIDTH-1:0]       c2f_data;
    logic                        c2f_valid;
    logic                        c2f_yumi;

    // chip core-side signals ---------------------
    logic [FLIT_WIDTH-1:0]       chip_rx_data;
    logic                        chip_rx_valid;
    logic                        chip_rx_yumi;
    logic                        chip_tx_ready;

    // loopback register --------------------------
    logic [FLIT_WIDTH-1:0]       loopback_data_r;
    logic                        loopback_valid_r;

    // sender trace replay ------------------------
    logic [ROM_ADDR_WIDTH_P-1:0] tx_rom_addr;
    logic [ROM_DATA_WIDTH_P-1:0] tx_rom_data;
    logic                        tx_start_d_half;
    // logic                        f2c_parity;

    // receiver trace replay ----------------------
    logic [ROM_ADDR_WIDTH_P-1:0] rx_rom_addr;
    logic [ROM_DATA_WIDTH_P-1:0] rx_rom_data;
    logic                        rx_tr_ready;
    logic [FLIT_WIDTH-1:0]       c2f_data_d_half;
    logic                        c2f_valid_d_half;
    logic                        c2f_valid_d_one_and_half;

    // IDK if we need this lol
    logic [7:0]                  power_high;
    logic [7:0]                  power_low;
    assign power_high = 7'b111_1111;
    assign power_low  = 7'b000_0000;

    // =============================================================
    //  Start test area
    // =============================================================

    bsg_link_wrapper #(
        .FLIT_WIDTH   (FLIT_WIDTH),
        .CHANNEL_WIDTH(CHANNEL_WIDTH)
    ) FPGA_link (
        .core_clk_i                 (core_clk)
       ,.reset_i                    (core_reset)

       // link domain
        // upstream / f2c IO domain
       ,.io_master_clk_i            (io_clk)
       ,.upstream_io_link_reset_i   (upstream_io_reset)
       ,.async_token_reset_i        (async_token_reset)
       ,.token_clk_i                (f2c_token)

        // downstream / c2f IO domain
       ,.downstream_io_link_reset_i (downstream_io_reset)
       ,.downstream_io_clk_i        (c2f_io_clk)
       ,.downstream_io_data_i       (c2f_io_data)
       ,.downstream_io_valid_i      (c2f_io_valid)

        // upstream pad outputs -> to chip downstream
       ,.upstream_io_clk_r_o        (f2c_io_clk)
       ,.upstream_io_data_r_o       (f2c_io_data)
       ,.upstream_io_valid_r_o      (f2c_io_valid)

        // downstream token -> credit return to chip upstream
       ,.downstream_core_token_r_o  (c2f_token) // credit return
       // end link domain

       // tb values
        // core-facing f2c (data going to chip)
       ,.tx_data_i                  (f2c_data)
       ,.tx_valid_i                 (f2c_valid)
       ,.tx_ready_o                 (f2c_ready)

        // core-facing c2f (data coming back from chip)
       ,.rx_data_o                  (c2f_data)
       ,.rx_valid_o                 (c2f_valid)
       ,.rx_yumi_i                  (c2f_yumi)
    );


    // ================ CHIP ===============
    bsg_link_wrapper #(
        .FLIT_WIDTH   (FLIT_WIDTH),
        .CHANNEL_WIDTH(CHANNEL_WIDTH)
    ) CHIP_link (
        .core_clk_i                 (core_clk)
       ,.reset_i                    (core_reset)

        // upstream / TX IO domain
       ,.io_master_clk_i            (io_clk)
       ,.upstream_io_link_reset_i   (upstream_io_reset)
       ,.async_token_reset_i        (async_token_reset)
       ,.token_clk_i                (c2f_token)

        // downstream / RX IO domain (from fpga upstream)
       ,.downstream_io_link_reset_i (downstream_io_reset)
       ,.downstream_io_clk_i        (f2c_io_clk)
       ,.downstream_io_data_i       (f2c_io_data)
       ,.downstream_io_valid_i      (f2c_io_valid)

        // upstream pad outputs -> to fpga downstream
       ,.upstream_io_clk_r_o        (c2f_io_clk)
       ,.upstream_io_data_r_o       (c2f_io_data)
       ,.upstream_io_valid_r_o      (c2f_io_valid)

        // downstream token -> credit return to fpga upstream
       ,.downstream_core_token_r_o  (f2c_token)

        // core-facing RX (data arriving from fpga)
       ,.rx_data_o                  (chip_rx_data)
       ,.rx_valid_o                 (chip_rx_valid)
       ,.rx_yumi_i                  (chip_rx_yumi)

        // core-facing TX (loopback data going back to fpga)
       ,.tx_data_i                  (loopback_data_r)
       ,.tx_valid_i                 (loopback_valid_r)
       ,.tx_ready_o                 (chip_tx_ready)
    );

    // Register holds data input for one cycle before being sending to output
    // Does not accept new flit until current flit has been consumed
    always_ff @(posedge core_clk) begin
        if (core_reset) begin
            loopback_valid_r <= 1'b0;
            loopback_data_r  <= '0;
        end else begin
            if (chip_rx_valid & ~loopback_valid_r) begin
                loopback_data_r  <= chip_rx_data;
                loopback_valid_r <= 1'b1;
            end else if (loopback_valid_r & chip_tx_ready) begin
                loopback_valid_r <= 1'b0;
            end
        end
    end

    assign chip_rx_yumi = chip_rx_valid & ~loopback_valid_r;
    // ================ End CHIP ===============

    // ================ Chip module (uncomment to replace CHIP_link + loopback) ===============
    // chip CHIP_DUT (
    //     .core_clk       (core_clk)
    //    ,.hard_reset     (core_reset)
    //
    //    ,.ds_clk         (ds_clk)
    //    ,.ds_data        (ds_data)
    //    ,.ds_valid       (ds_valid)
    //    ,.ds_token       (ds_token)
    //    ,.ds_data_parity (ds_data_parity)
    //
    //    ,.us_clk         (us_clk)
    //    ,.us_data        (us_data)
    //    ,.us_valid       (us_valid)
    //    ,.us_token       (us_token)
    //    ,.us_data_parity (us_data_parity)
    //
    //    // ,.scan_in      ()
    //    // ,.scan_out     ()
    //    // ,.scan_en      ()
    // );



    // =============================================================
    //  Trace replay area
    // =============================================================

    // sender (f2c path) ------------------------------------------

    bsg_fsb_node_trace_replay #(
        .ring_width_p    (FLIT_WIDTH),
        .rom_addr_width_p(ROM_ADDR_WIDTH_P)
    ) fpga_sender_trace_replay (
        .clk_i       (~io_clk)
       ,.reset_i     (tb_io_reset)
       ,.en_i        (1'b1)

        // Sender trace replay does not need to receive anything
       ,.v_i         (1'b0)
       ,.data_i      ({FLIT_WIDTH{1'b0}})
       ,.ready_o     ()

        // TX side – drives data into fpga f2c path
       ,.v_o         (f2c_valid)
       ,.data_o      (f2c_data)
       ,.yumi_i      (tx_start_d_half)

       ,.rom_addr_o  (tx_rom_addr)
       ,.rom_data_i  (tx_rom_data)

       ,.done_o      ()
       ,.error_o     ()
    );

    always_ff @(negedge io_clk) begin
        tx_start_d_half <= f2c_valid & f2c_ready;
    end

    tx_trace_rom #(
        .width_p     (ROM_DATA_WIDTH_P),
        .addr_width_p(ROM_ADDR_WIDTH_P)
    ) TX_ROM (
        .addr_i      (tx_rom_addr)
       ,.data_o      (tx_rom_data)
    );

    // parity_generator #(
    //     .WIDTH_p(FLIT_WIDTH)
    // ) f2c_parity_gen (
    //     .bits_i  (f2c_data),
    //     .parity_o(f2c_parity)
    // );

    // receiver (c2f path) ----------------------------------------

    bsg_fsb_node_trace_replay #(
        .ring_width_p    (FLIT_WIDTH),
        .rom_addr_width_p(ROM_ADDR_WIDTH_P)
    ) fpga_receiver_trace_replay (
        // RX side – receives data from fpga c2f path
        .v_i         (c2f_valid_d_one_and_half)
       ,.data_i      (c2f_data_d_half)
       ,.ready_o     (rx_tr_ready)

       ,.clk_i       (~io_clk)
       ,.reset_i     (tb_io_reset)
       ,.en_i        (1'b1)

        // Receiver trace replay does not need to send anything
        // It only needs to check if the data has been correctly received
       ,.v_o         ()
       ,.data_o      ()
       ,.yumi_i      (1'b0)

       ,.rom_addr_o  (rx_rom_addr)
       ,.rom_data_i  (rx_rom_data)

       ,.done_o      ()
       ,.error_o     ()
    );

    always_ff @(negedge io_clk) begin
        c2f_data_d_half          <= c2f_data;
        c2f_valid_d_half         <= c2f_valid;
        c2f_valid_d_one_and_half <= c2f_valid_d_half;
    end

    assign c2f_yumi = c2f_valid & rx_tr_ready;

    rx_trace_rom #(
        .width_p     (ROM_DATA_WIDTH_P),
        .addr_width_p(ROM_ADDR_WIDTH_P)
    ) RX_ROM (
        .addr_i      (rx_rom_addr)
       ,.data_o      (rx_rom_data)
    );

endmodule // chip_tester