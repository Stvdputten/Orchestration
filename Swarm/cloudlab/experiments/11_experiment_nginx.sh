#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiment that has the nginx conf settings changed, worker process settings in the conf"

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

# The resources have been set, now we rerun the baseline to ensure that the system is similar to the previous stress tests
# Running the baseline tests for all benchmarks and stressing the system
# From the previous baseline test, we need to be sure that the nginx can handle the requests and the system is stable so we decrease the threads and open connections
# This experiment should shows what the load is the benchmarks are overloaded, a.k.a. the breaking point of the systems

# Check if the requests influence the latency with different connections and max threads of tester
# Shows the breaking point of social network is not that high actually, the throughput bottlenecks around 2000 RPS
unset benchmark
for benchmark in socialNetwork; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	# for requests in 200 500 1000 1500 2000 2500 3000; do
	for requests in 200 500 1000 1500 2000 2500 3000 3500 4000 5000 6000 7000; do
		for connections in 512; do
			for threads in 8; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

unset benchmark
for benchmark in mediaMicroservices; do
	echo "Running the baseline tests stress 5 for $benchmark"
	export benchmark=$benchmark
	for requests in 200 500 1000 1500 2500 3500 4000 5000 6000 7000; do
		for connections in 512; do
			for threads in 8; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

unset benchmark
for benchmark in hotelReservation; do
	echo "Running the baseline tests stress 5 for $benchmark"
	export benchmark=$benchmark
	for requests in 3500 4000 5000 6000 7000; do
		for connections in 512; do
			for threads in 8; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

unset benchmark
for benchmark in hotelReservation; do
	echo "Running the baseline tests stress 5 for $benchmark"
	export benchmark=$benchmark
	for requests in 8000 9000 10000 11000 12000 13000 14000 15000 16000; do
		for connections in 512; do
			for threads in 8; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done