#!/usr/bin/env bash

# Running the baseline tests for all benchmarks
echo "Running the baseline tests for all benchmarks"

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

# Ensure not earlier deployments exists
clean_up(){
	ssh $manager "nomad job stop -purge media-microservices" > /dev/null
	ssh $manager "nomad job stop -purge hotel-reservation" > /dev/null
	ssh $manager "nomad job stop -purge social-network" > /dev/null
}

# sleep 5

# clean_up

unset benchmark
for benchmark in socialNetwork; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for requests in 500 1500 2000 3000 4000 5000 10000 15000 20000; do
		for connections in 512; do
			for threads in 4; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

unset benchmark
for benchmark in mediaMicroservices; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for requests in 500 1000 2000 3000 4000 5000 6000 7000; do
		for connections in 512; do
			for threads in 4; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

unset benchmark
for benchmark in hotelReservation; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for requests in 500 3000 4000 6000 10000 12000 14000 16000 18000 20000; do
		for connections in 512; do
			for threads in 4; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done


echo "Experiment $experiment has been run and is done!"

exit 0
# ssh -n "$manager" "cd /users/stvdp/DeathStarBench/socialNetwork/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
# ssh -n "$manager" "cd /users/stvdp/DeathStarBench/mediaMicroservices/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
