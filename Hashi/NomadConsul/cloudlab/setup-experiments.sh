#!/usr/bin/env bash

# This part is running seperately 
ips="configs/ips"
manager=$(head -n 1 configs/ips)
remote=$(head -n 1 configs/remote)

# device="eno1"
device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")
node3=$(sed -n '4p' configs/ips)
node3_hostname=$(ssh -n $node3 "hostname")
node3_ip=$(ssh -n $node3 "ip -4 a show $device |  grep \"inet\b\" | awk '{ print \$2}' | cut -d/ -f1")
date=$(date "+%d-%m-%y")
mkdir -p ./results/$date

# update the DSB after updating the files
pssh -i -h $ips "cd DeathStarBench && git reset --hard origin/local && git pull"
ssh -n $remote "cd DeathStarBench && git reset --hard origin/local && git pull"

# setup dns
# https://www.linuxuprising.com/2020/07/ubuntu-how-to-free-up-port-53-used-by.html
# ssh $manager "sudo lsof -i :53"
ssh $manager "sudo lsof -i :53" | grep "consul" 
if [  $? -ne 0 ]; then
	echo "Setup dns resolver"
	ssh $manager "echo 'DNS=8.8.8.8' | sudo tee -a /etc/systemd/resolved.conf && echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf"
	ssh $manager "sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf"
	ssh $manager "sudo systemctl restart systemd-resolved"

	ssh $manager "sed '9s/consul/root/' /etc/systemd/system/consul.service | sudo tee /etc/systemd/system/consul.service"
	ssh $manager "sed '11s/$/ -dns-port 53/' /etc/systemd/system/consul.service | sudo tee /etc/systemd/system/consul.service"
	ssh $manager "sudo systemctl daemon-reload"
	ssh $manager "sudo systemctl restart consul.service"
fi

# for benchmark in hotelReservation
for benchmark in socialNetwork mediaMicroservices hotelReservation
do 
	# Deploy app
	if [ $benchmark == "hotelReservation" ]; then
		echo "Deploying hotelReservation app"
		# pssh -i -h $ips "cd $dsb_dir/$benchmark/wrk2 && make clean && make"

		# Change variables in nomad file of the jaeger/dns/hostname
		ssh $manager "cd DeathStarBench/hotelReservation/nomad && sed -e '3s/\".*\"/\"$node3_hostname\"/' -e '8s/\".*\"/\"$node3_ip\"/' -e '13s/\".*\"/\"$ip_manager\"/' hotel-reservation.nomad | sudo tee hotel-reservation.nomad"

		# setup dns resolver on node3
		echo "Dns resolver setup on node3"
		ssh stvdp@$node3_ip "cat /etc/systemd/resolved.conf" | grep "8.8.8.8" 
		if [  $? -ne 0 ]; then
			echo "Setup dns resolver"
			ssh stvdp@$node3_ip "echo 'DNS=8.8.8.8' | sudo tee -a /etc/systemd/resolved.conf && echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf"
			ssh stvdp@$node3_ip "sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf"
			ssh stvdp@$node3_ip "sudo systemctl restart systemd-resolved"
		fi

		# deploy 1 of the services
		ssh $manager "cd DeathStarBench/hotelReservation/nomad && nomad job stop -purge hotel-reservation"
		ssh $manager "cd DeathStarBench/hotelReservation/nomad && nomad job run hotel-reservation.nomad"
		echo "hotelReservation app is ready to be experimented on."

		echo "hotelReservation workloads are being run..."
		ssh -n $remote "cd DeathStarBench/hotelReservation/wrk2 && export nginx_ip=$node3_ip && ./workload.sh" > ./results/$date/nomad-hr-wrk-mixed.txt

		# Stop the benchmark
		# ssh $manager "cd DeathStarBench/hotelReservation/nomad && nomad job stop hotel-reservation"
		ssh $manager "cd DeathStarBench/hotelReservation/nomad && nomad job stop hotel-reservation"
		# exit 0

		echo "hotelReservation experiment cleaned up."

	elif [ $benchmark == "mediaMicroservices" ]; then
		echo "Deploying mediaMicroservices app"
		# pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/wrk2 && make clean && make"

		# Change variables in nomad file of the jaeger/dns/hostname
		ssh $manager "cd DeathStarBench/mediaMicroservices/nomad && sed -e '3s/\".*\"/\"$node3_hostname\"/' -e '8s/\".*\"/\"$node3_ip\"/' -e '13s/\".*\"/\"$ip_manager\"/' media-microservices.nomad | sudo tee media-microservices.nomad"
		pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/nomad && sed '43s/\([0-9]\{1,3\}\.\)\{1,3\}[0-9]\{1,3\}/$ip_manager/' nginx.conf | sudo tee nginx.conf"

		# deploy 1 of the services
		ssh $manager "cd DeathStarBench/mediaMicroservices/nomad && nomad job stop -purge media-microservices"
		ssh $manager "cd DeathStarBench/mediaMicroservices/nomad && nomad job run media-microservices.nomad"

		# Load the dataset 
		ssh stvdp@$node3_ip "cd DeathStarBench/mediaMicroservices/scripts && python3 write_movie_info.py && ./register_movies.sh && ./register_users.sh" > /dev/null
		echo "mediaMicroservices app is ready to be experimented on."

		echo "mediaMicroservices workloads are being run..."
		ssh -n $remote "cd DeathStarBench/mediaMicroservices/wrk2 && export nginx_ip=$node3_ip && ./workload.sh" > ./results/$date/nomad-mm-wrk-compose.txt

		# Stop the benchmark
		ssh $manager "cd DeathStarBench/mediaMicroservices/nomad && nomad job stop media-microservices"

		echo "mediaMicroservices experiment cleaned up."
		# exit 0

	elif [ $benchmark == "socialNetwork" ]; then
		echo "Deploying socialNetwork app"

		# Change variables in nomad file of the jaeger/dns/hostname
		ssh $manager "cd DeathStarBench/socialNetwork/nomad && sed -e '3s/\".*\"/\"$node3_hostname\"/' -e '8s/\".*\"/\"$node3_ip\"/' -e '13s/\".*\"/\"$ip_manager\"/' social-network.nomad | sudo tee social-network.nomad"
		pssh -i -h $ips "cd DeathStarBench/socialNetwork/nomad/nginx-web-server/conf && sed '45s/\([0-9]\{1,3\}\.\)\{1,3\}[0-9]\{1,3\}/$ip_manager/' nginx.conf | sudo tee nginx.conf"

		# deploy 1 of the services
		ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job stop -purge social-network"
		ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job run social-network.nomad"

		# Load the dataset 
		ssh stvdp@$node3_ip "cd DeathStarBench/socialNetwork/ && python3 scripts/init_social_graph.py"
		echo "socialNetwork app is ready to be experimented on."

		echo "socialNetwork workloads are being run..."
		# ./setup-tester.sh
		# ssh -n $remote "ssh -i /tmp/sshkey -o StrictHostKeyChecking=no -L 8080:localhost:8080 stvdp@$node3_ip" 

		ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node3_ip && ./workload-home.sh" > ./results/$date/nomad-sn-wrk-home.txt
		ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node3_ip && ./workload-user.sh" > ./results/$date/nomad-sn-wrk-user.txt
		ssh -n $remote "cd DeathStarBench/socialNetwork/wrk2 && export nginx_ip=$node3_ip && ./workload-compose.sh" > ./results/$date/nomad-sn-wrk-compose.txt
		# echo "socialNetwork results are in."

		# Stop the benchmark
		ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job stop social-network"

		echo "SocialNetwork experiment cleaned up."
		# exit 0
	fi
done 