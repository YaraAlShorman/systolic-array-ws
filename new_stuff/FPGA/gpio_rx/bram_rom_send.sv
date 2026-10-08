// bram_rom_send.sv
module bram_rom_send (
    input  logic        clk_i,
    input  logic [8:0]  addr_i,   // 512 depth = 9 bits
    output logic [35:0] data_o
);
    logic [35:0] mem [0:511];
    initial $readmemb("send_rom.mem", mem);

    always_ff @(posedge clk_i)
        data_o <= mem[addr_i];
endmodule