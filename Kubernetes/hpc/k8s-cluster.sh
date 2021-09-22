#!/usr/bin/env bash
source configs/roles

managers=(${!MANAGER_@})
# ssh "${!managers[0]}" "cat ~/.kube/config"
# ssh "${!managers[0]}" "cat ~/.kube/config" > ~/.kube/new-config
ssh "${!managers[0]}" "cat ~/.kube/config" > ~/.kube/config
# KUBECONFIG=~/.kube/config:~/.kube/new-config 
# kubectl config view --flatten > ~/.kube/config
