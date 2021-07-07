#!/usr/bin/env bash 

ips="configs/ips"
manager=$(head -n 1 configs/ips)

# Setup Promotheus telemetry
pssh -i -h $ips 'cat << EOF | sudo tee -a /etc/nomad.d/nomad.hcl
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
} 
client {
  host_volume "test" {
    path = "/users/stvdp/"
    read_only = true
  }
  plugin "docker" {
    config{
      volumes {
        enabled = true
      }
    }
  }
}

EOF'
pssh -i -h $ips "sudo systemctl restart nomad.service"

# Deploy on remote
scp prometheus.nomad "$manager:~"
scp grafana.nomad "$manager:~"
ssh $manager "nomad job run prometheus.nomad"
ssh $manager "nomad job run grafana.nomad"

# count=1
# while IFS= read -r line; do
# 	echo $count
# 	# scp "configs/prometheus.yml" "$line:~"
# 	scp "configs/prometheus.nomad" "$line:~"
#   count=$((count + 1))
# done <"$ips"
