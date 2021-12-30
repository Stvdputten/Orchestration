#!/usr/bin/env bash

# Running the baseline tests for all benchmarks
echo "Running the baseline tests for all benchmarks"

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

# Make sure not previous deployments are running
ssh $manager "docker stack rm social-network"
ssh $manager "docker stack rm media-microservices"
ssh $manager "docker stack rm hotel-reservation"

unset benchmark
./setup-experiments.sh -t 4 -c 8 -d 30 -R 200 

# for benchmark in socialNetwork mediaMicroservices hotelReservation; do
# 	echo "Running the baseline tests for $benchmark"
# 	export benchmark=$benchmark
# 	./setup-experiments.sh -t 4 -c 8 -d 30 -R 200 
# done
