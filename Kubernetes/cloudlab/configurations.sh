#!/usr/bin/env bash

ips="configs/ips"

echo "Docker Install Beginning..."
# dpkg lock should done, so all should end with exit code 1
# https://www.edureka.co/community/42504/error-dpkg-frontend-is-locked-by-another-process
echo "Ensuring all dpkg are not locked, may take a while. Grab a coffee!"
pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'"
while [ $? -ne 0 ]; do
  echo "Waiting for front lock to be lifted"
  sleep 10
  pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'" 
done

echo "Ensure bash is used as remote shell"
pssh -i -h $ips 'sudo chsh -s /bin/bash $USER'

# Install docker
pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
pssh -i -h $ips "test -f 'get-docker.sh'"
while [ ! $? -eq  0 ]; do
  pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
  pssh -i -h $ips "test -f 'get-docker.sh'"
done
pssh -i -h $ips "sudo apt-get update && sudo apt-get install -y vim git vim apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop"

# Configure Docker to run as the user
pssh -i -h $ips "docker --version"
while [ $? -ne  0 ]; do
  echo "Waiting for docker to be installed"
  pssh -i -h $ips "VERSION=20.10 && sudo sh get-docker.sh > /dev/null 2&1"
  pssh -i -h $ips 'sudo usermod -aG docker $USER'
  pssh -i -h $ips "docker --version"
done

echo "Disable ufw"
# Disable ufw
pssh -i -h $ips "sudo ufw disable"

# https://docs.docker.com/engine/swarm/swarm-tutorial/
# Swarm
# pssh -i -h $ips "sudo ufw allow 7946/udp"
# pssh -i -h $ips "sudo ufw allow 2377,7946,4789/tcp"

# prometheus, 8000 is the changed value of cadvisor
# pssh -i -h $ips "sudo ufw allow 9323,3000,9090,8080,8000,9100,9323/tcp"
# pssh -i -h $ips "sudo ufw allow 9323,3000,9090,8080,8000,9100,9323/udp"

# Ensure daemon.json
echo "Ensure daemon.json"
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
echo "Ensure systemctl"
pssh -i -h $ips "sudo systemctl enable docker"
pssh -i -h $ips "sudo systemctl daemon-reload"
pssh -i -h $ips "sudo systemctl restart docker"

# docker-compose for hotel
# pssh -i -h $ips 'sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose'
# pssh -i -h $ips 'sudo chmod +x /usr/local/bin/docker-compose'

# Have the directories for DSB
pssh -i -h $ips "git clone --single-branch --branch local https://github.com/Stvdputten/DeathStarBench"

echo "Configurations done"