#!/usr/bin/env bash
# The params
user="stvdp"
# remote=$(head -n 1 configs/remote)
manager=$(head -n 1 configs/ips)
ips=configs/remote
ipss=configs/ips

echo "Setup Tester"
echo "Starting remote env start-up scripts"

# dpkg lock should done, so all should end with exit code 1
# https://www.edureka.co/community/42504/error-dpkg-frontend-is-locked-by-another-process
echo "Ensuring all dpkg are not locked, may take a while. Grab a coffee!"
pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'"
while [ ! $? -eq 0 ]; do
  echo "Waiting for front lock to be lifted"
  sleep 10
  pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | grep 'SUCCESS'" 
done
pssh -i -h $ips "sudo apt-get update && sudo apt-get install -y vim git vim git apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop"

# Install docker
echo "Docker Install Beginning..."
pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
pssh -i -h $ips "test -f 'get-docker.sh'"
while [ ! $? -eq  0 ]; do
  pssh -i -h $ips "curl -fsSL https://get.docker.com -o get-docker.sh"
  pssh -i -h $ips "test -f 'get-docker.sh'"
done
pssh -i -h $ips "sudo apt-get update && sudo apt-get install -y vim git vim apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop"

# Configure Docker to be run as the user
pssh -i -h $ips 'sudo usermod -aG docker $USER'
pssh -i -h $ips "docker --version"
while [ ! $? -eq  0 ]; do
  echo "Waiting for docker to be installed"
  pssh -i -h $ips "VERSION=20.10 && sudo sh get-docker.sh > /dev/null 2&1"
  pssh -i -h $ips "docker --version"
done
pssh -i -h $ips 'sudo usermod -aG docker $USER'

# Enable docker service
pssh -i -h $ips "sudo systemctl enable docker"
pssh -i -h $ips "sudo systemctl daemon-reload"
pssh -i -h $ips "sudo systemctl restart docker"

# Setup wrk2 etc
pssh -i -h $ips "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
pssh -i -h $ips "pip install --no-input asyncio aiohttp"
pssh -i -h $ips "sudo luarocks install luasocket"

# Download the repo
pssh -i -h $ips "git clone --single-branch --branch local https://github.com/Stvdputten/DeathStarBench"

#  Check if wrk is exists
pssh -i -h $ips "cd DeathStarBench/socialNetwork/wrk2 && make clean && make"
pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/wrk2 && make clean && make"
ssh -i -h $ips "cd DeathStarBench/hotelReservation/wrk2 && make clean && make"

# Send ssh-key to remote cluster
pssh -n $ips "ssh-keygen -t rsa -f /tmp/sshkey -q -N '' <<< $'\ny' >/dev/null 2>&1"
for remote in $(cat $ips); do
  pubkey=$(ssh -n "$remote" "cat /tmp/sshkey.pub")
  pssh -i -h $ipss "echo $pubkey >> /users/stvdp/.ssh/authorized_keys"
done


echo "Configurations remote tester done"
# echo "$manager"
echo "The ip of remote experimentor is:"
echo "$ips"