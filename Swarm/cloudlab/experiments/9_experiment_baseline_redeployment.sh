#!/usr/bin/env bash

# We need to run the higher requests amount here to be sure it's not just a random deployment thing
# Hotel reservation has a different amount of requests, because of the nginx bottleneck

# Run from the dir above
cd $(dirname $0)/..

# Running the baseline tests for all benchmarks and stressing the system
# From the previous baseline test, we need to be sure that the nginx can handle the requests and the system is stable so we decrease the threads and open connections
# This experiment should shows what the load is the benchmarks are overloaded, a.k.a. the breaking point of the systems

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

# Remove any stack of previous experiments
ssh $manager "docker stack rm social-network"
ssh $manager "docker stack rm media-microservices"
ssh $manager "docker stack rm hotel-reservation"

# Check if the requests influence the latency with different connections and max threads of tester
# Shows the breaking point of social network is not that high actually, the throughput bottlenecks around 2000 RPS
unset benchmark
for benchmark in socialNetwork mediaMicroservices; do
	echo "Running the baseline tests stress 5 for $benchmark"
	export benchmark=$benchmark
	for requests in 1500 2000 2500 3500 4000 5000 6000 7000; do
		for connections in 512; do
			for threads in 8; do
				ssh $manager "docker stack rm social-network"
				ssh $manager "docker stack rm media-microservices"
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

# Check if the requests influence the latency with different connections and max threads of tester
# Shows the breaking point of social network is not that high actually, the throughput bottlenecks around 2000 RPS
unset benchmark
for benchmark in hotelReservation; do
	echo "Running the baseline tests stress 5 for $benchmark"
	export benchmark=$benchmark
	for requests in 7000 8000 9000 10000 11000 12000 13000 14000 15000 16000; do
		for connections in 512; do
			for threads in 8; do
				ssh $manager "docker stack rm hotel-reservation"
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

# Breaking hotelreservation takes a bit of an effort
# unset benchmark
# for benchmark in hotelReservation; do
# 	echo "Running the baseline tests stress 5 for $benchmark"
# 	export benchmark=$benchmark
# 	# for requests in 200 500 1000 1500 2000 2500 3000; do
# 	# for requests in 8000 9000 10000 11000; do
# 	for requests in 8000 9000 10000 11000; do
# 		for connections in 512; do
# 			for threads in 8; do
# 				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
# 			done
# 		done
# 	done
# done

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
	for requests in 8000 9000 10000 11000 12000 13000 14000; do
		for connections in 512; do
			for threads in 8; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done