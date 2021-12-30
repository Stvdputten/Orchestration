#!/usr/bin/env bash

source configs/roles
user="stvdp"
agents=(${!AGENT_@})
manager=$(head -n 1 configs/ips)
nomad_version="1.1.6"

SERVER_1_IP=$(echo "$SERVER_1_IP" | cut -d'@' -f 2)
SERVER_2_IP=$(echo "$SERVER_2_IP" | cut -d'@' -f 2)
SERVER_3_IP=$(echo "$SERVER_3_IP" | cut -d'@' -f 2)

device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")

hashi-up nomad install \
  --ssh-target-addr $SERVER_1_IP \
  --ssh-target-user $user \
  --server \
  --version $nomad_version \
  --bootstrap-expect 3 \
  --advertise "{{ GetInterfaceIP \"$device\"}}"
  # --address '{{ GetInterfaceIP "eth0"}}'

hashi-up nomad install \
  --ssh-target-addr $SERVER_2_IP \
  --ssh-target-user $user \
  --server \
  --version $nomad_version \
  --bootstrap-expect 3 \
  --advertise "{{ GetInterfaceIP \"$device\"}}"
  # --address '{{ GetInterfaceIP "eth0"}}'

hashi-up nomad install \
  --ssh-target-addr $SERVER_3_IP \
  --ssh-target-user $user \
  --server \
  --version $nomad_version \
  --bootstrap-expect 3 \
  --advertise "{{ GetInterfaceIP \"$device\"}}"
  # --address '{{ GetInterfaceIP "eth0"}}'

# Can be done parallel, $command & , but might be preferable to do it sequentially
echo "Setup workers"
for agent in ${agents[@]}; do
  hashi-up nomad install \
    --ssh-target-addr  $(echo ${!agent} | cut -d'@' -f 2 ) \
    --ssh-target-user $user \
    --version $nomad_version \
    --client \
    --advertise "{{ GetInterfaceIP \"$device\"}}"
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

exit 0