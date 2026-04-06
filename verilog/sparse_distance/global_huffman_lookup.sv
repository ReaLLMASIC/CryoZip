module global_huffman_lookup#(
    parameter MAX_CODE_DISTANCE = `MAX_CODE_DISTANCE,
    parameter MAX_ZERO_CNT = `MAX_ZERO_CNT,
    parameter MAX_NUM_BITS = `MAX_NUM_BITS, // number of bits being processed each cycle.
    parameter MAX_OUTPUT_NUM = `MAX_OUTPUT_NUM, //number of stored indicies per eDRAM wordline

    parameter HUFF_LUT_DEPTH = `HUFF_LUT_DEPTH,
    parameter HUFF_CODE_LENGTH = `HUFF_CODE_LENGTH,

    parameter IDX_PER_WL = `IDX_PER_WL,
    
    parameter IN_FIFO_WRD_SIZE = $clog2(HUFF_LUT_DEPTH),
    parameter IN_FIFO_RD_WIDTH = (IDX_PER_WL*IN_FIFO_WRD_SIZE),
    parameter IN_FIFO_WR_WIDTH = (MAX_OUTPUT_NUM*IN_FIFO_WRD_SIZE),
    parameter IN_FIFO_DEPTH_BIT = (1*IN_FIFO_WR_WIDTH), //put this to global sysdef
    parameter IN_FIFO_RNWRD_WIDTH = $clog2(IDX_PER_WL+1),
    parameter IN_FIFO_WNWRD_WIDTH = $clog2(MAX_OUTPUT_NUM+1),
    parameter IN_FIFO_PTR_WIDTH = $clog2((IN_FIFO_DEPTH_BIT/IN_FIFO_WRD_SIZE)+1),

    parameter TX_FIFO_WRD_SIZE = `TX_FIFO_WRD_SIZE,
    parameter TX_FIFO_RD_WIDTH = `TX_FIFO_RD_WIDTH,
    parameter TX_FIFO_WR_WIDTH = `TX_FIFO_WR_WIDTH,
    parameter TX_FIFO_DEPTH_BIT = `TX_FIFO_DEPTH_BIT, //tx fifo depth in bits
    parameter TX_FIFO_RNWRD_WIDTH = $clog2((TX_FIFO_RD_WIDTH/TX_FIFO_WRD_SIZE)+1),
    parameter TX_FIFO_WNWRD_WIDTH = $clog2((TX_FIFO_WR_WIDTH/TX_FIFO_WRD_SIZE)+1),
    parameter TX_FIFO_PTR_WIDTH = $clog2((TX_FIFO_DEPTH_BIT/TX_FIFO_WRD_SIZE)+1)
    
)(

    input                                                           clk,
    input                                                           rstn,

    //Huffman index input   
    input  [MAX_OUTPUT_NUM-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]         huff_lut_index,
    input  [MAX_OUTPUT_NUM-1:0]                                     huff_lut_index_vld,
    input                                                           huff_lut_index_last,

    //Read Huffman code length  
    input  [IDX_PER_WL-1:0][$clog2(HUFF_CODE_LENGTH):0]             huff_code_length_rd_data,
    output logic[IDX_PER_WL-1:0]                                    huff_code_length_rd_req,
    output logic[IDX_PER_WL-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]        huff_code_length_rd_addr,

    //Read Huffman code
    input  [IDX_PER_WL-1:0][HUFF_CODE_LENGTH-1:0]                   huff_code_rd_data,
    output logic[IDX_PER_WL-1:0]                                    huff_code_rd_req,
    output logic[IDX_PER_WL-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]        huff_code_rd_addr,

    //TX FIFO Read
    output logic                                                    tx_out_vld,
    output logic[TX_FIFO_RD_WIDTH-1:0]                              tx_out_data,
    output logic                                                    tx_out_last);

logic  [MAX_OUTPUT_NUM-1:0][$clog2(HUFF_LUT_DEPTH)-1:0] huff_lut_index_reg;
logic  [MAX_OUTPUT_NUM-1:0]                             huff_lut_index_vld_reg;
logic                                                   huff_lut_index_last_reg;
logic                                                   in_last;

logic   [IDX_PER_WL-1:0]                                huff_info_valid;

logic                                                   tx_last, tx_last_d, tx_last_dd;

logic                                                   in_fifo_wreq;
logic   [IN_FIFO_WNWRD_WIDTH-1:0]                       in_fifo_wnwrd, next_in_fifo_wnwrd;
logic   [IN_FIFO_WR_WIDTH-1:0]                          in_fifo_wdata, next_in_fifo_wdata;
logic                                                   in_fifo_wrdy;

logic                                                   in_fifo_rreq, next_in_fifo_rreq;
logic   [IN_FIFO_RNWRD_WIDTH-1:0]                       in_fifo_rnwrd, next_in_fifo_rnwrd;
logic                                                   in_fifo_rrdy;
logic   [IN_FIFO_RD_WIDTH-1:0]                          in_fifo_rdata;

logic   [IN_FIFO_PTR_WIDTH-1:0]                         in_fifo_datacnt;
logic                                                   in_fifo_last;

logic                                                   tx_fifo_wreq;
logic   [TX_FIFO_WNWRD_WIDTH-1:0]                       tx_fifo_wnwrd, next_tx_fifo_wnwrd;
logic   [TX_FIFO_WR_WIDTH-1:0]                          tx_fifo_wdata, next_tx_fifo_wdata;
logic                                                   tx_fifo_wrdy;

logic                                                   tx_fifo_rreq, next_tx_fifo_rreq;
logic   [TX_FIFO_RNWRD_WIDTH-1:0]                       tx_fifo_rnwrd, next_tx_fifo_rnwrd;
logic                                                   tx_fifo_rrdy;
logic   [TX_FIFO_RD_WIDTH-1:0]                          tx_fifo_rdata;

logic   [TX_FIFO_PTR_WIDTH-1:0]                         tx_fifo_datacnt;

logic                                                   next_last_hold, last_hold, last_hold_d;
logic                                                   next_ilast_hold, ilast_hold, ilast_hold_d;

//Input Gating
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        huff_lut_index_vld_reg <= 0;
        huff_lut_index_last_reg <= 0;
    end
    else begin
        huff_lut_index_vld_reg <= huff_lut_index_vld;
        huff_lut_index_last_reg <= huff_lut_index_last;
    end
end
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        huff_lut_index_reg <= 0;
    end
    else if(|huff_lut_index_vld)begin
        huff_lut_index_reg <= huff_lut_index;
    end
end

//IN FIFO Write logic
always_comb begin
    next_in_fifo_wnwrd = 0;
    next_in_fifo_wdata = huff_lut_index_reg;

    for(int i=0;i<MAX_OUTPUT_NUM;i++) begin
        if(huff_lut_index_vld_reg[i])
            next_in_fifo_wnwrd = next_in_fifo_wnwrd+1;
    end
end
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        in_fifo_wnwrd <= 0;
        in_fifo_wdata <= 0;
    end
    else if(|huff_lut_index_vld_reg)begin
        in_fifo_wnwrd <= next_in_fifo_wnwrd;
        in_fifo_wdata <= next_in_fifo_wdata;
    end
end
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        in_fifo_wreq <= 0;
    end
    else begin
        in_fifo_wreq <= |huff_lut_index_vld_reg;
    end
end

//IN FIFO Read logic
assign in_fifo_rreq = (ilast_hold_d & ~ilast_hold) ? (in_fifo_datacnt>0) : in_fifo_rrdy;
assign in_fifo_rnwrd = (ilast_hold_d & ~ilast_hold) ? in_fifo_datacnt : IN_FIFO_RD_WIDTH;
always_comb begin
    next_ilast_hold = ilast_hold;
    if(in_last) begin
        next_ilast_hold = 1;
    end
    else if(ilast_hold) begin //ilast_hold aligns with fifo ptr update after final write to fifo.
        next_ilast_hold = in_fifo_rrdy;
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        in_last <= 0;
    end
    else begin
        in_last <= huff_lut_index_last_reg; 
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        ilast_hold <= 0;
        ilast_hold_d<=0;
        in_fifo_last <= 0;
    end
    else begin
        ilast_hold <= next_ilast_hold;
        ilast_hold_d<=ilast_hold;
        in_fifo_last <= (ilast_hold_d & ~ilast_hold);
    end
end

//Input FIFO
syncfifo #(
    .RDATA_TRANSP (1'b0),//TODO: See if this can set to 1
    .WRD_SIZE     (IN_FIFO_WRD_SIZE),
    .WR_WIDTH     (IN_FIFO_WR_WIDTH),
    .RD_WIDTH     (IN_FIFO_RD_WIDTH),
    .DEPTH_BIT    (IN_FIFO_DEPTH_BIT)
) u_in_syncfifo (
    .i_clk     (clk),
    .i_resetn  (rstn),

    .i_wreq    (in_fifo_wreq),
    .i_wnwrd   (in_fifo_wnwrd),
    .i_wdata   (in_fifo_wdata),
    .o_wrdy    (in_fifo_wrdy),

    // Read interface
    .i_rreq    (in_fifo_rreq),
    .i_rnwrd   (in_fifo_rnwrd),
    .o_rrdy    (in_fifo_rrdy),
    .o_rdata   (in_fifo_rdata),

    .o_datacnt (in_fifo_datacnt)
);

//Huff Table look up
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        huff_code_rd_req <= 0;
        huff_code_length_rd_req <= 0;
        
    end
    else begin
        for(int i=0;i<in_fifo_rnwrd;i++) begin
            huff_code_rd_req[i] <= in_fifo_rrdy & in_fifo_rreq;
            huff_code_length_rd_req[i] <= in_fifo_rrdy & in_fifo_rreq;
        end
    end
end
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        huff_code_length_rd_addr <= 0;
        huff_code_rd_addr <= 0;
        
    end
    else if((in_fifo_rrdy & in_fifo_rreq)) begin
        for(int i=0;i<in_fifo_rnwrd;i++) begin
            huff_code_rd_addr[i] <= in_fifo_rdata[i*$clog2(HUFF_LUT_DEPTH)+:$clog2(HUFF_LUT_DEPTH)];
            huff_code_length_rd_addr[i] <= in_fifo_rdata[i*$clog2(HUFF_LUT_DEPTH)+:$clog2(HUFF_LUT_DEPTH)];
        end
    end
end

//Code length and Huffman Codebook look up
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        huff_info_valid <= 0;
        tx_last_d <= 0;
        tx_last <= 0;
    end
    else begin
        huff_info_valid <= huff_code_rd_req | huff_code_length_rd_req;
        tx_last_d <= tx_last;
        tx_last <= in_fifo_last;
    end
end

//FIFO write logic
always_comb begin
    next_tx_fifo_wdata = 0;
    next_tx_fifo_wnwrd = 0;
    for(int i=IDX_PER_WL-1;i>=0;i--) begin
        if((next_tx_fifo_wnwrd==0) && (huff_info_valid[i]==1)) begin
            next_tx_fifo_wdata = huff_code_rd_data[i];
            next_tx_fifo_wnwrd = huff_code_length_rd_data[i];
        end
        else if(huff_info_valid[i]==1)begin
            // $display("after shift %b",(next_tx_fifo_wdata << huff_code_length_rd_data[i]));
            next_tx_fifo_wdata = (next_tx_fifo_wdata << huff_code_length_rd_data[i]) | huff_code_rd_data[i];
            // $display("after or %b",next_tx_fifo_wdata);
            next_tx_fifo_wnwrd = next_tx_fifo_wnwrd + huff_code_length_rd_data[i];
            // $display("nwrd to write %d",huff_code_length_rd_data[i]);
        end
    end
end
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        tx_fifo_wdata <= 0;
        tx_fifo_wnwrd <= 0;
    end
    else if(|huff_info_valid) begin
        tx_fifo_wdata <= next_tx_fifo_wdata;
        tx_fifo_wnwrd <= next_tx_fifo_wnwrd;
    end
end
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        tx_fifo_wreq <= 0;
    end
    else begin
        tx_fifo_wreq <= |huff_info_valid;
    end
end

//tx_last_dd aligns with tx_fifo write signals
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        tx_last_dd <= 0;
    end
    else begin
        tx_last_dd <= tx_last_d;
    end
end

//FIFO read logic
assign tx_fifo_rreq = (last_hold_d & ~last_hold) ? (tx_fifo_datacnt>0) : tx_fifo_rrdy;
assign tx_fifo_rnwrd = (last_hold_d & ~last_hold) ? tx_fifo_datacnt : TX_FIFO_RD_WIDTH;
always_comb begin
    next_last_hold = last_hold;
    if(tx_last_dd) begin
        next_last_hold = 1;
    end
    else if(last_hold) begin //last_hold aligns with fifo ptr update after final write to fifo (tx_last_dd).
        next_last_hold = tx_fifo_rrdy;
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        last_hold <= 0;
        last_hold_d<=0;
        tx_out_last <= 0;
    end
    else begin
        last_hold <= next_last_hold;
        last_hold_d<=last_hold;
        tx_out_last <= (last_hold_d & ~last_hold);
    end
end

//FIFO output gating
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        tx_out_data <= 0;
    end
    else if(tx_fifo_rreq) begin
        tx_out_data <= tx_fifo_rdata;
    end
end
always_ff @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        tx_out_vld <= 0;
    end
    else begin
        tx_out_vld <= tx_fifo_rreq;
    end
end

//M input N output FIFO
syncfifo #(
    .RDATA_TRANSP (1'b0),
    .WRD_SIZE     (TX_FIFO_WRD_SIZE),
    .WR_WIDTH     (TX_FIFO_WR_WIDTH),
    .RD_WIDTH     (TX_FIFO_RD_WIDTH),
    .DEPTH_BIT    (TX_FIFO_DEPTH_BIT)
) u_tx_syncfifo (
    .i_clk     (clk),
    .i_resetn  (rstn),

    .i_wreq    (tx_fifo_wreq),
    .i_wnwrd   (tx_fifo_wnwrd),
    .i_wdata   (tx_fifo_wdata),
    .o_wrdy    (tx_fifo_wrdy),

    // Read interface
    .i_rreq    (tx_fifo_rreq),
    .i_rnwrd   (tx_fifo_rnwrd),
    .o_rrdy    (tx_fifo_rrdy),
    .o_rdata   (tx_fifo_rdata),

    .o_datacnt (tx_fifo_datacnt)
);

//FIFO CHECKS
always @(posedge clk) begin
    if (in_fifo_wreq===1 && in_fifo_wrdy===0) begin
        $error("IN FIFO write request asserted while FIFO not ready");
        $finish;
    end
    if (tx_fifo_wreq===1 && tx_fifo_wrdy===0) begin
        $error("TX FIFO write request asserted while FIFO not ready");
        $finish;
    end
end


endmodule