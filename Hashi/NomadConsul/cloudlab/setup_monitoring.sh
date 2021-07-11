#!/usr/bin/env bash 

ips="configs/ips"
manager=$(head -n 1 configs/ips)

# TODO setup experiments
pssh -i -h $ips "git clone --recurse-submodules --single-branch --branch local https://github.com/Stvdputten/DeathStarBench DeathStarBench"
pssh -i -h $ips "git clone --recurse-submodules https://github.com/Stvdputten/Orchestration"
pssh -i -h $ips "cd Orchestration/Hashi/NomadConsul/local/ && rmdir DeathStarBench && git clone --recurse-submodules --single-branch --branch local https://github.com/Stvdputten/DeathStarBench DeathStarBench"

# pssh -i -h $ips "cd Orchestration/Hashi/NomadConsul/local/DeathStarBench && git checkout local"

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
  host_volume "DSB" {
    path = "/users/stvdp/DeathStarBench"
    read_only = true
  }
}
plugin "docker" {
  config{
    volumes {
      enabled = true
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
