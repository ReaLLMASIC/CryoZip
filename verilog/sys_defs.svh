`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__

//For baseline compression
`define CODE_DISTANCE 3
`define NUM_BITS 1
//For GEO and DZC
`define K 9
`define W 8

`define MAX_CODE_DISTANCE 19
`define MAX_NUM_ROWS (`MAX_CODE_DISTANCE+1)
`define MAX_NUM_COLS ((`MAX_CODE_DISTANCE-1)/2)
`define MAX_SYNDROME_PER_ROUND (`MAX_NUM_ROWS*`MAX_NUM_COLS)
//Accounting for X&Z syndrome and process serially
//If X only, 18 is enough for d=19
`define MAX_NUM_BITS 36
//maximum valid output of compression
`define MAX_OUTPUT_NUM 18
//0-510+1
`define MAX_ZERO_CNT 510

//Huffman Table
`define HUFF_CODE_LENGTH 64
`define HUFF_LUT_DEPTH 512

//Global Huffmantable Lookup
`define IDX_PER_WL 1
`define TX_FIFO_WRD_SIZE 1
`define TX_FIFO_RD_WIDTH 1
`define TX_FIFO_WR_WIDTH (`IDX_PER_WL * `HUFF_CODE_LENGTH)
`define TX_FIFO_DEPTH_BIT (64 * `TX_FIFO_WR_WIDTH)

//Config
typedef struct packed {
    logic   [$clog2(`MAX_CODE_DISTANCE):0]         code_distance;
    logic   [$clog2(`MAX_SYNDROME_PER_ROUND):0]    num_cols_x_num_rows;
    logic   [$clog2(`MAX_NUM_ROWS):0]              num_rows;
    logic   [$clog2(`MAX_NUM_COLS):0]              num_cols;
    logic   [$clog2(`MAX_ZERO_CNT):0]              rle_zero_cnt;
    logic   [$clog2(`HUFF_LUT_DEPTH)-1:0]          huff_base_addr; //used in group_huffman_throughput.sv
    logic   [$clog2(`MAX_NUM_BITS):0]              num_bits;
}COMPRESSION_CONFIG;

`endif
