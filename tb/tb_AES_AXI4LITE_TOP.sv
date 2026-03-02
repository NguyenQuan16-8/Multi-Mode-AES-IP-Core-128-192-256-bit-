`timescale 1ns/1ps

module tb_AES_AXI4LITE_TOP;

  // Clock / Reset
  reg s_axi_aclk;
  reg s_axi_aresetn;

  initial begin
    s_axi_aclk = 1'b0;
    forever #5 s_axi_aclk = ~s_axi_aclk; // 100MHz
  end

  // AXI4-Lite signals (32-bit, 8-bit addr)
  reg  [7:0]  s_axi_awaddr;
  reg         s_axi_awvalid;
  wire        s_axi_awready;

  reg  [31:0] s_axi_wdata;
  reg  [3:0]  s_axi_wstrb;
  reg         s_axi_wvalid;
  wire        s_axi_wready;

  wire [1:0]  s_axi_bresp;
  wire        s_axi_bvalid;
  reg         s_axi_bready;

  reg  [7:0]  s_axi_araddr;
  reg         s_axi_arvalid;
  wire        s_axi_arready;

  wire [31:0] s_axi_rdata;
  wire [1:0]  s_axi_rresp;
  wire        s_axi_rvalid;
  reg         s_axi_rready;

  // DUT
  AES_AXI4LITE_TOP dut (
    .s_axi_aclk    (s_axi_aclk),
    .s_axi_aresetn (s_axi_aresetn),

    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),

    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wstrb   (s_axi_wstrb),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),

    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bready  (s_axi_bready),

    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),

    .s_axi_rdata   (s_axi_rdata),
    .s_axi_rresp   (s_axi_rresp),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rready  (s_axi_rready)
  );

  // Register map 
  localparam [7:0] ADDR_CTRL   = 8'h00;
  localparam [7:0] ADDR_STATUS = 8'h04;
  localparam [7:0] ADDR_KEYLEN = 8'h08;

  localparam [7:0] ADDR_KEY0   = 8'h0C; // .. 0x28
  localparam [7:0] ADDR_DIN0   = 8'h2C; // .. 0x38
  localparam [7:0] ADDR_DOUT0  = 8'h3C; // .. 0x48

  // AXI Master tasks
  task axi_write32;
    input [7:0]  addr;
    input [31:0] data;
    input [3:0]  strb;
    begin
      // drive
      @(negedge s_axi_aclk);
      s_axi_awaddr  <= addr;
      s_axi_awvalid <= 1'b1;

      s_axi_wdata   <= data;
      s_axi_wstrb   <= strb;
      s_axi_wvalid  <= 1'b1;

      s_axi_bready  <= 1'b1;

      // wait accept AW and W (independent)
      while (!s_axi_awready) @(posedge s_axi_aclk);
      @(negedge s_axi_aclk);
      s_axi_awvalid <= 1'b0;

      while (!s_axi_wready) @(posedge s_axi_aclk);
      @(negedge s_axi_aclk);
      s_axi_wvalid <= 1'b0;

      // wait response
      while (!s_axi_bvalid) @(posedge s_axi_aclk);

      if (s_axi_bresp !== 2'b00) begin
        $display("**AXI WRITE BRESP ERROR** addr=%h bresp=%b time=%0t", addr, s_axi_bresp, $time);
        $finish;
      end

      // handshake B
      @(negedge s_axi_aclk);
      s_axi_bready <= 1'b0;
    end
  endtask

  task axi_read32;
    input  [7:0]  addr;
    output [31:0] data;
    begin
      @(negedge s_axi_aclk);
      s_axi_araddr  <= addr;
      s_axi_arvalid <= 1'b1;
      s_axi_rready  <= 1'b1;

      // wait accept AR
      while (!s_axi_arready) @(posedge s_axi_aclk);
      @(negedge s_axi_aclk);
      s_axi_arvalid <= 1'b0;

      // wait RVALID
      while (!s_axi_rvalid) @(posedge s_axi_aclk);

      if (s_axi_rresp !== 2'b00) begin
        $display("**AXI READ RRESP ERROR** addr=%h rresp=%b time=%0t", addr, s_axi_rresp, $time);
        $finish;
      end

      data = s_axi_rdata;

      @(negedge s_axi_aclk);
      s_axi_rready <= 1'b0;
    end
  endtask

  // poll done (STATUS bit1) with timeout
  task wait_done;
    input integer max_cycles;
    integer k;
    reg [31:0] st;
    begin
      for (k=0; k<max_cycles; k=k+1) begin
        axi_read32(ADDR_STATUS, st);
        if (st[1] == 1'b1) disable wait_done;
        @(posedge s_axi_aclk);
      end
      $display("**TIMEOUT** waiting DONE");
      $finish;
    end
  endtask

  // clear done sticky by writing STATUS.bit1=1 (with strobe on byte0)
  task clear_done;
    begin
      axi_write32(ADDR_STATUS, 32'h0000_0002, 4'h1);
    end
  endtask

  // Random helpers
  integer seed;
  function [31:0] rand32;
    begin
      rand32 = $random(seed);
    end
  endfunction


  task program_key;
    input [1:0] kl;
    reg [31:0] k0,k1,k2,k3,k4,k5,k6,k7;
    begin
      k0 = rand32(); k1 = rand32(); k2 = rand32(); k3 = rand32();
      k4 = rand32(); k5 = rand32(); k6 = rand32(); k7 = rand32();

      // For determinism & clarity, zero unused words
      if (kl == 2'b00) begin
        k4=32'h0; k5=32'h0; k6=32'h0; k7=32'h0;
      end else if (kl == 2'b01) begin
        k6=32'h0; k7=32'h0;
      end

      // write KEY regs
      axi_write32(ADDR_KEY0, k0, 4'hF);
      axi_write32(ADDR_KEY0+8'h04, k1, 4'hF);
      axi_write32(ADDR_KEY0+8'h08, k2, 4'hF);
      axi_write32(ADDR_KEY0+8'h0C, k3, 4'hF);
      axi_write32(ADDR_KEY0+8'h10, k4, 4'hF);
      axi_write32(ADDR_KEY0+8'h14, k5, 4'hF);
      axi_write32(ADDR_KEY0+8'h18, k6, 4'hF);
      axi_write32(ADDR_KEY0+8'h1C, k7, 4'hF);

      $display("  KEY7..0 = %08h_%08h_%08h_%08h_%08h_%08h_%08h_%08h",
               k7,k6,k5,k4,k3,k2,k1,k0);
    end
  endtask

  task program_din_random;
    output [127:0] din128;
    reg [31:0] d0,d1,d2,d3;
    begin
      d0 = rand32(); d1 = rand32(); d2 = rand32(); d3 = rand32();
      din128 = {d3,d2,d1,d0};

      axi_write32(ADDR_DIN0, d0, 4'hF);
      axi_write32(ADDR_DIN0+8'h04, d1, 4'hF);
      axi_write32(ADDR_DIN0+8'h08, d2, 4'hF);
      axi_write32(ADDR_DIN0+8'h0C, d3, 4'hF);

      $display("  DIN3..0 = %08h_%08h_%08h_%08h  (128b=%h)", d3,d2,d1,d0, din128);
    end
  endtask

  task program_din_from128;
    input [127:0] din128;
    begin
      axi_write32(ADDR_DIN0,      din128[31:0],   4'hF);
      axi_write32(ADDR_DIN0+8'h04, din128[63:32],  4'hF);
      axi_write32(ADDR_DIN0+8'h08, din128[95:64],  4'hF);
      axi_write32(ADDR_DIN0+8'h0C, din128[127:96], 4'hF);
    end
  endtask

  task read_dout_to128;
    output [127:0] dout128;
    reg [31:0] o0,o1,o2,o3;
    begin
      axi_read32(ADDR_DOUT0, o0);
      axi_read32(ADDR_DOUT0+8'h04, o1);
      axi_read32(ADDR_DOUT0+8'h08, o2);
      axi_read32(ADDR_DOUT0+8'h0C, o3);
      dout128 = {o3,o2,o1,o0};
      $display("  DOUT3..0= %08h_%08h_%08h_%08h  (128b=%h)", o3,o2,o1,o0, dout128);
    end
  endtask


  task start_op;
    input mode_bit;
    begin
      // write CTRL with mode + start
      // bit1=mode, bit0=start
      axi_write32(ADDR_CTRL, {30'd0, mode_bit, 1'b1}, 4'h1);
    end
  endtask


  task test_wstrb_byte_write;
    reg [31:0] rd;
    begin
      $display("\n=== WSTRB byte-write sanity check ===");
      axi_write32(ADDR_DIN0, 32'hAABB_CCDD, 4'hF); // full write
      axi_write32(ADDR_DIN0, 32'h0000_00EE, 4'h1); // only byte0 -> should become ...EE
      axi_read32(ADDR_DIN0, rd);
      $display("  DIN0 after byte-write = %08h (expect AABB_CCEE)", rd);
      if (rd !== 32'hAABB_CCEE) begin
        $display("**FAIL** WSTRB not working as expected");
        $finish;
      end else begin
        $display("  WSTRB OK");
      end
    end
  endtask

  // One loopback test: encrypt then decrypt
  task run_loopback;
    input [1:0] kl;
    input integer idx;
    reg [127:0] pt_in;
    reg [127:0] ct_mid;
    reg [127:0] pt_out;
    begin
      $display("\n------------------------------------------------------------");
      $display("[CASE %0d] keylen=%b  (00=128,01=192,10=256)", idx, kl);

      // program keylen
      axi_write32(ADDR_KEYLEN, {30'd0, kl}, 4'h1);

      // program key
      program_key(kl);

      // ---------------- ENCRYPT ----------------
      $display("  -- ENCRYPT --");
      program_din_random(pt_in);
      clear_done();
      start_op(1'b0); // mode=0 enc

      wait_done(400000);

      read_dout_to128(ct_mid);
      $display("  PT_in  = %h", pt_in);
      $display("  CT_mid = %h", ct_mid);

      // ---------------- DECRYPT ----------------
      $display("  -- DECRYPT --");
      program_din_from128(ct_mid);
      clear_done();
      start_op(1'b1); // mode=1 dec

      wait_done(500000);

      read_dout_to128(pt_out);
      $display("  PT_out = %h", pt_out);

      if (pt_out !== pt_in) begin
        $display("**FAIL** loopback mismatch!");
        $display("  PT_in  = %h", pt_in);
        $display("  CT_mid = %h", ct_mid);
        $display("  PT_out = %h", pt_out);
        $finish;
      end else begin
        $display("PASS loopback");
      end
    end
  endtask

  integer i;

  initial begin
    // init AXI to 0
    s_axi_awaddr  = 0;
    s_axi_awvalid = 0;
    s_axi_wdata   = 0;
    s_axi_wstrb   = 0;
    s_axi_wvalid  = 0;
    s_axi_bready  = 0;

    s_axi_araddr  = 0;
    s_axi_arvalid = 0;
    s_axi_rready  = 0;

    seed = 32'hC0FFEE;

    // reset
    s_axi_aresetn = 1'b0;
    repeat (10) @(posedge s_axi_aclk);
    s_axi_aresetn = 1'b1;
    repeat (5) @(posedge s_axi_aclk);

    // sanity WSTRB test
    test_wstrb_byte_write();

    // Run loopback for 3 keylens, a few cases each
    $display("\n=== AXI AES LOOPBACK TEST (ENC->DEC) ===");

    for (i=0; i<5; i=i+1) run_loopback(2'b00, i); // AES-128
    for (i=0; i<5; i=i+1) run_loopback(2'b01, i); // AES-192
    for (i=0; i<5; i=i+1) run_loopback(2'b10, i); // AES-256

    $display("\nALL AXI LOOPBACK TESTS PASS");
    #50;
    $finish;
  end

endmodule
