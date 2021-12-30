#!/usr/bin/env bash

# Running the baseline tests for all benchmarks and stressing the system
# From the previous baseline test, we can see that threads and connections should be high enough and do not negatively show any issues, requests can effect the latency

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

# Check if the requests influence the latency with different connections and max threads of tester 
unset benchmark
# for benchmark in mediaMicroservices hotelReservation; do
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests stress 3 for $benchmark"
	export benchmark=$benchmark
	for requests in 200 500 1000 1500 2000 2500 3000; do
		for connections in 512 1024; do
			for threads in 8 16; do
				./setup-experiments.sh -t $threads -c $connections -d 60 -R $requests
			done
		done
	done
done