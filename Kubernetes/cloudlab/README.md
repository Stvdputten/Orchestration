# Setup the k8s cluster on cloudlab

## Prerequisits
pssh
assuming there is an existing ubuntu template to which you can ssh with your current username. Otherwise edit `configurations` to include username in output to IPS. Or change ips.

## Steps
1. put in the ips in configs ips of all workers and masters
2. add their roles in configs/roles
3. change tester ip in setup-tester.sh
4. 

## Monitoring
password: prom-operator 
user: admin

## PORTS
[guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
control-plane node(s)

## GUIDE
[guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
do not forget to disable swap!
[swap disable](https://graspingtech.com/disable-swap-ubuntu/)
[guide-ubuntu20.04](https://computingforgeeks.com/deploy-kubernetes-cluster-on-ubuntu-with-kubeadm/)
