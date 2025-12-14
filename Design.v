module control_unit(
    input  [5:0] op,
    input  [5:0] func,

    input  [4:0] rs,
    input  [4:0] rt,

    // pipeline register numbers for hazard/forwarding
    input  [4:0] edestReg,     // ***NEW EXTRA CREDIT*** ern (EXE dest)
    input  [4:0] mdestReg,     // mrn (MEM dest)
    input  [4:0] wdestReg,     // wrn (WB dest)

    // pipeline control bits
    input        ewreg,        // ***NEW EXTRA CREDIT***
    input        em2reg,        // ***NEW EXTRA CREDIT***
    input        mwreg,
    input        mm2reg,        // ***NEW EXTRA CREDIT***
    input        wwreg,
    input        wm2reg,

    input        rsrtequ,       // ***NEW EXTRA CREDIT*** branch compare result

    output reg        wreg,
    output reg        m2reg,
    output reg        wmem,
    output reg [3:0]  aluc,
    output reg        aluimm,
    output reg        regrt,

    output reg [1:0]  fwda,     // internal forwarding in ID
    output reg [1:0]  fwdb,

    output reg [1:0]  pcsrc,    // ***NEW EXTRA CREDIT*** npc mux select
    output reg        wpcir,    // ***NEW EXTRA CREDIT*** enable for PC + IF/ID
    output reg        jal,      // ***NEW EXTRA CREDIT*** jal flag
    output reg        shift,    // ***NEW EXTRA CREDIT*** shift flag (for sa mux)
    output reg        sext      // ***NEW EXTRA CREDIT*** sign extend enable (if you want)
);

    reg i_rs, i_rt;            // ***NEW EXTRA CREDIT*** does ID instruction read rs/rt
    reg stall;                 // ***NEW EXTRA CREDIT***

    always @(*) begin
        // defaults
        wreg   = 1'b0;
        m2reg  = 1'b0;
        wmem   = 1'b0;
        aluc   = 4'b0010;
        aluimm = 1'b0;
        regrt  = 1'b0;

        pcsrc  = 2'b00;        // pc4
        jal    = 1'b0;
        shift  = 1'b0;
        sext   = 1'b1;

        // assume uses both operands unless overridden
        i_rs = 1'b1;
        i_rt = 1'b1;

        // --------------------------------------------
        // decode main instruction types
        // --------------------------------------------
        case (op)
            6'b000000: begin // R-type
                regrt = 1'b0; // rd
                wreg  = 1'b1;
                i_rs  = 1'b1;
                i_rt  = 1'b1;

                case (func)
                    6'b100000: aluc = 4'b0010; // add
                    6'b100010: aluc = 4'b0110; // sub
                    6'b100100: aluc = 4'b0000; // and
                    6'b100101: aluc = 4'b0001; // or
                    6'b100110: aluc = 4'b0011; // xor

                    // ***NEW EXTRA CREDIT*** shifts (use sa mux)
                    6'b000000: begin aluc = 4'b1000; shift = 1'b1; end // sll (example encoding)
                    6'b000010: begin aluc = 4'b1001; shift = 1'b1; end // srl

                    // ***NEW EXTRA CREDIT*** jr: pcsrc = 11 (da)
                    6'b001000: begin
                        wreg  = 1'b0;
                        pcsrc = 2'b11;
                        i_rt  = 1'b0; // jr only uses rs
                    end
                    default: ;
                endcase
            end

            6'b100011: begin // lw
                wreg   = 1'b1;
                m2reg  = 1'b1;
                aluimm = 1'b1;
                regrt  = 1'b1; // rt
                i_rs   = 1'b1;
                i_rt   = 1'b0;
            end

            6'b101011: begin // sw
                wmem   = 1'b1;
                aluimm = 1'b1;
                regrt  = 1'b1; // rt field is source reg, but keep consistent
                wreg   = 1'b0;
                i_rs   = 1'b1;
                i_rt   = 1'b1;
            end

            6'b000100: begin // beq
                wreg   = 1'b0;
                i_rs   = 1'b1;
                i_rt   = 1'b1;
                if (rsrtequ) pcsrc = 2'b01; // bpc
            end

            6'b000101: begin // bne
                wreg   = 1'b0;
                i_rs   = 1'b1;
                i_rt   = 1'b1;
                if (!rsrtequ) pcsrc = 2'b01; // bpc
            end

            6'b000010: begin // j
                wreg  = 1'b0;
                i_rs  = 1'b0;
                i_rt  = 1'b0;
                pcsrc = 2'b10; // jpc
            end

            6'b000011: begin // jal
                // jal writes PC+8 into $31 :contentReference[oaicite:2]{index=2}
                jal   = 1'b1;
                wreg  = 1'b1;
                m2reg = 1'b0;
                pcsrc = 2'b10; // jump target
                i_rs  = 1'b0;
                i_rt  = 1'b0;
            end

            default: begin
                i_rs = 1'b0;
                i_rt = 1'b0;
            end
        endcase

        // --------------------------------------------
        // ***NEW EXTRA CREDIT*** stall + wpcir
        // stall formula from pdf :contentReference[oaicite:3]{index=3}
        // --------------------------------------------
        stall = ewreg & em2reg & (edestReg != 0) &
                ( (i_rs & (edestReg == rs)) | (i_rt & (edestReg == rt)) );

        wpcir = ~stall; // inverse stall enables PC + IF/ID updates :contentReference[oaicite:4]{index=4}

        // --------------------------------------------
        // ***NEW EXTRA CREDIT*** internal forwarding (ID stage da/db)
        // priority: EXE (ealu) > MEM (malu/mmo) > WB (wdi)
        // 00 qa/qb, 01 ealu, 10 malu, 11 wdi
        // --------------------------------------------
        fwda = 2'b00;
        fwdb = 2'b00;

        if (ewreg && (edestReg != 0) && (edestReg == rs)) fwda = 2'b01;
        else if (mwreg && (mdestReg != 0) && (mdestReg == rs)) fwda = 2'b10;
        else if (wwreg && (wdestReg != 0) && (wdestReg == rs)) fwda = 2'b11;

        if (ewreg && (edestReg != 0) && (edestReg == rt)) fwdb = 2'b01;
        else if (mwreg && (mdestReg != 0) && (mdestReg == rt)) fwdb = 2'b10;
        else if (wwreg && (wdestReg != 0) && (wdestReg == rt)) fwdb = 2'b11;

        // --------------------------------------------
        // ***NEW EXTRA CREDIT*** cancel instruction on stall
        // pdf says: when stalling, you must cancel so it doesn't execute twice :contentReference[oaicite:5]{index=5}
        // easiest: zero the control signals that go into ID/EXE
        // --------------------------------------------
        if (stall) begin
            wreg   = 1'b0;
            m2reg  = 1'b0;
            wmem   = 1'b0;
            aluimm = 1'b0;
            regrt  = 1'b0;
            jal    = 1'b0;
            shift  = 1'b0;
            pcsrc  = 2'b00; // keep pc4 selected; PC won't update anyway because wpcir=0
        end
    end
