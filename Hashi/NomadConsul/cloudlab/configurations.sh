#!/usr/bin/env bash

if [ -z "$ips" ]; then
  ips="configs/ips"
  export ips=$ips
fi

docker_version="20.10"

# dpkg lock should done, so all should end with exit code 1
# https://www.edureka.co/community/42504/error-dpkg-frontend-is-locked-by-another-process
echo "Ensuring all dpkg are not locked, may take a while. Grab a coffee!"
echo "Make sure your ssh-key is added as default key to ssh-agent"
count=0
pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'"
while [ $? -ne 0 ]; do
  echo "Waiting for front lock to be lifted"
  sleep 10
  count=$((count+1))
  if [ $count -eq 10 ]; then
    echo "Failed to unlock dpkg"
    exit 1
  fi
  pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | grep 'SUCCESS'" 
done

# Install docker
pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
pssh -i -h $ips "test -f 'get-docker.sh'"
while [ ! $? -eq  0 ]; do
  pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
  pssh -i -h $ips "test -f 'get-docker.sh'"
done
pssh -i -h $ips "sudo apt-get update && sudo apt-get install -y vim git vim apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop" > /dev/null 2>&1

# Configure Docker to run as the user
pssh -i -h $ips "docker --version"
while [ $? -ne  0 ]; do
  echo "Waiting for docker to be installed"
  pssh -i -h $ips "VERSION=$docker_version && sudo sh get-docker.sh" > /dev/null 2>&1
  pssh -i -h $ips 'sudo usermod -aG docker $USER'
  pssh -i -h $ips "docker --version"
done

# Ensure daemon.json
pssh -i -h $ips 'sudo rm /etc/docker/daemon.json' > /dev/null 2>&1
pssh -i -h $ips "sudo mkdir -p /etc/systemd/system/docker.service.d" /dev/null 2>&1
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

# # Consul
# pssh -i -h $ips "sudo ufw allow 8300,8301,8302,8500,8600/udp"
# pssh -i -h $ips "sudo ufw allow 8300,8301,8302,8500,8600/tcp"

# # Nomad
# pssh -i -h $ips "sudo ufw allow 4648/udp"
# pssh -i -h $ips "sudo ufw allow 4646,4647,4648/tcp"

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

# Setup packages required to load datasets or use wrk2 etc
# sometimes the packages are not installed, so we try to install them again?
pssh -i -h $ips "sudo apt-get install -y pip luarocks libz-dev libssl-dev" > /dev/null 2>&1
pssh -i -h $ips "sudo dpkg -s luarocks libssl-dev zlib1g-dev python3-pip" > /dev/null 2>&1
count=0 
while [ $? -ne 0 ]; do
  echo "Waiting for luarocks, libssl-dev, zlib1g-dev, python3-pip to be installed"
  pssh -i -h $ips "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
  count=$((count+1))
  if [ $count -eq 10 ]; then
    echo "Failed to install packages, exiting"
    exit 1
  fi
  pssh -i -h $ips "sudo dpkg -s luarocks libssl-dev zlib1g-dev python3-pip" > /dev/null 2>&1
done

pssh -i -h $ips "pip install --no-input asyncio aiohttp" > /dev/null 2>&1
pssh -i -h $ips "python3 -c 'import aiohttp, asyncio'" > /dev/null 2>&1 
count=0
while [ $? -ne 0 ]; do
  echo "Waiting for python3 asyncio and aiohttp to be installed"
  pssh -i -h $ips "pip install --no-input asyncio aiohttp"
  count=$((count+1))
  if [ $count -eq 10 ]; then
    echo "Failed to install packages, exiting"
    exit 1
  fi
  pssh -i -h $ips "python3 -c 'import aiohttp, asyncio'" > /dev/null 2>&1 
done

pssh -i -h $ips "sudo luarocks install luasocket" > /dev/null 2>&1
pssh -i -h $ips "luarocks list | grep 'luasocket'"
count=0
while [ $? -ne 0 ]; do
  echo "Waiting for luasocket to be installed"
  pssh -i -h $ips "sudo luarocks install luasocket" 
  count=$((count+1))
  if [ $count -eq 10 ]; then
    echo "Failed to install packages, exiting"
    exit 1
  fi
  pssh -i -h $ips "luarocks list | grep 'luasocket'" > /dev/null 2>&1
done

echo "Configurations done"
exit 0