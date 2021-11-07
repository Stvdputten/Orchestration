#!/usr/bin/env bash

# This part is running seperately 
ips="configs/ips"
manager=$(head -n 1 configs/ips)
node3=$(sed -n '4p' configs/ips)
node3_hostname=$(ssh -n $node3 "hostname")
node3_ip=$(ssh -n $node3 "ip -4 a show eno1 |  grep \"inet\b\" | awk '{ print \$2}' | cut -d/ -f1")

device="eno1"
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")

benchmark="social-network"
benchmark="media-microservices"
benchmark="hotel-reservations"

# Download the repo
# pssh -i -h $ips "git clone --single-branch --branch local https://github.com/Stvdputten/DeathStarBench"

# update the DSB after updating the files
pssh -i -h $ips "cd DeathStarBench && git pull && git reset --hard origin/local"

# Setup wrk2 etc
# pssh -i -h $ips "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
# pssh -i -h $ips "pip install --no-input asyncio aiohttp"
# pssh -i -h $ips "sudo luarocks install luasocket"

# pssh -i -h $ips "cd DeathStarBench/socialNetwork/wrk2 && make clean && make"
# pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/wrk2 && make clean && make"
# pssh -i -h $ips "cd DeathStarBench/hotelReservation/wrk2 && make clean && make"

# setup dns
# https://www.linuxuprising.com/2020/07/ubuntu-how-to-free-up-port-53-used-by.html
# ssh $manager "sudo lsof -i :53"
# ssh $manager "echo 'DNS=8.8.8.8' | sudo tee -a /etc/systemd/resolved.conf && echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf"
# ssh $manager "sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf"
# ssh $manager "sudo systemctl restart systemd-resolved"

# ssh $manager "sed '9s/consul/root/' /etc/systemd/system/consul.service | sudo tee /etc/systemd/system/consul.service"
# ssh $manager "sed '11s/$/ -dns-port 53/' /etc/systemd/system/consul.service | sudo tee /etc/systemd/system/consul.service"
# ssh $manager "sudo systemctl daemon-reload"
# ssh $manager "sudo systemctl restart consul.service"


# Change variables in nomad file of the jaeger/dns/hostname
# ssh $manager "cd DeathStarBench/mediaMicroservices/nomad && sed -e '3s/\".*\"/\"$node3_hostname\"/' -e '8s/\".*\"/\"$node3_ip\"/' -e '13s/\".*\"/\"$ip_manager\"/' media-microservices.nomad | sudo tee media-microservices.nomad"
# pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/nomad && sed '43s/\([0-9]\{1,3\}\.\)\{1,3\}[0-9]\{1,3\}/$ip_manager/' nginx.conf | sudo tee nginx.conf"

# ssh $manager "cd DeathStarBench/socialNetwork/nomad && sed -e '3s/\".*\"/\"$node3_hostname\"/' -e '8s/\".*\"/\"$node3_ip\"/' -e '13s/\".*\"/\"$ip_manager\"/' social-network-detach.nomad | sudo tee social-network-detach.nomad"
pssh -i -h $ips "cd DeathStarBench/socialNetwork/nomad/nginx-web-server/conf && sed '45s/\([0-9]\{1,3\}\.\)\{1,3\}[0-9]\{1,3\}/$ip_manager/' nginx.conf | sudo tee nginx.conf"

# ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job run social-network-detach.nomad"
# ssh $manager "cd DeathStarBench/socialNetwork/nomad && sed -e '3s/\".*\"/\"$node3_hostname\"/' -e '8s/\".*\"/\"$node3_ip\"/' -e '13s/\".*\"/\"$ip_manager\"/' social-network-detach.nomad | sudo tee social-network-detach.nomad"
# pssh -i -h $ips "cd DeathStarBench/socialNetwork/nomad/nginx-web-server/conf && sed '45s/\([0-9]\{1,3\}\.\)\{1,3\}[0-9]\{1,3\}/$ip_manager/' nginx.conf | tee nginx.conf"

# deploy 1 of the services
# ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job run social-network.nomad"
# ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job run social-network-detach.nomad"
# ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job run social-network-single-node.nomad"
# export NOMAD_VAR_jaeger=128.110.217.86
# ssh $manager "cd DeathStarBench/mediaMicroservices/nomad && nomad job run media-microservices-detach.nomad"
# ssh $manager "cd DeathStarBench/mediaMicroservices/nomad && nomad job run media-microservice.nomad"
# ssh $manager "cd DeathStarBench/hotelReservation/nomad & & nomad job run hotel-reservation.nomad"


# Replace nginx ip 
# pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/nomad && sed -i -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}:53'/128.110.217.91:8600/g nginx.conf"
# curl -X POST -d "first_name=first_name_1&last_name=last_name_1&username=username_1&password=password_1" http://localhost:8080/wrk2-api/user/register



# Setup dataset
# pssh -i -h $ips "sudo rm -rf /root/DeathStarBench"
# pssh -i -h $ips "sudo rm -rf DeathStarBench"
# pssh -i -h $ips "cd DeathStarBench && git checkout local"
