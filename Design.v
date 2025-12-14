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
