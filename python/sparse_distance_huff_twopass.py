import heapq
from collections import Counter
import os

import sys
sys.setrecursionlimit(100000)

def rle_encode(measurement_rounds, max_zero_cnt):
    rle = []
    flat = [int(c) for c in measurement_rounds]

    count = 0
    idx = 0

    for i,bit in enumerate(flat):
        if bit == 0:
            if count < max_zero_cnt:
                count += 1
                continue

        # either bit is no longer 0, or exceed maximum run length
        if bit == 0: #exceeds max zero count
            assert count == max_zero_cnt
            # flush the run
            rle.append(count+1)
            idx += 1
            count = 1
        else: #not 0 anymore
            rle.append(count)
            count = 0

    return rle

class HuffmanNode:
    def __init__(self, weight, value=None, left=None, right=None):
        self.weight = weight
        self.value = value
        self.left = left
        self.right = right
    def __lt__(self, other):  # heapq requires comparator on weight
        return self.weight < other.weight

def build_codes(node, prefix='', codebook=None):
    if codebook is None:
        codebook = {}
    if node.value is not None:
        codebook[node.value] = prefix
        return codebook
    if node.left is not None:
        build_codes(node.left,  prefix + '1', codebook)
    if node.right is not None:
        build_codes(node.right, prefix + '0', codebook)
    return codebook

def frequency_table_gen(all_rle_counts, max_nz_distance):
    # Initialize all possible symbols with frequency 0, symbol space are from 0 to max_nz_distance+1
    freq_counter = Counter({i: 0 for i in range(max_nz_distance + 2)})
    # Count actual occurrences
    freq_counter.update(all_rle_counts)
    return freq_counter


def huffman_task(freq_counter):
    # Build heap
    heap = []
    for value, freq in freq_counter.items():
        heapq.heappush(heap, HuffmanNode(freq, value))
    # Build Huffman tree
    while len(heap) > 1:
        node1 = heapq.heappop(heap)
        node2 = heapq.heappop(heap)
        merged = HuffmanNode(node1.weight + node2.weight, None, node1, node2)
        heapq.heappush(heap, merged)
    # Build Huffman codes
    huffman_codes = {}
    if heap:
        huffman_root = heap[0]
        huffman_codes = build_codes(huffman_root)

    # Without grouping
    sorted_lut = sorted(huffman_codes.keys(), key=lambda x: int(x))
    return huffman_codes, sorted_lut

# Configurations
error_rates = [0.0001,0.0005,0.001]
code_distances = [19]
max_nz_distances = [510]

huff_code_length = 64

num_batches = 10000

bb_code = 0
cc_code = 0

#for bb_code
bb_total_bits_dict = {6:36,10:54,12:72,18:144,24:392}
for d, max_nz_distance in zip(code_distances, max_nz_distances):
    for e in error_rates:
        # print(f"code distance {d} error rate {e}")
        # file access
        num_rows = d+1
        num_cols = (d-1)/2
        if bb_code:
            input_dirname = f"/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/bb_inputs/circuit_noise/d_{d}/" + f"e_{e:.6f}/"
            output_dirname = f"/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/bb_outputs/compression_circuit/d_{d}/" + f"e_{e:.6f}/"
            total_bits = (d+1)*bb_total_bits_dict[d]
        elif cc_code:
            input_dirname = f"/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/cc_inputs/circuit_noise/d_{d}/" + f"e_{e:.6f}/"
            output_dirname = f"/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/cc_outputs/compression_circuit/d_{d}/" + f"e_{e:.6f}/"
            total_bits = (d+1)*3*(d**2-1)/8
        else:
            input_dirname = f"/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/inputs/circuit_noise_new/d_{d}/" + f"e_{e:.6f}/"
            output_dirname = f"/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/outputs/compression_circuit/d_{d}/" + f"e_{e:.6f}/"
            total_bits = num_rows*num_cols*(d+1)
        
        input_filename = os.path.join(input_dirname, "parity_array.in")
        os.makedirs(output_dirname, exist_ok=True)
        # print(total_bits)
        #Golden Brick Gen
        dirname_golden_out = f"/afs/eecs.umich.edu/vlsida/projects/QEC/vsim/outputs/golden_distance_huff/d_{d}/" + f"e_{e:.6f}/"
        outfile_golden = dirname_golden_out + f"bitstream_{max_nz_distance}.out"
        lutfile = dirname_golden_out + f"hufflut_{max_nz_distance}.txt"
        lengthlutfile = dirname_golden_out + f"hufflengthlut_{max_nz_distance}.txt"
        os.makedirs(dirname_golden_out, exist_ok=True)

        #RLE Compression
        nz_distances_flat = []
        nz_distances_batches = []
        with open(input_filename, 'r') as f:
            for batch in range(num_batches*2):
                lines = [f.readline().strip() for _ in range(d+1)]

                if len(lines) < d+1 or any(line == '' for line in lines):
                    break
                flat_seq = ''.join(lines)
                if set(flat_seq) == {'0'}:
                    continue

                nz_distances = rle_encode(flat_seq, max_nz_distance)                
                # print(nz_distances)
                if(batch<num_batches):
                    nz_distances_flat.extend(nz_distances)
                else:
                    nz_distances_batches.append(nz_distances)

        # Generate Huffman Tree According to Statistics from all batches
        freq_counter = frequency_table_gen(nz_distances_flat,max_nz_distance)
        huffman_codes, sorted_lut= huffman_task(freq_counter)
        num_entries = len(huffman_codes)
        max_code_len = max(len(code) for code in huffman_codes.values()) if huffman_codes else 0
        print(f"code distances {d} error rate {e} entries of Huffman table: {num_entries} max code length {max_code_len}") 
        output_filename = os.path.join(output_dirname, f"rev_sparse_distance_huff_{max_nz_distance}.out")
        bits_filename = os.path.join(output_dirname, f"rev_bits_sparse_distance_huff_{max_nz_distance}.out")

        with open(output_filename, 'w') as fout, open(bits_filename, 'w') as bout, open(outfile_golden, 'w') as fgold:
            ratios = []
            valid_batches = 0
            for i,nz_distances in enumerate(nz_distances_batches):
                # Compression Ratio
                huff_encoded_bits = sum(len(huffman_codes[v]) for v in nz_distances)
                huff_compression_ratio = total_bits / huff_encoded_bits if huff_encoded_bits != 0 else 0
                
                fout.write(f"{huff_compression_ratio:.6f}\n")
                bout.write(f"{huff_encoded_bits:.6f}\n")
                # Encoded Bitstream
                bitstream = ''.join(huffman_codes[v] for v in nz_distances)
                fgold.write(f"{bitstream}\n")

        # Print the Huffman Table to a file
        with open(lutfile, "w") as f, open(lengthlutfile,"w") as flength:
            for symbol in sorted_lut:
                code = huffman_codes[symbol]
                rev_code = code[::-1]  # reverse the bit string
                f.write(f"{rev_code.zfill(huff_code_length)}\n")
                flength.write(f"{len(code):x}\n") # length in hex