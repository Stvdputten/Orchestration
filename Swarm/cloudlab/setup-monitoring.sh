#!/usr/bin/env bash

# ips="$HOME/.pssh_hosts_files_hpc_swarm"
if [ -z "$ips" ]; then
	ips="configs/ips"
	export ips=$ips
fi
if [ -z "$manager" ]; then
	manager=$(head -n 1 configs/ips)
	export manager=$manager
fi
if [ -z "$remote" ]; then
	remote=$(head -n 1 configs/remote)
	export remote=$remote
fi

# OLD Make sure prometheus isn't installed in home directory
# pssh -i -h $ips "rm -rf prometheus"
# pssh -i -h $ips "git clone https://github.com/stvdputten/prometheus"

# NEW https://github.com/stefanprodan/swarmprom
pssh -i -h $ips "rm -rf swarmprom"
pssh -i -h $ips "git clone https://github.com/stefanprodan/swarmprom.git "

echo "First monitoring"
ssh -n $manager "sudo ufw allow 5001"
ssh -n $manager "docker stack rm monitoring"
ssh -n $manager "docker run -it -d -p 5001:8080 -v /var/run/docker.sock:/var/run/docker.sock dockersamples/visualizer"
# ssh -n $manager "cd prometheus && docker stack deploy -c docker-stack.yml monitoring"
ssh -n $manager "cd swarmprom && ADMIN_USER=admin ADMIN_PASSWORD=admin docker stack deploy -c docker-compose.yml monitoring"

echo "Monitoring is setup"

