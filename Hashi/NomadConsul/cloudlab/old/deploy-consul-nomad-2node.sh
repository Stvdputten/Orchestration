#!/usr/bin/env bash

# Change the IP addresses
SERVER_1_IP=ms1045.utah.cloudlab.us
AGENT_1_IP=ms1005.utah.cloudlab.us
user="stvdp"


echo "Setup control-plane"
hashi-up consul install \
  --ssh-target-addr $SERVER_1_IP \
  --ssh-target-user $user \
  --server \
  --client-addr 0.0.0.0 \
  --connect \
  --bind-addr '{{ GetInterfaceIP "eno1"}}'

hashi-up consul install \
  --ssh-target-addr $AGENT_1_IP \
  --ssh-target-user $user \
  --connect \
  --retry-join $SERVER_1_IP \
  --bind-addr '{{ GetInterfaceIP "eno1"}}'

hashi-up nomad install \
  --ssh-target-addr $SERVER_1_IP \
  --ssh-target-user $user \
  --server \
  --advertise '{{ GetInterfaceIP "eno1"}}'

hashi-up nomad install \
  --ssh-target-addr $AGENT_1_IP \
  --ssh-target-user $user \
  --client \
  --retry-join $SERVER_1_IP \
  --advertise '{{ GetInterfaceIP "eno1"}}'
