#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiments to see if our expectation of 16 cores breaking the system simply because of the amount of cores on the client"

# Run from the dir above
cd $(dirname $0)/..

# node params
export ips="configs/ips"
export manager=$(head -n 1 configs/ips)
export remote=$(head -n 1 configs/remote)

# experiment params
export experiment=$(echo "$0" | cut -d'/' -f2 | cut -d'_' -f1)
export availability=0
export unlimited=0
export horizontal=1
export vertical=1

# Make sure not previous deployments are running
ssh $manager "docker stack rm social-network" > /dev/null 2>&1
ssh $manager "docker stack rm media-microservices" > /dev/null 2>&1
ssh $manager "docker stack rm hotel-reservation" > /dev/null 2>&1

#  8 vs 16 threads should overload nginx

# Running the baseline tests for all benchmarks and stressing the system
# From the previous baseline test, we need to be sure that the nginx can handle the requests and the system is stable so we decrease the threads and open connections
# This experiment should shows that the nginx breaking point is based on the connections to handle and threads overloading it.

# Check if the requests influence the latency with different connections and max threads of tester
# Shows the breaking point of social network is not that high actually, the throughput bottlenecks around 2000 RPS
unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests stress 5 for $benchmark"
	export benchmark=$benchmark
	for requests in 200 500 1000 1500 2000 2500 3000 4000 5000 6000; do
		for connections in 1024; do
			for threads in 16; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done
