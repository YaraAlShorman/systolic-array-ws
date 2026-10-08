// gpio_rx.sv
//
// bsg_link RX endpoint for FPGA-to-FPGA GPIO loopback test.
// Receives hex counter flits from gpio_tx, displays them on
// the HEX displays, and echoes each flit back unchanged.
//
// Reset is driven externally by gpio_tx via GPIO_1[20].
// An internal counter sequences the link resets once
// hard_reset deasserts (mirrors chip_top.sv approach).
//
// io_master_clk is tied to core_clk to save a GPIO pin.
//
// GPIO_0 pin map (RX drives -> TX's GPIO_1):
//   [0]     upstream_io_clk_r_o   (forwarded RX clock)
//   [1]     upstream_io_valid_r_o
//   [18:2]  upstream_io_data_r_o[16:0]  (17-bit channel)
//   [19]    downstream_core_token_r_o   (credit return to TX upstream)
//   [35:20] unused
//
// GPIO_1 pin map (RX reads <- TX's GPIO_0):
//   [0]     downstream_io_clk_i
//   [1]     downstream_io_valid_i
//   [18:2]  downstream_io_data_i[16:0]  (17-bit channel)
//   [19]    token_clk_i                 (credit return from TX downstream)
//   [20]    hard_reset (from gpio_tx)
//   [35:21] unused

