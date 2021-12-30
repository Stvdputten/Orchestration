#!/usr/bin/env bash

# we follow
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
# source ./configs/ips
echo "Kubernetes setup is starting."
source configs/roles

if [ -z "$ips" ]; then
  ips="configs/ips"
  export ips=$ips
fi

if [ -z "$manager" ]; then
  manager=$(head -n 1 configs/ips)
  export manager=$manager
fi

# device="eno1"
device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")

managers=(${!MANAGER_@})
workers=(${!WORKER_@})

# echo "$ip_manager"
# echo $managers
# echo ${!managers[0]}
ssh $manager "sudo kubeadm init --control-plane-endpoint='$ip_manager' --apiserver-advertise-address='$ip_manager' --upload-certs --apiserver-cert-extra-sans='$ip_manager' --pod-network-cidr=10.244.0.0/16" > configs/logs.txt
ssh $manager 'mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config'

# SETUP first control plane node
ssh $manager 'kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml'
# # Untaint the nodes to make it possible to deploy apps on the master nodes


# # kubeadm join 145.100.58.221:6443 --token 3gvp72.t5zc882ufn97rdvm \
# #         --discovery-token-ca-cert-hash sha256:ff14d5c7774df238b9e244d5efd69bf70f5ba66d3f3284869b4c61b71c2208ea \
# #         --control-plane --certificate-key 561b97142e6ad0674f438585c12ae29d576034214576a5b949c98a116400beb2

add_manager=$(cat configs/logs.txt | grep "\-\-certificate-key")
# echo "The manager control plane stuff is: $add_manager"
join=$(ssh $manager 'kubeadm token create --print-join-command')
# echo "$join $add_manager"

# Can be done parallel, $command & , but might be preferable to do it sequentially
echo "Setup control-plane"
for manager in ${managers[@]:1}
do
    echo "${!manager} joining the cluster"
    ssh -n "${!manager}" "sudo $join $add_manager" > /dev/null 2>&1
    ssh -n "${!manager}" 'mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config' > /dev/null 2>&1
    sleep 5
done

echo "Setup worker nodes"
for worker in ${workers[@]}
do
    echo "${!worker} joining the cluster"
    # indirect parameter expansion
    ssh -n "${!worker}" "sudo $join" > /dev/null 2>&1
    sleep 2
done

# echo "Copy Kubernetes configs"
# https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/ 
# setup k8s access on local machine
# scp $manager:'$HOME/.kube/config' "$HOME/.kube/cloudlab_config_k8"
# export KUBECONFIG="$HOME/.kube/config" 
# export KUBECONFIG="$HOME/.kube/cloudlab_config_k8:$KUBECONFIG"

echo "Kubernetes setup is done."
