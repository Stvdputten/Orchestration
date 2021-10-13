#!/usr/bin/env bash

source configs/roles
user="stvdp"
agents=(${!AGENT_@})

SERVER_1_IP=$(echo "$SERVER_1_IP" | cut -d'@' -f 2)
SERVER_2_IP=$(echo "$SERVER_2_IP" | cut -d'@' -f 2)
SERVER_3_IP=$(echo "$SERVER_3_IP" | cut -d'@' -f 2)

hashi-up nomad install \
  --ssh-target-addr $SERVER_1_IP \
  --ssh-target-user $user \
  --server \
  --bootstrap-expect 3 \
  --advertise '{{ GetInterfaceIP "eno1"}}'
  # --address '{{ GetInterfaceIP "eth0"}}'

hashi-up nomad install \
  --ssh-target-addr $SERVER_2_IP \
  --ssh-target-user $user \
  --server \
  --bootstrap-expect 3 \
  --advertise '{{ GetInterfaceIP "eno1"}}'
  # --address '{{ GetInterfaceIP "eth0"}}'

hashi-up nomad install \
  --ssh-target-addr $SERVER_3_IP \
  --ssh-target-user $user \
  --server \
  --bootstrap-expect 3 \
  --advertise '{{ GetInterfaceIP "eno1"}}'
  # --address '{{ GetInterfaceIP "eth0"}}'

# Can be done parallel, $command & , but might be preferable to do it sequentially
echo "Setup workers"
for agent in ${agents[@]}; do
  hashi-up nomad install \
    --ssh-target-addr  $(echo ${!agent} | cut -d'@' -f 2 ) \
    --ssh-target-user $user \
    --client \
    --advertise '{{ GetInterfaceIP "eno1"}}'
    # --advertise-addr '{{ GetInterfaceIP "eth0"}}'

# enable docker volumes
# https://stackoverflow.com/questions/18660798/here-document-gives-unexpected-end-of-file-error no spaces before eof
ssh -n ${!agent} 'cat << EOF | sudo tee -a /etc/nomad.d/nomad.hcl 
client {
  options = {
    "docker.volumes.enabled" = "true"
  }
} 
EOF' > /dev/null
ssh -n ${!agent} 'sudo systemctl restart nomad.service'
done
