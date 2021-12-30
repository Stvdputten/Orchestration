#!/usr/bin/env bash

# Only change compared to setup-experiments is that this includes the clients hostname also

# Run from the dir above
cd $(dirname $0)/..

# Read the parameters if any
while getopts t:c:d:R: flag
do
    case "${flag}" in
        t) t=${OPTARG};;
        c) c=${OPTARG};;
        d) d=${OPTARG};;
        R) R=${OPTARG};;
    esac
done

if [ -z "$t" ] && [ -z "$c" ] && [ -z "$d" ] && [ -z "$R" ]; then
	echo "-------------------------------------------------------";
	echo "No params, using default settings of -t 4 -c 8 -d 30 -R 200";
	echo "-------------------------------------------------------";
	t=4
	c=8
	d=30
	R=200
else
	echo "-------------------------------------------------------";
	echo "Experiments are run using the following parameters:";
	echo "Threads: $t";
	echo "Connections: $c";
	echo "Duration (seconds): $d";
	echo "Req/sec: $R";
	echo "-------------------------------------------------------";
fi

# echo $benchmark
# exit 0 

# This part is running seperately 
if [ -z "$ips" ]; then
	ips="configs/ips"
	export ips=$ips
fi
if [ -z "$manager" ]; then
	manager=$(head -n 1 configs/ips)
	export manager=$manager
fi
if [ -z "$remote" ]; then
	remote=$(head -n 1 configs/remote)
	export remote=$remote
fi

# Make sure prometheus isn't installed in home directory
# pssh -i -h $ips "git clone https://github.com/Stvdputten/DeathStarBench"

# update the DSB after updating the files
pssh -i -h $ips "cd DeathStarBench && git pull && git reset --hard origin/local" > /dev/null 2>&1
ssh -n $remote "cd DeathStarBench && git reset --hard origin/local && git pull" > /dev/null 2>&1

# check what type of server is used and set the correct path
if echo $manager | cut -d@ -f2 | grep "amd" > /dev/null; then
	server_type="c6525-25g"
elif echo $manager | cut -d@ -f2 | grep "ms" > /dev/null; then
	server_type="m510"
fi

# setup directories based on date
date=$(date "+%H:%MT%d-%m-%Y")
dir_date=$(date "+%d-%m-%y")
mkdir -p ./results/$dir_date

