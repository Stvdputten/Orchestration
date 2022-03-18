#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiments to explore the current chosen setup with multiple clients and unlimited params"

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
export clients=0

# Make sure not previous deployments are running
ssh $manager "docker stack rm social-network" > /dev/null 2>&1
ssh $manager "docker stack rm media-microservices" > /dev/null 2>&1
ssh $manager "docker stack rm hotel-reservation" > /dev/null 2>&1

# Run workloads on all remotes
unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	export clients=0
	for remote in $(cat configs/remote); do
		export remote=$remote
		export clients=$((clients+1))
		./setup-experiments.sh -t 8 -c 512 -d 30 -R 500 
	done
done

echo "All experiment have been run (hopefully)."

# Conculsion 
# The multiple clients don't make any big (> 1 ms) difference for the baseline