#!/usr/bin/env bash

ips="configs/ips"
manager="$(head -n 1 'configs/ips')"
managers=(${!MANAGER_@})


# Helm install
ssh -n $manager "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3"
ssh -n $manager "chmod 700 get_helm.sh"
ssh -n $manager "./get_helm.sh"

# monitoring
kubectl create namespace monitoring

# https://sysdig.com/blog/kubernetes-monitoring-prometheus/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# prometheus monitoring stack
# https://github.com/prometheus-community/helm-charts/tree/main/charts
# https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
helm install kube-prom-stack prometheus-community/kube-prometheus-stack -n monitoring

# get secrets of grafana of prometheus
kubectl get secrets kube-prom-stack-grafana -o yaml -n monitoring
kubectl get secrets kube-prom-stack-kube-prome-admission -n monitoring
# echo passwd | base64 -d 

# dashboard
kubectl apply -f configs/dashboard-adminuser.yaml

# portforward 
# kubectl port-forward pod/kube-prom-stack-grafana-6487b679b 3000:3000
pod_name_gf=kubectl get pods  -n monitoring | grep "grafana" | awk '{ print $1 }'
pod_name_prom=kubectl get pods  -n monitoring | grep "prome-prometheus" | awk '{ print $1 }'
kubectl port-forward -n monitoring $pod_name_gf 3000:3000 & kubectl port-forward -n monitoring $pod_name_prom 9090:9090 


# # Make sure prometheus isn't installed in home directory
# pssh -i -h $ips "rm -rf prometheus"
# pssh -i -h $ips "git clone https://github.com/stvdputten/prometheus"

# echo "First monitoring"
# ssh -n $manager "sudo ufw allow 5001"
# ssh -n $manager "docker run -it -d -p 5001:8080 -v /var/run/docker.sock:/var/run/docker.sock dockersamples/visualizer"
# ssh -n $manager "cd prometheus && docker stack deploy -c docker-stack.yml monitoring"

# echo "Monitoring is setup"

