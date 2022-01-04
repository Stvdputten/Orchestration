#!/usr/bin/env bash

# Running all the preliminary tests for all benchmarks (May take a while)

# Long running test to see if the system is stable 
echo "Running all the preliminary tests for all benchmarks (May take a while)"
./0_experiment_baseline_stress_0.sh
./1_experiment_baseline_stress_1.sh
./2_experiment_baseline_stress_2.sh
# ./3_experiment_multiple_clients.sh
./4_experiment_baseline_duration.sh
./5_experiment_baseline_stress_4.sh
# ./6_experiment_baseline_stress_5.sh
./7_experiment_baseline_stress_4.sh
# ./8_experiment_baseline_temporal_6.sh
./9_experiment_baseline_redeployment.sh
./10_experiment_baseline_duration_retrieve_params.sh
./11_experiment_baseline_stress_4.sh
