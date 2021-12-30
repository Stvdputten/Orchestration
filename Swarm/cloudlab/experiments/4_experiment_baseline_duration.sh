#!/usr/bin/env bash

# This part basically checks the assumption of duration on the latency measurements.

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

unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests for $benchmark"
	export benchmark=$benchmark
	for duration in 30 60 150; do
		./setup-experiments.sh -t 8 -c 512 -d $duration -R 500 
	done
done
