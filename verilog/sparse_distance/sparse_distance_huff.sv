module sparse_distance_huff #(
    parameter MAX_CODE_DISTANCE = `MAX_CODE_DISTANCE,
    parameter MAX_ZERO_CNT = `MAX_ZERO_CNT, 
    parameter MAX_NUM_BITS = `MAX_NUM_BITS, // number of bits being processed each cycle.
    parameter MAX_OUTPUT_NUM = `MAX_OUTPUT_NUM,
    parameter MAX_NUM_ROWS = MAX_CODE_DISTANCE+1, // number of rows of ancilla qubits in the lattice
    parameter MAX_NUM_COLS = (MAX_CODE_DISTANCE-1)/2, // number of columns of ancilla qubits in the lattice
    parameter IDX_PER_WL = `IDX_PER_WL,

    parameter TX_FIFO_WRD_SIZE = `TX_FIFO_WRD_SIZE,
    parameter TX_FIFO_RD_WIDTH = `TX_FIFO_RD_WIDTH,
    parameter TX_FIFO_WR_WIDTH = `TX_FIFO_WR_WIDTH,
    parameter TX_FIFO_DEPTH_BIT = `TX_FIFO_DEPTH_BIT, //tx fifo depth in bits

    parameter HUFF_LUT_DEPTH = `HUFF_LUT_DEPTH,
    parameter HUFF_CODE_LENGTH = `HUFF_CODE_LENGTH
)(
    input   logic                                                   clk,
    input   logic                                                   rstn,

    input   COMPRESSION_CONFIG                                      compress_cfg,
    input                                                           compress_cfg_vld,

    input   [MAX_NUM_ROWS-1:0][MAX_NUM_COLS-1:0]                    measurement_round,
    input                                                           valid_in,

    //Read Huffman code length
    input   [IDX_PER_WL-1:0][$clog2(HUFF_CODE_LENGTH):0]            huff_code_length_rd_data,
    output  logic[IDX_PER_WL-1:0]                                   huff_code_length_rd_req,
    output  logic[IDX_PER_WL-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]       huff_code_length_rd_addr,

    //Read Huffman code
    input   [IDX_PER_WL-1:0][HUFF_CODE_LENGTH-1:0]                  huff_code_rd_data,
    output  logic[IDX_PER_WL-1:0]                                   huff_code_rd_req,
    output  logic[IDX_PER_WL-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]       huff_code_rd_addr,

    //TX FIFO Read
    output  logic                                                   tx_out_vld,
    output  logic[TX_FIFO_RD_WIDTH-1:0]                             tx_out_data,
    output  logic                                                   tx_out_last
);

    logic [MAX_OUTPUT_NUM-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]         rle_out;
    logic [MAX_OUTPUT_NUM-1:0]                                     compress_vld;
    logic                                                          compress_last;
    
    COMPRESSION_CONFIG                                             compress_cfg_reg;
    logic                                                          compress_cfg_vld_reg;


    // Config
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            compress_cfg_reg <= 0;
            compress_cfg_vld_reg <= 0;
        end
        else if(compress_cfg_vld) begin
            compress_cfg_reg <= compress_cfg;
            compress_cfg_vld_reg <= 1;
        end
        else begin
            compress_cfg_vld_reg <= 0;
        end
    end
    
    sparse_distance_throughput #(
        .MAX_CODE_DISTANCE(MAX_CODE_DISTANCE),
        .MAX_ZERO_CNT(MAX_ZERO_CNT),
        .MAX_NUM_BITS(MAX_NUM_BITS)
    ) sparse_distance_inst (
        .compress_cfg      (compress_cfg_reg),
        .compress_cfg_vld  (compress_cfg_vld_reg),
        .measurement_round (measurement_round),
        .valid_in          (valid_in),
        .clk               (clk),
        .rstn              (rstn),
        .rle_out           (rle_out),
        .compress_vld      (compress_vld),
        .compress_last     (compress_last)
    );

    global_huffman_lookup #(
        .MAX_CODE_DISTANCE   (MAX_CODE_DISTANCE),
        .MAX_ZERO_CNT        (MAX_ZERO_CNT),
        .HUFF_LUT_DEPTH      (HUFF_LUT_DEPTH),
        .HUFF_CODE_LENGTH    (HUFF_CODE_LENGTH),
        .TX_FIFO_WRD_SIZE    (TX_FIFO_WRD_SIZE),
        .TX_FIFO_RD_WIDTH    (TX_FIFO_RD_WIDTH),
        .TX_FIFO_WR_WIDTH    (TX_FIFO_WR_WIDTH),
        .TX_FIFO_DEPTH_BIT   (TX_FIFO_DEPTH_BIT)
    ) global_huffman_lookup_inst (
        .clk                        (clk),
        .rstn                       (rstn),
        // Huffman index input
        .huff_lut_index             (rle_out),
        .huff_lut_index_vld         (compress_vld),
        .huff_lut_index_last        (compress_last),
        // Read Huffman code length
        .huff_code_length_rd_data   (huff_code_length_rd_data),
        .huff_code_length_rd_req    (huff_code_length_rd_req),
        .huff_code_length_rd_addr   (huff_code_length_rd_addr),
        // Read Huffman code
        .huff_code_rd_data          (huff_code_rd_data),
        .huff_code_rd_req           (huff_code_rd_req),
        .huff_code_rd_addr          (huff_code_rd_addr),
        // TX FIFO Read
        .tx_out_vld                 (tx_out_vld),
        .tx_out_data                (tx_out_data),
        .tx_out_last                (tx_out_last)
    );

endmodule