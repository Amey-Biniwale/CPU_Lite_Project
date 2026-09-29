`default_nettype none

module DATA_MEM(
    // CLOCK AND RESET
    input wire SCLK,
    input wire SRESETn,
    
    // INPUT FROM THE CACHE
    input wire [47:0] MEM_ACCESS, // VALID TRANSACTION : 47, WRITE/READ : 46, ADDRESS : 45-32, WDATA : 31-0
    
    // OUTPUT TO THE CACHE
    output reg [32:0] RET_DATA,
    output reg FIFO_EN 
    );
    
/*    reg [31:0] MEM [0:16383];
    
    always @(posedge SCLK or negedge SRESETn) begin
        if(!SRESETn) begin
            FIFO_EN <= 0;
            RET_DATA <= 0;
        end
        else begin
            FIFO_EN <= 0;
            if(MEM_ACCESS[47]) begin
                if(MEM_ACCESS[46]) begin
                    MEM[MEM_ACCESS[45:32]] <= MEM_ACCESS[31:0];
                end
                else begin
                    RET_DATA <= {1'b1,MEM[MEM_ACCESS[45:32]]};
                    FIFO_EN <= 1;
                end
             end
        end
    end */
endmodule

