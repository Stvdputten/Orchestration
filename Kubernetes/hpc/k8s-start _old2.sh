#!/usr/bin/env bash

# we follow
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
# source ./configs/ips
source configs/roles
ips="configs/ips"

# kubeadm_version="1.20.7-00"
# kubelet_version="1.20.7-00"
# kubectl_version="1.20.7-00"


managers=(${!MANAGER_@})
workers=(${!WORKER_@})
# echo $workers
# for manager in ${managers[@]}
# do
#     # ssh "${!manager}" "ls"
#     ssh "${!manager}" "sudo ufw allow 6443,2379,2380,10250,10251,10252,10255/tcp"
#     ssh "${!manager}" "sudo ufw reload"
# done

# for worker in ${workers[@]}
# do
#     # indirect parameter expansion
#     ssh "${!worker}" "sudo ufw allow 10250/tcp"
#     ssh "${!worker}" "sudo ufw allow 30000:32767/tcp"
#     ssh "${!manager}" "sudo ufw reload"
# done

# # required ports
# # control planes nodes
pssh -i -h $ips "sudo ufw allow 6443,2379,2380,10250,10251,10252,10255/tcp"
pssh -i -h $ips "sudo ufw reload"

# # worker nodes
pssh -i -h $ips "sudo ufw allow 10250,10251,10255/tcp"
pssh -i -h $ips "sudo ufw allow 30000:32767/tcp"

#  SETUP KUBERNETES
ips="configs/ips"

# # install kubeadm/kubelet/kubectl
pssh -i -h $ips "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common"
wait
pssh -i -h $ips "sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg"
wait
pssh -i -h $ips "echo 'deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list"
wait
pssh -i -h $ips "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y kubelet kubeadm kubectl"
wait
pssh -i -h $ips "sudo apt-mark hold kubelet kubeadm kubectl"
wait
# check
pssh -i -h $ips "kubectl version --client && kubeadm version"

# # Disable swap
pssh -i -h $ips "sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"
pssh -i -h $ips "sudo swapoff -a"
# # might be different depending on the distro
# pssh -i -h $ips "sudo rm /dev/mapper/vgubuntu-swap_1"

# # configure sysctl
pssh -i -h $ips "sudo modprobe overlay"
pssh -i -h $ips "sudo modprobe br_netfilter"
pssh -i -h $ips "sudo sysctl net.ipv4.ip_forward=1"
pssh -i -h $ips "sudo sysctl net.ipv4.conf.default.promote_secondaries=1"

pssh -i -h $ips 'cat << EOF | sudo tee /etc/sysctl.d/kubernetes.conf 
net.bridge.bridge-nf-call-ip6tables = 1 
net.ipv4.ip_forward = 1
net.ipv4.conf.default.promote_secondaries = 1
net.bridge.bridge-nf-call-iptables = 1 
EOF'

# https://kubernetes.io/docs/concepts/cluster-administration/networking/
# net.ipv4.ip_forward = 1 
pssh -i -h $ips "sudo sysctl --system"

exit 0
# SETUP MASTER NODES
# # kubeadm init --apiserver-advertise-address="145.100." --apiserver-cert-extra-sans="192.168.53.10"  --node-name k8s-master --pod-network-cidr=192.168.0.0/16
# kubeadm init --apiserver-advertise-address="145.100.58.129" --apiserver-cert-extra-sans="145.100.58.129"  --node-name 101319 --pod-network-cidr=192.168.0.0/16

# ssh ${!managers[0]} "sudo kubeadm init --control-plane-endpoint='${!managers[0]}' --apiserver-advertise-address='${!managers[0]}' --upload-certs --apiserver-cert-extra-sans='${!managers[0]}' --pod-network-cidr=192.168.0.0/16" > configs/logs.txt
# ssh ${!managers[0]} 'kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml'
# ssh ${!managers[0]} 'kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml'
# echo ${!managers[0]}
# in 1.21 calico didn't work so we are using flannel
# SETUP first control plane node
ssh ${!managers[0]} "sudo kubeadm init --control-plane-endpoint='${!managers[0]}' --apiserver-advertise-address='${!managers[0]}' --upload-certs --apiserver-cert-extra-sans='${!managers[0]}' --pod-network-cidr=10.244.0.0/16" > configs/logs.txt
ssh ${!managers[0]} 'mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config'


# Untaint the nodes to make it possible to deploy apps on the master nodes
# setup k8s for local pc


# kubeadm join 145.100.58.221:6443 --token 3gvp72.t5zc882ufn97rdvm \
#         --discovery-token-ca-cert-hash sha256:ff14d5c7774df238b9e244d5efd69bf70f5ba66d3f3284869b4c61b71c2208ea \
#         --control-plane --certificate-key 561b97142e6ad0674f438585c12ae29d576034214576a5b949c98a116400beb2

# ssh ${!managers[0]} "sudo kubeadm init phase upload-certs --upload-certs" >
add_manager=$(cat configs/logs.txt | grep "\-\-certificate-key")
echo "The manager control plane stuff is: $add_manager"
join=$(ssh ${!managers[0]} 'kubeadm token create --print-join-command')
# echo "$join $add_manager"

echo "Setup control-plane"
for manager in ${managers[@]:1}
do
    ssh "${!manager}" "sudo $join $add_manager" &
    ssh "${!managers}" 'mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config' &
done
wait

echo "Setup worker nodes"
for worker in ${workers[@]}
do
    # indirect parameter expansion
    ssh "${!worker}" "sudo $join" &
done

echo "Kubernetes setup is done."
# kubectl taint nodes --all node-role.kubernetes.io/master-

# # next step remove it to 