#!/usr/bin/env bash

# Step 1
if [[ $1 == "start-nodes" ]]; then
    source start_nodes.sh -m $2 -w $3
    wait
    source pssh.sh
    wait
    exit 1
fi

# Step 2
if [[ $1 == "configure" ]]; then
    source configurations.sh
    wait
    exit 1
fi

# Step 3
if [[ $1 == "start-k8" ]]; then
    source ./k8s-conf.sh
    wait
    source ./k8s-start.sh
    exit 1
fi

if [[ $1 == "onevm" ]]; then
    source ./action_nodes.sh -a $2
    wait
    exit 1
fi

if [[ $1 == "reset-k8" ]]; then
    source ./k8s-reset.sh
    wait
    exit 1
fi

# Step 4
if [[ $1 == "experiments" ]]; then
    source ./experiments.sh
    wait
    exit 1
fi

# Step 5
if [[ $1 == "local-k8" ]]; then
    source ./k8s-cluster.sh
    wait
    exit 1
fi


