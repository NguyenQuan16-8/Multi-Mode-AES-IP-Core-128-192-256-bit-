module AES_ENCRYPT (
  input              clk,
  input              rst_n,

  input              start,
  input      [1:0]   keylen,        // 00=128, 01=192, 10=256
  input      [255:0] key_in,
  input      [127:0] plaintext,

  output reg         busy,
  output reg         ciphertext_valid,
  output reg [127:0] ciphertext
);

  // Nr from keylen
  reg [3:0] Nr;
  always @(*) begin
    case (keylen)
      2'b00: Nr = 4'd10;
      2'b01: Nr = 4'd12;
      2'b10: Nr = 4'd14;
      default: Nr = 4'd14;
    endcase
  end

  // KEYEXP
  reg keyexp_start;

  wire        rk_valid;
  wire [127:0] rk;
  wire [3:0]  rk_idx;
  wire        keyexp_busy;

  AES_KEYEXP u_keyexp (
    .clk(clk),
    .rst_n(rst_n),
    .start(keyexp_start),
    .keylen(keylen),
    .key_in(key_in),
    .rk_valid(rk_valid),
    .rk_out(rk),
    .rk_idx(rk_idx),
    .busy(keyexp_busy)
  );

  // AES state + round/phase
  reg [127:0] state;   // state after AddRoundKey
  reg [3:0]   round;   // 1..Nr (round key index to apply after core)
  reg [1:0]   phase;   // 0..3 (build 4 columns per round)

  // buffer for 4 columns of core_out
  reg [31:0] core_buf0, core_buf1, core_buf2, core_buf3;

  wire [127:0] core_out = {core_buf0, core_buf1, core_buf2, core_buf3};

  // RoundKey0 pack 
  wire [127:0] rk0_pack = {key_in[ 31:  0], key_in[ 63: 32], key_in[ 95: 64], key_in[127: 96]};

  // Unpack state bytes (column-major)
  wire [7:0] b00 = state[127:120];
  wire [7:0] b10 = state[119:112];
  wire [7:0] b20 = state[111:104];
  wire [7:0] b30 = state[103: 96];

  wire [7:0] b01 = state[ 95: 88];
  wire [7:0] b11 = state[ 87: 80];
  wire [7:0] b21 = state[ 79: 72];
  wire [7:0] b31 = state[ 71: 64];

  wire [7:0] b02 = state[ 63: 56];
  wire [7:0] b12 = state[ 55: 48];
  wire [7:0] b22 = state[ 47: 40];
  wire [7:0] b32 = state[ 39: 32];

  wire [7:0] b03 = state[ 31: 24];
  wire [7:0] b13 = state[ 23: 16];
  wire [7:0] b23 = state[ 15:  8];
  wire [7:0] b33 = state[  7:  0];

  // ShiftRow
  reg [7:0] in_r0, in_r1, in_r2, in_r3;

  always @(*) begin
    case (phase)
      2'd0: begin
        in_r0 = b00; in_r1 = b11; in_r2 = b22; in_r3 = b33;
      end
      2'd1: begin
        in_r0 = b01; in_r1 = b12; in_r2 = b23; in_r3 = b30;
      end
      2'd2: begin
        in_r0 = b02; in_r1 = b13; in_r2 = b20; in_r3 = b31;
      end
      default: begin // 2'd3
        in_r0 = b03; in_r1 = b10; in_r2 = b21; in_r3 = b32;
      end
    endcase
  end

  // 4 S-box (SubBytes)
  wire [7:0] sb_r0, sb_r1, sb_r2, sb_r3;

  AES_SBOX u_sb0(.sbox_in(in_r0), .sbox_out(sb_r0));
  AES_SBOX u_sb1(.sbox_in(in_r1), .sbox_out(sb_r1));
  AES_SBOX u_sb2(.sbox_in(in_r2), .sbox_out(sb_r2));
  AES_SBOX u_sb3(.sbox_in(in_r3), .sbox_out(sb_r3));

  wire [31:0] col_subshift = {sb_r0, sb_r1, sb_r2, sb_r3};

  // MixColumns 
  wire [31:0] col_mixed;
  AES_MIXCOL u_mixcol (
    .in_col(col_subshift),
    .out_col(col_mixed)
  );

  wire is_final_round = (round == Nr);
  wire [31:0] col_core = is_final_round ? col_subshift : col_mixed;

  // FSM
  localparam ST_IDLE   = 2'd0;
  localparam ST_CORE   = 2'd1; // 4 cycles build core_out
  localparam ST_ADDROUNDKEY = 2'd2; //  AddRoundKey

  reg [1:0] st, st_n;

  always @(*) begin
    st_n = st;
    case (st)
      ST_IDLE: begin
        if (start) st_n = ST_CORE;
      end

      ST_CORE: begin
        if (phase == 2'd3) begin
          if (rk_valid && (rk_idx == round)) begin
            if (round == Nr) st_n = ST_IDLE;
            else             st_n = ST_CORE;
          end else begin
            st_n = ST_ADDROUNDKEY;
          end
        end
      end

      ST_ADDROUNDKEY: begin
        if (rk_valid && (rk_idx == round)) begin
          if (round == Nr) st_n = ST_IDLE;
          else             st_n = ST_CORE;
        end
      end

      default: st_n = ST_IDLE;
    endcase
  end

  // Sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= ST_IDLE;
      busy <= 1'b0;
      keyexp_start <= 1'b0;

      state <= 128'd0;
      round <= 4'd0;
      phase <= 2'd0;

      core_buf0 <= 32'd0;
      core_buf1 <= 32'd0;
      core_buf2 <= 32'd0;
      core_buf3 <= 32'd0;

      ciphertext <= 128'd0;
      ciphertext_valid <= 1'b0;

    end else begin
      st <= st_n;

      ciphertext_valid <= 1'b0;
      keyexp_start <= 1'b0;

      case (st)
        ST_IDLE: begin
          busy <= 1'b0;
          if (start) begin
            busy <= 1'b1;
            keyexp_start <= 1'b1;

            // AddRoundKey0 ngay lập tức
            state <= (plaintext ^ rk0_pack);

            round <= 4'd1;
            phase <= 2'd0;
          end
        end

        ST_CORE: begin
          // store current column
          case (phase)
            2'd0: core_buf0 <= col_core;
            2'd1: core_buf1 <= col_core;
            2'd2: core_buf2 <= col_core;
            default: core_buf3 <= col_core; // phase=3
          endcase

          if (phase == 2'd3) begin
            if (rk_valid && (rk_idx == round)) begin
              state <= ({core_buf0, core_buf1, core_buf2, col_core} ^ rk);

              if (round == Nr) begin
                ciphertext <= ({core_buf0, core_buf1, core_buf2, col_core} ^ rk);
                ciphertext_valid <= 1'b1;
                busy <= 1'b0;
              end else begin
                round <= round + 4'd1;
                phase <= 2'd0;
              end
            end else begin
              phase <= 2'd0;
            end
          end else begin
            phase <= phase + 2'd1;
          end
        end

        // Wait for rk(round), then AddRoundKey
        ST_ADDROUNDKEY: begin
          if (rk_valid && (rk_idx == round)) begin
            state <= (core_out ^ rk);

            if (round == Nr) begin
              ciphertext <= (core_out ^ rk);
              ciphertext_valid <= 1'b1;
              busy <= 1'b0;
            end else begin
              round <= round + 4'd1;
              phase <= 2'd0;
            end
          end
        end

        default: ;
      endcase
    end
  end

endmodule
