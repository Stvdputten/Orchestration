#!/usr/bin/env bash

# Running the baseline tests for all benchmarks and stressing the system

# Run from the dir above
cd $(dirname $0)/..

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

# Check if the requests influence the latency
unset benchmark
# for benchmark in socialNetwork ; do
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests stress 1 for $benchmark"
	export benchmark=$benchmark
	for requests in 500 1000 1500 2000 2500 3000; do
		./setup-experiments.sh -t 4 -c 8 -d 30 -R $requests
	done
done

# Check if the connections influence the latency
for connections in 128 512 1024 2048; do
	./setup-experiments.sh -t 4 -c $connections -d 30 -R 200
done

# Check if the threads influence the latency
# number of connections need to be >= number of threads
for threads in 8 16; do
	./setup-experiments.sh -t $threads -c 16 -d 30 -R 200
done