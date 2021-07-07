#!/usr/bin/env bash

# hardcoded 
ips="/home/stvdputten/.pssh_hosts_files_cloudlab"

echo "Docker Install Beginning..."
# Run if there is not docker 
if [[ ! pssh -i -h $ips "docker version" ]]; then
    pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
    pssh -i -h $ips "sudo sh get-docker.sh > /dev/null 2&1"

fi

# Configure Docker to run as the user
pssh -i -h $ips 'sudo usermod -aG docker $USER'
pssh -i -h $ips "docker --version"

# https://docs.docker.com/engine/swarm/swarm-tutorial/
# Swarm
pssh -i -h $ips "sudo ufw allow 7946/udp"
pssh -i -h $ips "sudo ufw allow 2377,7946,4789/tcp"

# Monitoring

pssh -i -h $ips 'sudo rm /etc/docker/daemon.json'
pssh -i -h $ips 'cat << EOF | sudo tee /etc/docker/daemon.json 
{  
   "log-driver": "journald", 
   "metrics-addr" : "172.18.0.1:9323", 
   "experimental" : true, "default-ulimits": 
   { 
	"memlock": { 
		"Name": "memlock", 
		"Hard": -1, "Soft": -1 
	}, 
   "stack": 
   { 
	"Name": "stack", 
	"Hard": -1, 
	"Soft": -1 
   }
   } 
}
EOF'
pssh -i -h $ips 'sudo service docker restart'
# pssh -i -h $ips "sudo systemctl daemon-reload"
# pssh -i -h $ips "sudo systemctl restart docker"

# pssh -i -h $ips 'git clone https://github.com/stvdputten/docker-swarm-cluster.git'
# pssh -i -h $ips 'cd docker-swarm-cluster && bash create.sh'

echo "Docker has been setup"