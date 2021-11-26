#!/usr/bin/env bash
# The params
user="stvdp"
ip="ms0810.utah.cloudlab.us"
remote="$user@$ip"
manager=$(head -n 1 configs/ips)

echo "Setup Tester"
echo "Starting remote env start-up scripts"
# Configurations
ips="configs/ips"

pod_name_prom=kubectl get pods  -n monitoring | grep "prome-prometheus" | awk '{ print $1 }'

# echo "Docker Install Beginning..."
ssh $remote "curl -fsSL https://get.docker.com -o get-docker.sh"

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
ssh -n $remote "sudo sh get-docker.sh > /dev/null 2&1"

# Configure Docker to run as the user
ssh -n $remote 'sudo usermod -aG docker $USER'
ssh -n $remote "docker --version"

# Disable ufw
ssh -n $remote "sudo ufw disable"

# docker-compose for hotel
ssh -n $remote 'sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose'
ssh -n $remote 'sudo chmod +x /usr/local/bin/docker-compose'

# Install kubectl 
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-other-package-management
ssh -n "$remote" "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common"
wait
ssh -n "$remote" "sudo rm /etc/apt/sources.list.d/kubernetes.list" 
wait
ssh -n "$remote" "sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg"
wait
ssh -n "$remote" 'echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list'
wait
ssh -n "$remote" "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y kubectl"
wait
ssh -n "$remote" "sudo apt-mark hold kubectl"
wait
ssh -n "$remote" "kubectl version --client"

# Get directory for experiments 
ssh -n $remote "sudo git clone --single-branch --branch local https://github.com/Stvdputten/DeathStarBench" 

# Send ssh-key to remote cluster
ssh -n "$remote" "ssh-keygen -t rsa -f /tmp/sshkey -q -N '' <<< $'\ny' >/dev/null 2>&1"
pubkey=$(ssh -n "$remote" "cat /tmp/sshkey.pub")
pssh -i -h $ips "echo $pubkey >> /users/stvdp/.ssh/authorized_keys"

# connect to k8  cluster
ssh -n "$remote" "mkdir -p ~/.kube/"
ssh -n "$remote" "touch ~/.kube/cloudlab_config_k8"
ssh -n "$remote" "scp -i /tmp/sshkey $manager:/users/stvdp/.kube/config /users/stvdp/.kube/cloudlab_config_k8"
ssh -n "$remote" "echo export KUBECONFIG=\'/users/stvdp/.kube/cloudlab_config_k8\' >> ~/.bashrc_profile"
ssh -n "$remote" "echo export KUBECONFIG=\'/users/stvdp/.kube/cloudlab_config_k8\' >> ~/.bashrc"

# install packages required for running tests with 
ssh -n "$remote" "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
ssh -n "$remote" "pip install --no-input asyncio aiohttp"
ssh -n "$remote" "sudo luarocks install -y luasocket"


# deploy application k8s
./setup-experiments.sh

# nomad/hashi/kubectl

echo "Configurations remote tester done"
echo "$manager"
echo "The ip of remote experimentor is:"
echo "$remote"