endmodule

// =============================================================
// Simple 5-stage pipelined datapath with basic forwarding
// Supports R-type ALU ops needed by the provided test program.
// =============================================================

module reg_file(
    input             clk,
    input             we,
    input      [4:0]  rna,
    input      [4:0]  rnb,
    input      [4:0]  wn,
    input      [31:0] wd,
    output reg [31:0] qa,
    output reg [31:0] qb
);
    reg [31:0] registers [0:31];

    // Initialize registers per project specification
    integer i;
    initial begin
        registers[0]  = 32'h00000000;
        registers[1]  = 32'hA00000AA;
        registers[2]  = 32'h10000011;
        registers[3]  = 32'h20000022;
        registers[4]  = 32'h30000033;
        registers[5]  = 32'h40000044;
        registers[6]  = 32'h50000055;
        registers[7]  = 32'h60000066;
        registers[8]  = 32'h70000077;
        registers[9]  = 32'h80000088;
        registers[10] = 32'h90000099;
        for (i = 11; i < 32; i = i + 1) registers[i] = 32'b0;
    end

    always @(*) begin
        qa = registers[rna];
        qb = registers[rnb];
    end

    always @(posedge clk) begin
        if (we && wn != 0) registers[wn] <= wd;
        registers[0] <= 32'b0; // enforce $zero
    end
endmodule

