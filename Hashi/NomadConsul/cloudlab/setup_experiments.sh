#!/usr/bin/env bash

# This part is running seperately 
ips="configs/ips"
manager=$(head -n 1 configs/ips)

# Make sure prometheus isn't installed in home directory
# pssh -i -h $ips "git clone https://github.com/Stvdputten/DeathStarBench"
pssh -i -h $ips "sudo git clone --single-branch --branch local https://github.com/Stvdputten/DeathStarBench /root/DeathStarBench"
# pssh -i -h $ips "cd DeathStarBench && git checkout local"

# deploy 1 of the services
# ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm.yml social-network"
# ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm-jaeger.yml social-network"

# ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-compose-swarm.yml media-service"

# Assumes you have portforwarded the service, e.g. ssh -L 5000:localhost:5000 user@server
# pssh -i -h $ips "cd DeathStarBench/hotelReservation && docker-compose build"
# ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-compose-swarm-local.yml hotel-reservation"