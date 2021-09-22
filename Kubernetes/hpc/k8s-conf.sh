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

echo "Kubernetes configured."