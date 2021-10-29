#!/usr/bin/env bash

# ips="$HOME/.pssh_hosts_files"
ips="configs/ips"

# dpkg lock should done, so all should end with exit code 1
# https://www.edureka.co/community/42504/error-dpkg-frontend-is-locked-by-another-process
# echo "Ensuring all dpkg are not locked, may take a while. Grab a coffee!"
pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'"
while [ ! $? -eq 0 ]; do
  echo "Waiting for front lock to be lifted"
  sleep 10
  pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | echo SUCCESS" 
done

echo "Docker Install Beginning..."
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
pssh -i -h $ips "sudo apt-get update -y"
pssh -i -h $ips "sudo apt-get install -y docker-ce docker-ce-cli containerd.io "

# Configure Docker to be run as the user
pssh -i -h $ips 'sudo usermod -aG docker $USER'
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

echo "Nomad and Consul Install Beginning..."

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