#!/usr/bin/env bash 

ips="configs/ips"
# Setup Promotheus telemetry
# pssh -i -h ~/.pssh_hosts_files "cat telemetry | sudo tee -a /etc/nomad.d/nomad.hcl"
pssh -i -h $ips 'cat << EOF | sudo tee -a /etc/nomad.d/nomad.hcl
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
} 
EOF'
pssh -i -h $ips "sudo systemctl restart nomad.service"
# pssh -i -h $ips 'NOMAD_IP_prometheus_ui=ip addr show eth0 | grep "inet\b" | awk "{print \$2}" | cut -d/ -f1'