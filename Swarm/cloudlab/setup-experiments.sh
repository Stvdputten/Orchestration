#!/usr/bin/env bash

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
	t=8
	c=512
	d=30
	R=500
	echo "-------------------------------------------------------";
	echo "No params, using default settings of -t $t -c $c -d $d -R $R";
else
	echo "-------------------------------------------------------";
	echo "Experiments are run using the following parameters:";
	echo "Threads: $t";
	echo "Connections: $c";
	echo "Duration (seconds): $d";
	echo "Req/sec: $R";
fi

# Experiment parameters
# Check if we use unlimited resources in the deployment files
# 0 means true
# 1 means false
if [ -z "$unlimited" ]; then
	# resources are unlimited
	export unlimited=0
fi

if [ -z "$availability" ]; then
	# master nodes consists of 3 nodes, cause of high availability
	export availability=0
fi

if [ -z "$vertical" ]; then
	# resources have not been increased
	export vertical=1
fi

if [ -z "$horizontal" ]; then
	# containers have not been scaled global/horizontal
	export horizontal=1
fi


# This part checks the nodes params
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
if [ -z "$experiment" ]; then
	experiment="free"
	export experiment=$experiment
fi

echo "Running experiment $experiment";
echo "Current benchmark is $benchmark"
if [ $availability -eq 0 ]; then echo "Availability is on"; else echo "Availability is off"; fi
if [ $horizontal -eq 0 ]; then echo "Horizontal is on"; else echo "Horizontal is off"; fi
if [ $vertical -eq 0 ]; then echo "Vertical is on"; else echo "Vertical is off"; fi
if [ $unlimited -eq 0 ]; then echo "UNLIMITED resources"; else echo "LIMITED resources"; fi
echo "-------------------------------------------------------";

# update the DSB after updating the files
pssh -i -h $ips "cd DeathStarBench && git pull && git reset --hard origin/local" > /dev/null 2>&1
ssh -n $remote "cd DeathStarBench && git reset --hard origin/local && git pull" > /dev/null 2>&1

# check what type of server is used and set the correct path
if echo $manager | cut -d@ -f2 | grep "amd" > /dev/null; then
	server_type="c6525-25g"
elif echo $manager | cut -d@ -f2 | grep "ms" > /dev/null; then
	server_type="m510"
fi

# PARAMS ORCHESTRATOR WIDE

# setup directories based on date for the experiments
dir_date=$(date "+%d-%m-%y")
dir_date="/$dir_date/$experiment"
mkdir -p ./results/$dir_date

# file params to output
output_name=$server_type-exp$experiment-havail$availability-hori$horizontal-verti$vertical-infi$unlimited-t$t-c$c-d$d-R$R

# return ip manager and network device
device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")

# PARAMS ORCHESTRATOR SPECIFIC

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
					if [ $unlimited -eq 1 ]; then 
						elif [ $vertical -eq 0 ]; then 
							echo "Running $bench_name with limited resources and vertical scaling"
							ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-swarm-limited-horizontal.yml hotel-reservation"
						elif [ $horizontal -eq 0 ]; then 
							echo "Running $bench_name with limited resources and horizontal scaling"
							ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-swarm-limited-vertical.yml hotel-reservation"
						else
							echo "Running $bench_name with limited resources"
							ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-swarm-limited-resources.yml hotel-reservation"
						fi
					elif [ $unlimited -eq 0 ]; then
						echo "Running hotel reservation with unlimited resources"
						ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-compose-swarm-local.yml hotel-reservation"
					fi
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
		ssh -n $remote "cd DeathStarBench/hotelReservation/wrk2 && export nginx_ip=$node_name_nginx && ./workload.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-hr-wrk-mixed-$output_name
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
				count=$((count+1))
				sleep 5
				if [ $count -gt 10 ]; then
					echo "Swarm services are not ready"
					ssh -n $manager "docker stack rm $bench_name"
					sleep 5
					pssh -i -h $ips "sudo systemctl restart docker"
					if [ $unlimited -eq 1 ]; then 
						if [ $vertical -eq 0 ]; then 
							echo "Running media-microservices with limited resources and vertical scaling"
							ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-swarm-limited-vertical.yml media-microservices"
						elif [ $horizontal -eq 0 ]; then 
							echo "Running media-microservices with limited resources and horizontal scaling"
							ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-swarm-limited-horizontal.yml media-microservices"
						else
							echo "Running media-microservices with limited resources"
							ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-swarm-limited-resources.yml media-microservices"
						fi
					elif [ $unlimited -eq 0 ]; then
						echo "Running media-microservices with unlimited resources"
						ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-compose-swarm.yml media-microservices"
					fi
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
		ssh -n $remote "cd DeathStarBench/mediaMicroservices/wrk2 && export nginx_ip=$node_name_nginx && ./workload.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-mm-wrk-compose-$output_name
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
			if [ $unlimited -eq 1 ]; then 
				echo "Running socialNetwork with limited resources"
				ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-swarm-limited-resources.yml social-network"
			elif [ $unlimited -eq 0 ]; then
				echo "Running socialNetwork with unlimited resources"
				ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm-jaeger.yml social-network"
			fi

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
					if [ $unlimited -eq 1 ]; then 
						if [ $vertical -eq 0 ]; then 
							echo "Running $bench_name with limited resources and vertical scaling"
							ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-swarm-limited-vertical.yml social-network"
						elif [ $horizontal -eq 0 ]; then 
							echo "Running $bench_name with limited resources and horizontal scaling"
							ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-swarm-limited-horizontal.yml social-network"
						else
							echo "Running $bench_name with limited resources"
							ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-swarm-limited-resources.yml social-network"
						fi
					elif [ $unlimited -eq 0 ]; then
						echo "Running socialNetwork with unlimited resources"
						ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm-jaeger.yml social-network"
					fi
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
		# ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-home.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-sn-wrk-home-$experiment-$server_type-t$t-c$c-d$d-R$R.txt
		# ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-user.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-sn-wrk-user-$experiment-$server_type-t$t-c$c-d$d-R$R.txt
		# ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-compose.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-sn-wrk-compose-$experiment-$server_type-t$t-c$c-d$d-R$R.txt
		ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node_name_nginx && ./workload-mixed.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/swarm-sn-wrk-mixed-$output_name
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

exit 0