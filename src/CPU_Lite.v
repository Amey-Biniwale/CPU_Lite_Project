`default_nettype none

module CPU_Lite(
    // FAST CLOCK AND ACTIVE LOW RESET
    input wire FCLK,
    input wire FRESETn,
    
    // SLOW CLOCK AND ACTIVE LOW RESET
    input wire SCLK,
    input wire SRESETn,
    
    output wire [1:0] EMPTY,
    output wire [1:0] FULL
    );
    
    // PROG_MEM <--> CPU_Core
    
    wire [31:0] PROG;
    wire [11:0] PC;
    
    // CPU_Core <--> L1_Data_Cache
    
    wire START;
    wire [13:0] ADDRESS;
    wire [31:0] WDATA;
    wire WRITE;
    wire READ;
    
    wire [31:0] RDATA;
    wire RDATA_VALID;
    wire WRITE_COMP;
    
    // L1_Data_Cache <--> ASYNC FIFO
    
    wire [47:0] MEM_ACCESS;
    wire [47:0] FIFO_DATA_MEM;
    wire EN_CAC_MEM;
    
    wire [32:0] DATA_FIFO_CACHE;
    
    // ASYNC FIFO <--> DATA MEMORY
    
    wire EN_MEM_CAC;
    wire [32:0] DATA_MEM_FIFO;
    
    PROG_MEM prog(
        .PC(PC),
        .PROG(PROG)
    );
    
    CPU_Core core(
        .FCLK(FCLK),
        .FRESETn(FRESETn),
        
        .PROG(PROG),
        
        .RDATA(RDATA),
        .RDATA_VALID(RDATA_VALID),
        .WRITE_COMP(WRITE_COMP),
        
        .PC(PC),
        
        .START(START),
        .ADDRESS(ADDRESS),
        .WDATA(WDATA),
        .WRITE(WRITE),
        .READ(READ)
    );
    
    L1_Data_Cache cache(
        .FCLK(FCLK),
        .FRESETn(FRESETn),
        
        .START(START),
        .ADDRESS(ADDRESS),
        .WDATA(WDATA),
        .WRITE(WRITE),
        .READ(READ),
        
        .MEM_DATA(RDATA),
        .RDATA_VALID(RDATA_VALID),
        .WRITE_COMP(WRITE_COMP),
        
        .DATA_MEM_DATA(DATA_FIFO_CACHE),
        
        .MEM_ACCESS(MEM_ACCESS),
        .FIFO_EN(EN_CAC_MEM)
    );
    
    async_fifo #(
        .WIDTH(48),
        .DEPTH(4)
    ) fifo_cache_mem(
        .wr_clk(FCLK),
        .rd_clk(SCLK),
        .wr_en(EN_CAC_MEM),
        .rd_en(!EMPTY[0]),
        .wr_rst(FRESETn),
        .rd_rst(SRESETn),
        .din(MEM_ACCESS),
        .dout(FIFO_DATA_MEM),
        .full(FULL[0]),
        .empty(EMPTY[0])
    );
    
    async_fifo #(
        .WIDTH(33),
        .DEPTH(4)
    ) fifo_mem_cache(
        .wr_clk(SCLK),
        .rd_clk(FCLK),
        .wr_en(EN_MEM_CAC),
        .rd_en(!EMPTY[1]),
        .wr_rst(SRESETn),
        .rd_rst(FRESETn),
        .din(DATA_MEM_FIFO),
        .dout(DATA_FIFO_CACHE),
        .full(FULL[1]),
        .empty(EMPTY[1])
    );
    
    DATA_MEM mem(
        .SCLK(SCLK),
        .SRESETn(SRESETn),
        
        .MEM_ACCESS(FIFO_DATA_MEM),
        
        .RET_DATA(DATA_MEM_FIFO),
        .FIFO_EN(EN_MEM_CAC)
    );
endmodule

