#!/usr/bin/env bash

# setup params
export ips="configs/ips"
export manager=$(head -n 1 configs/ips)
export remote=$(head -n 1 configs/remote)
# availability=0 high availability mode, availability=1 low availability mode
export availability=0

# Setting up the ssh-agent
ssh-add ~/.ssh/id_rsa

# Setting up the environment
./configurations.sh

# Settings up the cluster
./start-consul.sh
./start-nomad.sh

# Settings up the tester
./setup-tester.sh