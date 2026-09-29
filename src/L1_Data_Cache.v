`default_nettype none

module L1_Data_Cache (
    // CLOCK AND RESET
    input wire FCLK,
    input wire FRESETn,
    
    // INPUTS FROM THE CPU_CORE
    input wire START,
    input wire [13:0] ADDRESS,
    input wire [31:0] WDATA,
    input wire WRITE,
    input wire READ,
    
    // OUTPUTS TO THE CPU CORE
    output reg [31:0] MEM_DATA,
    output reg RDATA_VALID,
    output reg WRITE_COMP,
    
    // INPUTTS FROM THE DATA MEMORY
    input wire [32:0] DATA_MEM_DATA,  // 32nd bit : VALID
    
    // OUTPUTS TO THE DATA MEMORY
    output reg [47:0] MEM_ACCESS, // VALID TRANSACTION : 47th WRITE/READ : 46th bit, ADDRESS : 45-32, WDATA : 31-0
    output reg FIFO_EN
    );
    
    reg [1:0] PS, NS;
    
    reg MISS, DONE_FETCH, DATA_DONE, WAIT_SIG;
    
    reg [5:0] TAG [0:63];
    reg VALID [0:63];
    reg [31:0] CACHE [0:63][0:3];
    
    integer i, j;
    
    reg [1:0] count;
    reg line_done;
    
    reg [13:0] SEND_ADDR;
    
    reg [31:0] RET_DATA;
    
    reg START_PREV;
    
    always @(posedge FCLK or negedge FRESETn) begin
        if(!FRESETn) begin
            START_PREV <= 0;
        end
        else begin
            START_PREV <= START;
        end
    end
    
    localparam IDLE = 2'd0;
    localparam FETCH = 2'd1;
    localparam WAIT = 2'd2;
    
    always @(posedge FCLK or negedge FRESETn) begin
        if(!FRESETn) begin
            PS <= IDLE;
        end
        else begin
            PS <= NS;
        end
    end
    
    always @(*) begin
        case(PS)
            IDLE : NS = MISS ? FETCH : IDLE;
            FETCH : begin
                if(WAIT_SIG) begin
                    NS = WAIT;
                end
                else if(DONE_FETCH) begin
                    NS = IDLE;
                end
                else begin
                    NS = FETCH;
                end
            end
            WAIT : begin
                if(DATA_DONE) begin
                    NS = FETCH;
                end
                else begin
                    NS = WAIT;
                end
            end
            default : begin
                NS = IDLE;
            end
        endcase
    end
    
    always @(posedge FCLK or negedge FRESETn) begin
        if(!FRESETn) begin
            FIFO_EN <= 0;
            RDATA_VALID <= 0;
            WAIT_SIG <= 0;
            DATA_DONE <= 0;
            MISS <= 0;
            DONE_FETCH <= 0;
            line_done <= 0;
            
            for(i = 0; i < 64; i = i + 1) begin
                VALID[i] <= 0;
                TAG[i] <= 0;
                for(j = 0; j < 4; j = j + 1) CACHE[i][j] <= 0;
            end
            
            MEM_DATA <= 0;
            WRITE_COMP <= 0;

            SEND_ADDR <= 0;
            RET_DATA <= 0;
            
            MEM_ACCESS <= 0;
            
            count <= 0;
        end
        else begin
            FIFO_EN <= 0;
            RDATA_VALID <= 0;
            WAIT_SIG <= 0;
            DATA_DONE <= 0;
            MISS <= 0;
            DONE_FETCH <= 0;
            WRITE_COMP <= 0;
            case(PS)
                IDLE : begin
                    if(!START_PREV && START) begin
                        if(WRITE) begin
                            if((TAG[ADDRESS[7:2]] == ADDRESS[13:8]) && VALID[ADDRESS[7:2]]) begin
                                CACHE[ADDRESS[7:2]][ADDRESS[1:0]] <= WDATA;
                            end
                            MEM_ACCESS <= {1'b1,1'b1,ADDRESS,WDATA};
                            FIFO_EN <= 1;
                            WRITE_COMP <= 1;
                        end
                        else if(READ) begin
                            if((TAG[ADDRESS[7:2]] == ADDRESS[13:8]) && VALID[ADDRESS[7:2]]) begin
                                MEM_DATA <= CACHE[ADDRESS[7:2]][ADDRESS[1:0]];
                                RDATA_VALID <= 1;
                            end
                            else begin
                                MISS <= 1;
                                SEND_ADDR <= ADDRESS;
                            end
                        end
                    end
                end
                FETCH : begin
                    if(!WAIT_SIG && !DONE_FETCH) begin
                        if(count == 3) line_done <= 1;
                        else line_done <= 0;
                        if(!line_done) begin
                           MEM_ACCESS <= {1'b1,1'b0,{SEND_ADDR[13:2],count},32'b0};
                            FIFO_EN <= 1;
                            WAIT_SIG <= 1; 
                        end
                        else begin
                            TAG[SEND_ADDR[7:2]] <= SEND_ADDR[13:8];
                            DONE_FETCH <= 1;
                            VALID[SEND_ADDR[7:2]] <= 1;
                            count <= 0;
                            RDATA_VALID <= 1;
                            MEM_DATA <= RET_DATA;
                        end
                    end
                end
                WAIT : begin
                    if(DATA_MEM_DATA[32] && !DATA_DONE) begin
                        CACHE[SEND_ADDR[7:2]][count] <= DATA_MEM_DATA[31:0];
                        DATA_DONE <= 1;
                        count <= count + 1;
                        if(count == SEND_ADDR[1:0]) begin
                            RET_DATA[31:0] <= DATA_MEM_DATA[31:0];
                        end
                    end
                end
            endcase
        end
    end
    
endmodule

