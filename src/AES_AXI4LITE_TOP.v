module AES_AXI4LITE_TOP (
  input  wire         s_axi_clk,
  input  wire         s_axi_arst_n,

  // Write Address
  input  wire [7:0]   s_axi_awaddr,
  input  wire         s_axi_awvalid,
  output reg          s_axi_awready,

  // Write Data
  input  wire [31:0]  s_axi_wdata,
  input  wire [3:0]   s_axi_wstrb,
  input  wire         s_axi_wvalid,
  output reg          s_axi_wready,

  // Write Response
  output reg  [1:0]   s_axi_bresp,
  output reg          s_axi_bvalid,
  input  wire         s_axi_bready,

  // Read Address
  input  wire [7:0]   s_axi_araddr,
  input  wire         s_axi_arvalid,
  output reg          s_axi_arready,

  // Read Data
  output reg  [31:0]  s_axi_rdata,
  output reg  [1:0]   s_axi_rresp,
  output reg          s_axi_rvalid,
  input  wire         s_axi_rready
);

  // REGISTERS
  reg        mode;        // 0=enc, 1=dec
  reg [1:0]  keylen_reg;
  reg        start_pulse; // 1-cycle
  reg        done_sticky;

  reg [31:0] KEY0,KEY1,KEY2,KEY3,KEY4,KEY5,KEY6,KEY7;
  reg [31:0] DIN0,DIN1,DIN2,DIN3;

  reg [31:0] DOUT0,DOUT1,DOUT2,DOUT3;

  wire [255:0] key_in  = {KEY7,KEY6,KEY5,KEY4,KEY3,KEY2,KEY1,KEY0};
  wire [127:0] data_in = {DIN3,DIN2,DIN1,DIN0};

  // AES cores
  wire enc_busy, enc_valid;
  wire [127:0] enc_ct;

  wire dec_busy, dec_valid;
  wire [127:0] dec_pt;

  wire start_enc = start_pulse & ~mode;
  wire start_dec = start_pulse &  mode;

  AES_ENCRYPT u_enc (
    .clk(s_axi_clk),
    .rst_n(s_axi_arst_n),
    .start(start_enc),
    .keylen(keylen_reg),
    .key_in(key_in),
    .plaintext(data_in),
    .busy(enc_busy),
    .ciphertext_valid(enc_valid),
    .ciphertext(enc_ct)
  );

  AES_DECRYPT u_dec (
    .clk(s_axi_clk),
    .rst_n(s_axi_arst_n),
    .start(start_dec),
    .keylen(keylen_reg),
    .key_in(key_in),
    .ciphertext(data_in),
    .busy(dec_busy),
    .plaintext_valid(dec_valid),
    .plaintext(dec_pt)
  );

  wire busy       = mode ? dec_busy  : enc_busy;
  wire done_pulse = mode ? dec_valid : enc_valid;

  reg start_cmd;
  reg clear_done_cmd;

  always @(posedge s_axi_clk or negedge s_axi_arst_n) begin
    if (!s_axi_arst_n) begin
      start_pulse <= 1'b0;
      done_sticky <= 1'b0;
    end else begin
      start_pulse <= 1'b0; // 1-cycle pulse

      if (done_pulse) done_sticky <= 1'b1;
      if (clear_done_cmd) done_sticky <= 1'b0;

      if (start_cmd && !busy) begin
        start_pulse <= 1'b1;
        done_sticky <= 1'b0;
      end
    end
  end

  // Latch output data on done_pulse
  always @(posedge s_axi_clk or negedge s_axi_arst_n) begin
    if (!s_axi_arst_n) begin
      DOUT0 <= 0; DOUT1 <= 0; DOUT2 <= 0; DOUT3 <= 0;
    end else begin
      if (done_pulse) begin
        if (!mode) begin
          DOUT0 <= enc_ct[31:0];
          DOUT1 <= enc_ct[63:32];
          DOUT2 <= enc_ct[95:64];
          DOUT3 <= enc_ct[127:96];
        end else begin
          DOUT0 <= dec_pt[31:0];
          DOUT1 <= dec_pt[63:32];
          DOUT2 <= dec_pt[95:64];
          DOUT3 <= dec_pt[127:96];
        end
      end
    end
  end

  // WSTRB apply
  task apply_wstrb32;
    inout reg [31:0] target;
    input [31:0]     wdata;
    input [3:0]      wstrb;
    begin
      if (wstrb[0]) target[7:0]   = wdata[7:0];
      if (wstrb[1]) target[15:8]  = wdata[15:8];
      if (wstrb[2]) target[23:16] = wdata[23:16];
      if (wstrb[3]) target[31:24] = wdata[31:24];
    end
  endtask


  reg [31:0] ctrl_merge;

  always @(posedge s_axi_clk or negedge s_axi_arst_n) begin
    if (!s_axi_arst_n) begin
      s_axi_awready <= 1'b0;
      s_axi_wready  <= 1'b0;
      s_axi_bvalid  <= 1'b0;
      s_axi_bresp   <= 2'b00;

      mode <= 1'b0;
      keylen_reg <= 2'b00;

      KEY0<=0;KEY1<=0;KEY2<=0;KEY3<=0;KEY4<=0;KEY5<=0;KEY6<=0;KEY7<=0;
      DIN0<=0;DIN1<=0;DIN2<=0;DIN3<=0;

      start_cmd <= 1'b0;
      clear_done_cmd <= 1'b0;

      ctrl_merge <= 32'd0;

    end else begin
      // default command pulses
      start_cmd <= 1'b0;
      clear_done_cmd <= 1'b0;

      // ready when no pending B
      s_axi_awready <= ~s_axi_bvalid;
      s_axi_wready  <= ~s_axi_bvalid;

      // finish B
      if (s_axi_bvalid && s_axi_bready)
        s_axi_bvalid <= 1'b0;

      // do write when AW & W handshake in same cycle
      if (s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid) begin
        case (s_axi_awaddr)

          8'h00: begin
            // CTRL
            ctrl_merge = {30'd0, mode, 1'b0};
            if (s_axi_wstrb[0]) ctrl_merge[7:0]   = s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) ctrl_merge[15:8]  = s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) ctrl_merge[23:16] = s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) ctrl_merge[31:24] = s_axi_wdata[31:24];

            mode <= ctrl_merge[1];
            if (ctrl_merge[0]) start_cmd <= 1'b1;
          end

          8'h04: begin
            // STATUS: write 1 to bit1 (byte0) clears done
            if (s_axi_wstrb[0] && s_axi_wdata[1]) clear_done_cmd <= 1'b1;
          end

          8'h08: begin
            // KEYLEN bits[1:0] in byte0
            if (s_axi_wstrb[0]) keylen_reg <= s_axi_wdata[1:0];
          end

          8'h0C: apply_wstrb32(KEY0, s_axi_wdata, s_axi_wstrb);
          8'h10: apply_wstrb32(KEY1, s_axi_wdata, s_axi_wstrb);
          8'h14: apply_wstrb32(KEY2, s_axi_wdata, s_axi_wstrb);
          8'h18: apply_wstrb32(KEY3, s_axi_wdata, s_axi_wstrb);
          8'h1C: apply_wstrb32(KEY4, s_axi_wdata, s_axi_wstrb);
          8'h20: apply_wstrb32(KEY5, s_axi_wdata, s_axi_wstrb);
          8'h24: apply_wstrb32(KEY6, s_axi_wdata, s_axi_wstrb);
          8'h28: apply_wstrb32(KEY7, s_axi_wdata, s_axi_wstrb);

          8'h2C: apply_wstrb32(DIN0, s_axi_wdata, s_axi_wstrb);
          8'h30: apply_wstrb32(DIN1, s_axi_wdata, s_axi_wstrb);
          8'h34: apply_wstrb32(DIN2, s_axi_wdata, s_axi_wstrb);
          8'h38: apply_wstrb32(DIN3, s_axi_wdata, s_axi_wstrb);

          default: begin end
        endcase

        // write response
        s_axi_bvalid <= 1'b1;
        s_axi_bresp  <= 2'b00;
      end
    end
  end

  // AXI READ (simple, 1 outstanding)
  always @(posedge s_axi_clk or negedge s_axi_arst_n) begin
    if (!s_axi_arst_n) begin
      s_axi_arready <= 1'b0;
      s_axi_rvalid  <= 1'b0;
      s_axi_rresp   <= 2'b00;
      s_axi_rdata   <= 32'd0;
    end else begin
      s_axi_arready <= ~s_axi_rvalid;

      if (s_axi_arready && s_axi_arvalid) begin
        s_axi_rvalid <= 1'b1;
        s_axi_rresp  <= 2'b00;

        case (s_axi_araddr)
          8'h00: s_axi_rdata <= {30'd0, mode, 1'b0};
          8'h04: s_axi_rdata <= {30'd0, done_sticky, busy};
          8'h08: s_axi_rdata <= {30'd0, keylen_reg};

          8'h0C: s_axi_rdata <= KEY0;
          8'h10: s_axi_rdata <= KEY1;
          8'h14: s_axi_rdata <= KEY2;
          8'h18: s_axi_rdata <= KEY3;
          8'h1C: s_axi_rdata <= KEY4;
          8'h20: s_axi_rdata <= KEY5;
          8'h24: s_axi_rdata <= KEY6;
          8'h28: s_axi_rdata <= KEY7;

          8'h2C: s_axi_rdata <= DIN0;
          8'h30: s_axi_rdata <= DIN1;
          8'h34: s_axi_rdata <= DIN2;
          8'h38: s_axi_rdata <= DIN3;

          8'h3C: s_axi_rdata <= DOUT0;
          8'h40: s_axi_rdata <= DOUT1;
          8'h44: s_axi_rdata <= DOUT2;
          8'h48: s_axi_rdata <= DOUT3;

          default: s_axi_rdata <= 32'd0;
        endcase
      end

      if (s_axi_rvalid && s_axi_rready)
        s_axi_rvalid <= 1'b0;
    end
  end

endmodule
