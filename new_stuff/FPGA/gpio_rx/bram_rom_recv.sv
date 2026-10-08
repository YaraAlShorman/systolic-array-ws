// bram_rom_recv.sv
module bram_rom_recv (
    input  logic        clk_i,
    input  logic [9:0]  addr_i,   // 1024 depth = 10 bits
    output logic [35:0] data_o
);
    logic [35:0] mem [0:1023];
    initial $readmemb("recv_rom.mem", mem);

    always_ff @(posedge clk_i)
        data_o <= mem[addr_i];
endmodule