module alu(
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  aluc,
    output reg [31:0] r
);
    always @(*) begin
        case (aluc)
            4'b0000: r = a & b;
            4'b0001: r = a | b;
            4'b0010: r = a + b;
            4'b0011: r = a ^ b;
            4'b0110: r = a - b;
            default: r = 32'b0;
        endcase
    end
endmodule

module datapath(
    input clk,

    output reg [31:0] pc,
    output reg [31:0] dinstOut,

    // EX stage
    output reg        ewreg,
    output reg        em2reg,
    output reg        ewmem,
    output reg [3:0]  ealuc,
    output reg        ealuimm,
    output reg [4:0]  edestReg,
    output reg [31:0] eqa,
    output reg [31:0] eqb,
    output reg [31:0] eimm32,

    // MEM stage
    output reg        mwreg,
    output reg        mm2reg,
    output reg        mwmem,
    output reg [4:0]  mdestReg,
    output reg [31:0] mr,
    output reg [31:0] mqb,

    // WB stage
    output reg        wwreg,
    output reg        wm2reg,
    output reg [4:0]  wdestReg,
    output reg [31:0] wr,
    output reg [31:0] wdo,
    output     [31:0] wbData,

    // control extras
    output [1:0] fwda,
    output [1:0] fwdb,
    output [1:0] pcsrc,
    output       wpcir
);
    initial begin
        pc       = 32'b0;
        dinstOut = 32'b0;
        ewreg    = 1'b0; em2reg = 1'b0; ewmem = 1'b0; ealuc = 4'b0; ealuimm = 1'b0; edestReg = 5'b0; eqa = 32'b0; eqb = 32'b0; eimm32 = 32'b0;
        mwreg    = 1'b0; mm2reg = 1'b0; mwmem = 1'b0; mdestReg = 5'b0; mr = 32'b0; mqb = 32'b0;
        wwreg    = 1'b0; wm2reg = 1'b0; wdestReg = 5'b0; wr = 32'b0; wdo = 32'b0;
    end
    // --------------------------------------------
    // Instruction memory
    // --------------------------------------------
    reg [31:0] imem [0:31];
    initial begin
        imem[0] = 32'h00221820; // add $3,$1,$2
        imem[1] = 32'h01232022; // sub $4,$9,$3
        imem[2] = 32'h01232825; // or  $5,$9,$3
        imem[3] = 32'h01233026; // xor $6,$9,$3
        imem[4] = 32'h01233824; // and $7,$9,$3
        imem[5] = 32'h00000000;
        imem[6] = 32'h00000000;
        imem[7] = 32'h00000000;
        imem[8] = 32'h00000000;
        imem[9] = 32'h00000000;
    end

    // --------------------------------------------
    // Data memory
    // --------------------------------------------
    reg [31:0] dmem [0:31];
    integer di;
    initial begin
        dmem[0] = 32'hA00000AA;
        dmem[1] = 32'h10000011;
        dmem[2] = 32'h20000022;
        dmem[3] = 32'h30000033;
        dmem[4] = 32'h40000044;
        dmem[5] = 32'h50000055;
        dmem[6] = 32'h60000066;
        dmem[7] = 32'h70000077;
        dmem[8] = 32'h80000088;
        dmem[9] = 32'h90000099;
        for (di = 10; di < 32; di = di + 1) dmem[di] = 32'b0;
    end

    // --------------------------------------------
    // IF stage
    // --------------------------------------------
    wire [31:0] pc4  = pc + 4;
    reg  [31:0] dpc4;

    // Branch/jump address helpers (scoped for TB peeks)
    wire [31:0] bpc = dpc4 + {{14{dinstOut[15]}}, dinstOut[15:0], 2'b00};
    wire [31:0] jpc = {dpc4[31:28], dinstOut[25:0], 2'b00};

    wire [31:0] npc = (pcsrc == 2'b00) ? pc4 :
                      (pcsrc == 2'b01) ? bpc :
                      (pcsrc == 2'b10) ? jpc :
                      eqa; // jr fallback

    always @(posedge clk) begin
        if (wpcir) pc <= npc;
    end

    // IF/ID register
    always @(posedge clk) begin
        if (wpcir) begin
            dinstOut <= imem[pc[31:2]];
            dpc4     <= pc4;
        end
    end

    // --------------------------------------------
    // ID stage
    // --------------------------------------------
    wire [5:0] op   = dinstOut[31:26];
    wire [4:0] rs   = dinstOut[25:21];
    wire [4:0] rt   = dinstOut[20:16];
    wire [4:0] rd   = dinstOut[15:11];
    wire [5:0] func = dinstOut[5:0];
    wire [31:0] imm32 = {{16{dinstOut[15]}}, dinstOut[15:0]};

    wire id_wreg, id_m2reg, id_wmem, id_aluimm, id_regrt, id_jal, id_shift, id_sext;
    wire [3:0] id_aluc;
    control_unit CU(
        .op(op), .func(func), .rs(rs), .rt(rt),
        .edestReg(edestReg), .mdestReg(mdestReg), .wdestReg(wdestReg),
        .ewreg(ewreg), .em2reg(em2reg), .mwreg(mwreg), .mm2reg(mm2reg), .wwreg(wwreg), .wm2reg(wm2reg),
        .rsrtequ(rsrtequ),
        .wreg(id_wreg), .m2reg(id_m2reg), .wmem(id_wmem), .aluc(id_aluc), .aluimm(id_aluimm), .regrt(id_regrt),
        .fwda(fwda), .fwdb(fwdb), .pcsrc(pcsrc), .wpcir(wpcir), .jal(id_jal), .shift(id_shift), .sext(id_sext)
    );

    wire [31:0] qa, qb;
    reg_file RF(
        .clk(clk),
        .we(wwreg),
        .rna(rs),
        .rnb(rt),
        .wn(wdestReg),
        .wd(wbData),
        .qa(qa),
        .qb(qb)
    );

    // Internal forwarding for branches (not used here but wired for completeness)
    wire [31:0] ealu_result;

    wire [31:0] da = (fwda == 2'b01) ? ealu_result :
                     (fwda == 2'b10) ? mr         :
                     (fwda == 2'b11) ? wbData     : qa;
    wire [31:0] db = (fwdb == 2'b01) ? ealu_result :
                     (fwdb == 2'b10) ? mr         :
                     (fwdb == 2'b11) ? wbData     : qb;
    wire rsrtequ = (da == db);

    wire [4:0] destReg = id_regrt ? rt : rd;

    // ID/EX registers
    reg [4:0] ers, ert;
    always @(posedge clk) begin
        ewreg    <= id_wreg;
        em2reg   <= id_m2reg;
        ewmem    <= id_wmem;
        ealuc    <= id_aluc;
        ealuimm  <= id_aluimm;
        edestReg <= destReg;
        eqa      <= da;
        eqb      <= db;
        eimm32   <= imm32;
        ers      <= rs;
        ert      <= rt;
    end

    // --------------------------------------------
    // EX stage with forwarding from MEM/WB
    // --------------------------------------------
    wire [31:0] forward_a = (mwreg && mdestReg != 0 && mdestReg == ers) ? mr :
                            (wwreg && wdestReg != 0 && wdestReg == ers) ? wbData :
                            eqa;

    wire [31:0] forward_b = (mwreg && mdestReg != 0 && mdestReg == ert) ? mr :
                            (wwreg && wdestReg != 0 && wdestReg == ert) ? wbData :
                            eqb;

    wire [31:0] alu_b = ealuimm ? eimm32 : forward_b;
    alu ALU(.a(forward_a), .b(alu_b), .aluc(ealuc), .r(ealu_result));

    // EX/MEM registers
    always @(posedge clk) begin
        mwreg    <= ewreg;
        mm2reg   <= em2reg;
        mwmem    <= ewmem;
        mdestReg <= edestReg;
        mr       <= ealu_result;
        mqb      <= forward_b;
    end

    // --------------------------------------------
    // MEM stage (no real loads/stores used in program)
    // --------------------------------------------
    always @(posedge clk) begin
        if (mwmem) dmem[mr[31:2]] <= mqb;
    end

    wire [31:0] mmo = mm2reg ? dmem[mr[31:2]] : 32'b0;

    // MEM/WB registers
    always @(posedge clk) begin
        wwreg    <= mwreg;
        wm2reg   <= mm2reg;
        wdestReg <= mdestReg;
        wr       <= mr;
        wdo      <= mmo;
    end

    assign wbData = wm2reg ? wdo : wr;
endmodule
