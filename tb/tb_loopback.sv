`timescale 1ns/1ps

module tb_AES_LOOPBACK_RAND;

  reg clk;
  reg rst_n;

  // ENCRYPT
  reg          start_enc;
  reg  [1:0]   keylen;
  reg  [255:0] key_in;
  reg  [127:0] plaintext_in;

  wire         enc_busy;
  wire         ciphertext_valid;
  wire [127:0] ciphertext_out;

  AES_ENCRYPT u_enc (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_enc),
    .keylen(keylen),
    .key_in(key_in),
    .plaintext(plaintext_in),
    .busy(enc_busy),
    .ciphertext_valid(ciphertext_valid),
    .ciphertext(ciphertext_out)
  );

  // DECRYPT
  reg          start_dec;
  reg  [127:0] ciphertext_in;

  wire         dec_busy;
  wire         plaintext_valid;
  wire [127:0] plaintext_out;

  AES_DECRYPT u_dec (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_dec),
    .keylen(keylen),
    .key_in(key_in),
    .ciphertext(ciphertext_in),
    .busy(dec_busy),
    .plaintext_valid(plaintext_valid),
    .plaintext(plaintext_out)
  );

  // clock 100MHz
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  integer errors;

  // pulse start "safe"
  task pulse_start_enc;
    begin
      @(negedge clk);
      start_enc = 1'b1;
      @(posedge clk);
      @(negedge clk);
      start_enc = 1'b0;
    end
  endtask

  task pulse_start_dec;
    begin
      @(negedge clk);
      start_dec = 1'b1;
      @(posedge clk);
      @(negedge clk);
      start_dec = 1'b0;
    end
  endtask

  // wait valid with timeout
  task wait_ct_valid_timeout;
    input integer max_cycles;
    integer k;
    begin
      for (k = 0; k < max_cycles; k = k + 1) begin
        if (ciphertext_valid === 1'b1) disable wait_ct_valid_timeout;
        @(posedge clk);
      end
      $display("** TIMEOUT ** waiting ciphertext_valid after %0d cycles", max_cycles);
      $finish;
    end
  endtask

  task wait_pt_valid_timeout;
    input integer max_cycles;
    integer k;
    begin
      for (k = 0; k < max_cycles; k = k + 1) begin
        if (plaintext_valid === 1'b1) disable wait_pt_valid_timeout;
        @(posedge clk);
      end
      $display("** TIMEOUT ** waiting plaintext_valid after %0d cycles", max_cycles);
      $finish;
    end
  endtask

  // Random helpers
  integer seed;

  function [127:0] rand128;
    reg [31:0] a,b,c,d;
    begin
      a = $random(seed);
      b = $random(seed);
      c = $random(seed);
      d = $random(seed);
      rand128 = {a,b,c,d};
    end
  endfunction

  function [255:0] rand_key_for_len;
    input [1:0] kl;
    reg [255:0] k;
    reg [31:0] w0,w1,w2,w3,w4,w5,w6,w7;
    begin
      w0 = $random(seed);
      w1 = $random(seed);
      w2 = $random(seed);
      w3 = $random(seed);
      w4 = $random(seed);
      w5 = $random(seed);
      w6 = $random(seed);
      w7 = $random(seed);

      // pack: {w7,w6,w5,w4,w3,w2,w1,w0}
      case (kl)
        2'b00: k = {32'h0,32'h0,32'h0,32'h0, w3,w2,w1,w0}; // AES-128
        2'b01: k = {32'h0,32'h0, w5,w4, w3,w2,w1,w0};      // AES-192
        default: k = {w7,w6,w5,w4,w3,w2,w1,w0};            // AES-256
      endcase

      rand_key_for_len = k;
    end
  endfunction

  // Pretty name for keylen
  function [8*7-1:0] kl_name; // "AES-128" etc (7 chars)
    input [1:0] kl;
    begin
      case (kl)
        2'b00: kl_name = "AES-128";
        2'b01: kl_name = "AES-192";
        default: kl_name = "AES-256";
      endcase
    end
  endfunction

  // One loopback case (PRINT CLEAR)
  task run_one;
    input [1:0]   kl;
    input integer idx;
    reg [127:0] p;
    reg [255:0] k;
    reg [127:0] c;
    reg [127:0] p_dec;
    begin
      // randomize inputs
      p = rand128();
      k = rand_key_for_len(kl);

      keylen        = kl;
      key_in        = k;
      plaintext_in  = p;

      // Header for this case
      $display("\n------------------------------------------------------------");
      $display("[CASE] %s  idx=%0d  time=%0t", kl_name(kl), idx, $time);
      $display("  KEY_in (ENC/DEC) = %h", k);
      $display("  PT_in  (ENC)     = %h", p);

      // ENCRYPT
      pulse_start_enc();
      wait_ct_valid_timeout(300000);
      c = ciphertext_out;

      $display("  CT_out (ENC)     = %h", c);

      // DECRYPT
      ciphertext_in = c;
      $display("  CT_in  (DEC)     = %h", ciphertext_in);

      pulse_start_dec();
      wait_pt_valid_timeout(400000);
      p_dec = plaintext_out;

      $display("  PT_out (DEC)     = %h", p_dec);

      if (p_dec !== p) begin
        errors = errors + 1;
        $display("  ==> RESULT: **FAIL** (expected PT=%h)", p);
      end else begin
        $display("  ==> RESULT: PASS");
      end

      // small gap
      repeat (5) @(posedge clk);
    end
  endtask

  integer i;

  initial begin
    errors       = 0;
    seed         = 32'hC0FFEE;

    start_enc    = 0;
    start_dec    = 0;
    keylen       = 0;
    key_in       = 0;
    plaintext_in = 0;
    ciphertext_in= 0;

    // reset
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // AES-128
    $display("\n=== LOOPBACK RANDOM AES-128 (20 cases) ===");
    for (i=0; i<20; i=i+1) run_one(2'b00, i);

    // AES-192
    $display("\n=== LOOPBACK RANDOM AES-192 (20 cases) ===");
    for (i=0; i<20; i=i+1) run_one(2'b01, i);

    // AES-256
    $display("\n=== LOOPBACK RANDOM AES-256 (20 cases) ===");
    for (i=0; i<20; i=i+1) run_one(2'b10, i);

    $display("\n======================");
    if (errors == 0) $display("ALL RANDOM LOOPBACK TESTS PASS");
    else            $display("RANDOM LOOPBACK FAIL: errors=%0d", errors);
    $display("======================\n");

    #20;
    $finish;
  end

endmodule
