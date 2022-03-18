#!/usr/bin/env bash


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

if [ -z "$availability" ]; then
	export availability=0
fi

# Make sure correct network interface is being used
# device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | cut -d: -f1")
device="ens1f0"
# echo $device

count=1
# https://stackoverflow.com/questions/10929453/read-a-file-line-by-line-assigning-the-value-to-a-variable
while IFS= read -r line || [[ -n "$line" ]]; do
	if [ $availability -eq 0 ]; then
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
	elif [ $availability -ne 0 ]; then
		echo $count
		if [[ count -gt 1 ]]; then
			echo "WORKER $line"
			ssh -n -tt $line "$join_worker"
		elif [[ count -eq 1 ]]; then
			echo "First manager setup"
			echo "$line"

			result=$(ssh -n $line "ip addr show $device | grep 'inet\b' | awk '{print $2}' | cut -d/ -f1")
			ip=$(echo $result | awk '{print $2}')
			ssh -n $line "docker swarm init --advertise-addr $ip"
			join_worker=$(ssh -n $line "docker swarm join-token worker | grep 'docker swarm'")
			# echo $join_manager
			# echo $join_worker
			echo "Commands are ready"
		fi
	else
		echo "Something went wrong with the param availability"
		exit 1
	fi
	count=$((count + 1))
done < "$ips" 

echo "Cluster is setup"
exit 0 
