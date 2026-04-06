#@ Revised Sparse Distance + Huff for DAC @#
SOURCE_ROOT =  ../../../verilog
TESTBENCH = $(SOURCE_ROOT)/sys_defs.svh \
			$(SOURCE_ROOT)/util/mem.v \
			../sparse_distance_huff_tb.sv
SIM_FILES = $(SOURCE_ROOT)/sparse_distance/sparse_distance_throughput.sv \
			$(SOURCE_ROOT)/sparse_distance/global_huffman_lookup.sv \
			$(SOURCE_ROOT)/util/syncfifo.v \
			$(SOURCE_ROOT)/sparse_distance/sparse_distance_huff.sv

CLOCK_PERIOD = 10
CODE_DISTANCE = 19
ERROR_RATE = 0.001000
NUM_BITS = 18
ZERO_CNT = 510

VV         = vcs -full64
VVOPTS     = +lint=TFIPC-L -sverilog -assert svaext -xprop=tmerge +vc -Mupdate -line -full64 -kdb -lca -nc -o $@ \
      		-debug_access+all $(VCS_BAD_WARNINGS) +define+CLOCK_PERIOD=$(CLOCK_PERIOD) +incdir+verilog/ \
			+define+CODE_DISTANCE=$(CODE_DISTANCE) +define+ERROR_RATE=$(ERROR_RATE) +define+NUM_BITS=$(NUM_BITS)  +define+ZERO_CNT=$(ZERO_CNT)

ifdef WAVES
VVOPTS += +define+DUMP_VCD=1 +memcbk +vcs+dumparrays +sdfverbose
endif

all: clean
.PHONY:clean sim

clean:
	rm -rf sim/*sim sim/*.daidir sim/csrc sim/*.key
	rm -rf sim/vcdplus.vpd sim/vc_hdrs.h
	rm -rf sim/unifiedInference.log sim/xprop.log
	rm -rf sim/*.cov sim/cov_report_* sim/cm.log
	rm -rf sim/verdi* sim/novas*
	rm -rf sim/dve* sim/inter.vpd sim/DVEfiles

###########################
#		Simulation		  #
###########################
sim:
	cd sim; $(VV) $(VVOPTS) $(TESTBENCH) $(SIM_FILES); ./$@ | tee sim_log.txt

diff:
	diff	outputs/sparse_distance_huff/d_$(CODE_DISTANCE)/e_$(ERROR_RATE)/bitstream_$(ZERO_CNT).out \
	    	outputs/golden_distance_huff/d_$(CODE_DISTANCE)/e_$(ERROR_RATE)/bitstream_$(ZERO_CNT).out