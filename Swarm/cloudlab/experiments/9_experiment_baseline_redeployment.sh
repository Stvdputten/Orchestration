#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiment to check if redeploying each time has effect on the results (it should not be much)"

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
export N=3 # Number of iterations

# Make sure not previous deployments are running
ssh $manager "docker stack rm social-network" > /dev/null 2>&1
ssh $manager "docker stack rm media-microservices" > /dev/null 2>&1
ssh $manager "docker stack rm hotel-reservation" > /dev/null 2>&1

# We need to run the higher requests amount here to be sure it's not just a random deployment thing
# Hotel reservation has a different amount of requests, because of the nginx bottleneck

# Running the baseline tests for all benchmarks and stressing the system
# From the previous baseline test, we need to be sure that the nginx can handle the requests and the system is stable so we decrease the threads and open connections
# This experiment should shows what the load is the benchmarks are overloaded, a.k.a. the breaking point of the systems


clean_up() {
	ssh $manager "docker stack rm social-network" >/dev/null 2>&1
	ssh $manager "docker stack rm media-microservices" >/dev/null 2>&1
	ssh $manager "docker stack rm hotel-reservation" >/dev/null 2>&1
}

clean_up
# Check if the requests influence the latency with different connections and max threads of tester
# Shows the breaking point of social network is not that high actually, the throughput bottlenecks around 2000 RPS
for ((i = 1; i <= N; i++)); do
	sleep 5
	unset benchmark
	for benchmark in socialNetwork; do
		export benchmark=$benchmark
		echo "Running the baseline tests stress $experiment for $benchmark"
		for requests in 500 1000 2000 3000 4000 6000 10000 15000; do
			for connections in 512; do
				for threads in 8; do
					clean_up
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
	for benchmark in mediaMicroservices; do
		export benchmark=$benchmark
		echo "Running the baseline tests stress $experiment for $benchmark"
		for requests in 500 1000 2000 3000 4000 6000 10000 15000; do
			for connections in 512; do
				for threads in 8; do
					clean_up
					./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests -N $i
				done
			done
		done
	done
done

clean_up
# Check if the requests influence the latency with different connections and max threads of tester
# Shows the breaking point of social network is not that high actually, the throughput bottlenecks around 2000 RPS

for ((i = 1; i <= N; i++)); do
	sleep 5
	unset benchmark
	for benchmark in hotelReservation; do
		export benchmark=$benchmark
		echo "Running the baseline tests stress $experiment for $benchmark"
		for requests in 500 1000 2000 3000 4000 6000 10000 15000; do
			for connections in 512; do
				for threads in 8; do
					clean_up
					./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests -N $i
				done
			done
		done
	done
done
# Conclusion
# Doesnt seem to be consistent