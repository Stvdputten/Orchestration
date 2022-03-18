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
# device="ens1f0"
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")

# ORCHESTRATOR SPECIFIC PARAMS

# specify base dir of the DSB
dsb_dir="/users/stvdp/DeathStarBench/"

run_benchmark(){
	if [ $benchmark == "hotelReservation" ]; then
		echo "Deploying hotelReservation app"

		bench_name=hotel-res

		# Make sure no other namespace is currently active
		ssh $manager "kubectl delete namespace media-microsvc > /dev/null 2>&1"
		ssh $manager "kubectl delete namespace social-network > /dev/null 2>&1"

		ssh $manager "kubectl config set-context --current --namespace $bench_name"
		
		# create directories of hotel reserverations
		dir_exp=$(ssh $manager 'ls /proj/sched-serv-PG0/exp/ | tail -n 1')
		path_nfs="/proj/sched-serv-PG0/exp/$dir_exp/tmp"
		# doesn't have to be remote or manager
		k8_dir="$dsb_dir/$benchmark/kubernetes/"


		# Check if hotel is already deployed and port-forwarded to remote tester
		ssh -n $remote "curl localhost:5000" > /dev/null 2>&1
		result=$(echo $?)
		# ssh -n $manager "kubectl get all -A | grep deployment.apps/frontend | grep 1/1" > /dev/null 2>&1
		if [ $result -ne 0 ]; then 
			echo "HR is not yet deployed"
			# if the app is not deployed, deploy it

			# load the correct deployment files
			# ssh -n $manager "rm  $k8_dir/*.yaml"
			if [ $unlimited -eq 1 ]; then
				if [ $vertical -eq 0 ]; then
					echo "Running $bench_name with limited resources and vertical scaling"
					ssh -n $manager "cp -r $k8_dir/limited-vertical/* $k8_dir"
				elif [ $horizontal -eq 0 ]; then
					echo "Running $bench_name with limited resources and horizontal scaling"
					ssh -n $manager "cp -r $k8_dir/limited-horizontal/* $k8_dir"
				else
					echo "Running $bench_name with limited resources"
					ssh -n $manager "cp -r $k8_dir/limited/* $k8_dir"
				fi
			elif [ $unlimited -eq 0 ]; then
				echo "Running hotel-reservation with unlimited resources"
				ssh -n $manager "cp -r $k8_dir/unlimited/* $k8_dir"
			fi

			# create the pv directories
			pssh -i -h $ips "mkdir -p {$path_nfs/user,/$path_nfs/reservation,/$path_nfs/recommendation,/$path_nfs/rate,/$path_nfs/profile,/$path_nfs/geo}" > /dev/null 2>&1

			# update the pv yamls of k8s
			pssh -i -h $ips "cd $k8_dir && sed \"15s/stvdp-[0-9]\{6\}/$dir_exp/\" geo-pv.yaml | sudo tee geo-pv.yaml" > /dev/null 2>&1
			pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" profile-pv.yaml | sudo tee profile-pv.yaml" > /dev/null 2>&1
			pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" rate-pv.yaml | sudo tee rate-pv.yaml" > /dev/null 2>&1
			pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" recommendation-pv.yaml | sudo tee recommendation-pv.yaml" > /dev/null 2>&1
			pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" reservation-pv.yaml | sudo tee reservation-pv.yaml" > /dev/null 2>&1
			pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" user-pv.yaml | sudo tee user-pv.yaml" > /dev/null 2>&1

			# Deploy the app
			ssh -n "$manager" "cd $k8_dir && ./scripts/deploy.sh"  
			sleep 5

			# Check if deployment succeeded
			echo "Checking of the deployment succeeded"
			count=0
			ssh $manager "kubectl get pods | grep '0/1'"
			while [ $? -ne 1 ]; do
				echo "waiting for kubernetes hotel pods to be ready"
				count=$((count+1))
				sleep 10
				if [ $count -gt 10 ]; then
					echo "$benchmark deployment is stuck, redeploying"
					ssh -n "$manager" "cd $k8_dir && yes | ./scripts/zap.sh"
					ssh -n "$manager" "cd $k8_dir && ./scripts/deploy.sh"
				fi
				ssh $manager "kubectl get pods | grep '0/1'"
			done

			# port-forward the app to the tester
			cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/frontend' | awk '{ print \$3 }'")
			cluster_ip_jaeger=$(ssh $manager "kubectl get all  | grep 'service/jaeger' | awk '{ print \$3 }'")
			pod_name_nginx=$(ssh $manager "kubectl get pods -n $bench_name | grep 'frontend' | awk '{ print \$1 }'")
			pod_name_jaeger=$(ssh $manager "kubectl get pods -n $bench_name | grep 'jaeger' | awk '{ print \$1 }'")

			echo "The frontend, jaeger service is found on cluster ip $cluster_ip_frontend, $cluster_ip_jaeger"
			echo "The frontend service pod is found on $pod_name_nginx"
			echo "The jaeger service is found on $pod_name_jaeger"

			ssh $remote "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"
			ssh -n $remote "ssh -i /tmp/sshkey -fNT -L 5000:$cluster_ip_frontend:5000 stvdp@10.10.1.1" &

			sleep 5
			echo "Checking if remote is setup correctly"
			ssh $remote "curl --max-time 5 localhost:5000" > /dev/null 2>&1
			while [ $? -ne 0 ]; do
				echo "Checking if remote is setup correctly, again"
				ssh $remote "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"
				cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/frontend' | awk '{ print \$3 }'")
				ssh -n $remote "ssh -i /tmp/sshkey -fNT -L 5000:$cluster_ip_frontend:5000 stvdp@10.10.1.1" &
				ssh $remote "curl --max-time 5 localhost:5000" > /dev/null 2>&1
			done
			sleep 5

			# check if jaeger is deployed
			# ssh -n $remote "curl localhost:16686" > /dev/null 2>&1
			# ssh $manager "curl 'localhost:16686' > /dev/null 2>&1"
			# if [ $? -ne 0 ]; then
			# 	# ssh -n $remote "kubectl port-forward -n hotel-res $pod_name_jaeger 16686:16686 > /dev/null & " &
			# 	ssh -n $remote "ssh -fNT -i /tmp/sshkey -L 16686:$cluster_ip_jaeger:16686 stvdp@10.10.1.1" &
			# 	# ssh $manager "kubectl port-forward -n $bench_name $pod_name_jaeger 16686:16686  > /dev/null &" > /dev/null 2>&1 & 
			# fi

			# ssh $manager "curl 'localhost:5000' > /dev/null 2>&1"
			# if [ $? -ne 0 ]; then
			# 	ssh -n $remote "ssh -fNT -i /tmp/sshkey -L 5000:$cluster_ip_frontend:5000 stvdp@10.10.1.1" &
			# fi

			echo "Benchmark hotel ready"
		else
			echo "Benchmark is already deployed"
		fi

		# ssh -n "$manager" "cd $k8_dir && ./scripts/deploy.sh"

		# TODO check if jaeger and nginx are port-forwarded to the remote

		# get address of the nginx and jaeger service
		cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/frontend' | awk '{ print \$3 }'")
		cluster_ip_jaeger=$(ssh $manager "kubectl get all  | grep 'service/jaeger' | awk '{ print \$3 }'")
		pod_name_nginx=$(ssh $manager "kubectl get pods -n $bench_name | grep 'frontend' | awk '{ print \$1 }'")
		pod_name_jaeger=$(ssh $manager "kubectl get pods -n $bench_name | grep 'jaeger' | awk '{ print \$1 }'")

		echo "The frontend, jaeger service is found on cluster ip $cluster_ip_frontend, $cluster_ip_jaeger"
		echo "The frontend service pod is found on $pod_name_nginx"
		echo "The jaeger service is found on $pod_name_jaeger"

		ssh $remote "curl --max-time 5 localhost:5000" > /dev/null 2>&1
		while [ $? -ne 0 ]; do
			ssh -n $remote "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"
			cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/frontend' | awk '{ print \$3 }'")
			ssh -n $remote "ssh -i /tmp/sshkey -fNT -L 5000:$cluster_ip_frontend:5000 stvdp@10.10.1.1" &
			ssh $remote "curl --max-time 5 localhost:5000" > /dev/null 2>&1
		done
		sleep 5

		echo "hotelReservation app is ready to be experimented on."

		echo "hotelReservation workloads are being run..."

		ssh -n $remote "cd DeathStarBench/$benchmark/wrk2 && ./workload.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/k8s-hr-wrk-mixed-$output_name

		echo "Workload done"
		# ssh -n $remote "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"
		# ssh -n $remote "sudo kill -9 \$(ps -ef | grep 16686 | head -n 1 | awk '{ print \$2 }')"

		# Stop the benchmark
		# ssh -n "$manager" "cd $k8_dir && yes | ./scripts/zap.sh"
		echo "hotelReservation experiment cleaned up."

	elif [ $benchmark == "mediaMicroservices" ]; then
		echo "Deploying mediaMicroservices app"

		bench_name="media-microsvc"

		# Make sure not other namespace is currently active
		ssh $manager "kubectl delete namespace hotel-res > /dev/null 2>&1"
		ssh $manager "kubectl delete namespace social-network > /dev/null 2>&1"

		ssh $manager "kubectl config set-context --current --namespace $bench_name"
		# dir location of media microservices
		k8_dir="$dsb_dir/$benchmark/kubernetes"

		# Check if media microservices  is already deployed and port-forwarded to remote tester
		ssh -n $remote "curl localhost:8080" > /dev/null 2>&1
		# ssh -n $manager "kubectl get all -A"  | grep deployment.apps/nginx | grep 1/1 > /dev/null 2>&1
		if [ $? -ne 0 ]; then 
			# if the app is not deployed, deploy it

			# load the correct deployment files
			# ssh -n $manager "rm  $k8_dir/*.yaml"
			if [ $unlimited -eq 1 ]; then
				if [ $vertical -eq 0 ]; then
					echo "Running $bench_name with limited resources and vertical scaling"
					ssh -n $manager "cp -r $k8_dir/limited-vertical/* $k8_dir"
				elif [ $horizontal -eq 0 ]; then
					echo "Running $bench_name with limited resources and horizontal scaling"
					ssh -n $manager "cp -r $k8_dir/limited-horizontal/* $k8_dir"
				else
					echo "Running $bench_name with limited resources"
					ssh -n $manager "cp -r $k8_dir/limited/* $k8_dir"
				fi
			elif [ $unlimited -eq 0 ]; then
				echo "Running media-microservices with unlimited resources"
				ssh -n $manager "cp -r $k8_dir/unlimited/* $k8_dir"
			fi

			# deploy the media-microservice app
			ssh -n "$manager" "cd $k8_dir && ./scripts/deploy-all-services-and-configurations.sh"
			sleep 5

			# Check if deployment succeeded
			count=0
			ssh $manager "kubectl get pods" | grep '0/1' 
			while [ $? -ne 1 ]; do
				echo "waiting for kubernetes pods to be ready"
				count=$((count+1))
				sleep 15
				if [ $count -gt 10 ]; then
					echo "$benchmark deployment is stuck, redeploying"
					ssh -n "$manager" "kubectl delete namespace $bench_name"
					ssh -n "$manager" "cd $k8_dir && ./scripts/deploy-all-services-and-configurations.sh"
				fi
				ssh $manager "kubectl get pods | grep '0/1'"
			done

			# port-forward the pods names
			cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/nginx' | awk '{ print \$3 }'")
			cluster_ip_jaeger=$(ssh $manager "kubectl get all  | grep 'service/jaeger-out' | awk '{ print \$3 }'")
			pod_name_nginx=$(ssh $manager "kubectl get pods -n $bench_name | grep 'nginx' | awk '{ print \$1 }'")
			pod_name_jaeger=$(ssh $manager "kubectl get pods -n $bench_name | grep 'jaeger' | awk '{ print \$1 }'")

			# port-forward jaeger to local host
			# ssh $remote "curl 'localhost:16686' > /dev/null 2>&1"
			# if [ $? -ne 0 ]; then
			# 	# ssh -n $manager "kubectl port-forward -n $bench_name $pod_name_jaeger 16686:16686 &" > /dev/null 2>&1 &
			# 	ssh -n $remote "ssh -fNT -i /tmp/sshkey -L 16686:$cluster_ip_jaeger:16686 stvdp@10.10.1.1" &
			# fi

			ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
			ssh -n $remote "ssh -i /tmp/sshkey -fNT -L 8080:$cluster_ip_frontend:8080 stvdp@10.10.1.1" &
			ssh $remote "curl --max-time 5 localhost:8080" > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
				ssh -n $remote "ssh -i /tmp/sshkey -fNT -L 8080:$cluster_ip_frontend:8080 stvdp@10.10.1.1" &
			fi
			sleep 5
			#  Load the dataset
			echo "Loading the dataset"
			# ssh -n $manager "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
			# ssh -n $manager "kubectl port-forward -n $bench_name $pod_name_nginx 8080:8080 &" > /dev/null 2>&1 &
			# ssh -n $manager "sleep 3 && cd DeathStarBench/mediaMicroservices/scripts && python3 write_movie_info.py && ./register_movies.sh && ./register_users.sh" > /dev/null 2>&1
			# ssh -n $manager "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"

			# port-forward the app to the tester
			echo "Loading the dataset"
			if [ $horizontal -eq 0 ]; then
				while [ $count -ne 10 ]; do
					echo "$count"
					ssh -n $remote "cd DeathStarBench/mediaMicroservices/scripts python3 write_movie_info.py" > /dev/null 2>&1
					ssh -n $remote "cd DeathStarBench/mediaMicroservices/scripts && ./register_movies.sh && ./register_users.sh" > /dev/null 2>&1
					count=$((count+1))
				done
			elif [ $horizontal -eq 1 ]; then
				ssh -n $remote "cd DeathStarBench/mediaMicroservices/scripts && python3 write_movie_info.py" > /dev/null 2>&1
		 	fi
			ssh -n $remote "cd DeathStarBench/mediaMicroservices/scripts && ./register_movies.sh && ./register_users.sh" > /dev/null 2>&1

			echo "Benchmark media-microservices ready"
		else
			echo "Benchmark is already deployed"
		fi

		# port-forward the pods names
		cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/nginx' | awk '{ print \$3 }'")
		cluster_ip_jaeger=$(ssh $manager "kubectl get all  | grep 'service/jaeger-out' | awk '{ print \$3 }'")
		pod_name_nginx=$(ssh $manager "kubectl get pods -n $bench_name | grep 'nginx' | awk '{ print \$1 }'")
		pod_name_jaeger=$(ssh $manager "kubectl get pods -n $bench_name | grep 'jaeger' | awk '{ print \$1 }'")

		echo "The nginx service is found on $pod_name_nginx, $cluster_ip_frontend"
		echo "The jaeger service is found on $pod_name_jaeger, $cluster_ip_jaeger"

		ssh $remote "curl --max-time 5 localhost:8080" > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
			ssh -n $remote "ssh -i /tmp/sshkey -fNT -L 8080:$cluster_ip_frontend:8080 stvdp@10.10.1.1" &
		fi
		sleep 5

		echo "mediaMicroservices app is ready to be experimented on."

		echo "mediaMicroservices workloads are being run..."
		ssh -n $remote "cd DeathStarBench/$benchmark/wrk2 && ./workload.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/k8s-mm-wrk-compose-$output_name
		echo "Workload done"

		echo "mediaMicroservices experiment cleaned up."
		
	elif [ $benchmark == "socialNetwork" ]; then
		echo "Deploying socialNetwork app"

		bench_name=social-network

		# Make sure no other namespace is currently active
		ssh $manager "kubectl delete namespace hotel-res > /dev/null 2>&1"
		ssh $manager "kubectl delete namespace media-microsvc > /dev/null 2>&1"

		ssh $manager "kubectl config set-context --current --namespace $bench_name"

		# dir location of social-network
		k8_dir="$dsb_dir/$benchmark/kubernetes"

		# Check if social-network  is already deployed and port-forwarded to remote tester
		# ssh -n $manager "kubectl get all -A"  | grep deployment.apps/nginx | grep 1/1 > /dev/null 2>&1
		ssh -n $remote "curl --max-time 10 localhost:8080" > /dev/null 2>&1
		if [ $? -ne 0 ]; then 
			# if the app is not deployed, deploy it
			echo "Deploying because not deployed"

			# load the correct deployment files
			# ssh -n $manager "rm  $k8_dir/*.yaml"
			if [ $unlimited -eq 1 ]; then
				if [ $vertical -eq 0 ]; then
					echo "Running $bench_name with limited resources and vertical scaling"
					ssh -n $manager "cp -r $k8_dir/limited-vertical/* $k8_dir"
				elif [ $horizontal -eq 0 ]; then
					echo "Running $bench_name with limited resources and horizontal scaling"
					ssh -n $manager "cp -r $k8_dir/limited-horizontal/* $k8_dir"
				else
					echo "Running $bench_name with limited resources"
					ssh -n $manager "cp -r $k8_dir/limited/* $k8_dir"
				fi
			elif [ $unlimited -eq 0 ]; then
				echo "Running social-network with unlimited resources"
				ssh -n $manager "cp -r $k8_dir/unlimited/* $k8_dir"
			fi

			# Deploy social-network app
			ssh -n "$manager" "cd $k8_dir && ./scripts/deploy-all-services-and-configurations.sh"
			sleep 5

			# Check if deployment succeeded
			count=0
			ssh -n $manager "kubectl get pods | grep '0/1'"
			while [ $? -ne 1 ]; do
				echo "waiting for kubernetes pods to be ready"
				count=$((count+1))
				sleep 15
				if [ $count -gt 10 ]; then
					echo "$benchmark deployment is stuck, redeploying"
					ssh -n "$manager" "kubectl delete namespace $bench_name"
					ssh -n "$manager" "cd $k8_dir && ./scripts/deploy-all-services-and-configurations.sh"
				fi
				ssh $manager "kubectl get pods | grep '0/1'"
			done
			
			echo "port forwarding stuff"

			# port-forward the pods names
			cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/nginx' | awk '{ print \$3 }'")
			cluster_ip_jaeger=$(ssh $manager "kubectl get all  | grep 'service/jaeger-out' | awk '{ print \$3 }'")
			pod_name_nginx=$(ssh $manager "kubectl get pods -n $bench_name | grep 'nginx' | awk '{ print \$1 }'")
			pod_name_jaeger=$(ssh $manager "kubectl get pods -n $bench_name | grep 'jaeger' | awk '{ print \$1 }'")

			echo "The nginx service is found on $pod_name_nginx, $cluster_ip_frontend"
			echo "The jaeger service is found on $pod_name_jaeger, $cluster_ip_jaeger"

			# port-forward jaeger to local host
			# ssh $manager "curl 'localhost:16686' > /dev/null 2>&1"
			# curl 'localhost:16686' > /dev/null 2>&1
			# if [ $? -ne 0 ]; then
			# 	# ssh $manager "kubectl port-forward -n $bench_name $pod_name_jaeger 16686:16686 > /dev/null 2>&1 & "
			# 	# ssh -n $remote "ssh -fNT -i /tmp/sshkey -L 16686:$cluster_ip_jaeger:16686 stvdp@10.10.1.1" &
			# 	ssh -fNT -L 16686:$cluster_ip_jaeger:16686 $manager 
			# fi
			# echo 1
			ssh $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
			# echo 2
			cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/nginx' | awk '{ print \$3 }'")
			# echo 3
			ssh $remote "ssh -i /tmp/sshkey -fNT -L 8080:$cluster_ip_frontend:8080 stvdp@10.10.1.1" &
			# echo 4
			sleep 5

			#  Load the dataset
			# ssh -n $manager "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
			# ssh -n $manager "kubectl port-forward -n $bench_name $pod_name_nginx 8080:8080 &" > /dev/null 2>&1 &
			# ssh -n $manager "sleep 3 && cd DeathStarBench/socialNetwork/ && python3 scripts/init_social_graph.py" > /dev/null 2>&1 &
			# ssh -n $manager "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"

			# port-forward the app to the tester
			# ssh -n $remote "kubectl port-forward -n $bench_name $pod_name_nginx 8080:8080 > /dev/null 2>&1 &" &
			ssh $remote "curl --max-time 5 localhost:8080" > /dev/null 2>&1
			while [ $? -ne 0 ]; do
				echo "Remote  not yet working"
				ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
				cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/nginx' | awk '{ print \$3 }'")
				ssh -n $remote "ssh -i /tmp/sshkey -fNT -L 8080:$cluster_ip_frontend:8080 stvdp@10.10.1.1" &
			done 
			echo "Remote  has been set up"

			# echo 5
			sleep 5 
			echo "Loading the dataset"

			if [ $horizontal -eq 0 ]; then
				ssh -n $remote "cd DeathStarBench/socialNetwork/ && python3 scripts/init_social_graph.py" | grep Failed | wc -l
				while [ $? -ne 0 ]; do
					ssh -n $remote "cd DeathStarBench/socialNetwork/ && python3 scripts/init_social_graph.py" | grep Failed | wc -l
				done
			elif [ $horizontal -eq 1 ]; then
				ssh -n $remote "cd DeathStarBench/socialNetwork/ && python3 scripts/init_social_graph.py" | grep Failed | wc -l
		 	fi
			echo "Benchmark social-network ready"
		else
			echo "Benchmark is already deployed"
		fi
	
		# port-forward the pods names
		cluster_ip_frontend=$(ssh $manager "kubectl get all  | grep 'service/nginx' | awk '{ print \$3 }'")
		cluster_ip_jaeger=$(ssh $manager "kubectl get all  | grep 'service/jaeger-out' | awk '{ print \$3 }'")
		pod_name_nginx=$(ssh $manager "kubectl get pods -n $bench_name | grep 'nginx' | awk '{ print \$1 }'")
		pod_name_jaeger=$(ssh $manager "kubectl get pods -n $bench_name | grep 'jaeger' | awk '{ print \$1 }'")

		echo "The nginx service is found on $pod_name_nginx, $cluster_ip_frontend"
		echo "The jaeger service is found on $pod_name_jaeger, $cluster_ip_jaeger"

		ssh $remote "curl --max-time 5 localhost:8080" > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
			ssh -n $remote "ssh -i /tmp/sshkey -fNT -L 8080:$cluster_ip_frontend:8080 stvdp@10.10.1.1" &
		fi
		sleep 5

		echo "Social-network app is ready to be experimented on."

		echo "socialNetwork workloads are being run..."
		ssh -n $remote "cd DeathStarBench/$benchmark/wrk2 && ./workload-mixed.sh -t $t -c $c -d $d -R $R" > ./results/$dir_date/k8s-sn-wrk-mixed-$output_name
		echo "Workload done"

		# Stop the benchmark
		# ssh -n "$manager" "cd $k8_dir && yes | ./scripts/zap.sh"
		echo "SocialNetwork experiment cleaned up."
	fi
}

# deploy 1 of the services
if [ -z "$benchmark" ]; then
	echo "---------------------"
	echo "No benchmark specified, running all benchmarks with specified parameters"
	echo "---------------------"
	# for benchmark in socialNetwork mediaMicroservices  hotelReservation; do
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