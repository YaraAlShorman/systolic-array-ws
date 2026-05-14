// tx_trace_rom.sv
//
// ROM for fpga_sender_trace_replay.
// Sends test data through the FPGA f2c path and then disables.
// The receiver ROM is responsible for calling $finish.

module tx_trace_rom #(
    parameter width_p     = 36,
    parameter addr_width_p = 64
) (
    input  logic [addr_width_p-1:0] addr_i,
    output logic [width_p-1:0]      data_o
);

    // Formatting:
    //   <4 bit op> <32-bit data>
    //      op = 0000: wait one cycle
    //      op = 0001: send
    //      op = 0010: receive & check
    //      op = 0011: done; disable but do not stop
    //      op = 0100: finish; stop simulation

    always_comb case(addr_i)
        // Wait 3 cycles
        0: data_o = {4'b0000, 32'h0000_0000};
        1: data_o = {4'b0000, 32'h0000_0000};
        2: data_o = {4'b0000, 32'h0000_0000};

        // Send test data
        3: data_o = {4'b0001, 32'hDEAD_BEEF};
        4: data_o = {4'b0001, 32'hCAFE_BABE};
        5: data_o = {4'b0001, 32'h1234_5678};
        6: data_o = {4'b0001, 32'hAAAA_AAAA};

        // Done; disable but do not stop simulation
        7: data_o = {4'b0011, 32'h0000_0000};

        default: data_o = {4'b0000, 32'h0000_0000};
    endcase

endmodule // tx_trace_rom