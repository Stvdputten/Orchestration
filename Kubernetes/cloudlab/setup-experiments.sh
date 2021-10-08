#!/usr/bin/env bash

# This part is running seperately 
ips="configs/ips"
manager=$(head -n 1 configs/ips)
# Have the directories for DSB
# pssh -i -h $ips "git clone https://github.com/Stvdputten/DeathStarBench"
# pssh -i -h $ips "sudo git clone --single-branch --branch local https://github.com/Stvdputten/DeathStarBench /root/DeathStarBench"
# pssh -i -h $ips "cd DeathStarBench && git checkout local"

# deploy 1 of the services
# ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm.yml social-network"
# ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm-jaeger.yml social-network"

# ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-compose-swarm.yml media-service"

# Assumes you have portforwarded the service, e.g. ssh -L 5000:localhost:5000 user@server
# pssh -i -h $ips "cd DeathStarBench/hotelReservation && docker-compose build"
# ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-compose-swarm-local.yml hotel-reservation"

# Follow setup of dsb 

# paths && variables
dsb_dir="/users/stvdp/DeathStarBench/"
wrk_dir="$dsb_dir/socialNetwork/wrk2"
benchmark="/socialNetwork/"
k8_dir="$dsb_dir/$benchmark/kubernetes"

# TODO make it a choice?
namespace="social-network"
# namespace="hotel-reservations"
# namespace="mediareservations"

# make wrk
ssh -n "$remote" "cd $wrk_dir && sudo make"

# Run social-networks k8 benchmark

# Deploy app
ssh -n "$remote" "cd $k8_dir && ./scripts/deploy-all-services-and-configurations.sh"
sleep 15

# load dataset into the social-network
ssh -n $remote "cd $dsb_dir/$benchmark && python3 scripts/init_social_graph.py"

# port-forward the app

pod_name_nginx=$(ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl get pods  -n $namespace | grep 'nginx-thrift' | awk '{ print \$1 }'")
pod_name_media=$(ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl get pods  -n $namespace | grep 'media-service' | awk '{ print \$1 }'")
pod_name_jaeger=$(ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl get pods  -n $namespace | grep 'jaeger' | awk '{ print \$1 }'")

# port-forward nginx accesspoint to api
ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl port-forward -n $namespace $pod_name_nginx 8080:8080 & " & 

# jaeger to local pc to check if traces have been run correctly
ssh -n $remote "export KUBECONFIG=/users/stvdp/.kube/cloudlab_config_k8 && kubectl port-forward -n $namespace $pod_name_jaeger 16686:16686 & " & 
ssh -L 16686:localhost:16686 $remote 


# run workloads
ssh -n "$remote" "cd $wrk_dir && ./workload-compose.sh"
ssh -n "$remote" "cd $wrk_dir && ./workload-home.sh"
ssh -n "$remote" "cd $wrk_dir && ./workload-user.sh"



# Setup media reservations benchmark

# Setup hotel reservations benchmark