#!/usr/bin/env bash 

ips="configs/ips"
user="stvdp"

# Add consul server ip
manager=$(head -n 1 configs/ips)
# device="eno1"
# device="eno1d1"
device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")

# uses internal ip not public ip
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")
# add
pssh -i -h $ips "echo '$ip_manager consul_server' | sudo tee -a /etc/hosts"

# Setup nomad telemetry
pssh -i -h ~/.pssh_hosts_files "cat telemetry | sudo tee -a /etc/nomad.d/nomad.hcl"
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

# Setup node exporter
pssh -i -h $ips "sudo docker run \
    --net='host' \
    --pid='host' \
    -v '/:/host:ro,rslave' \
    quay.io/prometheus/node-exporter:latest \
    --path.rootfs=/host"

# Setup cadvisor telemetry
# VERSION=v0.36.0 # use the latest release version from https://github.com/google/cadvisor/releases
pssh -i -h $ips "sudo docker run -d \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:ro \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --volume=/dev/disk/:/dev/disk:ro \
    --publish=8085:8080 \
    --detach=true \
    --name=cadvisor \
    --privileged \
    --device=/dev/kmsg \
    gcr.io/cadvisor/cadvisor:latest"

# deploy job monitoring.nomad
scp "./configs/monitoring.nomad" "$manager:/users/$user/"
# choose the first client node as the prometheus server
prometheus_hostname=$(ssh -n $manager 'head -n 1 /etc/hosts ' | awk '{ print $4 }' | sed 's/localhost/node3/') 
ssh -n $manager "nomad job run -var='consul_ip=$ip_manager' -var='consul_name=consul_server' -var='prometheus_hostname=$prometheus_hostname' monitoring.nomad"

echo "Monitoring is setup"