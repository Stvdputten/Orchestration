#!/usr/bin/env bash

ips="configs/ips"

echo "Docker Install Beginning..."
pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"


# dpkg lock should done, so all should end with exit code 1
# https://www.edureka.co/community/42504/error-dpkg-frontend-is-locked-by-another-process
# echo "Ensuring all dpkg are not locked, may take a while. Grab a coffee!"
# pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend" | grep "SUCCESS"
# while [ ! $? -eq 1 ]; do
#   echo "Waiting for front lock to be lifted"
#   sleep 10
#   pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend" | grep "SUCCESS" 
# done

pssh -i -h $ips "sudo apt-get update && sudo apt-get install -y vim git vim git apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop"
pssh -i -h $ips "sudo sh get-docker.sh > /dev/null 2&1"

# Configure Docker to run as the user
pssh -i -h $ips 'sudo usermod -aG docker $USER'
pssh -i -h $ips "docker --version"

# https://docs.docker.com/engine/swarm/swarm-tutorial/
# Swarm
pssh -i -h $ips "sudo ufw allow 7946/udp"
pssh -i -h $ips "sudo ufw allow 2377,7946,4789/tcp"

# prometheus, 8000 is the changed value of cadvisor
pssh -i -h $ips "sudo ufw allow 9323,3000,9090,8080,8000,9100,9323/tcp"
pssh -i -h $ips "sudo ufw allow 9323,3000,9090,8080,8000,9100,9323/udp"

# Ensure daemon.json
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

# docker-compose for hotel
pssh -i -h $ips 'sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose'
pssh -i -h $ips 'sudo chmod +x /usr/local/bin/docker-compose'

echo "Configurations done"