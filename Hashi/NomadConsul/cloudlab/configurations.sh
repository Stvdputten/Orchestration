#!/usr/bin/env bash

#Contains stuff that only needs to be setup once

# ips="$HOME/.pssh_hosts_files"
ips="configs/ips"

# dpkg lock should done, so all should end with exit code 1
# https://www.edureka.co/community/42504/error-dpkg-frontend-is-locked-by-another-process
# echo "Ensuring all dpkg are not locked, may take a while. Grab a coffee!"
pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'"
while [ ! $? -eq 0 ]; do
  echo "Waiting for front lock to be lifted"
  sleep 10
  pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'" 
done

# Install docker
echo "Docker Install Beginning..."
pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
pssh -i -h $ips "test -f 'get-docker.sh'"
while [ ! $? -eq  0 ]; do
  pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
  pssh -i -h $ips "test -f 'get-docker.sh'"
done
pssh -i -h $ips "sudo apt-get update && sudo apt-get install -y vim git vim apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop"

# Configure Docker to be run as the user
pssh -i -h $ips 'sudo usermod -aG docker $USER'
pssh -i -h $ips "docker --version"
while [ ! $? -eq  0 ]; do
  echo "Waiting for docker to be installed"
  pssh -i -h $ips "VERSION=20.10 && sudo sh get-docker.sh > /dev/null 2&1"
  pssh -i -h $ips "docker --version"
done
pssh -i -h $ips 'sudo usermod -aG docker $USER'

# Ensure daemon.json
pssh -i -h $ips 'sudo rm /etc/docker/daemon.json'
pssh -i -h $ips "sudo mkdir -p /etc/systemd/system/docker.service.d"
# pssh -i -h $ips 'cat << EOF | sudo tee /etc/docker/daemon.json  
pssh -i -h $ips 'sudo tee /etc/docker/daemon.json  << EOF
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

# Enable docker service
pssh -i -h $ips "sudo systemctl enable docker"
pssh -i -h $ips "sudo systemctl daemon-reload"
pssh -i -h $ips "sudo systemctl restart docker"

echo "Nomad and Consul setup..."

# Install hashi-up
pssh -i -h $ips "curl -sLS https://get.hashi-up.dev | sudo sh"
pssh -i -h $ips "sudo install hashi-up /usr/local/bin/"
pssh -i -h $ips "hashi-up version"

# Disable ufw
pssh -i -h $ips "sudo ufw disable"

# Consul
pssh -i -h $ips "sudo ufw allow 8300,8301,8302,8500,8600/udp"
pssh -i -h $ips "sudo ufw allow 8300,8301,8302,8500,8600/tcp"

# Nomad
pssh -i -h $ips "sudo ufw allow 4648/udp"
pssh -i -h $ips "sudo ufw allow 4646,4647,4648/tcp"

# docker-compose for hotel
pssh -i -h $ips 'sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose'
pssh -i -h $ips 'sudo chmod +x /usr/local/bin/docker-compose'

# configuration for CNI
# https://www.nomadproject.io/docs/integrations/consul-connect
pssh -i -h $ips "curl -L -o cni-plugins.tgz 'https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)'-v1.0.1.tgz"
pssh -i -h $ips "sudo mkdir -p /opt/cni/bin"
pssh -i -h $ips "sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz"

#  bridge network to be routed via iptables
pssh -i -h $ips "echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-arptables"
pssh -i -h $ips "echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-ip6tables"
pssh -i -h $ips "echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables"

# setup dnsmasq https://computingforgeeks.com/install-and-configure-dnsmasq-on-ubuntu/
# sudo systemctl disable systemd-resolved
# sudo systemctl stop systemd-resolved

# Download the repo
pssh -i -h $ips "git clone --single-branch --branch local https://github.com/Stvdputten/DeathStarBench"

# Setup wrk2 etc
pssh -i -h $ips "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
pssh -i -h $ips "pip install --no-input asyncio aiohttp"
pssh -i -h $ips "sudo luarocks install luasocket"

echo "Configurations done"