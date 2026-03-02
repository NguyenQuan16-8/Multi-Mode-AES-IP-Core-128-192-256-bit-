module AES_RCON (
    input       [3:0] rkey,
    output  reg [31:0] rcon
);
always @(*) begin
    case (rkey)
        4'd1:   rcon = 32'h01000000;
        4'd2:   rcon = 32'h02000000;
        4'd3:   rcon = 32'h04000000;
        4'd4:   rcon = 32'h08000000;
        4'd5:   rcon = 32'h10000000;
        4'd6:   rcon = 32'h20000000;
        4'd7:   rcon = 32'h40000000;
        4'd8:   rcon = 32'h80000000;
        4'd9:   rcon = 32'h1b000000;
        4'd10 : rcon = 32'h36000000; 
        default: rcon = 32'h00000000;
    endcase
end
endmodule