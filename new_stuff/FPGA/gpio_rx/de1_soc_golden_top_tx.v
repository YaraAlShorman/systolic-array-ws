// ============================================================================
// Copyright (c) 2013 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Thu Jul 11 11:26:45 2013
// ============================================================================

`define ENABLE_ADC
`define ENABLE_AUD
`define ENABLE_CLOCK2
`define ENABLE_CLOCK3
`define ENABLE_CLOCK4
`define ENABLE_CLOCK
`define ENABLE_DRAM
`define ENABLE_FAN
`define ENABLE_FPGA
`define ENABLE_GPIO
`define ENABLE_HEX
//`define ENABLE_HPS
`define ENABLE_IRDA
`define ENABLE_KEY
`define ENABLE_LEDR
`define ENABLE_PS2
`define ENABLE_SW
`define ENABLE_TD
`define ENABLE_VGA

module DE1_SOC_golden_top_tx(

      /* Enables ADC - 3.3V */
	`ifdef ENABLE_ADC

      output             ADC_CONVST,
      output             ADC_DIN,
      input              ADC_DOUT,
      output             ADC_SCLK,

	`endif

       /* Enables AUD - 3.3V */
	`ifdef ENABLE_AUD

      input              AUD_ADCDAT,
      inout              AUD_ADCLRCK,
      inout              AUD_BCLK,
      output             AUD_DACDAT,
      inout              AUD_DACLRCK,
      output             AUD_XCK,

	`endif

      /* Enables CLOCK2  */
	`ifdef ENABLE_CLOCK2
      input              CLOCK2_50,
	`endif

      /* Enables CLOCK3 */
	`ifdef ENABLE_CLOCK3
      input              CLOCK3_50,
	`endif

      /* Enables CLOCK4 */
	`ifdef ENABLE_CLOCK4
      input              CLOCK4_50,
	`endif

      /* Enables CLOCK */
	`ifdef ENABLE_CLOCK
      input              CLOCK_50,
	`endif

       /* Enables DRAM - 3.3V */
	`ifdef ENABLE_DRAM
      output      [12:0] DRAM_ADDR,
      output      [1:0]  DRAM_BA,
      output             DRAM_CAS_N,
      output             DRAM_CKE,
      output             DRAM_CLK,
      output             DRAM_CS_N,
      inout       [15:0] DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_RAS_N,
      output             DRAM_UDQM,
      output             DRAM_WE_N,
	`endif

      /* Enables FAN - 3.3V */
	`ifdef ENABLE_FAN
      output             FAN_CTRL,
	`endif

      /* Enables FPGA - 3.3V */
	`ifdef ENABLE_FPGA
      output             FPGA_I2C_SCLK,
      inout              FPGA_I2C_SDAT,
	`endif

      /* Enables GPIO - 3.3V */
	`ifdef ENABLE_GPIO
      inout     [35:0]         GPIO_0,
      inout     [35:0]         GPIO_1,
	`endif
 

      /* Enables HEX - 3.3V */
	`ifdef ENABLE_HEX
      output      [6:0]  HEX0,
      output      [6:0]  HEX1,
      output      [6:0]  HEX2,
      output      [6:0]  HEX3,
      output      [6:0]  HEX4,
      output      [6:0]  HEX5,
	`endif
	
	/* Enables HPS */
	`ifdef ENABLE_HPS
      inout              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N, //1.5V
      output             HPS_DDR3_CK_P, //1.5V
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout       [3:0]  HPS_FLASH_DATA,
      output             HPS_FLASH_DCLK,
      output             HPS_FLASH_NCSO,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_I2C2_SCLK,
      inout              HPS_I2C2_SDAT,
      inout              HPS_I2C_CONTROL,
      inout              HPS_KEY,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif 

      /* Enables IRDA - 3.3V */
	`ifdef ENABLE_IRDA
      input              IRDA_RXD,
      output             IRDA_TXD,
	`endif

      /* Enables KEY - 3.3V */
	`ifdef ENABLE_KEY
      input       [3:0]  KEY,
	`endif

      /* Enables LEDR - 3.3V */
	`ifdef ENABLE_LEDR
      output      [9:0]  LEDR,
	`endif

      /* Enables PS2 - 3.3V */
	`ifdef ENABLE_PS2
      inout              PS2_CLK,
      inout              PS2_CLK2,
      inout              PS2_DAT,
      inout              PS2_DAT2,
	`endif

      /* Enables SW - 3.3V */
	`ifdef ENABLE_SW
      input       [9:0]  SW,
	`endif

      /* Enables TD - 3.3V */
	`ifdef ENABLE_TD
      input             TD_CLK27,
      input      [7:0]  TD_DATA,
      input             TD_HS,
      output            TD_RESET_N,
      input             TD_VS,
	`endif

      /* Enables VGA - 3.3V */
	`ifdef ENABLE_VGA
      output      [7:0]  VGA_B,
      output             VGA_BLANK_N,
      output             VGA_CLK,
      output      [7:0]  VGA_G,
      output             VGA_HS,
      output      [7:0]  VGA_R,
      output             VGA_SYNC_N,
      output             VGA_VS
	`endif
);


