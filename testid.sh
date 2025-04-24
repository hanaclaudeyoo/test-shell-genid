#!/bin/bash
set -euo pipefail

tests_passed=0
tests_failed=0

# Helper function to get current time
get_time() {
  out=$(date +%s%3N 2>/dev/null)
  if [[ "$out" =~ ^[0-9]+$ ]]; then
    echo "$out"
    return
  fi

  if command -v perl &>/dev/null && perl -e 'use Time::HiRes' &>/dev/null; then
    perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1000'
    return
  fi

  # fallback: epoch seconds * 1000
  echo "$(( $(date +%s) * 1000 ))"
}

# Helper function to verify genid output from output.txt
#	- Takes 1 arg: expected number of ids
verify_genid_output() {
	expected_num_ids=$1
	duration_ms=$2

	# Sort output.txt and pipe into sorted.txt
	sort output.txt > sorted.txt

	# Extract first id
	start_id=$(head -n 1 sorted.txt)
	expected_id_len=${#start_id}
	start_int=$((10#$start_id))

	# Generate expected.txt
	end_int=$((start_int + expected_num_ids - 1))
	for ((i = start_int; i <= end_int; i++)); do
		printf "%0${expected_id_len}d\n" "$i"
	done > expected.txt

	# Compare output.txt to expected.txt
	comm -3 expected.txt sorted.txt > mismatch.txt
	if [[ -s mismatch.txt ]]; then
		echo "    [FAIL]"
		cat mismatch.txt
        tests_failed=$((tests_failed + 1))
	else
        if [[ $duration_ms -eq 0 ]]; then
            rate="N/A (duration 0)"
        else
            rate=$((expected_num_ids * 1000 / duration_ms))
        fi
		echo "    [PASS]"
		echo "    Generated $expected_num_ids in IDs in $duration_ms ms ($rate IDs/sec)"
		tests_passed=$((tests_passed + 1))
	fi
}

test_proc_genid() {
	num_proc=$1
	num_ids_per_proc=$2
	test_name=$3

	# Clean up previous counter files
	rm -f .counter .counter.lock output.txt sorted.txt expected.txt mismatch.txt
	# Initialize counter with 00000
	echo 0 > .counter

	echo "Running test: $test_name"
	start_time=$(get_time)
	for ((i = 1; i <= num_proc; i++)); do
		(
			for ((j = 1; j <= num_ids_per_proc; j++)); do
				genid >> output.txt
			done
		) &
	done
	wait
	end_time=$(get_time)
	duration_ms=$((end_time - start_time))

	total_expected_ids=$((num_proc * num_ids_per_proc))
	verify_genid_output "$total_expected_ids" "$duration_ms"

	return 0
}

run_tests() {
	echo "=== testid.sh ==="
	
	# Load function
	source ./genid.sh
	
	test_proc_genid 1 1 single_proc_single_id
	test_proc_genid 1 1000 single_proc_many_id
	test_proc_genid 50 1 many_proc_single_id
	test_proc_genid 50 100 many_proc_many_id
	test_proc_genid 50 100 many_proc_many_id
	test_proc_genid 50 100 many_proc_many_id
	test_proc_genid 50 100 many_proc_many_id
	test_proc_genid 50 100 many_proc_many_id # Repeated runs to check performance consistency

	total_tests=$((tests_passed + tests_failed))

	echo "=== Test Summary ==="
	echo "Tests Passed: $tests_passed"
	echo "Tests Failed: $tests_failed"
	echo "($tests_passed/$total_tests)"

	# Clean up files before exit
	rm -f .counter .counter.lock output.txt sorted.txt expected.txt mismatch.txt
	
	# Exit with code 0 if all tests passed, 1 otherwise
	if [[ $tests_failed -eq 0 ]]; then
		exit 0
	else
		exit 1
	fi
}

run_tests