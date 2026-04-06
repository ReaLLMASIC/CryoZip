`timescale 1ns/1ps
module sparse_distance_huff_tb;
    // parameter for testbench
    parameter CODE_DISTANCE = `CODE_DISTANCE;
    parameter NUM_BITS = `NUM_BITS;
    parameter NUM_ROWS = CODE_DISTANCE + 1;
    parameter NUM_COLS = (CODE_DISTANCE-1)/2;
    parameter ZERO_CNT = `ZERO_CNT;
    
    parameter MAX_CODE_DISTANCE = `CODE_DISTANCE;
    parameter MAX_NUM_ROWS = MAX_CODE_DISTANCE + 1; // number of rows of ancilla qubits
    parameter MAX_NUM_COLS = (MAX_CODE_DISTANCE-1)/2; // number of columns of ancilla qubits
    parameter MAX_ZERO_CNT = `ZERO_CNT; //rle max zero count
    parameter MAX_NUM_BITS = `NUM_BITS; //number of bits to process per round
    parameter MAX_OUTPUT_NUM = `MAX_OUTPUT_NUM;
    parameter IDX_PER_WL = `IDX_PER_WL;

    parameter HUFF_LUT_DEPTH = `HUFF_LUT_DEPTH;
    parameter HUFF_CODE_LENGTH = `HUFF_CODE_LENGTH;

    parameter TX_FIFO_WRD_SIZE = `TX_FIFO_WRD_SIZE;
    parameter TX_FIFO_RD_WIDTH = `TX_FIFO_RD_WIDTH;
    parameter TX_FIFO_WR_WIDTH = `TX_FIFO_WR_WIDTH;
    parameter TX_FIFO_DEPTH_BIT = `TX_FIFO_DEPTH_BIT;

    parameter PROCESS_LATENCY = 100;//100ns
    parameter CLOCK_PERIOD = `CLOCK_PERIOD;
    // parameter NUM_ROUNDS = (100000/CODE_DISTANCE); // total number of measurement rounds of errors to simulate
    parameter NUM_ROUNDS = 1;
    parameter MAX_TOTAL_BITS = (MAX_CODE_DISTANCE+1)*MAX_NUM_ROWS*MAX_NUM_COLS;

    //Hardware
    logic                                                           clk;
    logic                                                           rstn;
    logic                                                           hw_valid_in;
    logic[MAX_NUM_ROWS-1:0][MAX_NUM_COLS-1:0]                       hw_syndrome_array_in;
    logic[IDX_PER_WL-1:0][$clog2(HUFF_CODE_LENGTH):0]               hw_huff_code_length_rd_data;
    logic[IDX_PER_WL-1:0]                                           hw_huff_code_length_rd_req;
    logic[IDX_PER_WL-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]               hw_huff_code_length_rd_addr;
    logic[IDX_PER_WL-1:0][HUFF_CODE_LENGTH-1:0]                     hw_huff_code_rd_data;
    logic[IDX_PER_WL-1:0]                                           hw_huff_code_rd_req;
    logic[IDX_PER_WL-1:0][$clog2(HUFF_LUT_DEPTH)-1:0]               hw_huff_code_rd_addr;
    logic                                                           hw_tx_out_vld;
    logic[TX_FIFO_RD_WIDTH-1:0]                                     hw_tx_out_data;
    logic                                                           hw_tx_out_last;
    COMPRESSION_CONFIG                                              compress_cfg_reg;
    logic                                                           compress_cfg_vld_reg;

    logic[IDX_PER_WL-1:0]                                           hw_huff_info_valid;
    logic                                                           hw_huff_info_last;
    
    //Software
    // reg [HUFF_CODE_LENGTH-1:0]                                      huff_code_lut [0:HUFF_LUT_DEPTH-1];
    // reg [$clog2(HUFF_CODE_LENGTH):0]                                huff_length_lut [0:HUFF_LUT_DEPTH-1];
    logic[MAX_TOTAL_BITS-1:0][TX_FIFO_RD_WIDTH-1:0]                 tb_tx_out_data;
    logic[MAX_CODE_DISTANCE:0][MAX_NUM_ROWS-1:0][MAX_NUM_COLS-1:0]  syndrome_array;
    logic                                                           result_ready;
    string                                                          str;
    integer                                                         hw_output_idx;
    integer                                                         cycles_count;
    
    `ifdef SYN
    sparse_distance_huff u_sparse_distance_huff (
        .clk                     (clk),
        .rstn                    (rstn),

        .compress_cfg            (compress_cfg_reg),
        .compress_cfg_vld        (compress_cfg_vld_reg),

        .measurement_round       (hw_syndrome_array_in),
        .valid_in                (hw_valid_in),

        .huff_code_length_rd_data(hw_huff_code_length_rd_data),
        .huff_code_rd_data       (hw_huff_code_rd_data),

        .huff_info_valid         (hw_huff_info_valid),
        .huff_info_last          (hw_huff_info_last)
    );
    `else
    sparse_distance_huff #(
        .MAX_CODE_DISTANCE (MAX_CODE_DISTANCE),
        .MAX_ZERO_CNT      (MAX_ZERO_CNT),
        .HUFF_LUT_DEPTH    (HUFF_LUT_DEPTH),
        .HUFF_CODE_LENGTH  (HUFF_CODE_LENGTH),
        .MAX_NUM_BITS      (MAX_NUM_BITS),
        .MAX_OUTPUT_NUM    (MAX_OUTPUT_NUM),
        .MAX_NUM_ROWS      (MAX_NUM_ROWS),
        .MAX_NUM_COLS      (MAX_NUM_COLS),
        .TX_FIFO_WRD_SIZE  (TX_FIFO_WRD_SIZE),
        .TX_FIFO_RD_WIDTH  (TX_FIFO_RD_WIDTH),
        .TX_FIFO_WR_WIDTH  (TX_FIFO_WR_WIDTH),
        .TX_FIFO_DEPTH_BIT (TX_FIFO_DEPTH_BIT)
    ) u_sparse_distance_huff (
        .clk                        (clk),
        .rstn                       (rstn),
        .compress_cfg               (compress_cfg_reg),
        .compress_cfg_vld           (compress_cfg_vld_reg),
        .measurement_round          (hw_syndrome_array_in),
        .valid_in                   (hw_valid_in),

        .huff_code_length_rd_data   (hw_huff_code_length_rd_data),
        .huff_code_length_rd_req    (hw_huff_code_length_rd_req),
        .huff_code_length_rd_addr   (hw_huff_code_length_rd_addr),

        .huff_code_rd_data          (hw_huff_code_rd_data),
        .huff_code_rd_req           (hw_huff_code_rd_req),
        .huff_code_rd_addr          (hw_huff_code_rd_addr),

        .tx_out_vld                 (hw_tx_out_vld),
        .tx_out_data                (hw_tx_out_data),
        .tx_out_last                (hw_tx_out_last)
    );

    genvar lut_gen;
    generate
        for(lut_gen=0;lut_gen<IDX_PER_WL;lut_gen=lut_gen+1) begin: LUTS
            mem_sp #(
                .DATA_BIT (HUFF_CODE_LENGTH),
                .DEPTH    (HUFF_LUT_DEPTH),
                .ADDR_BIT ($clog2(HUFF_LUT_DEPTH)),
                .BWE      (0)
            ) code_lut_inst (
                .clk   (clk),
                .addr  (hw_huff_code_rd_addr[lut_gen]),
                .wen   ('0),
                .bwe   ('0),
                .wdata ('0),
                .ren   (hw_huff_code_rd_req[lut_gen]),
                .rdata (hw_huff_code_rd_data[lut_gen])
            );

            mem_sp #(
                .DATA_BIT ($clog2(HUFF_CODE_LENGTH)+1),
                .DEPTH    (HUFF_LUT_DEPTH),
                .ADDR_BIT ($clog2(HUFF_LUT_DEPTH)),
                .BWE      (0)
            ) code_length_lut_inst (
                .clk   (clk),
                .addr  (hw_huff_code_length_rd_addr[lut_gen]),
                .wen   ('0),
                .bwe   ('0),
                .wdata ('0),
                .ren   (hw_huff_code_length_rd_req[lut_gen]),
                .rdata (hw_huff_code_length_rd_data[lut_gen])
            );
        end
    endgenerate
    `endif

    always #(CLOCK_PERIOD/2) clk = ~clk;

    // File I/0
    string filename, line;
    int status;
    int in_fd, out_fd;

    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0,sparse_distance_huff_tb); //"+all" enables all  signal dumping including Mem, packed array, etc.
        // $fsdbDumpfile("sim.fsdb");
        // $fsdbDumpvars(0,"+all",sparse_distance_huff_tb); //"+all" enables all  signal dumping including Mem, packed array, etc.
        $sformat(filename, "/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/inputs/circuit_noise_new/d_%0d/e_%0f/parity_array.in", `CODE_DISTANCE, `ERROR_RATE);
        in_fd = $fopen(filename, "r");
        $sformat(filename, "/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/outputs/sparse_distance_huff/d_%0d/e_%0f/bitstream_%0d.out", `CODE_DISTANCE, `ERROR_RATE, `ZERO_CNT);
        out_fd = $fopen(filename,"w");
    end

    `ifdef SYN
    //pass
    `else
    genvar i_gen;
    generate
        for(i_gen=0;i_gen<IDX_PER_WL;i_gen=i_gen+1) begin
            initial begin
                for(int d=0;d<HUFF_LUT_DEPTH;d++) begin
                    LUTS[i_gen].code_lut_inst.mem[d] = 0;
                    LUTS[i_gen].code_length_lut_inst.mem[d] = 0;
                end
                $sformat(filename, "/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/outputs/golden_distance_huff/d_%0d/e_%0f/hufflut_%0d.txt", `CODE_DISTANCE, `ERROR_RATE, `ZERO_CNT);
                $readmemb(filename, LUTS[i_gen].code_lut_inst.mem);
                $sformat(filename, "/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/outputs/golden_distance_huff/d_%0d/e_%0f/hufflengthlut_%0d.txt", `CODE_DISTANCE, `ERROR_RATE, `ZERO_CNT);
                $readmemh(filename, LUTS[i_gen].code_length_lut_inst.mem);
            end
        end
    endgenerate
    `endif

    initial begin
        #10 //wait for table initialization
        
        // $display("Huffman lookup table");
        // for(int d=0;d<HUFF_LUT_DEPTH;d++) begin
        //     $display("%d:%b",d,LUTS[0].code_lut_inst.mem[d]);
        // end

        clk=0;
        rstn=1;
        hw_syndrome_array_in = 0;
        hw_valid_in=0;
        compress_cfg_vld_reg = 0;
        syndrome_array = 0;
        
        repeat (10) @(negedge clk);
        rstn=0;
        repeat (10) @(negedge clk);
        rstn=1;
        repeat (10) @(negedge clk);

        `ifdef SYN
        for(int d=0;d<HUFF_LUT_DEPTH;d++) begin
            u_sparse_distance_huff.global_huffman_lookup_inst.global_huffman_lut_wrapper_inst.LUTS_0__code_lut_inst.uut.mem_core_array[d] = 1;
            u_sparse_distance_huff.global_huffman_lookup_inst.global_huffman_lut_wrapper_inst.LUTS_0__code_length_lut_inst.uut.mem_core_array[d] = 0;
        end
        // $display(u_sparse_distance_huff.global_huffman_lookup_inst.global_huffman_lut_wrapper_inst.LUTS_0__code_lut_inst.uut.mem_core_array[1]);
        $sformat(filename, "/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/outputs/golden_distance_huff/d_%0d/e_%0f/hufflut_%0d.txt", `CODE_DISTANCE, `ERROR_RATE, `ZERO_CNT);
        $readmemb(filename, u_sparse_distance_huff.global_huffman_lookup_inst.global_huffman_lut_wrapper_inst.LUTS_0__code_lut_inst.uut.mem_core_array);
        // $display(u_sparse_distance_huff.global_huffman_lookup_inst.global_huffman_lut_wrapper_inst.LUTS_0__code_lut_inst.uut.mem_core_array[1]);
        $sformat(filename, "/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/outputs/golden_distance_huff/d_%0d/e_%0f/hufflengthlut_%0d.txt", `CODE_DISTANCE, `ERROR_RATE, `ZERO_CNT);
        $readmemh(filename, u_sparse_distance_huff.global_huffman_lookup_inst.global_huffman_lut_wrapper_inst.LUTS_0__code_length_lut_inst.uut.mem_core_array);
        `endif
        
        //initialize config registers
        compress_cfg_reg.code_distance = `CODE_DISTANCE;
        compress_cfg_reg.num_cols_x_num_rows = NUM_ROWS*NUM_COLS;
        compress_cfg_reg.num_rows = NUM_ROWS;
        compress_cfg_reg.num_cols = NUM_COLS;
        compress_cfg_reg.rle_zero_cnt = ZERO_CNT;
        compress_cfg_reg.huff_base_addr =  0;
        compress_cfg_reg.num_bits = NUM_BITS;
        compress_cfg_vld_reg = 1;
        @(negedge clk);
        compress_cfg_vld_reg = 0;
        repeat (10) @(negedge clk);
        // Run through rounds of randomly generated error patterns
        for (int i = 0; i < NUM_ROUNDS; i++) begin
            
            // Parse syndrome data into an array
            for(int d = 0; d <= CODE_DISTANCE; d++) begin
                // Read input file for syndrome array
                // Every line of parity file represents the x or z ancilla at a time stamp.
                status = $fgets(line, in_fd);
                for (int j = 0; j < NUM_ROWS; j++) begin
                    for (int k = 0; k < NUM_COLS; k++) begin
                        syndrome_array[d][j][k] = line[j*NUM_COLS + k];
                        // $display("%s",line[j*NUM_COLS + k]);
                    end
                end
            end

            if(syndrome_array === 0) begin
                $display("*********************");
                $display("Round:%d, All zero syndromes, skipping", i);
                continue;
            end

            // for(int d=0;d<=CODE_DISTANCE;d++) begin
            //     $display("Syndrome Vector at t=%d", d);
            //     for(int j=0;j<NUM_ROWS;j++) begin
            //         $display("%b",syndrome_array[d][j]);
            //     end
            // end
            
            tb_tx_out_data = 0;
            result_ready = 0;
            hw_output_idx = 0;


            for(int d = 0; d<=CODE_DISTANCE;d++) begin
                hw_syndrome_array_in = syndrome_array[d];
                hw_valid_in = 1;
                @(negedge clk);
                hw_valid_in = 0;
                repeat (PROCESS_LATENCY/CLOCK_PERIOD) @(negedge clk);
            end
            
            //Wait for result
            while(~result_ready) begin
                // $display("Warning! The compression+transmission cannot finish on time");
                @(negedge clk);
            end
            result_ready = 0;

            `ifdef SYN
                //pass
            `else
            str = "";
            
            for (int q = 0; q < hw_output_idx; q++) begin
                for(int p = 0; p<TX_FIFO_RD_WIDTH ; p++) begin
                    str = {str, $sformatf("%b", tb_tx_out_data[q][p])};
                end
            end

            $fdisplay(out_fd,"%s",str);
            `endif
            // $display("%s",str);

            $display("*********************");
            $display("Round %d Completes", i);
        end

        repeat (10) @(negedge clk);

        $fclose(in_fd);
        $fclose(out_fd);
        $finish;
    end

    `ifdef SYN
    always @(negedge clk) begin
        if(hw_huff_info_last)
            result_ready = 1;
    end
    `else
    always @(negedge clk) begin
        if(hw_tx_out_vld) begin
            // $display("hw_non_zero=%b, hw_output_idx=%d",hw_non_zero[i],hw_output_idx);
            tb_tx_out_data[hw_output_idx]=hw_tx_out_data;
            hw_output_idx = hw_output_idx+1;
        end

        if(hw_tx_out_last)
            result_ready = 1;
    end

    always @(negedge clk) begin
        if(hw_valid_in) begin
            cycles_count = 0;
        end
        else begin
            cycles_count = cycles_count + 1;
        end

        if (hw_tx_out_last===1) begin
            $display("cycles till tx done %d, time %d ns",cycles_count, cycles_count*CLOCK_PERIOD);
        end
        if (u_sparse_distance_huff.compress_last===1) begin
            $display("cycles till compress done %d, time %d ns",cycles_count, cycles_count*CLOCK_PERIOD);
        end
    end
    `endif


endmodule