#!/usr/bin/env bash

# we follow
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
# source ./configs/ips
echo "Retrieving Kubernetes config."
source configs/roles
ips="configs/ips"

manager=$(head -n 1 configs/ips)
# device="eno1"
device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")

managers=(${!MANAGER_@})
workers=(${!WORKER_@})

echo "Copy Kubernetes configs"
# https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/ 
# setup k8s access on local machine
scp $manager:'$HOME/.kube/config' "$HOME/.kube/cloudlab_config_k8"
export KUBECONFIG="$HOME/.kube/config" 
export KUBECONFIG="$HOME/.kube/cloudlab_config_k8:$KUBECONFIG"

echo "Kubernetes configs have been set."
