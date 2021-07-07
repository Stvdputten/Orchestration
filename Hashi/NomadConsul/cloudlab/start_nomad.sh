#!/usr/bin/env bash

source configs/roles
user="stvdp"
agents=(${!AGENT_@})

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
    --ssh-target-addr ${!agent} \
    --ssh-target-user $user \
    --client \
    --advertise '{{ GetInterfaceIP "eno1"}}'
    # --advertise-addr '{{ GetInterfaceIP "eth0"}}'
done
