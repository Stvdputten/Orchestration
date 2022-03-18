#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiments to explore the params for wrk and how they influence the results"

# Run from the dir above
cd $(dirname $0)/..
# node params
export ips="configs/ips"
export manager=$(head -n 1 configs/ips)
export remote=$(head -n 1 configs/remote)

# experiment params
export experiment=$(echo "$0" | cut -d'/' -f2 | cut -d'_' -f1)
export availability=0
export unlimited=1
export horizontal=1
export vertical=1

# Make sure not previous deployments are running
ssh $manager "docker stack rm social-network" > /dev/null 2>&1
ssh $manager "docker stack rm media-microservices" > /dev/null 2>&1
ssh $manager "docker stack rm hotel-reservation" > /dev/null 2>&1

# Check if the requests influence the latency
unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for requests in 500 1000 1500 2000 2500 3000; do
		./setup-experiments.sh -t 4 -c 8 -d 30 -R $requests
	done
done

# Check if the connections influence the latency
unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for connections in 128 512 1024 2048; do
		./setup-experiments.sh -t 4 -c $connections -d 30 -R 200
	done
done

# Check if the threads influence the latency
# number of connections need to be >= number of threads
unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for threads in 4 8 16; do
		./setup-experiments.sh -t $threads -c 16 -d 30 -R 200
	done
done

# Conclusion
# Require more indepth search