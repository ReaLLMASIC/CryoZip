`timescale 1ns/1ps
module sparse_distance_throughput#(
    parameter MAX_CODE_DISTANCE = `MAX_CODE_DISTANCE,
    parameter MAX_ZERO_CNT = `MAX_ZERO_CNT, 
    parameter MAX_NUM_BITS = `MAX_NUM_BITS, // number of bits being processed each cycle.
    parameter HUFF_LUT_DEPTH = `HUFF_LUT_DEPTH,
    parameter MAX_OUTPUT_NUM = `MAX_OUTPUT_NUM,
    parameter MAX_NUM_ROWS = MAX_CODE_DISTANCE+1, // number of rows of ancilla qubits in the lattice
    parameter MAX_NUM_COLS = (MAX_CODE_DISTANCE-1)/2 // number of columns of ancilla qubits in the lattice
)(
    input [MAX_NUM_ROWS-1:0][MAX_NUM_COLS-1:0]                      measurement_round,
    input                                                           valid_in,
    input                                                           clk,
    input                                                           rstn,
    input COMPRESSION_CONFIG                                        compress_cfg,
    input                                                           compress_cfg_vld,
    output logic [MAX_OUTPUT_NUM-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]   rle_out, //Needs to be +1 larger, when MAX_NUM_BITS=1, The last bit of last round might have 2 simultaneous output.
    output logic [MAX_OUTPUT_NUM-1:0]                               compress_vld,
    output logic                                                    compress_last
);  
    logic [MAX_NUM_ROWS*MAX_NUM_COLS-1:0]                       measurement_rounds_reg;
    logic                                                       in_reg_vld;
    logic [$clog2(MAX_NUM_COLS*MAX_NUM_ROWS)-1:0]               next_per_round_cnt,per_round_cnt; //index of the per round bits
    logic [$clog2(HUFF_LUT_DEPTH)-1:0]                          next_bit_cnt,bit_cnt; //bit cnt of current bit
    logic [MAX_OUTPUT_NUM-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]      next_rle_out;
    logic [MAX_OUTPUT_NUM-1:0]                                  next_compress_vld; //indicate compress finish, last round
    logic [$clog2(MAX_OUTPUT_NUM)-1:0]                          next_vld_idx; 
    logic                                                       next_compress_last;
    logic [$clog2(MAX_CODE_DISTANCE):0]                         next_measurement_rounds_cnt, measurement_rounds_cnt; // Revised decoder take in d+1 rounds of input.
    logic                                                       rle_en;
    COMPRESSION_CONFIG                                          compress_cfg_reg;
    logic                                                       compress_cfg_vld_reg;

    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            measurement_rounds_reg<=0;
            in_reg_vld <=0;
        end
        else if(valid_in) begin
            measurement_rounds_reg<=measurement_round;
            in_reg_vld <=1;
        end
        else begin
            in_reg_vld<=0;
        end
    end

    always_comb begin
        next_rle_out = 0;
        next_compress_vld = 0;
        next_vld_idx = 0;
        next_compress_last = 0;
        next_per_round_cnt = per_round_cnt;
        next_measurement_rounds_cnt = measurement_rounds_cnt;
        next_bit_cnt = bit_cnt;
        
        //counters in per round input dimension
        if(per_round_cnt+MAX_NUM_BITS >= MAX_NUM_ROWS*MAX_NUM_COLS) begin//processing the last part of current input measurement round
            next_per_round_cnt = 0;
            next_measurement_rounds_cnt=measurement_rounds_cnt + 1;
        end
        else begin
            next_per_round_cnt=per_round_cnt+MAX_NUM_BITS;
        end

        for(int i=0;i<MAX_NUM_BITS;i++) begin
            if(per_round_cnt+i>MAX_NUM_ROWS*MAX_NUM_COLS-1) begin //exceed per round range, do nothing
                break;
                //do nothing
            end
            else if(measurement_rounds_reg[per_round_cnt+i] == 0 && next_bit_cnt < MAX_ZERO_CNT ) begin //counting 0 bits.
                // $display("Second case,i=%d,count=%d,idx=%d",i,next_bit_cnt,next_vld_idx);
                next_bit_cnt = next_bit_cnt + 1;
            end
            else if(measurement_rounds_reg[per_round_cnt+i] == 0) begin //exceeds max zero count, current bit is 0, then commit
                // $display("Third case,i=%d,count=%d,idx=%d",i,next_bit_cnt,next_vld_idx);
                //Cap max_zero_cnt run length of 0s with 1: commit max_zero_cnt+1
                //Cap max_zero_cnt run length of 0s with 0: commit max_zero_cnt
                next_rle_out[next_vld_idx] = MAX_ZERO_CNT+1;
                next_compress_vld[next_vld_idx] = 1;
                next_vld_idx = next_vld_idx + 1;
                next_bit_cnt = 1;
            end
            else begin //encounter 1, then commit
                // $display("Fourth case,i=%d,count=%d,idx=%d",i,next_bit_cnt,next_vld_idx);
                next_rle_out[next_vld_idx] = next_bit_cnt;
                next_compress_vld[next_vld_idx] = 1;
                next_vld_idx = next_vld_idx + 1;
                next_bit_cnt = 0;
            end

            if(measurement_rounds_cnt==MAX_CODE_DISTANCE && per_round_cnt+i==MAX_NUM_ROWS*MAX_NUM_COLS-1)begin //very last bit
                    next_compress_last = 1;
            end
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            rle_out <= 0;
            bit_cnt <= 0;
            compress_vld <= 0;
            measurement_rounds_cnt<=0;
            per_round_cnt<=0;
            compress_last <= 0;
        end
        else if(compress_last) begin
            rle_out <= 0;
            bit_cnt <= 0;
            measurement_rounds_cnt<=0;
            per_round_cnt<=0;
            compress_last<=0;
            compress_vld<= 0;
        end
        else if(in_reg_vld || rle_en)begin
            rle_out <= next_rle_out;
            bit_cnt <= next_bit_cnt;
            compress_vld <= next_compress_vld;
            compress_last <= next_compress_last;
            per_round_cnt <= next_per_round_cnt;
            measurement_rounds_cnt <= next_measurement_rounds_cnt;
        end
        else begin
            compress_vld <= 0;
        end
    end

    //rle enable signal
    always_ff @(posedge clk or negedge rstn)begin
        if(!rstn) begin
            rle_en <= 0;
        end
        else if(per_round_cnt+MAX_NUM_BITS>=MAX_NUM_ROWS*MAX_NUM_COLS) begin//processing the last row, last column of current round.
            rle_en <= 0;
        end
        else if(in_reg_vld) begin
            rle_en <= 1;
        end
    end

endmodule