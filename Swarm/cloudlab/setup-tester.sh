#!/usr/bin/env bash
# The params
user="stvdp"
remote=$(head -n 1 configs/remote)
manager=$(head -n 1 configs/ips)
ips=configs/ips

echo "Setup Tester"
echo "Starting remote env start-up scripts"

# dpkg lock should done, so all should end with exit code 1
# https://www.edureka.co/community/42504/error-dpkg-frontend-is-locked-by-another-process
echo "Ensuring all dpkg are not locked, may take a while. Grab a coffee!"
ssh -n $remote "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'"
while [ ! $? -eq 0 ]; do
  echo "Waiting for front lock to be lifted"
  sleep 10
  ssh -n $remote "sudo lsof /var/lib/dpkg/lock-frontend | grep 'SUCCESS'" 
done
ssh -n $remote "sudo apt-get update && sudo apt-get install -y vim git vim git apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop"

# Install docker
echo "Docker Install Beginning..."
ssh -n $remote "curl -fsSL https://get.docker.com -o get-docker.sh"
ssh -n $remote "test -f 'get-docker.sh'"
while [ ! $? -eq  0 ]; do
  ssh -n $remote "curl -fsSL https://get.docker.com -o get-docker.sh"
  ssh -n $remote "test -f 'get-docker.sh'"
done
ssh -n $remote "sudo apt-get update && sudo apt-get install -y vim git vim apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop"

# Configure Docker to be run as the user
ssh -n $remote 'sudo usermod -aG docker $USER'
ssh -n $remote "docker --version"
while [ ! $? -eq  0 ]; do
  echo "Waiting for docker to be installed"
  ssh -n $remote "VERSION=20.10 && sudo sh get-docker.sh > /dev/null 2&1"
  ssh -n $remote "docker --version"
done
ssh -n $remote 'sudo usermod -aG docker $USER'

# Enable docker service
ssh -n $remote "sudo systemctl enable docker"
ssh -n $remote "sudo systemctl daemon-reload"
ssh -n $remote "sudo systemctl restart docker"

# Setup wrk2 etc
ssh -n $remote "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
ssh -n $remote "pip install --no-input asyncio aiohttp"
ssh -n $remote "sudo luarocks install luasocket"

# Download the repo
ssh -n $remote "git clone --single-branch --branch local https://github.com/Stvdputten/DeathStarBench"

#  Check if wrk is exists
ssh $remote "cd DeathStarBench/socialNetwork/wrk2 && make clean && make"
ssh $remote "cd DeathStarBench/mediaMicroservices/wrk2 && make clean && make"
ssh $remote "cd DeathStarBench/hotelReservation/wrk2 && make clean && make"

# Install kubectl 
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-other-package-management
# ssh -n "$remote" "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common"
# wait
# ssh -n "$remote" "sudo rm /etc/apt/sources.list.d/kubernetes.list" 
# wait
# ssh -n "$remote" "sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg"
# wait
# ssh -n "$remote" 'echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list'
# wait
# ssh -n "$remote" "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y kubectl"
# wait
# ssh -n "$remote" "sudo apt-mark hold kubectl"
# wait
# ssh -n "$remote" "kubectl version --client"

# Send ssh-key to remote cluster
ssh -n "$remote" "ssh-keygen -t rsa -f /tmp/sshkey -q -N '' <<< $'\ny' >/dev/null 2>&1"
pubkey=$(ssh -n "$remote" "cat /tmp/sshkey.pub")
pssh -i -h $ips "echo $pubkey >> /users/stvdp/.ssh/authorized_keys"

# echo "Copy Kubernetes configs"
# https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/ 
# setup k8s access on remote machine
# ssh -n $remote 'mkdir -p $HOME/.kube'
# scp $manager:'/users/stvdp/.kube/config' .
# scp ./config  $remote:'/users/stvdp/.kube/config'
# rm ./config

# connect to k8  cluster
# ssh -n "$remote" "mkdir -p ~/.kube/"
# ssh -n "$remote" "touch ~/.kube/cloudlab_config_k8"
# ssh -n "$remote" "scp -i /tmp/sshkey $manager:/users/stvdp/.kube/config /users/stvdp/.kube/cloudlab_config_k8"
# ssh -n "$remote" "echo export KUBECONFIG=\'/users/stvdp/.kube/cloudlab_config_k8\' >> ~/.bashrc_profile"
# ssh -n "$remote" "echo export KUBECONFIG=\'/users/stvdp/.kube/cloudlab_config_k8\' >> ~/.bashrc"

# nomad/hashi/kubectl

# monitoring
# pod_name_prom=kubectl get pods  -n monitoring | grep "prome-prometheus" | awk '{ print $1 }'

echo "Configurations remote tester done"
# echo "$manager"
echo "The ip of remote experimentor is:"
echo "$remote"