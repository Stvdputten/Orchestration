#!/usr/bin/env bash

# Running all the preliminary tests for all benchmarks (May take a while)

# Long running test to see if the system is stable 
echo "Running all the preliminary tests for all benchmarks (May take a while)"
./12_experiment_baseline_stress.sh
./13_experiment_stress_vertical.sh
# ./14_experiment_stress_horizontal.sh
# ./15_experiment_stress_availability.sh