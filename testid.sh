#!/bin/bash
set -euo pipefail

tests_passed=0
tests_failed=0

# Helper function to verify genid output from output.txt
#	- Takes 1 arg: expected number of ids
verify_genid_output() {
	expected_num_ids=$1

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
		echo " - FAIL"
		cat mismatch.txt
		((tests_failed++))
	else
		echo " - PASS"
		((tests_passed++))
	fi
}

test_single_proc_single_id() {
	echo "Running test: single proc single id"

	# Clean up previous counter files
	rm -f .counter .counter.lock output.txt sorted.txt expected.txt mismatch.txt
	# Initialize counter with 00000
	echo 0 > .counter

	# Call genid once on one process
	id=$(genid)

	# Check id is valid
	if [[ "$id" == "00001" ]]; then
		echo " - PASS"
		((tests_passed++))
	else
		echo " - FAIL: - got $id"
		((tests_failed++))
	fi
	return 0
}

test_single_proc_many_ids() {
	echo "Running test: single proc many ids"

	# Clean up previous counter files
	rm -f .counter .counter.lock output.txt sorted.txt expected.txt mismatch.txt
	# Initialize counter with 00000
	echo 0 > .counter

	# Generate 1000 ids with one process
	for i in {1..1000}; do
		genid >> output.txt
	done

	verify_genid_output 1000
	return 0
}

test_many_proc_single_id() {
	echo "Running test: many proc single id"

	# Clean up previous counter files
	rm -f .counter .counter.lock output.txt sorted.txt expected.txt mismatch.txt
	# Initialize counter with 00000
	echo 0 > .counter

	# Fork 20 processes
	for i in {1..20}; do
		(
			genid >> output.txt
		) &
	done
	wait

	verify_genid_output 20
	return 0
}

test_many_proc_many_id() {
	echo "Running test: many proc many id"

	# Clean up previous counter files
	rm -f .counter .counter.lock output.txt sorted.txt expected.txt mismatch.txt
	# Initialize counter with 00000
	echo 0 > .counter

	# Fork 20 processes
	for i in {1..20}; do
		(
			for j in {1..200}; do
				genid >> output.txt
			done
		) &
	done
	wait

	verify_genid_output 4000
	return 0
}

run_tests() {
	echo "=== testid.sh ==="
	
	# Load function
	source ./genid.sh
	
	test_single_proc_single_id
	test_single_proc_many_ids
	test_many_proc_single_id
	test_many_proc_many_id

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