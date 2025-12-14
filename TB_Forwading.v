//Testbench 

`timescale 1ns / 1ps
module tb;

  reg clk;
  localparam integer CLK_HALF   = 5;   // 10ns period
  localparam integer MAX_CYCLES = 35;

  // ---- outputs from datapath (match module ports) ----
  wire [31:0] pc;
  wire [31:0] dinstOut;

  wire        ewreg, em2reg, ewmem;
  wire [3:0]  ealuc;
  wire        ealuimm;
  wire [4:0]  edestReg;
  wire [31:0] eqa, eqb, eimm32;

  wire        mwreg, mm2reg, mwmem;
  wire [4:0]  mdestReg;
  wire [31:0] mr, mqb;

  wire        wwreg, wm2reg;
  wire [4:0]  wdestReg;
  wire [31:0] wr, wdo;
  wire [31:0] wbData;

  wire [1:0]  fwda, fwdb;
  wire [1:0]  pcsrc;
  wire        wpcir;

  // ---- DUT ----
  datapath cpu (
    .clk(clk),

    .pc(pc),
    .dinstOut(dinstOut),

    .ewreg(ewreg),
    .em2reg(em2reg),
    .ewmem(ewmem),
    .ealuc(ealuc),
    .ealuimm(ealuimm),
    .edestReg(edestReg),
    .eqa(eqa),
    .eqb(eqb),
    .eimm32(eimm32),

    .mwreg(mwreg),
    .mm2reg(mm2reg),
    .mwmem(mwmem),
    .mdestReg(mdestReg),
    .mr(mr),
    .mqb(mqb),

    .wwreg(wwreg),
    .wm2reg(wm2reg),
    .wdestReg(wdestReg),
    .wr(wr),
    .wdo(wdo),
    .wbData(wbData),

    .fwda(fwda),
    .fwdb(fwdb),
    .pcsrc(pcsrc),
    .wpcir(wpcir)
  );

  // ---- dump waves ----
  initial begin
    $dumpfile("mips_minio_wave.vcd");
    $dumpvars(0, tb);
  end

  // ---- clock ----
  initial begin
    clk = 1'b0;
    forever #(CLK_HALF) clk = ~clk;
  end

  // ---- stop sim ----
  integer cyc;
  initial begin
    cyc = 0;
    repeat (MAX_CYCLES) begin
      @(posedge clk);
      cyc = cyc + 1;
    end
    $finish;
  end

  // =====================================================
  // INTERNAL PEEKS (hierarchical) - optional but helpful
  // =====================================================

  // IF/ID extras (exist inside datapath)
  wire [31:0] pc4    = cpu.pc4;
  wire [31:0] dpc4   = cpu.dpc4;
  wire [31:0] npc    = cpu.npc;

  // branch/jump signals inside datapath
  wire [31:0] bpc    = cpu.bpc;
  wire [31:0] jpc    = cpu.jpc;
  wire [31:0] da     = cpu.da;
  wire [31:0] db     = cpu.db;
  wire        rsrtequ= cpu.rsrtequ;

  // Convenience: decode fields from dinstOut
  wire [5:0] op    = dinstOut[31:26];
  wire [4:0] rs    = dinstOut[25:21];
  wire [4:0] rt    = dinstOut[20:16];
  wire [4:0] rd    = dinstOut[15:11];
  wire [5:0] funct = dinstOut[5:0];

  // Regfile peek (THIS matches your reg_file instance name RF)
  wire [31:0] R1  = cpu.RF.registers[1];
  wire [31:0] R2  = cpu.RF.registers[2];
  wire [31:0] R3  = cpu.RF.registers[3];
  wire [31:0] R4  = cpu.RF.registers[4];
  wire [31:0] R5  = cpu.RF.registers[5];
  wire [31:0] R6  = cpu.RF.registers[6];
  wire [31:0] R7  = cpu.RF.registers[7];
  wire [31:0] R9  = cpu.RF.registers[9];
  wire [31:0] R31 = cpu.RF.registers[31];

endmodule