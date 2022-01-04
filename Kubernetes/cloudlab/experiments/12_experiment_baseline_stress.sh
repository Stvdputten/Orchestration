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
export unlimited=1

# Ensure not earlier deployments exists
clean_up(){
	kubectl delete namespace media-microsvc
	kubectl delete namespace hotel-res
	kubectl delete namespace social-network
	ssh -n $remote "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"
	ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
	ssh -n $remote "sudo kill -9 \$(ps -ef | grep 16686 | head -n 1 | awk '{ print \$2 }')"

	ssh -n $manager "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"
	ssh -n $manager "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
	ssh -n $manager "sudo kill -9 \$(ps -ef | grep 16686 | head -n 1 | awk '{ print \$2 }')"

	kill -9 $(ps -ef | grep 16686 | head -n 1 | awk '{ print $2 }') > /dev/null 2>&1

	ssh -n "$manager" "cd /users/stvdp/DeathStarBench/hotelReservation/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
	ssh -n "$manager" "cd /users/stvdp/DeathStarBench/socialNetwork/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
	ssh -n "$manager" "cd /users/stvdp/DeathStarBench/mediaMicroservices/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
}
# echo "We have done all"
# exit 1

unset benchmark
for benchmark in socialNetwork mediaMicroservices hotelReservation; do
	echo "Running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	clean_up
	# for requests in 200 500 1000 1500 2000 3000 4000 5000 6000 7000 8000 9000 10000 11000 12000 13000 14000 15000 16000; do
	for requests in 500 1000; do
		for connections in 512; do
			for threads in 8; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

# ssh -n "$manager" "cd /users/stvdp/DeathStarBench/hotelReservation/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
# ssh -n "$manager" "cd /users/stvdp/DeathStarBench/socialNetwork/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
# ssh -n "$manager" "cd /users/stvdp/DeathStarBench/mediaMicroservices/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
# ssh -n $remote "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"
# ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
# ssh -n $remote "sudo kill -9 \$(ps -ef | grep 16686 | head -n 1 | awk '{ print \$2 }')"
# kill -9 $(ps -ef | grep 16686 | head -n 1 | awk '{ print $2 }')

# unset benchmark
# for benchmark in socialNetwork mediaMicroservices; do
# 	echo "Running the baseline tests stress $experiment for $benchmark"
# 	export benchmark=$benchmark
# 	# for requests in 200 500 1000 1500 2000 3000 4000 5000 6000 7000 8000 9000 10000 11000 12000 13000 14000 15000 16000; do
# 	for requests in 200 500 ; do
# 		for connections in 512; do
# 			for threads in 8; do
# 				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
# 			done
# 		done
# 	done
# done
clean_up

echo "Experiment $experiment has been run and is done!"

exit 0
# ssh -n "$manager" "cd /users/stvdp/DeathStarBench/socialNetwork/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
# ssh -n "$manager" "cd /users/stvdp/DeathStarBench/mediaMicroservices/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
