# Setup using hashi-up
[hash-ip](https://johansiebens.dev/posts/2020/07/deploying-a-highly-available-nomad-cluster-with-hashi-up/)


## Prerequisits
hashi-up installed, pssh
1. start_nodes
2. configuration
3. start-consul
4. start-nomad


# Consul
Set the ports for you servers in the configs/ips file!

## UI
http://145.100.59.188:8500/ui/

## Setup Service
[Service setup](https://learn.hashicorp.com/tutorials/consul/deployment-guide)
[Configurations](https://www.consul.io/docs/agent/options)
[Consul ports](https://www.consul.io/docs/install/ports)

## Debugging
Try curl `localhost:8500/v1/catalog/nodes`

## Client
These are the workers. Apparently.

### Cloudlab
`consul agent -node agent-two -data-dir=/tmp/consul -advertise='{{ GetInterfaceIP "eno1" }}' -bind 0.0.0.0 -ui -client="0.0.0.0"`

### HPC Cloud
open the ports through the `sudo ufw allow PORT` command and `netstat -tulpn | grep LISTEN` to see ports.
Sources are:
`https://www.2daygeek.com/enable-disable-up-down-nic-network-interface-port-linux/`
`https://www.cyberciti.biz/faq/unix-linux-check-if-port-is-in-use-command/`
8300, 8500, etc

### Server
This is the control plane.

### Cloudlab
`consul agent -server -node agent-one -data-dir=/tmp/consul -advertise='{{ GetInterfaceIP "eno1" }}' -bootstrap-expect=1 -bind 0.0.0.0 -ui -client="0.0.0.0"`

## HPC Cloud
Open the ports

# Nomad
If Consul is setup correctly, there should not be a alot of problems with nomad networking. 
[Configurations](https://www.nomadproject.io/docs/configuration)
[Nomad ports](https://www.nomadproject.io/docs/install/production/requirements)

## UI
UI should be visible on http://145.100.59.188:4646/ui/ which means port 4646

# TIPS HPC CLoud
I recommend using [pssh](https://www.cyberciti.biz/cloud-computing/how-to-use-pssh-parallel-ssh-program-on-linux-unix/)

## Man-in-the-middle verification
If you login to similar ips but different images. Run the following command: `ssh-keygen -R IP `.

## Change hostname of anything from image
Set SET_HOSTNAME in context. Options are many variables stated in (here](https://docs.opennebula.io/pdf/5.2/opennebula_5.2_operation_guide.pdf), e.g. $name

## Cheat Sheet Open Nebula CLI
Make use of it [here](https://lzone.de/cheat-sheet/OpenNebula)


# Future Work
- [Vault](https://www.vaultproject.io/)
- [Boundary](https://www.boundaryproject.io/)