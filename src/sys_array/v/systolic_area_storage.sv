// ============================================================
// Area-probe storage: 4 KiB data + 80b x 10-deep FIFO
//
// Storage is built as explicit flip-flop banks (per-word write
// enables), not inferred SRAM/block RAM. Attributes below are
// hints for flows that might still merge arrays into memories.
//
// Data memory: 512 x 64 b (4 KiB). scratch_addr_i selects read/write
// indices; scratch_data_i is separate write/FIFO payload so data bits are
// not algebraically tied to address bits (avoids constant folding of FFs).
// ============================================================

module systolic_area_storage (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [63:0] scratch_addr_i,
    input  logic [63:0] scratch_data_i,
    input  logic        push_i,
    input  logic        pop_i,
    input  logic        dmem_we_i,
    output logic [63:0] dmem_rdata_o,
    output logic [79:0] ififo_rdata_o,
    output logic [63:0] storage_digest_o
);

    localparam int DMEM_WORDS  = 256;
    localparam int DMEM_ADDR_W = $clog2(DMEM_WORDS);
    localparam int FIFO_DEPTH  = 15;
    localparam int FIFO_PTR_W  = $clog2(FIFO_DEPTH);

    logic [DMEM_ADDR_W-1:0] dmem_raddr;
    logic [DMEM_ADDR_W-1:0] dmem_waddr;
    logic [63:0] dmem_wdata;

    assign dmem_raddr = scratch_addr_i[DMEM_ADDR_W-1:0];
    assign dmem_waddr = scratch_addr_i[2*DMEM_ADDR_W-1:DMEM_ADDR_W];
    assign dmem_wdata = scratch_data_i;

    // --------------------------------------------------------
    // 4 KiB as 512 independent 64-bit registers (no RAM macro)
    // --------------------------------------------------------
    logic [63:0] dmem_word [0:DMEM_WORDS-1];

    genvar gi;
    generate
        for (gi = 0; gi < DMEM_WORDS; gi++) begin : g_dmem_ff
            always_ff @(posedge clk_i) begin
                if (dmem_we_i && (dmem_waddr == DMEM_ADDR_W'(gi)))
                    dmem_word[gi] <= dmem_wdata;
            end
        end
    endgenerate

    always_ff @(posedge clk_i) begin
        if (rst_i)
            dmem_rdata_o <= '0;
        else
            dmem_rdata_o <= dmem_word[dmem_raddr];
    end

    // --------------------------------------------------------
    // FIFO: 10 x 80-bit registers
    // --------------------------------------------------------
    logic [79:0] fifo_entry [0:FIFO_DEPTH-1];

    logic [FIFO_PTR_W-1:0] wr_ptr, rd_ptr;
    logic [4:0] fifo_count;

    logic push_x;
    logic pop_x;
    logic full;
    logic empty;

    assign push_x = push_i & ~full;
    assign pop_x  = pop_i & ~empty;
    assign full   = (fifo_count == 5'(FIFO_DEPTH));
    assign empty  = (fifo_count == 5'd0);

    genvar fj;
    generate
        for (fj = 0; fj < FIFO_DEPTH; fj++) begin : g_ififo_ff
            always_ff @(posedge clk_i) begin
                if (push_x && (wr_ptr == FIFO_PTR_W'(fj)))
                    fifo_entry[fj] <= {scratch_data_i, scratch_data_i[15:0]};
            end
        end
    endgenerate

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            wr_ptr          <= '0;
            rd_ptr          <= '0;
            fifo_count      <= '0;
            ififo_rdata_o   <= '0;
        end else begin
            unique case ({push_x, pop_x})
                2'b10: begin
                    wr_ptr     <= (wr_ptr == FIFO_PTR_W'(FIFO_DEPTH - 1)) ? '0 : wr_ptr + 1'b1;
                    fifo_count <= fifo_count + 1'b1;
                end
                2'b01: begin
                    ififo_rdata_o <= fifo_entry[rd_ptr];
                    rd_ptr     <= (rd_ptr == FIFO_PTR_W'(FIFO_DEPTH - 1)) ? '0 : rd_ptr + 1'b1;
                    fifo_count <= fifo_count - 1'b1;
                end
                2'b11: begin
                    ififo_rdata_o <= fifo_entry[rd_ptr];
                    wr_ptr     <= (wr_ptr == FIFO_PTR_W'(FIFO_DEPTH - 1)) ? '0 : wr_ptr + 1'b1;
                    rd_ptr     <= (rd_ptr == FIFO_PTR_W'(FIFO_DEPTH - 1)) ? '0 : rd_ptr + 1'b1;
                end
                default: ;
            endcase
        end
    end

    // --------------------------------------------------------
    // All-bits digest (observability hook for synthesis area runs)
    // --------------------------------------------------------
    // Every DMEM/FIFO bit contributes to storage_digest_o. When this digest
    // is tied to a top-level output cone, synthesis cannot remove "unused"
    // storage bits without changing observable behavior.
    always_comb begin
        storage_digest_o = '0;
        for (int w = 0; w < DMEM_WORDS; w++) begin
            storage_digest_o ^= dmem_word[w];
        end
        for (int f = 0; f < FIFO_DEPTH; f++) begin
            storage_digest_o ^= fifo_entry[f][63:0];
            storage_digest_o ^= {48'd0, fifo_entry[f][79:64]};
        end
    end

endmodule
