// rx_trace_rom.sv
//
// ROM for fpga_receiver_trace_replay.
// Receives and checks data returning on the FPGA c2f path after
// loopback through the chip.  Calls $finish after all checks pass.

module rx_trace_rom #(
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

        // Receive & check test data (must match tx_trace_rom send order)
        3: data_o = {4'b0010, 32'hDEAD_BEEF};
        4: data_o = {4'b0010, 32'hCAFE_BABE};
        5: data_o = {4'b0010, 32'h1234_5678};
        6: data_o = {4'b0010, 32'hAAAA_AAAA};

        // Finish; stop simulation
        7: data_o = {4'b0100, 32'h0000_0000};

        default: data_o = {4'b0000, 32'h0000_0000};
    endcase

endmodule // rx_trace_rom