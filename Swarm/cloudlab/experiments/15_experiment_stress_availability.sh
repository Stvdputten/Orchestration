#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Running the experiment "

# Run from the dir above
cd $(dirname $0)/..

# node params
export ips="configs/ips"
export manager=$(head -n 1 configs/ips)
export remote=$(head -n 1 configs/remote)

# experiment params
export experiment=$(echo "$0" | cut -d'/' -f2 | cut -d'_' -f1)
export availability=1
export unlimited=1
export horizontal=1
export vertical=1

# Make sure not previous deployments are running
ssh $manager "docker stack rm social-network" > /dev/null 2>&1
ssh $manager "docker stack rm media-microservices" > /dev/null 2>&1
ssh $manager "docker stack rm hotel-reservation" > /dev/null 2>&1

# sleep 5 

# unset benchmark
# for benchmark in socialNetwork; do
# 	echo "running the baseline tests stress $experiment for $benchmark"
# 	export benchmark=$benchmark
# 	for requests in 500 1500 2000 3000 4000 5000 6000 10000; do
# 		for connections in 512; do
# 			for threads in 4; do
# 				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
# 			done
# 		done
# 	done
# done

# sleep 5

# unset benchmark
# for benchmark in mediaMicroservices; do
# 	echo "running the baseline tests stress $experiment for $benchmark"
# 	export benchmark=$benchmark
# 	for requests in 500 1000 2000 3000 4000 5000; do
# 		for connections in 512; do
# 			for threads in 4; do
# 				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
# 			done
# 		done
# 	done
# done

sleep 5

unset benchmark
for benchmark in hotelReservation; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for requests in 500 1000 1500 2000 2500 3000 4000 6000 10000; do
		for connections in 512; do
			for threads in 4; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

echo "Experiment $experiment has been run and is done!"

exit 0
