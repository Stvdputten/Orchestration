#!/usr/bin/env bash

source configs/roles
ips="configs/ips"

managers=(${!MANAGER_@})
workers=(${!WORKER_@})
# https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
ssh ${!managers[0]} 'kubectl create namespace monitoring'
pssh -i -h $ips 'curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3'
pssh -i -h $ips 'chmod 700 get_helm.sh'
pssh -i -h $ips 'sudo ./get_helm.sh'
pssh -i -h $ips 'helm repo add prometheus-community https://prometheus-community.github.io/helm-charts'
pssh -i -h $ips 'helm repo update'
ssh ${!managers[0]} 'helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring'

# https://dev.to/kaitoii11/deploy-prometheus-monitoring-stack-to-kubernetes-with-a-single-helm-chart-2fbd

# portforward to 9090
# kubectl port-forward -n prometheus prometheus-prometheus-kube-prometheus-prometheus-0 9090


# portforward to 3000
# kubectl port-forward -n prometheus prometheus-grafana-686d899789-mrfpz 3000

# secret to login to grafana
# kubectl get secret --namespace prometheus prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# old
# kubectl port-forward -n prometheus prometheus-prometheus-prometheus-oper-prometheus-0 9090
# kubectl port-forward -n prometheus prometheus-grafana-5c5885d488-b9mlj 3000
# kubectl get secret --namespace prometheus prometheus-grafana -o yaml