/* 
 * bchang01 - I made this personal ROM module because we can make our own ROM and test that way
 * Currently, Tested regular operation, bigger operation, just negative a,
 * TODO: test just neg b, both negative, neg_weight for the last three, trigger metastability for weight loading sequence
 *       (done by changing weight while it is calculating), mac bypass testing, etc.
 */ 
module PE_test_ROM #(addr_width = 5, data_width = 47) (
    input  logic [addr_width-1 : 0] addr_i,
    output logic [data_width-1 : 0] data_o
);

    // data needs to be 


    // Formatting:
    // -  format:   <4 bit op> <packet>
    //      - op = 0000: wait one cycle
    //      - op = 0001: send
    //      - op = 0010: receive & check
    //      - op = 0011: done; disable but do not stop
    //      - op = 0100: finish; stop simulation
    //      - op = 0101: wait for cycle ctr to reach 0
    //      - op = 0110: set cycle ctr
    // -  packet: <valid> <b_is_weight> <mac_bypass> <8 bit A> <32 bit B>
    // Not sure if we want to use hex or decimal format though

    always_comb case(addr_i)
        // Wait 3 cycles
        0: data_o = {4'b0000, 1'b0, 1'b0, 1'b0, 8'h00, 32'h0000_0000};
        1: data_o = {4'b0000, 1'b0, 1'b0, 1'b0, 8'h00, 32'h0000_0000};
        2: data_o = {4'b0000, 1'b0, 1'b0, 1'b0, 8'h00, 32'h0000_0000};


        // load weight and wait a cycle (A=2 (useless), B = 3 (weight))
        3: data_o = {4'b0001, 1'b1, 1'b1, 1'b0, 8'd02, 32'd3};
        4: data_o = {4'b0000, 1'b0, 1'b0, 1'b0, 8'd00, 32'd0};
        // Compute (4*3)+4 (A = 4 (mul val), B = 4 (add val))
        5: data_o = {4'b0001, 1'b1, 1'b0, 1'b0, 8'd4, 32'd4};
        // Recv (A = 4 (must match prev A), B = 16 (out)
        6: data_o = {4'b0010, 1'b1, 1'b0, 1'b0, 8'd4, 32'd16};
        // Compute (20*3)+4 (A = 20 (mul val), B = 4 (add val))
        7: data_o = {4'b0001, 1'b1, 1'b0, 1'b0, 8'd20, 32'd4};
        // Recv (A = 20 (must match prev A), B = 64 (out)
        8: data_o = {4'b0010, 1'b1, 1'b0, 1'b0, 8'd20, 32'd64};

        
        // load weight and wait a cycle (A=27 (useless), B = 4 (weight))
        9: data_o = {4'b0001, 1'b1, 1'b1, 1'b0, 8'd27, 32'd4};
        10: data_o = {4'b0000, 1'b0, 1'b0, 1'b0, 8'd00, 32'd0};
        // Bigger test - Compute (19*4)+1024 (A = 8 (mul val), B = 1024 (add val))
        11: data_o = {4'b0001, 1'b1, 1'b0, 1'b0, 8'd19, 32'd1024};
        // Recv (A = 19 (must match prev A), B = 1100 (out)
        12: data_o = {4'b0010, 1'b1, 1'b0, 1'b0, 8'd19, 32'd1100};
        // Neg A - Compute (-4*4)+27 (A = -4 (mul val), B = 27 (add val))
        13: data_o = {4'b0001, 1'b1, 1'b0, 1'b0, ~8'd4 + 1'b1, 32'd27};
        // Recv (A = -4 (must match prev A), B = 9 (out)
        14: data_o = {4'b0010, 1'b1, 1'b0, 1'b0, ~8'd4 + 1'b1, 32'd11};
        // Neg B - Compute (5*4)-10
        15: data_o = {4'b0001,1'b1,1'b0,1'b0,8'd5,~32'd10+1'b1};
        16: data_o = {4'b0010,1'b1,1'b0,1'b0,8'd5,32'd10};
        // Both neg - compute (-5*4)-10
        17: data_o = {4'b0001,1'b1,1'b0,1'b0,~8'd5+1'b1,~32'd10+1'b1};
        18: data_o = {4'b0010,1'b1,1'b0,1'b0,~8'd5+1'b1,~32'd30+1'b1};

        // Load Negative weight and weight a cycle (A=8'hFF (useless), B = -2)
        19: data_o = {4'b0001,1'b1,1'b1,1'b0,8'hFF,~32'd2+1'b1};
        20: data_o = {4'b0000,1'b0,1'b0,1'b0,8'd0,32'd0};
        // (a+b positive) (4*-2)+20 = 12
        21: data_o = {4'b0001,1'b1,1'b0,1'b0,8'd4,32'd20};
        22: data_o = {4'b0010,1'b1,1'b0,1'b0,8'd4,32'd12};
        // (a negative) (-3*-2)+1 = 7
        23: data_o = {4'b0001,1'b1,1'b0,1'b0,~8'd3+1'b1,32'd1};
        24: data_o = {4'b0010,1'b1,1'b0,1'b0,~8'd3+1'b1,32'd7};
        // (b negative) (6*-2)+(-3) = -15
        25: data_o = {4'b0001,1'b1,1'b0,1'b0,8'd6,~32'd3+1'b1};
        26: data_o = {4'b0010,1'b1,1'b0,1'b0,8'd6,~32'd15+1'b1};
        // (both a+b negative) (8*-2)+(-10) = -26
        27: data_o = {4'b0001,1'b1,1'b0,1'b0,8'd8,~32'd10+1'b1};
        28: data_o = {4'b0010,1'b1,1'b0,1'b0,8'd8,~32'd26+1'b1};

        // bypass MAC, expect B directly
        29: data_o = {4'b0001,1'b1,1'b0,1'b1,8'd50,32'd123};
        30: data_o = {4'b0010,1'b1,1'b0,1'b0,8'd50,32'd123};

        // // Test changing weight mid compute - doesn't make sense since the PE finishes in a single cycle
        // // load weight = 5
        // 31: data_o = {4'b0001,1'b1,1'b1,1'b0,8'd0,32'd5};
        // 32: data_o = {4'b0000,1'b0,1'b0,1'b0,8'd0,32'd0};
        // // compute (10*5)+2 = 52
        // 33: data_o = {4'b0001,1'b1,1'b0,1'b0,8'd10,32'd2};
        // // change weight to 7 while it calculates
        // 34: data_o = {4'b0001,1'b1,1'b1,1'b0,8'd0,32'd7};
        // // receive expected from first op (because weight should be still registered)
        // 35: data_o = {4'b0010,1'b1,1'b0,1'b0,8'd10,32'd52};
                
        
        


        // Finish simulation
        31: data_o = {4'b0100, 1'b0, 1'b0, 1'b0, 8'h00, 32'h0000_0000};
        default: data_o = 'X;
    endcase
endmodule // PE_test_ROM