run_benchmark(){
	if [ $benchmark == "hotelReservation" ]; then
		echo "Deploying hotelReservation app"
		ssh $manager "docker stack rm media-microservices" > /dev/null 2>&1
		ssh $manager "docker stack rm social-network" > /dev/null 2>&1

		bench_name="hotel-reservation"
		ssh $manager "docker stack ls" | grep "$bench_name" > /dev/null 2>&1 
		if [ $? -ne 0 ]; then
			ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-compose-swarm-local.yml hotel-reservation"

			count=0
			ssh $manager "docker stack services $bench_name" | grep '0/1'
			while [ $? -ne 1 ]; do
				echo "waiting for swarm services to be ready"
				count=$((count+1))
				sleep 5
				if [ $count -gt 10 ]; then
					echo "Swarm services are not ready"
					ssh -n $manager "docker stack rm $bench_name"
					sleep 5
					pssh -i -h $ips "sudo systemctl restart docker"
					ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-compose-swarm-local.yml hotel-reservation"
					count=0
				fi
				ssh $manager "docker stack services $bench_name" | grep '0/1' 
			done
			echo "Swarm services ready"
		else
			echo "Benchmark already deployed"
		fi

		# get address of the nginx and jaeger service
		node_name_nginx=$(ssh $manager "docker service ps hotel-reservation_frontend | awk 'FNR == 2 {print \$4}'")
		node_name_jaeger=$(ssh $manager "docker service ps hotel-reservation_jaeger | awk 'FNR == 2 {print \$4}'")
		echo "The frontend service is found on $node_name_nginx"
		echo "The jaeger service is found on $node_name_jaeger"

		echo "hotelReservation app is ready to be experimented on."

		echo "hotelReservation workloads are being run..."
		ssh -n $remote "cd DeathStarBench/hotelReservation/wrk2 && export nginx_ip=$node_name_nginx && ./workload.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-hr-wrk-mixed-$remote-$server_type-t$t-c$c-d$d-R$R.txt
		echo "hotelReservation workloads done."

		# Stop the benchmark
		# ssh -n $manager "docker stack rm $benchmark"
		echo "hotelReservation experiment cleaned up."

	elif [ $benchmark == "mediaMicroservices" ]; then
		echo "Deploying mediaMicroservices app"
		bench_name="media-microservices"
		ssh $manager "docker stack rm hotel-reservation" > /dev/null 2>&1
		ssh $manager "docker stack rm social-network" > /dev/null 2>&1
		# ssh -n $manager "docker stack rm $benchmark"

		ssh $manager "docker stack ls" | grep "$bench_name" > /dev/null 2>&1 
		if [ $? -ne 0 ]; then
			ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-compose-swarm.yml media-microservices"

			count=0
			ssh $manager "docker stack services $bench_name" | grep '0/1' 
			while [ $? -ne 1 ]; do
				echo "waiting for swarm services to be ready"
				sleep 5
				if [ $count -gt 10 ]; then
					echo "Swarm services are not ready"
					ssh -n $manager "docker stack rm $bench_name"
					sleep 5
					pssh -i -h $ips "sudo systemctl restart docker"
					ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-compose-swarm.yml media-microservices"
					count=0
				fi
				ssh $manager "docker stack services $bench_name" | grep '0/1' 
			done
			echo "Swarm services ready"

			# Load the dataset 
			echo "mediaMicroservices loading the dataset..."
			node_name_nginx=$(ssh $manager "docker service ps media-microservices_nginx-web-server | awk 'FNR == 2 {print \$4}'")
			ssh -n stvdp@$node_name_nginx "cd DeathStarBench/mediaMicroservices/scripts && python3 write_movie_info.py && ./register_movies.sh && ./register_users.sh" > /dev/null 2>&1
		else 
			echo "Benchmark already deployed"
		fi
		echo "mediaMicroservices app is ready to be experimented on."

		# get address of the nginx and jaeger service
		node_name_nginx=$(ssh $manager "docker service ps media-microservices_nginx-web-server | awk 'FNR == 2 {print \$4}'")
		node_name_jaeger=$(ssh $manager "docker service ps media-microservices_jaeger | awk 'FNR == 2 {print \$4}'")
		echo "The nginx service is found on $node_name_nginx"
		echo "The jaeger service is found on $node_name_jaeger"

		echo "mediaMicroservices workloads are being run..."
		ssh -n $remote "cd DeathStarBench/mediaMicroservices/wrk2 && export nginx_ip=$node_name_nginx && ./workload.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-mm-wrk-compose--$remote-$server_type-t$t-c$c-d$d-R$R.txt
		echo "mediaMicroservices workloads done."

		# Stop the benchmark
		# ssh -n $manager "docker stack rm $benchmark"
		echo "mediaMicroservices experiment cleaned up."

		echo "mediaMicroservices app is ready to be experimented on."
		# exit 0
	elif [ $benchmark == "socialNetwork" ]; then
		echo "Deploying socialNetwork app"
		ssh $manager "docker stack rm hotel-reservation" > /dev/null 2>&1
		ssh $manager "docker stack rm media-microservices" > /dev/null 2>&1

		bench_name="social-network"
		ssh $manager "docker stack ls" | grep "$bench_name" > /dev/null 2>&1 
		if [ $? -ne 0 ]; then
			ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm-jaeger.yml social-network"

			count=0
			ssh $manager "docker stack services $bench_name" | grep '0/1' 
			while [ $? -ne 1 ]; do
				echo "waiting for swarm services to be ready"
				sleep 5
				if [ $count -gt 10 ]; then
					echo "Swarm services are not ready"
					ssh -n $manager "docker stack rm $bench_name"
					sleep 5
					pssh -i -h $ips "sudo systemctl restart docker"
					ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm-jaeger.yml social-network"
					count=0
				fi
				ssh $manager "docker stack services $bench_name" | grep '0/1' 
			done
			echo "Swarm services ready"

			# Load the dataset 
			echo "socialNetwork loading the dataset..."
			node_name_nginx=$(ssh $manager "docker service ps social-network_nginx-thrift | awk 'FNR == 2 {print \$4}'")
			ssh -n stvdp@$node_name_nginx "cd DeathStarBench/socialNetwork/ &&  python3 scripts/init_social_graph.py" > /dev/null 2>&1
		else
			echo "Benchmark already deployed"
		fi

		# get address of the nginx and jaeger service
		node_name_nginx=$(ssh $manager "docker service ps social-network_nginx-thrift | awk 'FNR == 2 {print \$4}'")
		node_name_jaeger=$(ssh $manager "docker service ps social-network_jaeger | awk 'FNR == 2 {print \$4}'")
		echo "The nginx service is found on $node_name_nginx"
		echo "The jaeger service is found on $node_name_jaeger"
		echo "socialNetwork app is ready to be experimented on."

		echo "socialNetwork workloads are being run..."
		# ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-home.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-sn-wrk-home-$server_type-t$t-c$c-d$d-R$R.txt
		# ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-user.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-sn-wrk-user-$server_type-t$t-c$c-d$d-R$R.txt
		# ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-compose.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-sn-wrk-compose-$server_type-t$t-c$c-d$d-R$R.txt
		ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-mixed.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-sn-wrk-mixed-$remote-$server_type-t$t-c$c-d$d-R$R.txt
		echo "socialNetwork workloads done."

		# Stop the benchmark
		# ssh -n $manager "docker stack rm $benchmark"
		echo "SocialNetwork experiment cleaned up."
	fi
}

# deploy 1 of the services
if [ -z "$benchmark" ]; then
	echo "---------------------"
	echo "No benchmark specified, running all benchmarks with specified parameters"
	echo "---------------------"
	for benchmark in socialNetwork mediaMicroservices hotelReservation; do
		echo "Running the baseline tests for $benchmark"
		run_benchmark
	done
else
	echo "---------------------"
	echo "Benchmark specified"
	echo "---------------------"
	run_benchmark
fi
