module AES_DECRYPT (
  input              clk,
  input              rst_n,
  input              start,
  input      [1:0]   keylen,        // 00=128, 01=192, 10=256
  input      [255:0] key_in,
  input      [127:0] ciphertext,
  output reg         busy,
  output reg         plaintext_valid,
  output reg [127:0] plaintext
);

  reg [3:0] Nr;
  always @(*) begin
    case (keylen)
      2'b00: Nr = 4'd10;
      2'b01: Nr = 4'd12;
      2'b10: Nr = 4'd14;
      default: Nr = 4'd14;
    endcase
  end

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

  reg [127:0] rk_mem [0:14];
  reg [14:0]  got_key;

  reg [14:0] req_mask;
  always @(*) begin
    case (Nr)
      4'd10: req_mask = 15'b000_0111_1111_1111; // 0..10
      4'd12: req_mask = 15'b001_1111_1111_1111; // 0..12
      default: req_mask = 15'b111_1111_1111_1111; // 0..14
    endcase
  end
  wire all_keys_ready = ((got_key & req_mask) == req_mask);

  reg [127:0] state;
  reg [3:0]   round;   // counts down Nr-1 .. 0
  reg [1:0]   phase;

  reg [31:0] core_buf0, core_buf1, core_buf2;

  // unpack 
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

  // InvShiftRows select 1 col
  reg [7:0] in_r0, in_r1, in_r2, in_r3;
  always @(*) begin
    case (phase)
      2'd0: begin in_r0=b00; in_r1=b13; in_r2=b22; in_r3=b31; end
      2'd1: begin in_r0=b01; in_r1=b10; in_r2=b23; in_r3=b32; end
      2'd2: begin in_r0=b02; in_r1=b11; in_r2=b20; in_r3=b33; end
      default: begin in_r0=b03; in_r1=b12; in_r2=b21; in_r3=b30; end
    endcase
  end

  wire [7:0] ib_r0, ib_r1, ib_r2, ib_r3;
  AES_INVSBOX u_isb0(.inv_in(in_r0), .inv_out(ib_r0));
  AES_INVSBOX u_isb1(.inv_in(in_r1), .inv_out(ib_r1));
  AES_INVSBOX u_isb2(.inv_in(in_r2), .inv_out(ib_r2));
  AES_INVSBOX u_isb3(.inv_in(in_r3), .inv_out(ib_r3));

  wire [31:0] col_ss = {ib_r0, ib_r1, ib_r2, ib_r3};

  
  wire [31:0] rk_col =
    (phase == 2'd0) ? rk_mem[round][127:96] :
    (phase == 2'd1) ? rk_mem[round][95:64]  :
    (phase == 2'd2) ? rk_mem[round][63:32]  :
                      rk_mem[round][31:0];


  wire [31:0] col_ark = col_ss ^ rk_col;

  wire [31:0] col_invmix;
  AES_INVMIXCOL u_invmixcol(.in_col(col_ark), .out_col(col_invmix));

  wire [31:0] col_out = (round == 4'd0) ? col_ark : col_invmix;

  localparam ST_IDLE   = 2'd0;
  localparam ST_KEYEXP = 2'd1;
  localparam ST_CORE   = 2'd2;
  reg [1:0] st, st_n;

  integer i;

  always @(*) begin
    st_n = st;
    case (st)
      ST_IDLE: begin
        if (start) st_n = ST_KEYEXP;
      end

      ST_KEYEXP: begin
        if (all_keys_ready) st_n = ST_CORE;
      end

      ST_CORE: begin
        if (phase == 2'd3) begin
          if (round == 4'd0) st_n = ST_IDLE;
          else               st_n = ST_CORE;
        end
      end

      default: st_n = ST_IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= ST_IDLE;
      busy <= 1'b0;
      keyexp_start <= 1'b0;
      plaintext_valid <= 1'b0;
      plaintext <= 128'd0;

      state <= 128'd0;
      round <= 4'd0;
      phase <= 2'd0;

      core_buf0 <= 32'd0;
      core_buf1 <= 32'd0;
      core_buf2 <= 32'd0;

      got_key <= 15'd0;
      for (i=0;i<15;i=i+1) rk_mem[i] <= 128'd0;

    end else begin
      st <= st_n;

      plaintext_valid <= 1'b0;
      keyexp_start <= 1'b0;

      if (rk_valid) begin
        rk_mem[rk_idx] <= rk;
        got_key[rk_idx] <= 1'b1;
      end

      case (st)
        ST_IDLE: begin
          busy <= 1'b0;
          if (start) begin
            busy <= 1'b1;
            got_key <= 15'd0;
            phase <= 2'd0;
            keyexp_start <= 1'b1;
          end
        end

        ST_KEYEXP: begin
          if (all_keys_ready) begin
            state <= (ciphertext ^ rk_mem[Nr]); // initial with K[Nr]
            round <= Nr - 4'd1;
            phase <= 2'd0;
          end
        end

        ST_CORE: begin
          case (phase)
            2'd0: core_buf0 <= col_out;
            2'd1: core_buf1 <= col_out;
            2'd2: core_buf2 <= col_out;
            default: begin end
          endcase

          if (phase == 2'd3) begin
            state <= {core_buf0, core_buf1, core_buf2, col_out};

            if (round == 4'd0) begin
              plaintext <= {core_buf0, core_buf1, core_buf2, col_out};
              plaintext_valid <= 1'b1;
              busy <= 1'b0;
            end else begin
              round <= round - 4'd1;
              phase <= 2'd0;
            end
          end else begin
            phase <= phase + 2'd1;
          end
        end

        default: ;
      endcase
    end
  end

endmodule
