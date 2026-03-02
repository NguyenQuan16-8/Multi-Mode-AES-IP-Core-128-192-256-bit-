`timescale 1ns/1ps

module tb_AES_DECRYPT;

  reg          clk;
  reg          rst_n;

  reg          start;
  reg  [1:0]   keylen;
  reg  [255:0] key_in;
  reg  [127:0] ciphertext;

  wire         busy;
  wire         plaintext_valid;
  wire [127:0] plaintext;

  AES_DECRYPT dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .keylen(keylen),
    .key_in(key_in),
    .ciphertext(ciphertext),
    .busy(busy),
    .plaintext_valid(plaintext_valid),
    .plaintext(plaintext)
  );

  // clock 100MHz
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  integer errors;

  wire         rk_valid  = dut.rk_valid;
  wire [3:0]   rk_idx  = dut.rk_idx;
  wire [127:0] rk       = dut.rk;

  wire [1:0]   st_dbg    = dut.st;
  wire [3:0]   round_dbg = dut.round;
  wire [1:0]   phase_dbg = dut.phase;

  task pulse_start;
    begin
      @(negedge clk);
      start = 1'b1;
      @(posedge clk);
      @(negedge clk);
      start = 1'b0;
    end
  endtask

  task wait_valid_timeout;
    input integer max_cycles;
    integer k;
    begin
      for (k = 0; k < max_cycles; k = k + 1) begin
        if (plaintext_valid === 1'b1) begin
          disable wait_valid_timeout;
        end
        @(posedge clk);
      end
      $display("** TIMEOUT ** waiting plaintext_valid after %0d cycles", max_cycles);
      $display("Last: start=%b busy=%b st=%0d round=%0d phase=%0d rk_valid=%b rk_idx=%0d",
               start, busy, st_dbg, round_dbg, phase_dbg, rk_valid, rk_idx);
      $finish;
    end
  endtask

  // wait busy deassert with timeout
  task wait_not_busy_timeout;
    input integer max_cycles;
    integer k;
    begin
      for (k = 0; k < max_cycles; k = k + 1) begin
        if (busy === 1'b0) begin
          disable wait_not_busy_timeout;
        end
        @(posedge clk);
      end
      $display("** TIMEOUT ** busy stuck high after %0d cycles", max_cycles);
      $display("Last: start=%b busy=%b st=%0d round=%0d phase=%0d rk_valid=%b rk_idx=%0d",
               start, busy, st_dbg, round_dbg, phase_dbg, rk_valid, rk_idx);
      $finish;
    end
  endtask


  task show_state;
    input [1:0] st;
    begin
      case (st)
        2'd0: $write("IDLE  ");
        2'd1: $write("KEYEXP");
        2'd2: $write("CORE  ");
        default: $write("UNK  ");
      endcase
    end
  endtask

  // Cycle-by-cycle log
  always @(posedge clk) begin
    if (!rst_n) begin
      // no log during reset
    end else begin
      if (start || busy || rk_valid || plaintext_valid) begin
        $write("[%0t] ", $time);
        $write("start=%b busy=%b ", start, busy);
        $write("st="); show_state(st_dbg);
        $write(" round=%0d phase=%0d ", round_dbg, phase_dbg);

        if (rk_valid) begin
          $write(" | RK valid idx=%0d rk=%h", rk_idx, rk);
        end

        if (plaintext_valid) begin
          $write(" | PT_VALID pt=%h", plaintext);
        end

        $write("\n");
      end
    end
  end

  // main test (3 NIST/FIPS-197 cases)
  initial begin
    errors     = 0;
    start      = 0;
    keylen     = 0;
    key_in     = 0;
    ciphertext = 0;

    // reset
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // CASE 1: AES-128
    $display("\n=== CASE 1: AES-128 ===");
    keylen = 2'b00;

    key_in = {
      32'h00000000, 32'h00000000,  // w7 w6
      32'h00000000, 32'h00000000,  // w5 w4
      32'h0c0d0e0f, 32'h08090a0b, 32'h04050607, 32'h00010203  // w3..w0
    };

    ciphertext = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    pulse_start();
    wait_valid_timeout(8000);

    if (plaintext !== 128'h00112233445566778899aabbccddeeff) begin
      $display("[AES-128] FAIL: got=%h exp=%h",
               plaintext, 128'h00112233445566778899aabbccddeeff);
      errors = errors + 1;
    end else begin
      $display("[AES-128] PASS: pt=%h", plaintext);
    end

    wait_not_busy_timeout(2000);
    repeat (2) @(posedge clk);

    // CASE 2: AES-192
    $display("\n=== CASE 2: AES-192 ===");
    keylen = 2'b01;

    key_in = {
      32'h00000000, 32'h00000000,        // w7 w6
      32'h14151617, 32'h10111213,        // w5 w4
      32'h0c0d0e0f, 32'h08090a0b, 32'h04050607, 32'h00010203  // w3..w0
    };

    ciphertext = 128'hdda97ca4864cdfe06eaf70a0ec0d7191;

    pulse_start();
    wait_valid_timeout(12000);

    if (plaintext !== 128'h00112233445566778899aabbccddeeff) begin
      $display("[AES-192] FAIL: got=%h exp=%h",
               plaintext, 128'h00112233445566778899aabbccddeeff);
      errors = errors + 1;
    end else begin
      $display("[AES-192] PASS: pt=%h", plaintext);
    end

    wait_not_busy_timeout(3000);
    repeat (2) @(posedge clk);

    // CASE 3: AES-256
    $display("\n=== CASE 3: AES-256 ===");
    keylen = 2'b10;

    key_in = {
      32'h1c1d1e1f, 32'h18191a1b,        // w7 w6
      32'h14151617, 32'h10111213,        // w5 w4
      32'h0c0d0e0f, 32'h08090a0b, 32'h04050607, 32'h00010203  // w3..w0
    };

    ciphertext = 128'h8ea2b7ca516745bfeafc49904b496089;

    pulse_start();
    wait_valid_timeout(18000);

    if (plaintext !== 128'h00112233445566778899aabbccddeeff) begin
      $display("[AES-256] FAIL: got=%h exp=%h",
               plaintext, 128'h00112233445566778899aabbccddeeff);
      errors = errors + 1;
    end else begin
      $display("[AES-256] PASS: pt=%h", plaintext);
    end

    wait_not_busy_timeout(5000);

    // summary
    $display("\n======================");
    if (errors == 0) begin
      $display("ALL TESTS PASS");
    end else begin
      $display("TESTS FAIL: errors=%0d", errors);
    end
    $display("======================\n");

    #20;
    $finish;
  end

endmodule
