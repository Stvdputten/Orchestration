#!/usr/bin/env bash

# Running the baseline tests for all benchmarks
echo "Running the baseline tests for all benchmarks and compare it to Swarms "

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

# Ensure no earlier deployments exists 
clean_up(){

	# kill -9 $(ps -ef | grep 16686 | head -n 1 | awk '{ print $2 }') > /dev/null 2>&1
	ssh $remote "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')" > /dev/null 2>&1
	ssh $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')" > /dev/null 2>&1
	ssh $remote "sudo kill -9 \$(ps -ef | grep 16686 | head -n 1 | awk '{ print \$2 }')" > /dev/null 2>&1

	ssh $manager "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"> /dev/null 2>&1
	ssh $manager "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"> /dev/null 2>&1
	ssh $manager "sudo kill -9 \$(ps -ef | grep 16686 | head -n 1 | awk '{ print \$2 }')" > /dev/null 2>&1

	ssh $manager "cd /users/stvdp/DeathStarBench/hotelReservation/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
	ssh $manager "cd /users/stvdp/DeathStarBench/socialNetwork/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
	ssh $manager "cd /users/stvdp/DeathStarBench/mediaMicroservices/kubernetes && yes | ./scripts/zap.sh" > /dev/null 2>&1
	ssh $manager "kubectl delete namespace media-microsvc" > /dev/null 2>&1
	ssh $manager "kubectl delete namespace hotel-res" > /dev/null 2>&1
	ssh $manager "kubectl delete namespace social-network" > /dev/null 2>&1
}

clean_up
sleep 5

unset benchmark
for benchmark in socialNetwork; do
	echo "running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for requests in 500 1500 2000 3000 4000 5000 6000 10000; do
		for connections in 512; do
			for threads in 4; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

clean_up
sleep 5

unset benchmark
for benchmark in mediaMicroservices; do
	echo "running the baseline tests stress $experiment for $benchmark"
	export benchmark=$benchmark
	for requests in 500 1000 2000 3000 4000 5000; do
		for connections in 512; do
			for threads in 4; do
				./setup-experiments.sh -t $threads -c $connections -d 30 -R $requests
			done
		done
	done
done

clean_up
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

# Conclusion does it break as swarm does?