module AES_INVMIXCOL(
  input  wire [31:0] in_col,
  output wire [31:0] out_col
);
  wire [7:0] s0 = in_col[31:24];
  wire [7:0] s1 = in_col[23:16];
  wire [7:0] s2 = in_col[15:8];
  wire [7:0] s3 = in_col[7:0];

  // compute x2, x4, x8 for each byte using mul2 
  wire [7:0] s0_2, s0_4, s0_8;
  wire [7:0] s1_2, s1_4, s1_8;
  wire [7:0] s2_2, s2_4, s2_8;
  wire [7:0] s3_2, s3_4, s3_8;

  // s0
  mul2 u0_2 (.mul2_in(s0),    .mul2_out(s0_2));
  mul2 u0_4 (.mul2_in(s0_2),  .mul2_out(s0_4));
  mul2 u0_8 (.mul2_in(s0_4),  .mul2_out(s0_8));

  // s1
  mul2 u1_2 (.mul2_in(s1),    .mul2_out(s1_2));
  mul2 u1_4 (.mul2_in(s1_2),  .mul2_out(s1_4));
  mul2 u1_8 (.mul2_in(s1_4),  .mul2_out(s1_8));

  // s2
  mul2 u2_2 (.mul2_in(s2),    .mul2_out(s2_2));
  mul2 u2_4 (.mul2_in(s2_2),  .mul2_out(s2_4));
  mul2 u2_8 (.mul2_in(s2_4),  .mul2_out(s2_8));

  // s3
  mul2 u3_2 (.mul2_in(s3),    .mul2_out(s3_2));
  mul2 u3_4 (.mul2_in(s3_2),  .mul2_out(s3_4));
  mul2 u3_8 (.mul2_in(s3_4),  .mul2_out(s3_8));

  // 09 = 8 ^ 1
  wire [7:0] s0_09 = s0_8 ^ s0;
  wire [7:0] s1_09 = s1_8 ^ s1;
  wire [7:0] s2_09 = s2_8 ^ s2;
  wire [7:0] s3_09 = s3_8 ^ s3;

  // 0B = 8 ^ 2 ^ 1
  wire [7:0] s0_0B = s0_8 ^ s0_2 ^ s0;
  wire [7:0] s1_0B = s1_8 ^ s1_2 ^ s1;
  wire [7:0] s2_0B = s2_8 ^ s2_2 ^ s2;
  wire [7:0] s3_0B = s3_8 ^ s3_2 ^ s3;

  // 0D = 8 ^ 4 ^ 1
  wire [7:0] s0_0D = s0_8 ^ s0_4 ^ s0;
  wire [7:0] s1_0D = s1_8 ^ s1_4 ^ s1;
  wire [7:0] s2_0D = s2_8 ^ s2_4 ^ s2;
  wire [7:0] s3_0D = s3_8 ^ s3_4 ^ s3;

  // 0E = 8 ^ 4 ^ 2
  wire [7:0] s0_0E = s0_8 ^ s0_4 ^ s0_2;
  wire [7:0] s1_0E = s1_8 ^ s1_4 ^ s1_2;
  wire [7:0] s2_0E = s2_8 ^ s2_4 ^ s2_2;
  wire [7:0] s3_0E = s3_8 ^ s3_4 ^ s3_2;

  // InvMixColumns matrix
  // [0e 0b 0d 09]
  // [09 0e 0b 0d]
  // [0d 09 0e 0b]
  // [0b 0d 09 0e]
  wire [7:0] o0 = s0_0E ^ s1_0B ^ s2_0D ^ s3_09;
  wire [7:0] o1 = s0_09 ^ s1_0E ^ s2_0B ^ s3_0D;
  wire [7:0] o2 = s0_0D ^ s1_09 ^ s2_0E ^ s3_0B;
  wire [7:0] o3 = s0_0B ^ s1_0D ^ s2_09 ^ s3_0E;

  assign out_col = {o0, o1, o2, o3};

endmodule
