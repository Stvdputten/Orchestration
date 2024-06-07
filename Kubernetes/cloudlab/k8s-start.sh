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

if [ -z "$availability" ]; then
  export availability=0
fi

# device="eno33"
# device2="ens1f0"

# device="eno1"
# device2="eno1d1"
device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")
# ip_manager_int=$(ssh -n $manager "ip addr show $device2 | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")

managers=(${!MANAGER_@})
workers=(${!WORKER_@})

echo $ip_manager
echo $ip_manager_int



# SETUP first control plane node
# TODO what happens if cfirst configs/logs fails? Rest of the script will fail? -> how to solve
# ssh $manager "sudo kubeadm init --control-plane-endpoint='$ip_manager_int' --apiserver-advertise-address='$ip_manager_int' --upload-certs --apiserver-cert-extra-sans='$ip_manager_int' --pod-network-cidr=10.244.0.0/16" > configs/logs.txt
ssh $manager "sudo kubeadm init --control-plane-endpoint='$ip_manager' --apiserver-advertise-address='$ip_manager' --upload-certs --apiserver-cert-extra-sans='$ip_manager' --pod-network-cidr=10.244.0.0/16" > configs/logs.txt
sleep 10
ssh $manager 'mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config'
ssh $manager 'kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml'

# clean up kubadm reset
# sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
# sudo rm -rf /etc/cni/net.d
# check internal ip addres
# kubectl get nodes -o wide
# pssh -i -h $ips "sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X"
# pssh -i -h $ips "sudo rm -rf /etc/cni/net.d"

add_manager=$(cat configs/logs.txt | grep "\-\-certificate-key")
join=$(ssh $manager 'kubeadm token create --print-join-command') 

# echo $availability

if [ $availability -eq 0 ]; then
    # Can be done parallel, $command & , but might be preferable to do it sequentially
    echo "Setup control-plane"
    for manager in ${managers[@]:1}
    do
        echo "${!manager} joining the cluster"
        # ssh -n "${!manager}" "sudo $join $add_manager" > /dev/null 2>&1
        ssh -n "${!manager}" "sudo $join $add_manager" 
        # ssh -n "${!manager}" 'mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config' > /dev/null 2>&1
        ssh -n "${!manager}" 'mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config' 
        sleep 5
    done

    echo "Setup worker nodes"
    for worker in ${workers[@]}
    do
        echo "${!worker} joining the cluster"
        # indirect parameter expansion
        # ssh -n "${!worker}" "sudo $join" > /dev/null 2>&1
        ssh -n "${!worker}" "sudo $join" 
        sleep 2
    done

elif [ $availability -eq 1 ]; then
    echo "Setup worker nodes"
    for worker in ${workers[@]}
    do
        echo "${!worker} joining the cluster"
        # indirect parameter expansion
        ssh -n "${!worker}" "sudo $join" > /dev/null 2>&1
        sleep 2
    done
fi

echo "Kubernetes setup is done."
