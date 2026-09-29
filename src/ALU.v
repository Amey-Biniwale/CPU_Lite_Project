`default_nettype none

`define ADD         8'h06
`define SUB         8'h07
`define MUL         8'h08
`define AND         8'h09
`define OR          8'h0A
`define NOT         8'h0B
`define CMP         8'h0C
`define EQ          8'h0D
`define ADDI        8'h16
`define SUBI        8'h17
`define SHL         8'h11
`define SHR         8'h12
`define SAR         8'h13

module ALU(
    input wire [7:0] OPCODE,
    input wire [31:0] OPA,
    input wire [31:0] OPB,
    input wire [11:0] OP_IMM,
    output reg [31:0] RES,
    output reg C,
    output reg V,
    output reg N,
    output reg Z
    );
    
    reg [63:0] MUL_REG;
    reg [32:0] SUB_REG;
    
    always @(*) begin
        RES = 0;
        Z = 0;
        N = 0;
        C = 0;
        V = 0;
        case(OPCODE)
            `ADD : begin
                {C, RES} = OPA + OPB;
                Z = RES == 0;
                N = RES[31];
                V = (OPA[31] == OPB[31]) & (OPA[31] != RES[31]);
            end
            `SUB : begin
                SUB_REG = OPA - OPB;
                RES = SUB_REG[31:0];
                C = OPA >= OPB;
                Z = RES == 0;
                N = RES[31];
                V = (OPA[31] != OPB[31]) & (OPA[31] != RES[31]);
            end
            `MUL : begin
                MUL_REG = (OPA * OPB);
                RES = MUL_REG[31:0];
                Z = RES == 0;
                N = RES[31];
            end
            `AND : begin
                RES = OPA & OPB;
                Z = RES == 0;
                N = RES[31];
            end
            `OR : begin
                RES = OPA | OPB;
                Z = RES == 0;
                N = RES[31];
            end
            `NOT : begin
                RES = ~OPA;
                Z = RES == 0;
                N = RES[31];
            end
            `CMP : begin
                SUB_REG = OPA - OPB;
                RES = SUB_REG[31:0];
                C = OPA >= OPB;
                Z = RES == 0;
                N = RES[31];
                V = (OPA[31] != OPB[31]) & (OPA[31] != RES[31]);
            end
            `EQ : begin
                RES = {32{(OPA == OPB)}};
                Z = RES == 0;
            end
            `ADDI : begin
                {C, RES} = OPA + {{20{OP_IMM[11]}},OP_IMM};
                Z = RES == 0;
                N = RES[31];
                V = (OPA[31] != RES[31]) & (OP_IMM[11] == OPA[31]);
            end
            `SUBI : begin
                SUB_REG = OPA - {{20{OP_IMM[11]}},OP_IMM};
                RES = SUB_REG[31:0];
                C = OPA >= {{20{OP_IMM[11]}},OP_IMM};
                Z = RES == 0;
                N = RES[31];
                V = (OPA[31] != OP_IMM[11]) & (OPA[31] != RES[31]);
            end
            `SHL : begin
                RES = OPA << OPB[4:0];
                Z = RES == 0;
                N = RES[31];
            end
            `SHR : begin
                RES = OPA >> OPB[4:0];
                Z = RES == 0;
                N = RES[31];
            end
            `SAR : begin
                RES = $signed(OPA) >>> OPB[4:0];
                Z = RES == 0;
                N = RES[31];
            end
            default : begin
                RES = 0;
                C = 0;
                N = 0;
                Z = 0;
                V = 0;
            end
        endcase
    end
endmodule
