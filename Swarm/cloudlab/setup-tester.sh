#!/usr/bin/env bash
# The params
user="stvdp"
if [ -z "$ips" ]; then
	ips="configs/ips"
	export ips=$ips
fi

if [ -z "$manager" ]; then
	manager=$(head -n 1 configs/ips)
	export manager=$manager
fi

if [ -z "$remote" ]; then
	remote=$(head -n 1 configs/remote)
	export remote=$remote
fi

echo $ips
echo $manager
echo $remote
echo $availability

echo "Setup Tester"
echo "Starting remote env start-up scripts"

# dpkg lock should done, so all should end with exit code 1
# https://www.edureka.co/community/42504/error-dpkg-frontend-is-locked-by-another-process
echo "Ensuring all dpkg are not locked, may take a while. Grab a coffee!"
ssh -n $remote "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'"
while [ ! $? -eq 0 ]; do
  echo "Waiting for front lock to be lifted"
  sleep 10
  ssh -n $remote "sudo lsof /var/lib/dpkg/lock-frontend | grep 'SUCCESS'" 
done
ssh -n $remote "sudo apt-get update && sudo apt-get install -y vim git vim git apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop"

# Install docker
echo "Docker Install Beginning..."
ssh -n $remote "curl -fsSL https://get.docker.com -o get-docker.sh" > /dev/null 2>&1
ssh -n $remote "test -f 'get-docker.sh'"
while [ ! $? -eq  0 ]; do
  ssh -n $remote "curl -fsSL https://get.docker.com -o get-docker.sh" > /dev/null 2>&1
  ssh -n $remote "test -f 'get-docker.sh'"
done
ssh -n $remote "sudo apt-get update && sudo apt-get install -y vim git vim apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop" > /dev/null 2>&1

# Configure Docker to be run as the user
ssh -n $remote 'sudo usermod -aG docker $USER'
ssh -n $remote "docker --version"
while [ ! $? -eq  0 ]; do
  echo "Waiting for docker to be installed"
  ssh -n $remote "VERSION=20.10 && sudo sh get-docker.sh > /dev/null 2&1"
  ssh -n $remote "docker --version"
done
ssh -n $remote 'sudo usermod -aG docker $USER'

# Enable docker service
ssh -n $remote "sudo systemctl enable docker"
ssh -n $remote "sudo systemctl daemon-reload"
ssh -n $remote "sudo systemctl restart docker"

# Setup wrk2 etc
ssh -n $remote "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
ssh -n $remote "pip install --no-input asyncio aiohttp"
ssh -n $remote "sudo luarocks install luasocket"

# Download the repo
ssh -n $remote "git clone --single-branch --branch local https://github.com/Stvdputten/DeathStarBench"

#  Check if wrk is exists
ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && make clean && make" > /dev/null 2>&1
ssh -n $remote "cd DeathStarBench/mediaMicroservices/wrk2 && make clean && make" > /dev/null 2>&1
ssh -n $remote "cd DeathStarBench/hotelReservation/wrk2 && make clean && make" > /dev/null 2>&1

# Send ssh-key to remote cluster
ssh -n $remote "ssh-keygen -t rsa -f /tmp/sshkey -q -N '' <<< $'\ny' >/dev/null 2>&1"
pubkey=$(ssh -n "$remote" "cat /tmp/sshkey.pub")
pssh -i -h $ips "echo $pubkey >> /users/stvdp/.ssh/authorized_keys"
# # TODO FIX broken pip error

# pssh -i -h $ips "cat ~/.ssh/authorized_keys | grep $pubkey > /dev/null 2>&1" 
# while [ ! $? -eq  0 ]; do
#   echo "Waiting for ssh-key to be installed"
#   pssh -i -h $ips "echo $pubkey >> /users/stvdp/.ssh/authorized_keys"
#   pssh -i -h $ips "cat ~/.ssh/authorized_keys | grep $pubkey > /dev/null 2>&1"
# done

echo "Configurations remote tester done"
# echo "$manager"
echo "The ip of remote experimentor is:"
echo "$remote"
exit 0