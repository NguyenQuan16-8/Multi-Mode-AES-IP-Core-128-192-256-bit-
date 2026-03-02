module mul2 (
    input  wire [7:0] mul2_in,
    output reg  [7:0] mul2_out
);
always @(*) begin
    if (mul2_in[7] == 1'b1)
        mul2_out = {mul2_in[6:0], 1'b0} ^ 8'h1B;
    else
        mul2_out = {mul2_in[6:0], 1'b0};
end
endmodule
