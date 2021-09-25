#!/usr/bin/env bash 

ips="configs/ips"

# Add consul server ip
manager=$(head -n 1 configs/ips)
device="eth1"
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")
# pssh -i -h $ips "echo '$ip_manager consul_server' | sudo tee -a /etc/hosts"

# Setup Promotheus telemetry
# pssh -i -h ~/.pssh_hosts_files "cat telemetry | sudo tee -a /etc/nomad.d/nomad.hcl"
# pssh -i -h $ips 'cat << EOF | sudo tee -a /etc/nomad.d/nomad.hcl
# telemetry {
#   collection_interval = "1s"
#   disable_hostname = true
#   prometheus_metrics = true
#   publish_allocation_metrics = true
#   publish_node_metrics = true
# } 
# EOF'
# pssh -i -h $ips "sudo systemctl restart nomad.service"
# pssh -i -h $ips 'NOMAD_IP_prometheus_ui=ip addr show eth0 | grep "inet\b" | awk "{print \$2}" | cut -d/ -f1'

echo "First monitoring"
# ssh -n $manager "cd prometheus && docker stack deploy -c docker-stack.yml monitoring"
scp "monitoring.nomad" "stvdputten@$manager:/home/stvdputten" 
ssh -n $manager "nomad job run -var='consul_ip=$ip_manager' -var='consul_name=consul_server' monitoring.nomad"

echo "Monitoring is setup"