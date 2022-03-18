#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiments to explore effect of duration on the measurements"

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

unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests $experiment for $benchmark"
	export benchmark=$benchmark
	for duration in 30 60 150; do
		./setup-experiments.sh -t 4 -c 512 -d $duration -R 500 
	done
done


# Conclusion
# Duration shows similar results