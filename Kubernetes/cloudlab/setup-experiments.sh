#!/usr/bin/env bash

# This part is running seperately 
ips="configs/ips"
manager=$(head -n 1 configs/ips)

# update the DSB after updating the files
# pssh -i -h $ips "cd DeathStarBench && git pull && git reset --hard origin/local"

# Setup wrk2 etc
# pssh -i -h $ips "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
# pssh -i -h $ips "pip install --no-input asyncio aiohttp"
# pssh -i -h $ips "sudo luarocks install luasocket"


benchmark="socialNetwork"
# benchmark="mediaMicroservices"
# benchmark="hotelReservation"

# paths && variables
dsb_dir="/users/stvdp/DeathStarBench/"
k8_dir="$dsb_dir/$benchmark/kubernetes"

# Deploy app
if [ $benchmark == "hotelReservation" ]; then
	echo "Deploying hotelReservation app"
	pssh -i -h $ips "cd $dsb_dir/$benchmark/wrk2 && make clean && make"

	kubectl config set-context --current --namespace hotel-res
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

	echo "hotelReservation app is ready to be experimented on."

elif [ $benchmark == "mediaMicroservices" ]; then
	echo "Deploying mediaMicroservices app"
	pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/wrk2 && make clean && make"
	kubectl config set-context --current --namespace media-microsvc

	# doesn't have to be remote or manager
	ssh -n "$manager" "cd $k8_dir && ./scripts/deploy-all-services-and-configurations.sh"

	echo "mediaMicroservices app is ready to be experimented on."
elif [ $benchmark == "socialNetwork" ]; then
	echo "Deploying socialNetwork app"
	pssh -i -h $ips "cd DeathStarBench/socialNetwork/wrk2 && make clean && make"
	kubectl config set-context --current --namespace social-network

	# doesn't have to be remote or manager
	ssh -n "$manager" "cd $k8_dir && ./scripts/deploy-all-services-and-configurations.sh"

	echo "socialNetwork app is ready to be experimented on."
fi



# port-forward the app
# pod_name_nginx=$(ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl get pods  -n $namespace | grep 'nginx-thrift' | awk '{ print \$1 }'")
# pod_name_media=$(ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl get pods  -n $namespace | grep 'media-service' | awk '{ print \$1 }'")
# pod_name_jaeger=$(ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl get pods  -n $namespace | grep 'jaeger' | awk '{ print \$1 }'")

# port-forward nginx accesspoint to api
# ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl port-forward -n $namespace $pod_name_nginx 8080:8080 & " & 

# jaeger to local pc to check if traces have been run correctly
# ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl port-forward -n $namespace $pod_name_jaeger 16686:16686 & " & 
# ssh -L 16686:localhost:16686 $remote 

# load dataset into the social-network
# ssh -n $remote "cd $dsb_dir/$benchmark && python3 scripts/init_social_graph.py"

#     # services
#     pssh -i -h $ips "mkdir -p {/tmp/user-pv,/tmp/reservation-pv,/tmp/recommendation-pv,/tmp/rate-pv,/tmp/profile-pv,/tmp/geo-pv}"
#     # services mongodb
#     pssh -i -h $ips "mkdir -p /tmp/db"
# #     ssh -n $remote "cd $dsb_dir/$benchmark && python3 scripts/init_hotel_reservations.py"
# fi




# run workloads
# ssh -n "$remote" "cd $wrk_dir && ./workload-compose.sh"
# ssh -n "$remote" "cd $wrk_dir && ./workload-home.sh"
# ssh -n "$remote" "cd $wrk_dir && ./workload-user.sh"



# Setup media reservations benchmark

# Setup hotel reservations benchmark