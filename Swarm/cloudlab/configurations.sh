#!/usr/bin/env bash

if [ -z "$ips" ]; then
  ips="configs/ips"
  export ips=$ips
fi

docker_version="20.10"

# dpkg lock should done, so all should end with exit code 1
# https://www.edureka.co/community/42504/error-dpkg-frontend-is-locked-by-another-process
echo "Ensuring all dpkg are not locked, may take a while. Grab a coffee!"
echo "Make sure your ssh-key is added as default key to ssh-agent"
count=0
pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | echo 'SUCCESS'"
while [ $? -ne 0 ]; do
  echo "Waiting for front lock to be lifted"
  sleep 10
  count=$((count+1))
  if [ $count -eq 10 ]; then
    echo "Failed to unlock dpkg"
    exit 1
  fi
  pssh -i -h $ips "sudo lsof /var/lib/dpkg/lock-frontend | grep 'SUCCESS'" 
done

# Install docker
pssh -i -h $ips "sudo apt-get remove docker docker-engine docker.io containerd runc && sudo apt-get update "
pssh -i -h $ips "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg  --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
pssh -i -h $ips "echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
pssh -i -h $ips "sudo apt-get update && sudo apt-get install -y docker-ce=5:20.10.24~3-0~ubuntu-focal docker-ce-cli=5:20.10.24~3-0~ubuntu-focal containerd.io"

pssh -i -h $ips "sudo docker --version"
while [ ! $? -eq  0 ]; do
  pssh -i -h $ips "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg  --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
  pssh -i -h $ips "echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
  pssh -i -h $ips "sudo apt-get update && sudo apt-get install -y docker-ce=5:20.10.24~3-0~ubuntu-focal docker-ce-cli=5:20.10.24~3-0~ubuntu-focal containerd.io"
  pssh -i -h $ips "sudo docker --version"
done
# pssh -i -h $ips "sudo apt-get update && sudo apt-get install -y vim git vim apt-transport-https ca-certificates curl gnupg-agent software-properties-common htop" > /dev/null 2>&1

# # Configure Docker to run as the user
pssh -i -h $ips "docker --version"
while [ $? -ne  0 ]; do
  echo "Waiting for docker to be installed"
  # pssh -i -h $ips "VERSION=$docker_version && sudo sh get-docker.sh" > /dev/null 2>&1
  pssh -i -h $ips 'sudo usermod -aG docker $USER'
  pssh -i -h $ips "docker --version"
done

# Disable ufw
pssh -i -h $ips "sudo ufw disable"

# Ensure daemon.json
pssh -i -h $ips 'sudo rm /etc/docker/daemon.json' > /dev/null 2>&1
pssh -i -h $ips "sudo mkdir -p /etc/systemd/system/docker.service.d" /dev/null 2>&1
pssh -i -h $ips 'sudo tee /etc/docker/daemon.json  << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "metrics-addr" : "0.0.0.0:9323",
  "experimental" : true
}
EOF'
pssh -i -h $ips "sudo systemctl enable docker"
pssh -i -h $ips "sudo systemctl daemon-reload"
pssh -i -h $ips "sudo systemctl restart docker"

# Have the directories for DSB
pssh -i -h $ips "git clone https://github.com/Stvdputten/DeathStarBench"

# Setup packages required to load datasets or use wrk2 etc
# sometimes the packages are not installed, so we try to install them again?
pssh -i -h $ips "sudo apt-get install -y pip luarocks libz-dev libssl-dev" > /dev/null 2>&1
pssh -i -h $ips "sudo dpkg -s luarocks libssl-dev zlib1g-dev python3-pip" > /dev/null 2>&1
count=0 
while [ $? -ne 0 ]; do
  echo "Waiting for luarocks, libssl-dev, zlib1g-dev, python3-pip to be installed"
  pssh -i -h $ips "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
  count=$((count+1))
  if [ $count -eq 10 ]; then
    echo "Failed to install packages, exiting"
    exit 1
  fi
  pssh -i -h $ips "sudo dpkg -s luarocks libssl-dev zlib1g-dev python3-pip" > /dev/null 2>&1
done

pssh -i -h $ips "pip install --no-input asyncio aiohttp" > /dev/null 2>&1
pssh -i -h $ips "python3 -c 'import aiohttp, asyncio'" > /dev/null 2>&1 
count=0
while [ $? -ne 0 ]; do
  echo "Waiting for python3 asyncio and aiohttp to be installed"
  pssh -i -h $ips "pip install --no-input asyncio aiohttp"
  count=$((count+1))
  if [ $count -eq 10 ]; then
    echo "Failed to install packages, exiting"
    exit 1
  fi
  pssh -i -h $ips "python3 -c 'import aiohttp, asyncio'" > /dev/null 2>&1 
done

pssh -i -h $ips "sudo luarocks install luasocket" > /dev/null 2>&1
pssh -i -h $ips "luarocks list | grep 'luasocket'"
count=0
while [ $? -ne 0 ]; do
  echo "Waiting for luasocket to be installed"
  pssh -i -h $ips "sudo luarocks install luasocket" 
  count=$((count+1))
  if [ $count -eq 10 ]; then
    echo "Failed to install packages, exiting"
    exit 1
  fi
  pssh -i -h $ips "luarocks list | grep 'luasocket'" > /dev/null 2>&1
done

echo "Configurations done"
exit 0