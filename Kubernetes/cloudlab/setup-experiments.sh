#!/usr/bin/env bash

# This part is running seperately 
ips="configs/ips"
manager=$(head -n 1 configs/ips)
remote=$(head -n 1 configs/remote)

device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")
node3=$(sed -n '4p' configs/ips)
node3_hostname=$(ssh -n $node3 "hostname")
node3_ip=$(ssh -n $node3 "ip -4 a show $device |  grep \"inet\b\" | awk '{ print \$2}' | cut -d/ -f1")

# update the DSB after updating the files
pssh -i -h $ips "cd DeathStarBench && git pull && git reset --hard origin/local"
ssh -n $remote "cd DeathStarBench && git reset --hard origin/local && git pull"

benchmark="socialNetwork"
# benchmark="mediaMicroservices"
# benchmark="hotelReservation"

# paths && variables
dsb_dir="/users/stvdp/DeathStarBench/"
# k8_dir="$dsb_dir/$benchmark/kubernetes"

# for benchmark in hotelReservation
for benchmark in socialNetwork mediaMicroservices hotelReservation
do 
	# Deploy app
	if [ $benchmark == "hotelReservation" ]; then
		echo "Deploying hotelReservation app"
		kubectl config set-context --current --namespace hotel-res
		benchmark="hotelReservation"
		k8_dir="$dsb_dir/$benchmark/kubernetes"
		
		# create directories of hotel reserverations
		dir_exp=$(ssh $manager 'ls /proj/sched-serv-PG0/exp/ | tail -n 1')
		path_nfs="/proj/sched-serv-PG0/exp/$dir_exp/tmp"
		pssh -i -h $ips "mkdir -p {$path_nfs/user,/$path_nfs/reservation,/$path_nfs/recommendation,/$path_nfs/rate,/$path_nfs/profile,/$path_nfs/geo}"

		# update the pv yamls of k8s
		pssh -i -h $ips "cd $k8_dir && sed \"15s/stvdp-[0-9]\{6\}/$dir_exp/\" geo-pv.yaml | sudo tee geo-pv.yaml" &> /dev/null
		pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" profile-pv.yaml | sudo tee profile-pv.yaml" &> /dev/null
		pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" rate-pv.yaml | sudo tee rate-pv.yaml" &> /dev/null
		pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" recommendation-pv.yaml | sudo tee recommendation-pv.yaml" &> /dev/null
		pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" reservation-pv.yaml | sudo tee reservation-pv.yaml" &> /dev/null
		pssh -i -h $ips "cd $k8_dir && sed \"13s/stvdp-[0-9]\{6\}/$dir_exp/\" user-pv.yaml | sudo tee user-pv.yaml" &> /dev/null

		# doesn't have to be remote or manager
		ssh -n "$manager" "cd $k8_dir && ./scripts/deploy.sh"
		sleep 5
		kubectl get pods | grep '0/1'
		while [ $? -ne 1 ]; do
			echo "waiting for pods to be ready"
			sleep 5
			kubectl get pods | grep '0/1'
		done

		# port-forward the pods names
		pod_name_nginx=$(kubectl get pods | grep 'frontend' | awk '{ print $1 }')
		pod_name_jaeger=$(kubectl get pods | grep 'jaeger' | awk '{ print $1 }')
		echo "hotelReservation app is ready to be experimented on."

		echo "hotelReservation workloads are being run..."
		ssh -n $remote "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"
		ssh -n $remote "kubectl port-forward -n hotel-res $pod_name_nginx 5000:5000 > /dev/null & sleep 3 && cd DeathStarBench/hotelReservation/wrk2 && ./workload.sh" > ./results/k8s-hr-wrk-mixed.txt & 
		echo " " > ./results/k8s-hr-wrk-mixed.txt
		head -n 3 ./results/k8s-hr-wrk-mixed.txt | grep Running
		while [ $? -ne 0 ]; do
			# echo "waiting for experiments to be ready"
			sleep 5
			head -n 3 ./results/k8s-hr-wrk-mixed.txt | grep Running
		done
		echo "Workload done"
		ssh -n $remote "sudo kill -9 \$(ps -ef | grep 5000 | head -n 1 | awk '{ print \$2 }')"

		# Stop the benchmark
		ssh -n "$manager" "cd $k8_dir && yes | ./scripts/zap.sh"
		echo "hotelReservation experiment cleaned up."

	elif [ $benchmark == "mediaMicroservices" ]; then
		echo "Deploying mediaMicroservices app"
		# pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/wrk2 && make clean && make"
		kubectl config set-context --current --namespace media-microsvc
		benchmark="mediaMicroservices"
		k8_dir="$dsb_dir/$benchmark/kubernetes"

		# doesn't have to be remote or manager
		ssh -n "$manager" "cd $k8_dir && ./scripts/deploy-all-services-and-configurations.sh"
		sleep 5
		kubectl get pods | grep '0/1'
		while [ $? -ne 1 ]; do
			echo "waiting for pods to be ready"
			sleep 5
			kubectl get pods | grep '0/1'
		done

		# port-forward the pods names
		pod_name_nginx=$(kubectl get pods | grep 'nginx' | awk '{ print $1 }')
		pod_name_jaeger=$(kubectl get pods | grep 'jaeger' | awk '{ print $1 }')

		#  Load the dataset
		ssh -n $manager "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
		ssh -n $manager "kubectl port-forward -n media-microsvc $pod_name_nginx 8080:8080 &" > /dev/null &
		ssh -n $manager "sleep 3 && cd DeathStarBench/mediaMicroservices/scripts && python3 write_movie_info.py && ./register_movies.sh && ./register_users.sh" > /dev/null
		ssh -n $manager "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
		echo "mediaMicroservices app is ready to be experimented on."

		echo "mediaMicroservices workloads are being run..."
		ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
		ssh -n $remote "kubectl port-forward -n media-microsvc $pod_name_nginx 8080:8080 > /dev/null & sleep 3 && cd DeathStarBench/mediaMicroservices/wrk2 && ./workload.sh" > ./results/k8s-mm-wrk-compose.txt & 
		echo " " > ./results/k8s-mm-wrk-compose.txt
		head -n 3 ./results/k8s-mm-wrk-compose.txt | grep Running
		while [ $? -ne 0 ]; do
			# echo "waiting for experiments to be ready"
			sleep 5
			head -n 3 ./results/k8s-mm-wrk-compose.txt | grep Running
		done
		echo "Workload done"
		ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"

		# Stop the benchmark
		ssh -n "$manager" "cd $k8_dir && yes | ./scripts/zap.sh"
		echo "mediaMicroservices experiment cleaned up."
		
	elif [ $benchmark == "socialNetwork" ]; then
		echo "Deploying socialNetwork app"
		# pssh -i -h $ips "cd DeathStarBench/socialNetwork/wrk2 && make clean && make"
		kubectl config set-context --current --namespace social-network

		benchmark="socialNetwork"
		# benchmark="mediaMicroservices"
		# benchmark="hotelReservation"
		k8_dir="$dsb_dir/$benchmark/kubernetes"

		# Deploy social-network app
		ssh -n "$manager" "cd $k8_dir && ./scripts/deploy-all-services-and-configurations.sh"
		sleep 5
		kubectl get pods | grep '0/1'
		while [ $? -ne 1 ]; do
			echo "waiting for pods to be ready"
			sleep 5
			kubectl get pods | grep '0/1'
		done

		# port-forward the pods names
		pod_name_nginx=$(kubectl get pods | grep 'nginx-thrift' | awk '{ print $1 }')
		pod_name_jaeger=$(kubectl get pods | grep 'jaeger' | awk '{ print $1 }')

		#  Load the dataset
		ssh -n $manager "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
		ssh -n $manager "kubectl port-forward -n social-network $pod_name_nginx 8080:8080 > /dev/null & sleep 3 && cd DeathStarBench/socialNetwork/ && python3 scripts/init_social_graph.py" > /dev/null &
		sleep 30
		echo "socialNetwork app is ready to be experimented on."

		echo "socialNetwork workloads are being run..."
		ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"
		ssh -n $remote "kubectl port-forward -n social-network $pod_name_nginx 8080:8080 > /dev/null & sleep 3 && cd DeathStarBench/socialNetwork/wrk2 && ./workload-home.sh" > ./results/k8s-sn-wrk-home.txt & 
		echo " " > ./results/k8s-sn-wrk-home.txt
		head -n 3 ./results/k8s-sn-wrk-home.txt | grep Running
		while [ $? -ne 0 ]; do
			# echo "waiting for experiments to be ready"
			sleep 5
			head -n 3 ./results/k8s-sn-wrk-home.txt | grep Running
		done
		echo "Workload home done"

		ssh -n $remote "sleep 3 && cd DeathStarBench/socialNetwork/wrk2 && ./workload-user.sh" > ./results/k8s-sn-wrk-user.txt & 
		echo " " > ./results/k8s-sn-wrk-user.txt
		head -n 3 ./results/k8s-sn-wrk-user.txt | grep Running
		while [ $? -ne 0 ]; do
			# echo "waiting for experiments to be ready"
			sleep 5
			head -n 3 ./results/k8s-sn-wrk-user.txt | grep Running
		done
		echo "Workload user done"

		ssh -n $remote "sleep 3 && cd DeathStarBench/socialNetwork/wrk2 && ./workload-compose.sh" > ./results/k8s-sn-wrk-compose.txt & 
		echo " " > ./results/k8s-sn-wrk-compose.txt
		head -n 3 ./results/k8s-sn-wrk-compose.txt | grep Running
		while [ $? -ne 0 ]; do
			# echo "waiting for experiments to be ready"
			sleep 5
			head -n 3 ./results/k8s-sn-wrk-compose.txt | grep Running
		done
		echo "Workload compose done"

		ssh -n $remote "sudo kill -9 \$(ps -ef | grep 8080 | head -n 1 | awk '{ print \$2 }')"

		# clean up results
		# awk 'NR > 2 { print }' ./results/k8s-sn-wrk-home.txt | tee ./results/k8s-sn-wrk-home.txt 
		# awk 'NR > 2 { print }' ./results/k8s-sn-wrk-user.txt | tee ./results/k8s-sn-wrk-user.txt 
		# awk 'NR > 2 { print }' ./results/k8s-sn-wrk-compose.txt | tee ./results/k8s-sn-wrk-compose.txt 

		# Stop the benchmark
		ssh -n "$manager" "cd $k8_dir && yes | ./scripts/zap.sh"
		echo "SocialNetwork experiment cleaned up."
	fi
done