//=======================================================
//  REG/WIRE declarations
//=======================================================





//=======================================================
//  Structural coding
//=======================================================

// Tie off unused outputs
assign ADC_CONVST    = 1'b0;
assign ADC_DIN       = 1'b0;
assign ADC_SCLK      = 1'b0;
assign AUD_DACDAT    = 1'b0;
assign AUD_XCK       = 1'b0;
assign DRAM_ADDR     = 13'b0;
assign DRAM_BA       = 2'b0;
assign DRAM_CAS_N    = 1'b1;
assign DRAM_CKE      = 1'b0;
assign DRAM_CLK      = 1'b0;
assign DRAM_CS_N     = 1'b1;
assign DRAM_LDQM     = 1'b0;
assign DRAM_RAS_N    = 1'b1;
assign DRAM_UDQM     = 1'b0;
assign DRAM_WE_N     = 1'b1;
assign FAN_CTRL      = 1'b0;
assign FPGA_I2C_SCLK = 1'b0;
assign IRDA_TXD      = 1'b0;
assign TD_RESET_N    = 1'b0;
assign VGA_B         = 8'b0;
assign VGA_BLANK_N   = 1'b0;
assign VGA_CLK       = 1'b0;
assign VGA_G         = 8'b0;
assign VGA_HS        = 1'b0;
assign VGA_R         = 8'b0;
assign VGA_SYNC_N    = 1'b0;
assign VGA_VS        = 1'b0;

// Unused GPIO pins — high impedance
assign GPIO_0[35:34] = 2'bz;
assign GPIO_1[35:34] = 2'bz;

// Unused LEDs and HEX displays (segments active low, 7'h7F = all off)
assign LEDR[9:1]     = 9'b0;
assign HEX0          = 7'h7F;
assign HEX1          = 7'h7F;
assign HEX2          = 7'h7F;
assign HEX3          = 7'h7F;
assign HEX4          = 7'h7F;
assign HEX5          = 7'h7F;

// TX instantiation
//fpga_tx_synth tx (
//    .clk_i            (CLOCK_50),
//    .reset_i          (~KEY[0]),
//    .gpio_flit_o      (GPIO_0[31:0]),
//    .gpio_flit_v_o    (GPIO_0[32]),
//    .gpio_flit_ready_i(GPIO_0[33]),
//    .gpio_link_data_i (GPIO_1[31:0]),
//    .gpio_link_v_i    (GPIO_1[32]),
//    .gpio_link_yumi_o (GPIO_1[33]),
//    .done_o           (LEDR[0])
//);

fpga_tx_synth tx (
    .clk_i            (CLOCK_50),
    .reset_i          (~KEY[0]),

    // TX drives GPIO_0
    .gpio_flit_o      (GPIO_0[31:0]),
    .gpio_flit_v_o    (GPIO_0[32]),
    .gpio_link_yumi_o (GPIO_0[33]),

    // TX reads GPIO_1
    .gpio_flit_ready_i(GPIO_1[33]),
    .gpio_link_data_i (GPIO_1[31:0]),
    .gpio_link_v_i    (GPIO_1[32]),

    .done_o           (LEDR[0])
);

fpga_rx_synth rx (
    .clk_i            (CLOCK_50),
    .reset_i          (~KEY[0]),

    // RX reads GPIO_0
    .gpio_flit_i      (GPIO_0[31:0]),
    .gpio_flit_v_i    (GPIO_0[32]),
    .gpio_link_yumi_i (GPIO_0[33]),

    // RX drives GPIO_1
    .gpio_flit_ready_o(GPIO_1[33]),
    .gpio_link_data_o (GPIO_1[31:0]),
    .gpio_link_v_o    (GPIO_1[32])
);

endmodule
