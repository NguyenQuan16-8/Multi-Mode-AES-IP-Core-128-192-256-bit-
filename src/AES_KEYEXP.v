module AES_KEYEXP (
  input              clk,
  input              rst_n,

  input              start,
  input      [1:0]   keylen,       // 00=128, 01=192, 10=256
  input      [255:0] key_in,

  output reg         rk_valid,
  output reg [127:0] rk_out,
  output reg [3:0]   rk_idx,   // 0..Nr
  output reg         busy
);

  // Nk / Nr / total_words (COMB)
  reg  [3:0] Nk;
  reg  [3:0] Nr;
  reg  [6:0] total_words;
  reg  [3:0] Nk_minus1;

  always @* begin
    case (keylen)
      2'b00: begin Nk = 4'd4; Nr = 4'd10; total_words = 7'd44; end
      2'b01: begin Nk = 4'd6; Nr = 4'd12; total_words = 7'd52; end
      2'b10: begin Nk = 4'd8; Nr = 4'd14; total_words = 7'd60; end
      default: begin Nk = 4'd8; Nr = 4'd14; total_words = 7'd60; end
    endcase
    Nk_minus1 = Nk - 4'd1;
  end

  reg [3:0] Nk_r, Nr_r, Nk_minus1_r;
  reg [6:0] total_words_r;

  reg [31:0] window [0:7];

  reg [31:0] w_im1;
  always @* begin
    case (Nk_r)
      4'd4: w_im1 = window[3];
      4'd6: w_im1 = window[5];
      4'd8: w_im1 = window[7];
      default: w_im1 = window[7];
    endcase
  end

  wire [31:0] w_iNk = window[0];

  // Counters
  reg [6:0] word_i;     // index of word being generated (i)
  reg [3:0] nk_pos;     // i % Nk
  reg [3:0] rcon_idx;   // 1.. (increment when i%Nk==0)

  // RotWord / SubWord / Rcon
  wire do_core_g    = (nk_pos == 4'd0);
  wire do_256_extra = (Nk_r == 4'd8) && (nk_pos == 4'd4);

  wire [31:0] rot_im1 = {w_im1[23:0], w_im1[31:24]};

  reg  [31:0] subword_in;
  wire [7:0]  sb0, sb1, sb2, sb3;
  AES_SBOX u_sb0(.sbox_in(subword_in[31:24]), .sbox_out(sb0));
  AES_SBOX u_sb1(.sbox_in(subword_in[23:16]), .sbox_out(sb1));
  AES_SBOX u_sb2(.sbox_in(subword_in[15: 8]), .sbox_out(sb2));
  AES_SBOX u_sb3(.sbox_in(subword_in[ 7: 0]), .sbox_out(sb3));
  wire [31:0] subword_out = {sb0, sb1, sb2, sb3};

  wire [31:0] rcon_value;
  AES_RCON u_rcon(.rkey(rcon_idx), .rcon(rcon_value));

  reg [31:0] temp2;
  always @* begin
    subword_in = w_im1;
    temp2      = w_im1;

    if (do_core_g) begin
      subword_in = rot_im1;
      temp2      = subword_out ^ rcon_value;
    end else if (do_256_extra) begin
      subword_in = w_im1;
      temp2      = subword_out;
    end
  end

  wire [31:0] w_new = w_iNk ^ temp2;

  // RoundKey stream buffer (last 4 words)
  reg [31:0] rk_buf [0:3];

  wire [31:0] rk_next0 = rk_buf[1];
  wire [31:0] rk_next1 = rk_buf[2];
  wire [31:0] rk_next2 = rk_buf[3];
  wire [31:0] rk_next3 = w_new;

  wire [127:0] pack_next_rk = {rk_next0, rk_next1, rk_next2, rk_next3};

  // PRE_FEED
  reg [3:0]  pre_kidx;     // 4..Nk-1
  reg [31:0] pre_word;

  always @* begin
    case (pre_kidx)
      4: pre_word = key_in[159:128];
      5: pre_word = key_in[191:160];
      6: pre_word = key_in[223:192];
      default: pre_word = key_in[255:224];
    endcase
  end

  // FSM
  localparam ST_IDLE     = 2'd0;
  localparam ST_PRE_FEED = 2'd1;
  localparam ST_RUN      = 2'd2;

  reg [1:0] state, next_state;
  integer j;

  wire emit_rk = (word_i[1:0] == 2'b11);

  always @(*) begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (start) begin
          if (Nk == 4'd4) next_state = ST_RUN;
          else            next_state = ST_PRE_FEED;
        end
      end
      ST_PRE_FEED: begin
        if (pre_kidx == Nk_minus1_r) next_state = ST_RUN;
        else                         next_state = ST_PRE_FEED;
      end
      ST_RUN: begin
        if (word_i >= total_words_r) next_state = ST_IDLE;
        else                         next_state = ST_RUN;
      end

      default: next_state = ST_IDLE;
    endcase
  end

  // 2) STATE/DATAPATH REGISTERS
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;

      busy     <= 1'b0;
      rk_valid <= 1'b0;
      rk_out   <= 128'd0;
      rk_idx   <= 4'd0;

      Nk_r          <= 4'd0;
      Nr_r          <= 4'd0;
      total_words_r <= 7'd0;
      Nk_minus1_r   <= 4'd0;

      word_i   <= 7'd0;
      nk_pos   <= 4'd0;
      rcon_idx <= 4'd1;

      pre_kidx <= 4'd0;

      for (j=0; j<8; j=j+1) window[j] <= 32'd0;
      for (j=0; j<4; j=j+1) rk_buf[j] <= 32'd0;

    end else begin
      state <= next_state;

      // default pulse
      rk_valid <= 1'b0;

      case (state)

        // ST_IDLE: latch params, init buffers/counters, emit RK0
        ST_IDLE: begin
          busy <= 1'b0;

          if (start) begin
            busy <= 1'b1;

            // latch params
            Nk_r          <= Nk;
            Nr_r          <= Nr;
            total_words_r <= total_words;
            Nk_minus1_r   <= Nk_minus1;

            // init window from key_in
            window[0] <= key_in[ 31:  0];
            window[1] <= key_in[ 63: 32];
            window[2] <= key_in[ 95: 64];
            window[3] <= key_in[127: 96];
            window[4] <= key_in[159:128];
            window[5] <= key_in[191:160];
            window[6] <= key_in[223:192];
            window[7] <= key_in[255:224];

            // init rk_buf = w0..w3
            rk_buf[0] <= key_in[ 31:  0];
            rk_buf[1] <= key_in[ 63: 32];
            rk_buf[2] <= key_in[ 95: 64];
            rk_buf[3] <= key_in[127: 96];

            word_i   <= Nk;     // start generate from w[Nk]
            nk_pos   <= 4'd0;
            rcon_idx <= 4'd1;

            pre_kidx <= 4'd4;

            // Emit RK0 (round 0 key)
            rk_out   <= {key_in[ 31:  0], key_in[ 63: 32], key_in[ 95: 64], key_in[127: 96]};
            rk_idx   <= 4'd0;
            rk_valid <= 1'b1;
          end
        end

        // ST_PRE_FEED: for Nk=6 or 8, feed remaining key words into rk_buf
        ST_PRE_FEED: begin
          rk_buf[0] <= rk_buf[1];
          rk_buf[1] <= rk_buf[2];
          rk_buf[2] <= rk_buf[3];
          rk_buf[3] <= pre_word;

          // For AES-256: after loading w4..w7, emit RK1 = w4..w7
          if ((Nk_r == 4'd8) && (pre_kidx == 4'd7)) begin
            rk_out   <= {key_in[159:128], key_in[191:160], key_in[223:192], key_in[255:224]};
            rk_idx   <= 4'd1;
            rk_valid <= 1'b1;
          end

          // advance pre_kidx if staying in PRE_FEED
          if (next_state == ST_PRE_FEED) begin
            pre_kidx <= pre_kidx + 4'd1;
          end
        end

        // ST_RUN: generate words until total_words_r, emit rk every 4 words
        ST_RUN: begin
          if (word_i >= total_words_r) begin
            busy <= 1'b0;
          end else begin
            // keep busy
            busy <= 1'b1;

            // rk_buf shift push w_new
            rk_buf[0] <= rk_buf[1];
            rk_buf[1] <= rk_buf[2];
            rk_buf[2] <= rk_buf[3];
            rk_buf[3] <= w_new;

            // window shift push w_new (by Nk_r)
            if (Nk_r == 4'd4) begin
              window[0] <= window[1];
              window[1] <= window[2];
              window[2] <= window[3];
              window[3] <= w_new;
            end else if (Nk_r == 4'd6) begin
              window[0] <= window[1];
              window[1] <= window[2];
              window[2] <= window[3];
              window[3] <= window[4];
              window[4] <= window[5];
              window[5] <= w_new;
            end else begin
              window[0] <= window[1];
              window[1] <= window[2];
              window[2] <= window[3];
              window[3] <= window[4];
              window[4] <= window[5];
              window[5] <= window[6];
              window[6] <= window[7];
              window[7] <= w_new;
            end

            if (emit_rk) begin
              rk_out   <= pack_next_rk;
              rk_idx   <= word_i[6:2];   // round index
              rk_valid <= 1'b1;
            end

            word_i <= word_i + 7'd1;

            if (nk_pos == Nk_minus1_r) nk_pos <= 4'd0;
            else                       nk_pos <= nk_pos + 4'd1;

            if (nk_pos == 4'd0) rcon_idx <= rcon_idx + 4'd1;
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule
