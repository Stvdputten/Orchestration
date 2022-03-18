#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiments to DEEPER explore the params for wrk and how they influence the results"

# Run from the dir above
cd $(dirname $0)/..

# node params
export ips="configs/ips2"
export manager=$(head -n 1 configs/ips2)
export remote=$(head -n 1 configs/remote2)

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

# Check if the requests influence the latency with different connections and max threads of tester
# From stress 1 we see that requests when everything is consistent, influances the latency of the system 
# The latency is stable if we increase the connection

# Furthermore if we increase the threads, the latency is also stable 
# Thus we vary the requests and see if that influences the latency
unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do 
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for requests in 200 500; do
		for connections in 128 512 1024; do
			for threads in 4 8 16; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

# Conclusion
# We only see difference in the amount of requests send