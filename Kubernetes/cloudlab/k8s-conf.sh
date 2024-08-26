#!/usr/bin/env bash

# we follow
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
# source ./configs/ips
source configs/roles
# ips="configs/ips"

if [ -z "$ips" ]; then
  ips="configs/ips"
  export ips=$ips
fi

echo "Kubernetes configuration is starting."
kubeadm_version="1.24"
export kubeadm_version=$kubeadm_version
kubelet_version="1.24"
export kubelet_version=$kubelet_version
kubectl_version="1.24"
export kubectl_version=$kubectl_version
pssh -i -h $ips 'sudo chsh -s /bin/bash $USER'


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
# pssh -i -h $ips "sudo ufw allow 6443,2379,2380,10250,10251,10252,10255/tcp"
# pssh -i -h $ips "sudo ufw reload"

# # worker nodes
# pssh -i -h $ips "sudo ufw allow 10250,10251,10255/tcp"
# pssh -i -h $ips "sudo ufw allow 30000:32767/tcp"

#  SETUP KUBERNETES
ips="configs/ips"

# # install kubeadm/kubelet/kubectl
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-other-package-management
pssh -i -h $ips "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gpg gnupg-agent software-properties-common"
# # check
pssh -i -h $ips "kubectl version --client && kubeadm version"
while [ $? -ne 0 ]; do
    echo "Kubernetes installation."

    if  ! pssh -i -h $ips "test -f /etc/apt/sources.list.d/kubernetes.list"; then
        pssh -i -h $ips "sudo rm /etc/apt/sources.list.d/kubernetes.list"
    fi
    wait

    pssh -i -h $ips "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common"

    wait 
    # pssh -i -h $ips "sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg"
    pssh -i -h $ips "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.24/deb/Release.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"

    wait
    # pssh -i -h $ips 'echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list'
    # TODO make it possible to chance versions
    pssh -i -h $ips 'echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.24/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list'


    # pssh -i -h $ips "sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg"
    # wait
    # pssh -i -h $ips "echo 'deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list"
    # wait
    pssh -i -h $ips "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y --allow-change-held-packages kubelet=$kubelet_version.\* kubeadm=$kubeadm_version.\* kubectl=$kubectl_version.\*"
    wait
    pssh -i -h $ips "sudo apt-mark hold kubelet kubeadm kubectl"
    wait
    pssh -i -h $ips "kubectl version --client && kubeadm version"
done

pssh -i -h $ips "kubectl version --client && kubeadm version"
if [ $? -ne 0 ]; then
    echo "Kubernetes failed."
    exit 1
fi

# # Disable swap
pssh -i -h $ips "sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"
pssh -i -h $ips "sudo swapoff -a"
# # might be different depending on the distro
# pssh -i -h $ips "sudo rm /dev/mapper/vgubuntu-swap_1"

# # configure sysctl
pssh -i -h $ips "sudo modprobe overlay"
pssh -i -h $ips "sudo modprobe br_netfilter"
pssh -i -h $ips "sudo sysctl net.ipv4.ip_forward=1"
# pssh -i -h $ips "sudo sysctl net.ipv4.conf.default.promote_secondaries=1"

# net.ipv4.conf.default.promote_secondaries = 1
pssh -i -h $ips 'sudo tee /etc/sysctl.d/kubernetes.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1 
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1 
EOF'

# https://kubernetes.io/docs/concepts/cluster-administration/networking/
# net.ipv4.ip_forward = 1 
pssh -i -h $ips "sudo sysctl --system"

# Add the kubectl auto-completion
# https://kubernetes.io/docs/reference/kubectl/cheatsheet/
# SHELL_REMOTE=bash
# source <(kubectl completion $SHELL_REMOTE)  # setup autocomplete in zsh into the current shell
# echo "[[ $commands[kubectl] ]] && source <(kubectl completion $SHELL_REMOTE)" >> ~/.zshrc # add autocomplete permanently to your zsh shell

echo "Kubernetes configured."