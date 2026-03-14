// 
// Testbench for systolic array processing element PE.sv.
// Using trace.tr for testing inputs.
//

module PE_tb;

  /* Dump Test Waveform To VPD File */
  initial begin
    $fsdbDumpfile("waveform.fsdb");
    $fsdbDumpvars();
  end

  /* Non-synth clock generator */
  logic clk;
  bsg_nonsynth_clock_gen #(10000) clk_gen_1 (clk);

  /* Non-synth reset generator */
  logic reset;
  bsg_nonsynth_reset_gen #(.num_clocks_p(1),.reset_cycles_lo_p(5),. reset_cycles_hi_p(5))
    reset_gen
      (.clk_i        ( clk )
      ,.async_reset_o( reset )
      );

  logic tr_v_lo;
  logic [42:0] tr_data_lo; // ## 43-bits payload
  logic tr_ready_lo;
  logic tr_yumi_li;
  logic tr_yumi_lo;

  logic [31:0] rom_addr_li;
  logic [46:0] rom_data_lo; // ## 4-bit command + 43-bit payload

  // DUT IO signals
  logic pe_v_i, pe_b_is_weight_i, pe_mac_bypass_i;
  logic signed [7:0] pe_a_i;
  logic signed [31:0] pe_b_i;

  logic pe_v_o;
  logic signed [7:0] pe_a_o;
  logic signed [31:0] pe_b_o;
  logic signed [7:0] pe_weight_o;

  // Buffered output for trace replay
  logic dut_v_r;
  logic [42:0] dut_data_lo;	// ## 43-bit payload from DUT
  logic [42:0] dut_data_r;	// ## buffered 43-bit payload from dut_data_lo

  bsg_fsb_node_trace_replay #(
        .ring_width_p(43)	// ## 43-bits payload
      , .rom_addr_width_p(32) 
  ) trace_replay (
        .clk_i ( ~clk )
      , .reset_i( reset )
      , .en_i( 1'b1 )

      // Data from DUT output to trace replay
      , .v_i    ( dut_v_r )
      , .data_i ( dut_data_r )
      , .ready_o( tr_ready_lo )

      // Data from trace replay to DUT input
      , .v_o   ( tr_v_lo )
      , .data_o( tr_data_lo )
      , .yumi_i( tr_yumi_li )

      , .rom_addr_o( rom_addr_li )
      , .rom_data_i( rom_data_lo )

      , .done_o()
      , .error_o()
      );

  // trace_rom #(
  //      .width_p(47)		// ## 4-bit command + 43-bit payload
  //     ,.addr_width_p(32)
  // ) ROM (
  //      .addr_i( rom_addr_li )
  //     ,.data_o( rom_data_lo )
  //     );

  PE_test_ROM #(.addr_width(32), .data_width(47)) ROM (
      .addr_i( rom_addr_li ),
      .data_o( rom_data_lo )
  );

  PE #(
     .ENABLE_MAC_BYPASS(1)
    // ,.ROW_ID(0)
    // ,.COL_ID(0)
  ) DUT (
     .clk_i	   ( clk )
    ,.rst_i	   ( reset )
    ,.v_i	   ( pe_v_i )
    ,.mac_bypass_i ( pe_mac_bypass_i )

    ,.a_i	   ( pe_a_i )
    ,.b_i	   ( pe_b_i )
    ,.b_is_weight_i( pe_b_is_weight_i )

    ,.v_o	   ( pe_v_o )
    ,.a_o	   ( pe_a_o )
    ,.b_o	   ( pe_b_o )
    ,.weight_o     ( pe_weight_o)
  );

  // input mapping from trace
  assign pe_v_i 	  = tr_v_lo & tr_data_lo[42]; // only valid when SEND
  assign pe_b_is_weight_i = tr_data_lo[41];
  assign pe_mac_bypass_i  = tr_data_lo[40];
  assign pe_a_i 	  = tr_data_lo[39:32];
  assign pe_b_i 	  = tr_data_lo[31:0];

  // handshaking
  assign tr_yumi_li = tr_v_lo; 

  // Output handshake for PE: Capture valid results into registers
  // output bit template: 1 bit (v_o) + 1 bit (0) + 1 bit (0) + 8 bits (a_o) + 32 bits (b_o) = 43 bits
  always_ff @(posedge clk) begin
    if (reset) begin
      dut_v_r <= 0;
      dut_data_r <= 0;
    end
    else begin
      // When the PE signals a valid output
      if (pe_v_o) begin
        dut_v_r <= 1;
        // Map PE outputs to the 43-bit trace format
        dut_data_r <= dut_data_lo; 
      end
      // Clear the valid register once trace_replay consumes it (yumi)
      else if (tr_yumi_lo) begin
        dut_v_r <= 0;
      end
    end
  end

  // output template: 1b (v_o) + 1b (0) + 1b (0) + 8b (a_o) + 32b (b_o)
  always_comb begin
    dut_data_lo = { pe_v_o, 2'b00, pe_a_o, pe_b_o };
  end
  
  // trace_replay yumi
  always_ff @(negedge clk) begin
    tr_yumi_lo <= tr_ready_lo & dut_v_r;
  end

endmodule

