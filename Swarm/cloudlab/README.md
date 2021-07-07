# Cloudlab Setup

#### Hardware Configurations
Trying to keep the cores and stuff as low as possible, however it seems hard to do. So I probably have to tune the VMs afterwards.
Using experiment configuration, small-lan. Maybe there is an experiment where I can bottleneck the nodes? Idk.

#### Initial setup
Use small-lan to setup a few nodes. This can take a long time, or even fail. You can instantiate more nodes and use less. Furthermore you should receive a mail when things are ready. 
- Start the experiments on cloudlab, I run two experiments:
  - Workload generators (1-2 servers), using small-lan profile
  - Cluster with 8 nodes (3 manager, 5 workers), using small-lan profile
- Hardcode the address in the configs/ips, e.g. `stvdp@ms0305.utah.cloudlab.us`. ALso in configs/roles, e.g. `MANAGER1=stvdp@ms0305.utah.cloudlab.us`.

