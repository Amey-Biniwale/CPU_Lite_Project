`default_nettype none

`define Z PSR[0]
`define N PSR[1]
`define C PSR[2]
`define V PSR[3]

`define NOP         8'h00
`define LOAD        8'h01
`define LOAD_IND    8'h02
`define LOAD_IMM    8'h03
`define STORE       8'h04
`define STORE_IND   8'h05
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
`define JMP         8'h0E
`define JMP_IF      8'h0F
`define BEQ         8'h20
`define BNE         8'h21
`define BLT         8'h22
`define BGE         8'h23
`define HALT        8'hFF


module CPU_Core(
    // CLOCK And Active Low RESET
    input wire FCLK,
    input wire FRESETn,
    
    // INPUT FROM PROGRAMME MEMORY
    input wire [31:0] PROG,
    
    // INPUT FROM CACHE MEMORY
    input wire [31:0] RDATA,
    input wire RDATA_VALID,
    input wire WRITE_COMP,
    
    // SENDING PC TO THE PROGRAM MEMORY
    output reg [11:0] PC,
    
    // OUTPUT ADDRESS AND DATA TO CACHE MEMORY
    output reg START,
    output reg [13:0] ADDRESS,
    output reg [31:0] WDATA,
    output wire WRITE,
    output wire READ
);


    // GENERAL PURPOSE REGISTER
    reg [31:0] RG [0:15];
    // PROGRAM STATUS REGISTER
    reg [3:0] PSR;
    
    reg [2:0] PS, NS;
    
    reg [31:0] INSTR;
    
    reg DONE_EX, DONE_MEM;
    
    reg count;
    
    localparam IF = 3'd0;
    localparam ID = 3'd1;
    localparam EX = 3'd2;
    localparam MEM = 3'd3;
    localparam WB = 3'd4;
    
    // DECLARATION OF THE REGISTES
    wire [7:0] OPCODE;
    wire [3:0] Rs1, Rs2, Rd;
    wire [11:0] IMM;
    
    
    // EXTRACTING INFO FROM THE INSTRUCTION
    assign OPCODE = INSTR[31:24];
    assign Rd = INSTR[23:20];
    assign Rs1 = INSTR[19:16];
    assign Rs2 = INSTR[15:12];
    assign IMM = INSTR[11:0];
    
    // INPUTS AND OUTPUTS TO THE ALU
    reg [31:0] Rs1_REG, Rs2_REG, Rd_REG;
    wire C_REG, V_REG, N_REG, Z_REG;
    wire [31:0] Rd_ALU;
    
    // CONTROL SIGNALS
    wire MEM_GO, WB_GO;
    
    // MEMORY ACCESS ADDRESS
    reg [13:0] MEM_ADDR;
    reg [31:0] MEM_WDATA;
    
    // START MEMORY ACCES
    reg HALT;
    
    assign WRITE = (OPCODE == `STORE)       ||
                   (OPCODE == `STORE_IND);
                   
    assign READ =   (OPCODE == `LOAD)       ||
                    (OPCODE == `LOAD_IND);
    
    assign MEM_GO = (OPCODE == `LOAD)       ||
                    (OPCODE == `LOAD_IND)   ||
                    (OPCODE == `STORE)      ||
                    (OPCODE == `STORE_IND);
                    
    assign WB_GO = (OPCODE == `LOAD)        ||
                   (OPCODE == `LOAD_IND)    ||
                   (OPCODE == `LOAD_IMM)    ||
                   (OPCODE == `ADD)         ||
                   (OPCODE == `SUB)         ||
                   (OPCODE == `MUL)         ||
                   (OPCODE == `AND)         ||
                   (OPCODE == `OR)          ||
                   (OPCODE == `NOT)         ||
                   (OPCODE == `EQ)          ||
                   (OPCODE == `ADDI)        ||
                   (OPCODE == `SUBI)        ||
                   (OPCODE == `SHL)         ||
                   (OPCODE == `SHR)         ||
                   (OPCODE == `SAR);
    
    always @(posedge FCLK or negedge FRESETn) begin
        if(!FRESETn) begin
            PS <= IF;
        end
        else begin
            PS <= NS;
        end
    end
    
    
    
    always @(*) begin
        case(PS)
            IF : begin
                NS = ID;
            end
            ID : begin
                NS = EX;
            end
            EX : begin
                if(HALT) NS = EX;
                else if(DONE_EX) begin
                    if(MEM_GO) NS = MEM;
                    else if(WB_GO) NS = WB;
                    else NS = IF;
                end
                else NS = EX;
            end
            MEM : begin
                if(DONE_MEM) begin
                    if(WB_GO) NS = WB;
                    else NS = IF;
                end
                else NS = MEM;
            end
            WB : begin
                NS = IF;
            end
            default : begin
                NS = IF;
            end
        endcase
    end
    
    
    ALU alu(
        .OPCODE(OPCODE),
        .OPA(Rs1_REG),
        .OPB(Rs2_REG),
        .OP_IMM(IMM),
        .RES(Rd_ALU),
        .C(C_REG),
        .Z(Z_REG),
        .V(V_REG),
        .N(N_REG)
    );
    
    integer i;
    
    always @(posedge FCLK or negedge FRESETn) begin
        if(!FRESETn) begin
            count <= 0;
            
            PC <= 0;
            HALT <= 0;
            
            DONE_EX <= 0;
            DONE_MEM <= 0;
            
            for(i = 0; i < 16; i = i + 1) begin
                RG[i] <= 0;
            end
            
            INSTR <= 0;
            Rs1_REG <= 0;
            Rs2_REG <= 0;
            Rd_REG <= 0;
            MEM_ADDR <= 0;
            MEM_WDATA <= 0;
            `C <= 0;
            `Z <= 0;
            `N <= 0;
            `V <= 0;
            
            START <= 0;
            ADDRESS <= 0;
            WDATA <= 0;
        end
        else begin
            DONE_EX <= 0;
            DONE_MEM <= 0;
            case(PS)
                IF : begin
                    INSTR <= PROG;
                    if(!HALT)PC <= PC + 1;
                end
                ID : begin
                    Rs1_REG <= RG[Rs1];
                    Rs2_REG <= RG[Rs2];
                    count <= 0;
                    START <= 0;
                end
                EX : begin
                    case(OPCODE)
                        `NOP : begin
                            DONE_EX <= 1;
                        end
                        `LOAD : begin
                            MEM_ADDR <= {2'b00,IMM};
                            DONE_EX <= 1;
                        end
                        `LOAD_IND : begin
                            MEM_ADDR <= Rs1_REG[13:0];
                            DONE_EX <= 1;
                        end
                        `LOAD_IMM : begin
                            Rd_REG <= {20'd0,IMM};
                            DONE_EX <= 1;
                        end
                        `STORE : begin
                            MEM_WDATA <= RG[Rd];
                            MEM_ADDR <= {2'b00,IMM};
                            DONE_EX <= 1;
                        end
                        `STORE_IND : begin
                            MEM_ADDR <= Rs2_REG[13:0];
                            MEM_WDATA <= RG[Rd];
                            DONE_EX <= 1;
                        end
                        `ADD : begin
                            Rd_REG <= Rd_ALU;
                            `C <= C_REG;
                            `Z <= Z_REG;
                            `V <= V_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `SUB : begin
                            Rd_REG <= Rd_ALU;
                            `C <= C_REG;
                            `Z <= Z_REG;
                            `V <= V_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `MUL : begin
                            if(count == 1) begin
                            Rd_REG <= Rd_ALU;
                                `Z <= Z_REG;
                                `N <= N_REG;
                                DONE_EX <= 1;
                            end
                            else count <= count + 1;
                        end
                        `AND : begin
                            Rd_REG <= Rd_ALU;
                            `Z <= Z_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `OR : begin
                            Rd_REG <= Rd_ALU;
                            `Z <= Z_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `NOT : begin
                            Rd_REG <= Rd_ALU;
                            `Z <= Z_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `CMP : begin
                            `C <= C_REG;
                            `Z <= Z_REG;
                            `V <= V_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `EQ : begin
                            Rd_REG <= Rd_ALU;
                            `Z <= Z_REG;
                            DONE_EX <= 1;
                        end
                        `ADDI : begin
                            Rd_REG <= Rd_ALU;
                            `C <= C_REG;
                            `Z <= Z_REG;
                            `V <= V_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `SUBI : begin
                            Rd_REG <= Rd_ALU;
                            `C <= C_REG;
                            `Z <= Z_REG;
                            `V <= V_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `SHL : begin
                            Rd_REG <= Rd_ALU;
                            `Z <= Z_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `SHR : begin
                            Rd_REG <= Rd_ALU;
                            `Z <= Z_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `SAR : begin
                            Rd_REG <= Rd_ALU;
                            `Z <= Z_REG;
                            `N <= N_REG;
                            DONE_EX <= 1;
                        end
                        `JMP : begin
                            PC <= IMM;
                            DONE_EX <= 1;
                        end
                        `JMP_IF : begin
                            if(Rs1_REG != 0) PC <= IMM;
                            DONE_EX <= 1;
                        end
                        `BEQ : begin
                            if(`Z) PC <= IMM;
                            DONE_EX <= 1;
                        end
                        `BNE : begin
                            if(~`Z) PC <= IMM;
                            DONE_EX <= 1;
                        end
                        `BLT : begin
                            if(`N ^ `V) PC <= IMM;
                            DONE_EX <= 1;
                        end
                        `BGE : begin
                            if(~(`N ^ `V)) PC <= IMM;
                            DONE_EX <= 1;
                        end
                        `HALT : begin
                            HALT <= 1;
                        end
                        default : begin
                            Rd_REG <= 0;
                            `C <= 0;
                            `Z <= 0;
                            `V <= 0;
                            `N <= 0;
                            DONE_EX <= 1;
                        end
                    endcase
                end
                MEM : begin
                    START <= 1;
                    ADDRESS <= MEM_ADDR;
                    if(WRITE) begin
                       WDATA <= MEM_WDATA;
                       if(WRITE_COMP) DONE_MEM <= 1; 
                    end
                    else if(READ) begin
                        if(RDATA_VALID) begin
                            Rd_REG <= RDATA;
                            DONE_MEM <= 1;
                        end
                    end
                end
                WB : begin
                    RG[Rd] <= Rd_REG;
                end
                default : begin
                    
                end
            endcase
        end
    end
    
    
endmodule

