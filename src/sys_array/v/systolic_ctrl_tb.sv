// This file contains the toplevel testbench for testing
// the GCD design. 

module systolic_ctrl_tb;

  /* Dump Test Waveform To VPD File */
  initial begin
    $fsdbDumpfile("waveform.fsdb");
    $fsdbDumpvars(0, systolic_ctrl_tb, "+mda");
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

  logic dut_v_lo, dut_v_r;
  logic [175:0] dut_data_lo, dut_data_r;
  logic dut_ready_lo, dut_ready_r;

  logic tr_v_lo;
  logic [175:0] tr_data_lo;
  logic tr_ready_lo, tr_ready_r;

  logic [31:0] rom_addr_li;
  logic [179:0] rom_data_lo;

  logic tr_yumi_li, dut_yumi_li;

  bsg_fsb_node_trace_replay #(.ring_width_p(176)
                             ,.rom_addr_width_p(32) )
    trace_replay
      ( .clk_i ( ~clk ) // Trace Replay should run no negative clock edge!
      , .reset_i( reset )
      , .en_i( 1'b1 )

      , .v_i    (dut_v_r )
      , .data_i ( dut_data_r )
      , .ready_o( tr_ready_lo )

      , .v_o   ( tr_v_lo )
      , .data_o( tr_data_lo )
      , .yumi_i( tr_yumi_li )

      , .rom_addr_o( rom_addr_li )
      , .rom_data_i( rom_data_lo )

      , .done_o()
      , .error_o()
      );


  trace_rom #(.width_p(180),.addr_width_p(32))
    ROM
      (.addr_i( rom_addr_li )
      ,.data_o( rom_data_lo )
      );

 logic signed [3:0][7:0] tb_activations_i;
 logic signed [3:0][31:0] tb_psums_staggered_i;
 logic signed [3:0][7:0] tb_activations_skewed_o;
 logic signed [3:0][31:0] tb_final_psums_o;
 
 assign tb_activations_i = tr_data_lo[159:128];
 assign tb_psums_staggered_i = tr_data_lo[127:0];
 assign dut_data_lo[159:128] = tb_activations_skewed_o;
 assign dut_data_lo[127:0]   = tb_final_psums_o;
 assign dut_data_lo[175:162] = 14'b0;

 // Required for sim-par 
 systolic_ctrl #( .ARRAY_SIZE(4), .DATA_WIDTH(8), .PSUM_WIDTH(32)) DUT (
          .clk_i (clk)
         ,.rst_i (reset)
         ,.start (tr_v_lo)
         ,.ready_o (dut_ready_lo)
	 ,.num_input_rows (tr_data_lo[175:160])
         ,.\activations_i[0] (tb_activations_i[0])
	 ,.\activations_i[1] (tb_activations_i[1])
	 ,.\activations_i[2] (tb_activations_i[2])
	 ,.\activations_i[3] (tb_activations_i[3])
         ,.\psums_staggered_i[0] (tb_psums_staggered_i[0])
         ,.\psums_staggered_i[1] (tb_psums_staggered_i[1])
	 ,.\psums_staggered_i[2] (tb_psums_staggered_i[2])
	 ,.\psums_staggered_i[3] (tb_psums_staggered_i[3])
         ,.output_valid ()
         ,.input_valid_to_pe (dut_data_lo[161])
         ,.b_is_weight (dut_data_lo[160])
         ,.\activations_skewed_o[0] (tb_activations_skewed_o[0])
         ,.\activations_skewed_o[1] (tb_activations_skewed_o[1])
	 ,.\activations_skewed_o[2] (tb_activations_skewed_o[2])
	 ,.\activations_skewed_o[3] (tb_activations_skewed_o[3])
         ,.\final_psums_o[0] (tb_final_psums_o[0])
	 ,.\final_psums_o[1] (tb_final_psums_o[1])
	 ,.\final_psums_o[2] (tb_final_psums_o[2])
	 ,.\final_psums_o[3] (tb_final_psums_o[3])
  ); 
  /* //Required for sim-rtl
 systolic_ctrl #( .ARRAY_SIZE(4), .DATA_WIDTH(8), .PSUM_WIDTH(32)) DUT (
          .clk_i (clk)
         ,.rst_i (reset)
         ,.start (tr_v_lo)
         ,.ready_o (dut_ready_lo)
         ,.num_input_rows (tr_data_lo[175:160])
         ,.activations_i (tb_activations_i)
         ,.psums_staggered_i (tb_psums_staggered_i)
         ,.output_valid ()
         ,.input_valid_to_pe (dut_data_lo[161])
         ,.b_is_weight (dut_data_lo[160])
         ,.activations_skewed_o (tb_activations_skewed_o)
         ,.final_psums_o (tb_final_psums_o)
  );
  */
  assign dut_v_lo = 1'b1;
  assign tr_yumi_li = tr_v_lo;
  assign dut_yumi_li = tr_ready_lo & dut_v_lo;
  assign dut_data_r = dut_data_lo;
  assign dut_ready_r = dut_ready_lo;
  assign dut_v_r = dut_v_lo;
endmodule
