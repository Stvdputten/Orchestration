#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiment to see if we correctly identified the breaking points of the different benchmarks, hotel reservation is a bit higher because it's not using nginx"

# Run from the dir above
cd $(dirname $0)/..

# node params
export ips="configs/ips"
export manager=$(head -n 1 configs/ips)
export remote=$(head -n 1 configs/remote)

# experiment params
export experiment=$(echo "$0" | cut -d'/' -f2 | cut -d'_' -f1)
export availability=0 # 0 for high availability, 1 for low availability
export unlimited=0 # 1 for limited resources	
export horizontal=1 # 0 for vertical scaling
export vertical=1 # 0 for horizontal scaling
export N=5 # Number of iterations



# Make sure not previous deployments are running
ssh $manager "docker stack rm social-network" > /dev/null 2>&1
ssh $manager "docker stack rm media-microservices" > /dev/null 2>&1
ssh $manager "docker stack rm hotel-reservation" > /dev/null 2>&1

# We need to run the higher requests amount here to be sure it's not just a temporal thingy
# Hotel reservation has a different amount of requests, because of the nginx bottleneck

# Running the baseline tests for all benchmarks and stressing the system
# From the previous baseline test, we need to be sure that the nginx can handle the requests and the system is stable so we decrease the threads and open connections
# This experiment should shows what the load is the benchmarks are overloaded, a.k.a. the breaking point of the systems

# Check if the requests influence the latency with different connections and max threads of tester
# Shows the breaking point of social network is not that high actually, the throughput bottlenecks around 2000 RPS
# 5 jan added 20000 to just see if it can break with unlimited

clean_up() {
	ssh $manager "docker stack rm social-network" >/dev/null 2>&1
	ssh $manager "docker stack rm media-microservices" >/dev/null 2>&1
	ssh $manager "docker stack rm hotel-reservation" >/dev/null 2>&1
}


# clean_up
# for ((i = 1; i <= N; i++)); do
# 	sleep 5
# 	unset benchmark
# 	for benchmark in socialNetwork ; do
# 		export benchmark=$benchmark
# 		echo "Running the baseline tests stress $experiment for $benchmark"
# 		for requests in 500 1000 2000 3000 4000 6000 10000 15000; do
# 			for connections in 512; do
# 				for threads in 8; do
# 					./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests -N $i
# 				done
# 			done
# 		done
# 	done
# done

clean_up
for ((i = 1; i <= N; i++)); do
	sleep 5
	unset benchmark
	for benchmark in mediaMicroservices; do
		export benchmark=$benchmark
		echo "Running the baseline tests stress $experiment for $benchmark"
		for requests in 500 1000 2000 3000 4000 6000 10000 15000; do
			for connections in 512; do
				for threads in 8; do
					./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests -N $i
				done
			done
		done
	done
done

clean_up
for ((i = 1; i <= N; i++)); do
	sleep 5
	unset benchmark
	for benchmark in hotelReservation; do
		export benchmark=$benchmark
		for requests in 500 1000 2000 3000 4000 6000 10000 15000; do
			for connections in 512; do
				for threads in 8; do
					./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests -N $i
				done
			done
		done
	done
done

# Conclusion
# Seems that sn breaks the quickest, with around 2500, so tart a bit lower aorund 2000
# MM can take around 4000 requests, so start a bit lower 3000
# HR can take a lot even around 16k, but increasing it more should give it a noticeable amount of latency, so start around 14k