module gpio_rx_link (
     input  logic        CLOCK_50
    ,input  logic [9:0]  SW
    ,output logic [6:0]  HEX5, HEX4, HEX3, HEX2, HEX1, HEX0
    ,output logic [9:0]  LEDR
    ,inout  logic [35:0] GPIO_0
    ,inout  logic [35:0] GPIO_1
);

    // =========================================================
    //  Clocks
    // =========================================================

    logic core_clk;
    logic [31:0] clkdiv;
    clock_divider clk_div (.clock(CLOCK_50), .divided_clocks(clkdiv));

    assign core_clk = clkdiv[16];  // ~381 Hz: matches gpio_tx clock rate

    // io_master_clk tied to core_clk to save a GPIO pin.
    // bsg_link_oddr_phy divides it by 2 internally before forwarding.
    wire io_master_clk = core_clk;


    // =========================================================
    //  GPIO signal declarations
    // =========================================================

    // downstream inputs (from TX's GPIO_0)
    logic        dn_clk;
    logic        dn_valid;
    logic [16:0] dn_data;
    logic        token_clk;
    logic        hard_reset_in;

    // upstream outputs (to TX's GPIO_1)
    logic        up_clk;
    logic        up_valid;
    logic [16:0] up_data;
    logic        dn_token;

    // RX drives GPIO_0
    assign GPIO_0[0]     = up_clk;
    assign GPIO_0[1]     = up_valid;
    assign GPIO_0[18:2]  = up_data;
    assign GPIO_0[19]    = dn_token;
    assign GPIO_0[35:20] = '0;

    // RX reads GPIO_1
    assign dn_clk      = GPIO_1[0];
    assign dn_valid    = GPIO_1[1];
    assign dn_data     = GPIO_1[18:2];
    assign token_clk   = GPIO_1[19];
    assign hard_reset_in = GPIO_1[20];

	 
    // =========================================================
    //  Internal reset sequencer
    //
    //  Mirrors chip_top.sv: once hard_reset from TX deasserts,
    //  a counter sequences resets in order:
    //    async_token -> upstream IO -> downstream IO -> core
    // =========================================================

    // Synchronize hard_reset deassert into core_clk domain.
    // Assert is still combinationally fast (2-FF chain clears asynchronously).
    wire hard_reset_sync;
    async_rst_sync_deassert u_hard_reset_sync (
        .clk                    (core_clk)
       ,.rst                    (hard_reset_in)
       ,.async_rst_sync_deassert(hard_reset_sync)
    );

    // Reset counter — runs freely once hard_reset deasserts
    reg [5:0] reset_cnt = 6'd0;
    always @(posedge core_clk) begin
        if (hard_reset_sync)         reset_cnt <= 6'd0;
        else if (reset_cnt < 6'd63)  reset_cnt <= reset_cnt + 6'd1;
    end

    // async_token_reset: pulsed during counts 2..4 (bsg_link protocol)
//    wire async_token_reset_int = ~hard_reset_sync
//                                 && (reset_cnt >= 6'd2)
//                                 && (reset_cnt <  6'd5);
	 
    wire async_token_reset_int = hard_reset_sync ||
                                 ( (reset_cnt >= 6'd2)
                                 && (reset_cnt <  6'd5));

    // Upstream IO reset: released at count 16
    // Upstream releases first so TX's downstream sees a valid up_clk
    // while its own downstream reset is still asserted
    wire io_link_reset_int = hard_reset_sync || (reset_cnt < 6'd16);

    // Downstream IO reset: released at count 24 (8 counts after upstream)
    wire downstream_io_link_reset_int = hard_reset_sync || (reset_cnt < 6'd24);

    // Core reset: released last at count 32
    wire core_link_reset_int = hard_reset_sync || (reset_cnt < 6'd32);

    // Sync downstream IO link reset into the dn_clk domain
    // (dn_clk = TX's forwarded clock on GPIO_1[0])
    wire downstream_io_link_reset_sync;
    async_rst_sync_deassert u_dn_reset_sync (
//        .clk                    (dn_clk)
		  .clk                    (core_clk)
       ,.rst                    (downstream_io_link_reset_int)
       ,.async_rst_sync_deassert(downstream_io_link_reset_sync)
    );


    // =========================================================
    //  bsg_link_wrapper instantiation
    // =========================================================

    logic [31:0] link_rx_data;
    logic        link_rx_valid;
    logic        link_rx_yumi;
    logic        link_rx_parity_error;
    logic [31:0] link_tx_data;
    logic        link_tx_valid;
    logic        link_tx_ready;

    bsg_link_wrapper #(
        .FLIT_WIDTH   (32),
        .CHANNEL_WIDTH(17)
    ) u_link (
        .core_clk_i                 (core_clk)
       ,.reset_i                    (core_link_reset_int)

       ,.io_master_clk_i            (io_master_clk)
       ,.upstream_io_link_reset_i   (io_link_reset_int)
       ,.async_token_reset_i        (async_token_reset_int)
       ,.token_clk_i                (token_clk)

       ,.downstream_io_link_reset_i (downstream_io_link_reset_sync)
       ,.downstream_io_clk_i        (dn_clk)
       ,.downstream_io_data_i       (dn_data)
       ,.downstream_io_valid_i      (dn_valid)

       ,.upstream_io_clk_r_o        (up_clk)
       ,.upstream_io_data_r_o       (up_data)
       ,.upstream_io_valid_r_o      (up_valid)

       ,.downstream_core_token_r_o  (dn_token)

       ,.rx_data_o                  (link_rx_data)
       ,.rx_valid_o                 (link_rx_valid)
       ,.rx_yumi_i                  (link_rx_yumi)
       ,.rx_parity_error_o          (link_rx_parity_error)

       ,.tx_data_i                  (link_tx_data)
       ,.tx_valid_i                 (link_tx_valid)
       ,.tx_ready_o                 (link_tx_ready)
    );


    // =========================================================
    //  Echo path: receive flit from TX, send back unchanged
    //
    //  A single-entry buffer holds the flit until the upstream
    //  link accepts it.  New flits are not accepted while the
    //  buffer is full (natural backpressure via link_rx_yumi).
    // =========================================================

    logic [31:0] echo_data_r;
    logic        echo_valid_r;

    assign link_rx_yumi  = link_rx_valid && !echo_valid_r;
    assign link_tx_data  = echo_data_r;
    assign link_tx_valid = echo_valid_r;

    always_ff @(posedge core_clk) begin
        if (core_link_reset_int) begin
            echo_valid_r <= 1'b0;
            echo_data_r  <= '0;
        end else begin
            if (link_rx_yumi) begin
                echo_data_r  <= link_rx_data;
                echo_valid_r <= 1'b1;
            end else if (echo_valid_r && link_tx_ready) begin
                echo_valid_r <= 1'b0;
            end
        end
    end


    // =========================================================
    //  HEX display  (latch received counters on valid flit)
    //
    //  HEX0: received hex_val       (bits [3:0])
    //  HEX1: received half_hex_val  (bits [5:4])
    //  HEX4: reset_cnt low nibble   (link bring-up progress)
    //  HEX5: reset_cnt high bits
    // =========================================================

    logic [3:0] disp_hex_val;
    logic [1:0] disp_half_hex;

    always_ff @(posedge core_clk) begin
        if (core_link_reset_int) begin
            disp_hex_val  <= 4'h0;
            disp_half_hex <= 2'h0;
        end else if (link_rx_valid && link_rx_yumi) begin
            disp_hex_val  <= link_rx_data[3:0];
            disp_half_hex <= link_rx_data[5:4];
        end
    end

    seg7 seg7_0 (.hex(disp_hex_val),           .leds(HEX0));
    seg7 seg7_1 (.hex({2'b0, disp_half_hex}),  .leds(HEX1));
    seg7 seg7_2 (.hex(4'b0),                   .leds(HEX2));
    seg7 seg7_3 (.hex(4'b0),                   .leds(HEX3));
    seg7 seg7_4 (.hex(reset_cnt[3:0]),          .leds(HEX4));
    seg7 seg7_5 (.hex({2'b0, reset_cnt[5:4]}), .leds(HEX5));


    // =========================================================
    //  LED status
    // =========================================================

    assign LEDR[0]   = link_rx_valid;
    assign LEDR[1]   = link_tx_valid;
    assign LEDR[2]   = link_tx_ready;
	 assign LEDR[3]   = dn_valid;
	 assign LEDR[4]   = link_rx_yumi;
    assign LEDR[5]   = echo_valid_r;
    assign LEDR[8:6] = '0;
    assign LEDR[9]   = link_rx_parity_error;

endmodule


// -----------------------------------------------------------------------
// Async assert / sync deassert reset synchronizer.
// -----------------------------------------------------------------------
module async_rst_sync_deassert (
    input  wire clk,
    input  wire rst,
    output wire async_rst_sync_deassert
);
    reg rst_sync1;
    reg rst_sync2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rst_sync1 <= 1'b1;
            rst_sync2 <= 1'b1;
        end else begin
            rst_sync1 <= 1'b0;
            rst_sync2 <= rst_sync1;
        end
    end

    assign async_rst_sync_deassert = rst_sync2;
endmodule