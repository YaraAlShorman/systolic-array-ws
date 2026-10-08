// synthesizable top_chip_tb for fpga testing

module fpga_tx #(
    parameter int SEND_WIDTH_lp = 32,
    parameter int RECV_WIDTH_lp = 32
)(
    input  logic clk_i,       // local CLOCK_50 on TX board
    input  logic reset_i,

    // GPIO to RX board
    output logic [31:0] gpio_flit_o,
    output logic        gpio_flit_v_o,
    input  logic        gpio_flit_ready_i,

    // GPIO from RX board
    input  logic [31:0] gpio_link_data_i,
    input  logic        gpio_link_v_i,
    output logic        gpio_link_yumi_o,

    // Status
    output logic        done_o
);

    // --- Register all GPIO inputs to synchronize to local clock ---
    logic        flit_ready_r;
    logic [31:0] link_data_r;
    logic        link_v_r;

    //always_ff @(posedge clk_i) begin
    //    flit_ready_r <= gpio_flit_ready_i;
    //    link_data_r  <= gpio_link_data_i;
    //    link_v_r     <= gpio_link_v_i;
    //end
	 
	 assign flit_ready_r = gpio_flit_ready_i;
	 assign link_data_r = gpio_link_data_i;
	 assign link_v_r = gpio_link_v_i;

    // --- Send side ---
    logic [31:0] tr_data_lo;
    logic        tr_v_lo, tr_yumi_li;
    logic [31:0] rom_addr_send;
    logic [35:0] rom_data_send;
    logic        done_send;

    bsg_fsb_node_trace_replay #(
        .ring_width_p    (SEND_WIDTH_lp),
        .rom_addr_width_p(32)
    ) tracer_send (
        .clk_i   (~clk_i),
        .reset_i (reset_i),
        .en_i    (1'b1),
        .v_i     (1'b0),  .data_i('0),  .ready_o(),
        .v_o     (tr_v_lo),
        .data_o  (tr_data_lo),
        .yumi_i  (tr_yumi_li),
        .rom_addr_o(rom_addr_send),
        .rom_data_i(rom_data_send),
        .done_o  (done_send),
        .error_o ()
    );

    assign gpio_flit_o   = tr_data_lo;
    assign gpio_flit_v_o = tr_v_lo;
    assign tr_yumi_li    = flit_ready_r & tr_v_lo;  // use registered ready

    // --- Receive side ---
    logic        tr_ready_lo;
    logic        tr_v_li;
    logic [31:0] link_data_s;   // stable sampled data
    logic [31:0] rom_addr_recv;
    logic [35:0] rom_data_recv;
    logic        done_recv;

    // Sample on negedge for stability (same as original TB)
    always_ff @(negedge clk_i) begin
        gpio_link_yumi_o <= tr_ready_lo && link_v_r;
        tr_v_li          <= link_v_r;
        link_data_s      <= link_data_r;
    end

    bsg_fsb_node_trace_replay #(
        .ring_width_p    (RECV_WIDTH_lp),
        .rom_addr_width_p(32)
    ) tracer_recv (
        .clk_i   (~clk_i),
        .reset_i (reset_i),
        .en_i    (1'b1),
        .v_i     (tr_v_li),
        .data_i  (link_data_s),
        .ready_o (tr_ready_lo),
        .v_o(),  .data_o(),  .yumi_i(1'b0),
        .rom_addr_o(rom_addr_recv),
        .rom_data_i(rom_data_recv),
        .done_o  (done_recv),
        .error_o ()
    );

    // --- ROMs ---
    benchmark4_send_trace_rom #(.width_p(36), .addr_width_p(32))
        ROM_send (.addr_i(rom_addr_send), .data_o(rom_data_send));

    benchmark4_recv_trace_rom #(.width_p(36), .addr_width_p(32))
        ROM_recv (.addr_i(rom_addr_recv), .data_o(rom_data_recv));

    assign done_o = done_send && done_recv;

endmodule
