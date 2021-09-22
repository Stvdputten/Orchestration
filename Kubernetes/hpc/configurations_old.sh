#!/usr/bin/bash

# destination="$HOME/.pssh_hosts_files_hpc_k8"
ips="configs/ips"
# source $destination
version=""

# Update the apt packages and get a couple of basic tools
# pssh -i -h configs/ips "sudo apt-get update && wait && DEBIAN_FRONTEND=noninteractive && sudo apt-get install -y apt-transport-https" 
# && wait && DEBIAN_FRONTEND=noninteractive && sudo apt-get install -y apt-transport-https ca-certificates curl git vim gnupg gnupg-agent lsb-release software-properties-common"

# Install docker
# https://docs.docker.com/engine/install/ubuntu/
# https://askubuntu.com/questions/506158/unable-to-initialize-frontend-dialog-when-using-ssh
# pssh -i -h $ips "while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done"
pssh -i -h $ips "sudo apt-get update"
pssh -i -h $ips "while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done"
pssh -i -h $ips "DEBIAN_FRONTEND=noninteractive sudo apt-get install -y apt-transport-https ca-certificates curl git ufw vim gnupg gnupg-agent lsb-release software-properties-common"
pssh -i -h $ips "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
pssh -i -h $ips 'echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'

pssh -i -h $ips "sudo mkdir /tmp/archive/"

# Install Docker Community Edition
echo "Docker Install Beginning..."
pssh -i -h $ips "sudo apt-get update"
pssh -i -h $ips "while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done"
pssh -i -h $ips "DEBIAN_FRONTEND=noninteractive sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
# Install docker using a convenience scripts, but buggy
# pssh -i -x "-o StrictHostKeyChecking=no" -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
# pssh -i -x "-o StrictHostKeyChecking=no" -h $ips "DEBIAN_FRONTEND=noninteractive && sudo sh ./get-docker.sh"
pssh -i -h $ips "sudo service docker restart"



# Configure Docker to run as the user
pssh -i -h $ips "sudo usermod -aG docker $USER"
pssh -i -h $ips "docker --version"

pssh -i -h $ips "sudo mkdir -p /etc/systemd/system/docker.service.d"
pssh -i -h $ips 'cat << EOF | sudo tee /etc/docker/daemon.json 
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF'
pssh -i -h $ips "sudo systemctl daemon-reload"
pssh -i -h $ips "sudo systemctl restart docker"
# not necessary to enable
# pssh -i -h $ips "sudo systemctl enable docker"
# pssh -i -h $ips "sudo service docker restart"
echo "Docker has been setup"


