#!/usr/bin/env bash

# This part is running seperately 
ips="configs/ips"
manager=$(head -n 1 configs/ips)
remote=$(head -n 1 configs/remote)

# Make sure prometheus isn't installed in home directory
# pssh -i -h $ips "git clone https://github.com/Stvdputten/DeathStarBench"

# update the DSB after updating the files
pssh -i -h $ips "cd DeathStarBench && git pull && git reset --hard origin/local"
ssh -n $remote "cd DeathStarBench && git reset --hard origin/local && git pull"

# benchmark="socialNetwork"
# benchmark="mediaMicroservices"
benchmark="hotelReservation"
date=$(date "+%d-%m-%y")
mkdir -p ./results/$date
# deploy 1 of the services
for benchmark in socialNetwork mediaMicroservices hotelReservation
do
	if [ $benchmark == "hotelReservation" ]; then
		echo "Deploying hotelReservation app"
		ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-compose-swarm-local.yml hotel-reservation"
		echo "hotelReservation app is ready to be experimented on."
		benchmark="hotel-reservation"
		ssh $manager "docker stack services $benchmark" | grep '0/1'
		while [ $? -ne 1 ]; do
			echo "waiting for swarm services to be ready"
			sleep 5
			ssh $manager "docker stack services $benchmark" | grep '0/1' 
		done

		# get address of the nginx and jaeger service
		node_name_nginx=$(ssh $manager "docker service ps hotel-reservation_frontend | awk 'FNR == 2 {print \$4}'")
		node_name_jaeger=$(ssh $manager "docker service ps hotel-reservation_jaeger | awk 'FNR == 2 {print \$4}'")
		echo "hotelReservation app is ready to be experimented on."

		echo "hotelReservation workloads are being run..."
		ssh -n $remote "cd DeathStarBench/hotelReservation/wrk2 && export nginx_ip=$node_name_nginx && ./workload.sh" > ./results/$date/swarm-hr-wrk-mixed.txt
		echo "hotelReservation workloads done."

		# Stop the benchmark
		ssh -n $manager "docker stack rm $benchmark"
		echo "hotelReservation experiment cleaned up."

	elif [ $benchmark == "mediaMicroservices" ]; then
		echo "Deploying mediaMicroservices app"
		benchmark="media-microservices"
		# ssh -n $manager "docker stack rm $benchmark"
		ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-compose-swarm.yml media-microservices"
		ssh $manager "docker stack services $benchmark" | grep '0/1' 
		while [ $? -ne 1 ]; do
			echo "waiting for swarm services to be ready"
			sleep 5
			ssh $manager "docker stack services $benchmark" | grep '0/1' 
		done

		# get address of the nginx and jaeger service
		node_name_nginx=$(ssh $manager "docker service ps media-microservices_nginx-web-server | awk 'FNR == 2 {print \$4}'")
		node_name_jaeger=$(ssh $manager "docker service ps media-microservices_jaeger | awk 'FNR == 2 {print \$4}'")

		# Load the dataset 
		ssh -n stvdp@$node_name_nginx "cd DeathStarBench/mediaMicroservices/scripts && python3 write_movie_info.py && ./register_movies.sh && ./register_users.sh" > /dev/null
		echo "mediaMicroservices app is ready to be experimented on."

		echo "mediaMicroservices workloads are being run..."
		ssh -n $remote "cd DeathStarBench/mediaMicroservices/wrk2 && export nginx_ip=$node_name_nginx && ./workload.sh" > ./results/$date/swarm-mm-wrk-compose.txt
		echo "mediaMicroservices workloads done."

		# Stop the benchmark
		ssh -n $manager "docker stack rm $benchmark"
		echo "mediaMicroservices experiment cleaned up."

		echo "mediaMicroservices app is ready to be experimented on."
		# exit 0
	elif [ $benchmark == "socialNetwork" ]; then
		echo "Deploying socialNetwork app"
		ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm-jaeger.yml social-network"
		benchmark="social-network"
		ssh $manager "docker stack services $benchmark" | grep '0/1' 
		while [ $? -ne 1 ]; do
			echo "waiting for swarm services to be ready"
			sleep 5
			ssh $manager "docker stack services $benchmark" | grep '0/1' 
		done

		# get address of the nginx and jaeger service
		node_name_nginx=$(ssh $manager "docker service ps social-network_nginx-thrift | awk 'FNR == 2 {print \$4}'")
		node_name_jaeger=$(ssh $manager "docker service ps social-network_jaeger | awk 'FNR == 2 {print \$4}'")

		# Load the dataset 
		ssh -n stvdp@$node_name_nginx "cd DeathStarBench/socialNetwork/ &&  python3 scripts/init_social_graph.py"
		echo "socialNetwork app is ready to be experimented on."

		echo "socialNetwork workloads are being run..."
		ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-home.sh" > ./results/$date/swarm-sn-wrk-home.txt
		ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-user.sh" > ./results/$date/swarm-sn-wrk-user.txt
		ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-compose.sh" > ./results/$date/swarm-sn-wrk-compose.txt
		echo "socialNetwork workloads done."

		# Stop the benchmark
		ssh -n $manager "docker stack rm $benchmark"
		echo "SocialNetwork experiment cleaned up."
	fi
done