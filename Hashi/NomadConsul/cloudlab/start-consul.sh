#!/usr/bin/env bash

ips=configs/ips
source configs/roles

user="stvdp"
agents=(${!AGENT_@})
manager=$(head -n 1 configs/ips)

SERVER_1_IP=$(echo "$SERVER_1_IP" | cut -d'@' -f 2)
SERVER_2_IP=$(echo "$SERVER_2_IP" | cut -d'@' -f 2)
SERVER_3_IP=$(echo "$SERVER_3_IP" | cut -d'@' -f 2)

version="1.10.3"
device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")

echo "Setup control-plane"
hashi-up consul install \
  --ssh-target-addr $SERVER_1_IP \
  --ssh-target-user $user \
  --server \
  --client-addr 0.0.0.0 \
  --bootstrap-expect 3 \
  --version $version \
  --connect \
  --retry-join $SERVER_1_IP --retry-join $SERVER_2_IP --retry-join $SERVER_3_IP \
  --bind-addr "{{ GetInterfaceIP \"$device\"}}"
  # --bind-addr '{{ GetInterfaceIP "\$device"}}'
  # --advertise-addr '{{ GetInterfaceIP "eth0"}}'

hashi-up consul install \
  --ssh-target-addr $SERVER_2_IP \
  --ssh-target-user $user \
  --server \
  --client-addr 0.0.0.0 \
  --bootstrap-expect 3 \
  --version $version \
  --connect \
  --retry-join $SERVER_1_IP --retry-join $SERVER_2_IP --retry-join $SERVER_3_IP \
  --bind-addr "{{ GetInterfaceIP \"$device\"}}"
  # --bind-addr '{{ GetInterfaceIP "eno1"}}'
  # --advertise-addr '{{ GetInterfaceIP "eth0"}}'

hashi-up consul install \ #   --ssh-target-addr $SERVER_3_IP \
  --ssh-target-user $user \
  --server \
  --client-addr 0.0.0.0 \
  --version $version \
  --connect \
  --bootstrap-expect 3 \
  --retry-join $SERVER_1_IP --retry-join $SERVER_2_IP --retry-join $SERVER_3_IP \
  --bind-addr "{{ GetInterfaceIP \"$device\"}}"
  # --bind-addr '{{ GetInterfaceIP "eno1"}}'
  # --advertise-addr '{{ GetInterfaceIP "eth0"}}'

# Can be done parallel, $command & , but might be preferable to do it sequentially
echo "Setup workers"
for agent in ${agents[@]}; do
  hashi-up consul install \
    --ssh-target-addr  $(echo ${!agent} | cut -d'@' -f 2 ) \
    --ssh-target-user $user \
    --connect \
    --version $version \
    --retry-join $SERVER_1_IP --retry-join $SERVER_2_IP --retry-join $SERVER_3_IP \
    --bind-addr "{{ GetInterfaceIP \"$device\"}}"
    # --bind-addr '{{ GetInterfaceIP "eno1"}}'
    # --advertise-addr '{{ GetInterfaceIP "eth0"}}'
done

