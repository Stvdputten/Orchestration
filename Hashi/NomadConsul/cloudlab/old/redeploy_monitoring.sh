#!/usr/bin/env bash 

ips="configs/ips"
user="stvdp"

# Add consul server ip
manager=$(head -n 1 configs/ips)
device="eno1d1"
# uses internal ip not public ip
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")
# pssh -i -h $ips "echo '$ip_manager consul_server' | sudo tee -a /etc/hosts"

# deploy job monitoring.nomad
scp "./configs/monitoring.nomad" "$manager:/users/$user/" 
# choose the first client node as the prometheus server
prometheus_hostname=$(ssh -n $manager 'head -n 1 /etc/hosts ' | awk '{ print $4 }' | sed 's/localhost/node3/') 
ssh -n $manager "nomad job run -var='consul_ip=$ip_manager' -var='consul_name=consul_server' -var='prometheus_hostname=$prometheus_hostname' monitoring.nomad"

echo "Monitoring is setup"