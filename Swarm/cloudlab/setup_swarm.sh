#!/usr/bin/env bash

# input="/path/to/txt/file"
# input="/home/stvdputten/.pssh_hosts_files_cloudlab"
input="configs/ips"
# device="enp1s0"
device="eno1"
# localip
# device="enp1s0d1"
# device="eth0"
count=1
# https://stackoverflow.com/questions/10929453/read-a-file-line-by-line-assigning-the-value-to-a-variable
while IFS= read -r line || [[ -n "$line" ]]; do
	echo $count
	if [[ count -gt 1  && count -lt 4 ]]; then
		echo "MANAGER $line"
		ssh -n -tt $line "$join_manager"
		# echo "MANAGER $line"
	elif [[ count -gt 3 ]]; then
		echo "WORKER $line"
		ssh -n -tt $line "$join_worker"
	elif [[ count -eq 1 ]]; then
		echo "First manager setup"
		echo "$line"

		result=$(ssh -n $line "ip addr show $device | grep 'inet\b' | awk '{print $2}' | cut -d/ -f1")
		ip=$(echo $result | awk '{print $2}')
		ssh -n $line "docker swarm init --advertise-addr $ip"
		join_manager=$(ssh -n $line "docker swarm join-token manager | grep 'docker swarm'")
		join_worker=$(ssh -n $line "docker swarm join-token worker | grep 'docker swarm'")
		# echo $join_manager
		# echo $join_worker
		echo "Commands are ready"
	fi
	count=$((count + 1))
done < "$input" 

echo "Cluster is setup"
