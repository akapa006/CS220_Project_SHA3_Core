#!/bin/tcsh -f
# =============================================================================
# run_rtl.csh -- RTL verification of the SHA-3 core (run from sim/)
#
#   1. Regenerates the random vectors with the golden model (gen_vectors.py)
#   2. Runs the vector testbench twice: back-to-back input, then +gaps
#      (random 0-3 idle cycles before each word)
#   3. Runs the hand-written corner-case testbench (test_keccak.v)
#
# Logs: rtl_vectors.log, rtl_vectors_gaps.log, rtl_hardcoded.log
# Expect: "ALL 451 VECTORS PASSED" twice, and every hard-coded case passing.
# =============================================================================
python3 ../sw/gen_vectors.py || exit 1

vcs -full64 -timescale=1ns/1ps test_keccak_vectors.v ../rtl/*.v \
    -o simv_vectors -l comp_vectors.log > /dev/null || exit 1
./simv_vectors       | tee rtl_vectors.log      | grep -E "PASSED|FAILED|FAIL"
./simv_vectors +gaps | tee rtl_vectors_gaps.log | grep -E "PASSED|FAILED|FAIL"

vcs -full64 -timescale=1ns/1ps test_keccak.v ../rtl/*.v \
    -o simv_hardcoded -l comp_hardcoded.log > /dev/null || exit 1
./simv_hardcoded | tee rtl_hardcoded.log | tail -25
