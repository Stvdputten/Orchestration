#!/usr/bin/env bash

# Running the baseline tests for all benchmarks and stressing the system
# We can derive that connections and threads used by the client influence the latency measurements.
# This is probably because the nginx server is running on a node that has 16 cores, as such connections * threads from the client will overload the system quicker
# So we rerun the tests and are expecting 8 vs 16 threads to be the most effective, because nginx is running on a node with 16 cores.

# As such we can finally see the honest breaking point of the system.

# Run from the dir above
cd $(dirname $0)/..

# From the previous baseline test, we need to be sure that the nginx can handle the requests and the system is stable so we decrease the threads and open connections
# This experiment should shows what the load is the benchmarks are overloaded, a.k.a. the breaking point of the systems
# t/m 3000

# This part is running seperately 
ips="configs/ips"
export ips=$ips
manager=$(head -n 1 configs/ips)
export manager=$manager
remote=$(head -n 1 configs/remote)
export remote=$remote
experiment=5
export experiment=$experiment

# Remove any stack of previous experiments
ssh $manager "docker stack rm social-network"
ssh $manager "docker stack rm media-microservices"
ssh $manager "docker stack rm hotel-reservation"

# Shows the breaking point of media microservices is around the throughput bottlenecks around 19000 RPS
unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests stress 5 for $benchmark"
	export benchmark=$benchmark
	# for requests in 2500 3000 3500 4000 5000 6000; do
	for requests in 200 500 1000 1500 2000 2500 3000; do
		for connections in 512; do
			for threads in 8; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

# ssh $manager "docker stack rm social-network"
# ssh $manager "docker stack rm media-microservices"
# ssh $manager "docker stack rm hotel-reservation"