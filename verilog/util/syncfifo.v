`timescale 1ns/1ps
module syncfifo #
(
   parameter RDATA_TRANSP = 'd0,
   parameter WRD_SIZE       = 'd1,// Minimum word size = 1b, 2b, 4b, 8b, 16b......
   parameter WR_WIDTH     = 'd8, // Width of wdata
   parameter RD_WIDTH     = 'd8, // Width of rdata
   parameter WNWRD_WIDTH    = $clog2((WR_WIDTH/WRD_SIZE)+1), // Bus width for write-#words
   parameter RNWRD_WIDTH    = $clog2((RD_WIDTH/WRD_SIZE)+1), // Bus width for read-#words
   parameter DEPTH_BIT      = 'd32, // FIFO Depth in unit of bit
   parameter PTR_WIDTH = $clog2((DEPTH_BIT/WRD_SIZE)+1) // Bus width for fifo pointer
)
 (
   input                            i_clk,
   input                            i_resetn,
   
   //write
   input                            i_wreq,
   input      [WNWRD_WIDTH -1: 0]   i_wnwrd,
   input      [WR_WIDTH    -1: 0]   i_wdata,
   output                           o_wrdy,

   //read
   input                            i_rreq,
   input      [RNWRD_WIDTH -1: 0]   i_rnwrd,
   output                           o_rrdy,
   output     [RD_WIDTH    -1: 0]   o_rdata,
   output     [PTR_WIDTH   -1: 0]   o_datacnt
);

   reg [DEPTH_BIT     -1: 0] buffer;
   reg [PTR_WIDTH-1: 0] ptr;
   
   wire   write = i_wreq & o_wrdy;
   wire   read  = i_rreq & o_rrdy;
   wire   [WNWRD_WIDTH-1: 0] wnbit = write? i_wnwrd : 'd0;
   wire   [RNWRD_WIDTH-1: 0] rnbit = read ? i_rnwrd : 'd0;
   wire   [WR_WIDTH -1: 0] wdata = write? ~({(WR_WIDTH){1'b1}}<<(i_wnwrd*WRD_SIZE)) & i_wdata : 'd0;
   
   assign o_wrdy    = (DEPTH_BIT/WRD_SIZE)-ptr >= i_wnwrd;
   assign o_rrdy    = ptr >= i_rnwrd;
   assign o_rdata   = RDATA_TRANSP ? buffer[RD_WIDTH-1:0] : ~({DEPTH_BIT{1'b1}}<<(i_rnwrd*WRD_SIZE)) & buffer;
   assign o_datacnt = ptr;
   
   always @(posedge i_clk or negedge i_resetn) begin
      if(!i_resetn) begin
         ptr    <= 'd0;
         buffer <= 'd0;
      end
      else begin
         ptr    <= ptr - rnbit + wnbit;
         buffer <= (wdata<<((ptr-rnbit)*WRD_SIZE)) | (buffer>>(rnbit*WRD_SIZE));
      end
   end
endmodule