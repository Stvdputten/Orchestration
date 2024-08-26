#!/usr/bin/env bash

# WHAT THIS EXPERIMENT IS ABOUT
echo "Experiment; Template to stress the system baseline for all orchestrators with the new set limited resources"

# Run from the dir above
cd $(dirname $0)/..

# node params
export ips="configs/ips"
export manager=$(head -n 1 configs/ips)
export remote=$(head -n 1 configs/remote)

# experiment params
export experiment=$(echo "$0" | cut -d'/' -f2 | cut -d'_' -f1)
export availability=0 # 0 for high availability, 1 for low availability
export unlimited=1 # 1 for limited resources	
export horizontal=1 # 0 for vertical scaling
export vertical=1 # 0 for horizontal scaling
export N=5 # Number of iterations

# Make sure not previous deployments are running
clean_up() {
	ssh $manager "docker stack rm social-network" >/dev/null 2>&1
	ssh $manager "docker stack rm media-microservices" >/dev/null 2>&1
	ssh $manager "docker stack rm hotel-reservation" >/dev/null 2>&1
}

clean_up

# echo "We have done all"
# exit 1
for ((i = 1; i <= N; i++)); do
	sleep 
	unset benchmark
	# for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	for benchmark in socialNetwork; do
		echo "Running the baseline tests stress $experiment for $benchmark"
		export benchmark=$benchmark
		for requests in 500 1000 2000 3000 4000 6000 10000; do
			for connections in 512; do
				for threads in 8; do
					./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests -N $i
				done
			done
		done
	done
done

# for ((i = 1; i <= N; i++)); do
# 	sleep 5
# 	unset benchmark
# 	for benchmark in mediaMicroservices; do
# 		echo "running the baseline tests stress $experiment for $benchmark"
# 		export benchmark=$benchmark
# 		for requests in 500 1000 1500 2000 3000 4000 5000; do
# 			for connections in 512; do
# 				for threads in 8; do
#                                         ./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests -N $i
# 				done
# 			done
# 		done
# 	done
# done

# for ((i = 1; i <= N; i++)); do
# 	sleep 5
# 	unset benchmark
# 	for benchmark in hotelReservation; do
# 		echo "Running the baseline tests stress $experiment for $benchmark"
# 		export benchmark=$benchmark
#                 for requests in 500 1000 2000 3000 4000 6000 10000; do
# 			for connections in 512; do
# 				for threads in 8; do
#                                         ./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests -N $i
# 				done
# 			done
# 		done
# 	done
# done

clean_up

echo "Experiment $experiment has been run and is done!"

exit 0
