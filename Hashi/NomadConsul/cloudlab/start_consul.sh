#!/usr/bin/env bash

source configs/roles
user="stvdp"
agents=(${!AGENT_@})


echo "Setup control-plane"
hashi-up consul install \
  --ssh-target-addr $SERVER_1_IP \
  --ssh-target-user $user \
  --server \
  --client-addr 0.0.0.0 \
  --bootstrap-expect 3 \
  --connect \
  --retry-join $SERVER_1_IP --retry-join $SERVER_2_IP --retry-join $SERVER_3_IP \
  --bind-addr '{{ GetInterfaceIP "eno1"}}'
  # --advertise-addr '{{ GetInterfaceIP "eth0"}}'

hashi-up consul install \
  --ssh-target-addr $SERVER_2_IP \
  --ssh-target-user $user \
  --server \
  --client-addr 0.0.0.0 \
  --bootstrap-expect 3 \
  --connect \
  --retry-join $SERVER_1_IP --retry-join $SERVER_2_IP --retry-join $SERVER_3_IP \
  --bind-addr '{{ GetInterfaceIP "eno1"}}'
  # --advertise-addr '{{ GetInterfaceIP "eth0"}}'

hashi-up consul install \
  --ssh-target-addr $SERVER_3_IP \
  --ssh-target-user $user \
  --server \
  --client-addr 0.0.0.0 \
  --connect \
  --bootstrap-expect 3 \
  --retry-join $SERVER_1_IP --retry-join $SERVER_2_IP --retry-join $SERVER_3_IP \
  --bind-addr '{{ GetInterfaceIP "eno1"}}'
  # --advertise-addr '{{ GetInterfaceIP "eth0"}}'

# Can be done parallel, $command & , but might be preferable to do it sequentially
echo "Setup workers"
for agent in ${agents[@]}; do
  hashi-up consul install \
    --ssh-target-addr ${!agent} \
    --ssh-target-user $user \
    --connect \
    --retry-join $SERVER_1_IP --retry-join $SERVER_2_IP --retry-join $SERVER_3_IP \
    --bind-addr '{{ GetInterfaceIP "eno1"}}'
    # --advertise-addr '{{ GetInterfaceIP "eth0"}}'
done


# hashi-up consul install \
#   --ssh-target-addr $AGENT_2_IP \
#   --ssh-target-user $user \
#   --connect \
#   --retry-join $SERVER_1_IP --retry-join $SERVER_2_IP --retry-join $SERVER_3_IP \
#   --bind-addr '{{ GetInterfaceIP "eth0"}}'
#   # --advertise-addr '{{ GetInterfaceIP "eth0"}}'
