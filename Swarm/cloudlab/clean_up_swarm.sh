#!/usr/bin/env bash

# input="/path/to/txt/file"
# input="$HOME/.pssh_hosts_files_hpc_swarm"
ips="configs/ips"

pssh -i -h $ips "docker swarm leave --force"
pssh -i -h $ips "docker system prune --volumes --force"
# device="eth0"
# count=0
# while IFS= read -r line;do
#   echo $count
#   if [[ count -le 2 && count -gt 0 ]]; then
#   	echo "MANAGER $line"
# 	ssh -n -tt $line "$join_manager"
#   	# echo "MANAGER $line"
#   elif [[ count -gt 2 ]]; then
# 	echo "WORKER $line"
# 	ssh -n -tt $line "$join_worker"
#   fi
#   if [[ count -eq 0 ]]; then
# 	echo "First manager setup"
#   	echo "$line"
# 	result=$(ssh -n $line "ip addr show $device | grep 'inet\b' | awk '{print $2}' | cut -d/ -f1")
# 	ip=$(echo $result | awk '{print $2}')
# 	ssh -n $line "docker swarm init --advertise-addr $ip"
# 	join_manager=$(ssh -n $line "docker swarm join-token manager | grep 'docker swarm'")
# 	join_worker=$(ssh -n $line "docker swarm join-token worker | grep 'docker swarm'")
# 	# echo $join_manager
# 	# echo $join_worker
# 	echo "Commands are ready"
#   fi
#   count=$((count+1))
# done < "$input"

echo "Cluster is setup"
