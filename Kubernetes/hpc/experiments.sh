#!/usr/bin/env bash


ips="configs/ips"
# source $destination

# pssh -i -h configs/ips "DEBIAN_FRONTEND=noninteractive && sudo apt-get update && sudo apt-get install -y git"
# pssh -i -h $ips "sudo git clone https://github.com/delimitrou/DeathStarBench /root/DeathStarBench"
pssh -i -h $ips "sudo rm -rf /root/DeathStarBench"
pssh -i -h $ips "sudo git clone https://github.com/Panlichen/DeathStarBench /root/DeathStarBench"
