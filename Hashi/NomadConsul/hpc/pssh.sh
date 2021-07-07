#!/usr/bin/env bash

# prefix=Swarm
prefix=hashi-manager
prefix_worker=hashi-worker
# prefix=Hashi
# destination_pssh="$HOME/.pssh_hosts_files_hpc_k8"
# BUG if multiple instances exists, (previous still not deleted e.g.), doesn't correctly do this
destination_ips="configs/ips"
destination_roles="configs/roles"

# get IPs
manager_ips=$(onevm list -f NAME~${prefix} -l IP --no-header | grep -o '145.100\(.\)\{6\}[0-9]*')
worker_ips=$(onevm list -f NAME~${prefix_worker} -l IP --no-header | grep -o '145.100\(.\)\{6\}[0-9]*')
# echo $IP
# no ssh issues/warnings
ssh-keygen -R $manager_ips &>/dev/null
ssh-keygen -R $worker_ips &>/dev/null
# $IP > ${destination}

# create empty file to store IPs for pssh
if [[ -f "$destination_ips" ]]; then
    # echo $USER
    rm "${destination_ips}"
fi
touch "${destination_ips}"

if [[ -f "$destination_roles" ]]; then
    # echo $USER
    rm "${destination_roles}"
fi
touch "${destination_roles}"

# Setup the configs files
# quickfix to get multiple rows
i=0
for n in $manager_ips
do
    i=$(($i + 1))
    echo "SERVER_${i}_IP=$n" >> $destination_roles
    echo "$n" >> $destination_ips
done

i=0
for n in $worker_ips
do
    i=$(($i + 1))
    echo "AGENT_${i}_IP=$n" >> $destination_roles
    echo "$n" >> $destination_ips
done
echo "SSH is setup."