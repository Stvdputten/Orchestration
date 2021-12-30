#!/usr/bin/env bash

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

# update the DSB after updating the files to make sure the deployments files are up to date
pssh -i -h $ips "cd DeathStarBench && git pull && git reset --hard origin/local"
pssh -i -h $remotes "cd DeathStarBench && git reset --hard origin/local && git pull"
echo "Running the baseline tests for all benchmarks on the influence of multiple clients"

# Run workloads on all remotes
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests for $benchmark"
	export benchmark=$benchmark
	for remote in $(cat configs/remote); do
		export remote=$remote
		./setup-experiments_multi_clients.sh -t 8 -c 512 -d 30 -R 200 
	done
done

done
echo "All experiment have been run (hopefully)."