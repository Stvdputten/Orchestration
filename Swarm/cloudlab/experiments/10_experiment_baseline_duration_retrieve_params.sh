#!/usr/bin/env bash

# This part basically retrieves the params and uses a workload that "breaks" the system.

# Run from the dir above
cd $(dirname $0)/..

# Running the baseline tests for all benchmarks
echo "Running the baseline tests for all benchmarks on the influence of duration."

# This part is setting up the experiment
ips="configs/ips"
manager=$(head -n 1 configs/ips)
remote=$(head -n 1 configs/remote)
# experiment is based on the first number of the filename 
experiment=$(echo "$0" | cut -d'/' -f2 | cut -d'_' -f1)

export ips=$ips
export manager=$manager
export remote=$remote
export experiment=$experiment

ssh $manager "docker stack rm social-network"
ssh $manager "docker stack rm media-microservices"
ssh $manager "docker stack rm hotel-reservation"

# TODO add script to retrieve the params
# instead of running the pssh script, we can run the script directly

# social-network breaks around 2500 requests (11500 ms) based on stressing tests 23/12
# unset benchmark
# for benchmark in socialNetwork; do
# 	echo "Running the baseline tests for $benchmark"
# 	export benchmark=$benchmark
# 	for duration in 300; do
# 		./setup-experiments.sh -t 8 -c 512 -d $duration -R 3000 
# 	done
# done

# media-microservices breaks around 2500 requests (4000ms)
unset benchmark
for benchmark in mediaMicroservices; do
	echo "Running the baseline tests for $benchmark"
	export benchmark=$benchmark
	for duration in 300; do
		./setup-experiments.sh -t 8 -c 512 -d $duration -R 3000 
	done
done

# hotel-reservation breaks above 13000 requests (1500 ms), in temporal tests is shows 13000 but also 16000 requests gives (8500 ms)
unset benchmark
for benchmark in hotelReservation; do
	echo "Running the baseline tests for $benchmark"
	export benchmark=$benchmark
	for duration in 300; do
		./setup-experiments.sh -t 8 -c 512 -d $duration -R 16000 
	done
done