#!/usr/bin/env bash

ips="configs/ips"

# https://stackoverflow.com/questions/49721708/how-to-install-specific-version-of-kubernetes/50447714
# docker_version="20.10.7~3-0~ubuntu-focal"
# pssh -i -h ~/.pssh_hosts_files "mkdir Swarm"
# pssh -i -h ~/.pssh_hosts_files "cd Swarm"
# pssh -i -h ~/.pssh_hosts_files "git clone https://github.com/delimitrou/DeathStarBench Swarm/DeathStarBench"
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

# pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend"
pssh -i -h $ips "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y vim git apt-transport-https ca-certificates curl gnupg-agent software-properties-common"
# wait
# Should fix the apt-get lock or something
# pssh -i -h $ips "while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done"
# pssh -i -h $ips "sudo killall apt apt-get"
pssh -i -h $ips "docker --version" 
if [ ! $? -eq 0 ]; then
  pssh -i -h $ips "sudo sh get-docker.sh > /dev/null 2&1"
fi
# wait
# Configure Docker to run as the user
pssh -i -h $ips 'sudo usermod -aG docker $USER'
pssh -i -h $ips "docker --version"

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
# pssh -i -h $ips "sudo systemctl daemon-reload"
# pssh -i -h $ips "sudo systemctl restart docker"

pssh -i -h $ips "sudo ufw disable"

# https://docs.docker.com/engine/swarm/swarm-tutorial/
# Swarm
pssh -i -h $ips "sudo ufw allow 7946/udp"
pssh -i -h $ips "sudo ufw allow 2377,7946,4789/tcp"

# prometheus
pssh -i -h $ips "sudo ufw allow 9323,3000,9090,8080,9100,9323/tcp"
pssh -i -h $ips "sudo ufw allow 9323,3000,9090,8080,9100,9323/udp"

# "metrics-addr" : "$(ip addr show eth0 | grep "inet\b" | awk "{print \$2}" | cut -d/ -f1 |  awk "{print $2}"):9323",
# pssh -i -h $ips 'cat << EOF | sudo tee /etc/docker/daemon.json 
# {
#   "metrics-addr" : "0.0.0.0:9323",
#   "experimental" : true
# }
# EOF'

pssh -i -h $ips "sudo systemctl enable docker"
pssh -i -h $ips "sudo systemctl daemon-reload"
pssh -i -h $ips "sudo systemctl restart docker"

echo "Setup docker completed"
# Social-network
# pssh -i -h $ips "sudo ufw allow 8080,9042,8081,16686,14269/tcp"
# pssh -i -h $ips "sudo ufw allow 8080,9042,8081,16686,14269/udp"

