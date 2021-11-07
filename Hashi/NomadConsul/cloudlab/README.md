# Setup the nomad/consul cluster on cloudlab

## Prerequisits
Put ips of cluster in roles in the configs. Change the grafana and prometheus url string to match cluster name.
## Steps
1. update files in configs - ip's of vms (8 assumed), roles and monitoring settings
2. ./configuration.sh && ./start-consul.sh && ./start-nomad.sh
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
[DNS resolution from consul inside of Mesh Network](https://github.com/hashicorp/nomad/issues/8343)
[/etc/resolv.conf](https://superuser.com/questions/570082/in-etc-resolv-conf-what-exactly-does-the-search-configuration-option-do/570095)
[Forward DNS for Consul Service Discovery](https://learn.hashicorp.com/tutorials/consul/dns-forwarding?in=consul/networking)
[Consul dns interface](https://www.consul.io/docs/discovery/dns)
[Man-page resolv.conf](https://man7.org/linux/man-pages/man5/resolver.5.html)
[Forward DNS for Consul Service Discovery](https://learn.hashicorp.com/tutorials/consul/dns-forwarding?utm_source=consul.io&utm_medium=docs)


## Explanation
[Experience implementing Service Mesh on Nomad and Consul](https://prog.world/experience-implementing-service-mesh-on-nomad-and-consul/)

## Monitoring
Due to the nature of the DSB benchmarks, cadvisor is set to port 8085 instead of 8080