`default_nettype none
module async_fifo #(
  parameter WIDTH = 8,              // Width of the data
  parameter DEPTH = 16              // Depth of the FIFO (must be a power of 2)
) (
  input   wire              wr_clk, // Write clock
  input   wire              rd_clk, // Read clock
  input   wire              wr_en,  // Write enable
  input   wire              rd_en,  // Read enable
  input   wire              wr_rst, // Asynchronous reset for write domain
  input   wire              rd_rst, // Asynchronous reset for read domain
  input   wire  [WIDTH-1:0] din,    // Data input
  output  reg   [WIDTH-1:0] dout,   // Data output
  output  reg               full,   // FIFO full status flag
  output  reg               empty   // FIFO empty stattus flag
);

localparam PTR_WIDTH = $clog2(DEPTH); // Calculate PTR_WIDTH from DEPTH
reg   [WIDTH-1:0] mem [0:DEPTH-1];    // FIFO Memory

// Write and read pointers
reg   [PTR_WIDTH:0] wr_ptr_bin;
reg   [PTR_WIDTH:0] rd_ptr_bin;
reg   [PTR_WIDTH:0] wr_ptr_gray;
reg   [PTR_WIDTH:0] rd_ptr_gray;
// next values of pointers
wire  [PTR_WIDTH:0] wr_ptr_bin_next;
wire  [PTR_WIDTH:0] rd_ptr_bin_next;
wire  [PTR_WIDTH:0] wr_ptr_gray_next;
wire  [PTR_WIDTH:0] rd_ptr_gray_next;
// 2-FF sync registers for pointers
reg   [PTR_WIDTH:0] wr_ptr_gray_sync1; 
reg   [PTR_WIDTH:0] wr_ptr_gray_sync2;
reg   [PTR_WIDTH:0] rd_ptr_gray_sync1; 
reg   [PTR_WIDTH:0] rd_ptr_gray_sync2;
// temp status flags
wire                full_temp;
wire                empty_temp;
// iterator
integer             i;

// write pointer and full initialization on reset
always @ (posedge wr_clk or negedge wr_rst) begin
  if (!wr_rst) begin
    wr_ptr_bin  <= 'b0;
    wr_ptr_gray <= 'b0;
    full        <= 'b0;
  end else begin
    wr_ptr_bin  <= wr_ptr_bin_next;
    wr_ptr_gray <= wr_ptr_gray_next;
    full        <= full_temp;
  end
end

// read pointer and empty initialization on reset
always @(posedge rd_clk or negedge rd_rst) begin
  if (!rd_rst) begin
    rd_ptr_bin  <= 'b0;
    rd_ptr_gray <= 'b0;
    empty       <= 1'b1;
  end else begin
    rd_ptr_bin  <= rd_ptr_bin_next;
    rd_ptr_gray <= rd_ptr_gray_next;
    empty       <= empty_temp;
  end
end

// Synchronizing write pointer to read clock domain
always @(posedge rd_clk or negedge rd_rst) begin
  if (!rd_rst) begin
    wr_ptr_gray_sync1 <= 'b0;
    wr_ptr_gray_sync2 <= 'b0;
  end else begin
    wr_ptr_gray_sync1 <= wr_ptr_gray;
    wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
  end
end

// Synchronizing read pointer to write clock domain
always @(posedge wr_clk or negedge wr_rst) begin
  if (!wr_rst) begin
    rd_ptr_gray_sync1 <= 'b0;
    rd_ptr_gray_sync2 <= 'b0;
  end else begin
    rd_ptr_gray_sync1 <= rd_ptr_gray;
    rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
  end
end

// Memory write operation
always @(posedge wr_clk or negedge wr_rst) begin
  if (!wr_rst) begin
    for (i=0;i<DEPTH;i=i+1) 
      mem[i] <= 'b0;
  end else begin
    if (wr_en && !full)
      mem[wr_ptr_bin[PTR_WIDTH-1:0]] <= din;
  end
end

// Memory read operation
always @(posedge rd_clk or negedge rd_rst) begin
  if (!rd_rst)
    dout <= 'b0;
  else if (rd_en && !empty)
    dout <= mem[rd_ptr_bin[PTR_WIDTH-1:0]];
  else begin
    dout <= 0;
  end
end

// Write and read pointer logic
assign wr_ptr_bin_next  = wr_ptr_bin + (wr_en && !full);
assign wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;
assign rd_ptr_bin_next  = rd_ptr_bin + (rd_en && !empty);
assign rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;
// Full and empty conditions
assign full_temp        = (wr_ptr_gray_next == {~rd_ptr_gray_sync2[PTR_WIDTH:PTR_WIDTH-1], rd_ptr_gray_sync2[PTR_WIDTH-2:0]});
assign empty_temp       = (rd_ptr_gray_next == wr_ptr_gray_sync2);

endmodule
