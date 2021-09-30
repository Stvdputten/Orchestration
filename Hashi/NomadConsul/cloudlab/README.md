# Setup the nomad/consul cluster on cloudlab

## Prerequisits
Put ips of cluster in roles in the configs. Change the grafana and prometheus url string to match cluster name.
## Steps
1. update files in configs - ip's of vms (8 assumed), roles and monitoring settings
2. configuration.sh
3. 

## PORTS
[guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
control-plane node(s)
[fix changing ports consul sd prometheus](https://stackoverflow.com/questions/40355613/prometheus-how-to-replace-consul-server-ports-with-regex)
## GUIDE
[guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
do not forget to disable swap!
[swap disable](https://graspingtech.com/disable-swap-ubuntu/)
[guide-ubuntu20.04](https://computingforgeeks.com/deploy-kubernetes-cluster-on-ubuntu-with-kubeadm/)
