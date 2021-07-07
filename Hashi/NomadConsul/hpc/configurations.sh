#!/usr/bin/env bash

# ips="$HOME/.pssh_hosts_files"
ips="configs/ips"

# Install hashi-up
pssh -i -h $ips "curl -sLS https://get.hashi-up.dev | sudo sh"
pssh -i -h $ips "sudo install hashi-up /usr/local/bin/"
pssh -i -h $ips "hashi-up version"

# Install docker
# https://docs.docker.com/engine/install/ubuntu/
# Update the apt packages and get a couple of basic tools
pssh -i -h $ips "sudo apt-get update"
pssh -i -h $ips "sudo apt-get install -y unzip curl vim jq apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release"
pssh -i -h $ips "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
pssh -i -h $ips 'echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'

pssh -i -h $ips "sudo mkdir /tmp/archive/"

# Install Docker Community Edition
echo "Docker Install Beginning..."
pssh -i -h $ips "sudo apt-get update -y"
pssh -i -h $ips "sudo apt-get install -y docker-ce docker-ce-cli containerd.io "
# pssh -i -h $ips "sudo apt-get remove docker docker-engine docker.io"
# pssh -i -h $ips "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common "
# pssh -i -h $ips "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -"
# pssh -i -h $ips "sudo apt-key fingerprint 0EBFCD88"
# pssh -i -h $ips "sudo add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable'"
# pssh -i -h $ips "sudo apt-get update -y"
# pssh -i -h $ips "sudo apt-get install -y docker-ce"
# Configure Docker to be run as the user
pssh -i -h $ips "sudo usermod -aG docker $USER"
pssh -i -h $ips "sudo docker --version"

pssh -i -h $ips 'sudo rm /etc/docker/daemon.json'
pssh -i -h $ips "sudo mkdir -p /etc/systemd/system/docker.service.d"
pssh -i -h $ips 'cat << EOF | sudo tee /etc/docker/daemon.json  
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "metrics-addr" : "0.0.0.0:9323",
  "experimental" : true
}
EOF'

pssh -i -h $ips "sudo systemctl enable docker"
pssh -i -h $ips "sudo systemctl daemon-reload"
pssh -i -h $ips "sudo systemctl restart docker"
# Consul
pssh -i -h $ips "sudo ufw allow 8300,8301,8302,8500,8600/udp"
pssh -i -h $ips "sudo ufw allow 8300,8301,8302,8500,8600/tcp"

# Nomad
pssh -i -h $ips "sudo ufw allow 4648/udp"
pssh -i -h $ips "sudo ufw allow 4646,4647,4648/tcp"

# configuration for CNI
# https://www.nomadproject.io/docs/integrations/consul-connect
pssh -i -h $ips "curl -L -o cni-plugins.tgz 'https://github.com/containernetworking/plugins/releases/download/v0.9.0/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)'-v0.9.0.tgz"
pssh -i -h $ips "sudo mkdir -p /opt/cni/bin"
pssh -i -h $ips "sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz"

# Setup Promotheus telemetry
# pssh -i -h $ips "cat telemetry | sudo tee -a /etc/nomad.d/nomad.hcl"
# pssh -i -h $ips 'cat << EOF | sudo tee -a /etc/nomad.d/nomad.hcl
# telemetry {
#   collection_interval = "1s"
#   disable_hostname = true
#   prometheus_metrics = true
#   publish_allocation_metrics = true
#   publish_node_metrics = true
# } 
# EOF'
# pssh -i -h $ips "sudo systemctl restart nomad.service"