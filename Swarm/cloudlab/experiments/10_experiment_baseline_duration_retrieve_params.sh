#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiment that runs the believed breaking point params for a longer duration."

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

# This part basically retrieves the params and uses a workload that "breaks" the system.

# social-network breaks around 2500 requests (11500 ms) based on stressing tests 23/12
unset benchmark
for benchmark in socialNetwork; do
	echo "Running the baseline tests for $benchmark"
	export benchmark=$benchmark
	for duration in 300; do
		./setup-experiments.sh -t 8 -c 512 -d $duration -R 3000 
	done
done

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