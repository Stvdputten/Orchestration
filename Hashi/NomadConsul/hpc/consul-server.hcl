{ 
    data_dir = "/tmp/consul/server"

server           = true
// bootstrap_expect = 3
bootstrap_expect = 1
advertise_addr   = "{{ GetInterfaceIP `eth1` }}"
// bind             = "192.168.50.1"
bind             = "0.0.0.0"
client_addr      = "0.0.0.0"
ui               = true
datacenter       = "dc1"
// retry_join       = ["192.168.50.10", "192.168.50.11", "192.168.50.12"]
// retry_join       = ["192.168.50.10"]
}