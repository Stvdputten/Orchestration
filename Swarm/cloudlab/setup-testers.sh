#!/usr/bin/env bash

# Running the baseline tests for all benchmarks
echo "Running the baseline tests for all benchmarks"

for remote in $(cat configs/remote); do
	export remote=$remote
	echo "remote: $remote"
	./setup-tester.sh  &
done
