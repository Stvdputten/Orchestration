#!/usr/bin/env bash

# Read the parameters if any
while getopts t:c:d:R:N: flag; do
	case "${flag}" in
	t) t=${OPTARG} ;;
	c) c=${OPTARG} ;;
	d) d=${OPTARG} ;;
	R) R=${OPTARG} ;;
	N) N=${OPTARG} ;;
	esac
done

if [ -z "$t" ] && [ -z "$c" ] && [ -z "$d" ] && [ -z "$R" ]; then
	t=8
	c=512
	d=30
	R=500
	N=1
	echo "-------------------------------------------------------"
	echo "No params, using default settings of -t $t -c $c -d $d -R $R -N $N"
else
	echo "-------------------------------------------------------"
	echo "Experiments are run using the following parameters:"
	echo "Threads: $t"
	echo "Connections: $c"
	echo "Duration (seconds): $d"
	echo "Req/sec: $R"
fi

# Experiment parameters
# Check if we use unlimited resources in the deployment files
# 0 means true
# 1 means false
if [ -z "$unlimited" ]; then
	# resources are unlimited
	export unlimited=0
fi

if [ -z "$availability" ]; then
	# master nodes consists of 3 nodes, cause of high availability
	export availability=0
fi

if [ -z "$vertical" ]; then
	# resources have not been increased
	export vertical=1
fi

if [ -z "$horizontal" ]; then
	# containers have not been scaled global/horizontal
	export horizontal=1
fi

# This part checks the nodes params
if [ -z "$ips" ]; then
	ips="configs/ips"
	export ips=$ips
fi
if [ -z "$manager" ]; then
	manager=$(head -n 1 configs/ips)
	export manager=$manager
fi
if [ -z "$remote" ]; then
	remote=$(head -n 1 configs/remote)
	export remote=$remote
fi
if [ -z "$experiment" ]; then
	experiment="free"
	export experiment=$experiment
fi

echo "Running experiment $experiment"
echo "Current benchmark is $benchmark"
if [ $availability -eq 0 ]; then echo "Availability is on"; else echo "Availability is off"; fi
if [ $horizontal -eq 0 ]; then echo "Horizontal is on"; else echo "Horizontal is off"; fi
if [ $vertical -eq 0 ]; then echo "Vertical is on"; else echo "Vertical is off"; fi
if [ $unlimited -eq 0 ]; then echo "UNLIMITED resources"; else echo "LIMITED resources"; fi
echo "-------------------------------------------------------"

# update the DSB after updating the files
echo "Resetting the files"
pssh -i -h $ips "cd DeathStarBench && git reset --hard" >/dev/null 2>&1
pssh -i -h $ips "cd DeathStarBench && git pull && git reset --hard" >/dev/null 2>&1
ssh -n $remote "cd DeathStarBench && git reset --hard && git pull" >/dev/null 2>&1

# check what type of server is used and set the correct path
if echo $manager | cut -d@ -f2 | grep "amd" >/dev/null; then
	server_type="c6525-25g"
elif echo $manager | cut -d@ -f2 | grep "ms" >/dev/null; then
	server_type="m510"
fi

# PARAMS ORCHESTRATOR WIDE

# setup directories based on date for the experiments
dir_date=$(date "+%d-%m-%y")
dir_date="/$dir_date/$experiment/$benchmark/$N"
mkdir -p ./results/$dir_date

# file params to output
output_name=$server_type-exp$experiment-havail$availability-hori$horizontal-verti$vertical-infi$unlimited-client$clients-t$t-c$c-d$d-R$R-N$N

# return ip manager and network device
device=$(ssh $manager "ip link show | grep '2: ' | awk '{ print \$2}' | head -n 1 | cut -d: -f1")
# device="ens1f0"
ip_manager=$(ssh -n $manager "ip addr show $device | grep 'inet\b' | awk '{print \$2}' | cut -d/ -f1")

# PARAMS ORCHESTRATOR SPECIFIC

# node 3
if [ $availability -eq 0 ]; then
	node3=$(sed -n '4p' configs/ips)
else
	node3=$(sed -n '2p' configs/ips)
fi
node3_hostname=$(ssh -n $node3 "hostname")
node3_ip=$(ssh -n $node3 "ip -4 a show $device |  grep \"inet\b\" | awk '{ print \$2}' | cut -d/ -f1")

# setup dns
# https://www.linuxuprising.com/2020/07/ubuntu-how-to-free-up-port-53-used-by.html
# ssh $manager "sudo lsof -i :53"
ssh $manager "sudo lsof -i :53" | grep "consul" >/dev/null
if [ $? -ne 0 ]; then
	echo "Setup dns resolver"
	ssh $manager "echo 'DNS=8.8.8.8' | sudo tee -a /etc/systemd/resolved.conf && echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf"
	ssh $manager "sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf"
	ssh $manager "sudo systemctl restart systemd-resolved"

	ssh $manager "sed '9s/consul/root/' /etc/systemd/system/consul.service | sudo tee /etc/systemd/system/consul.service"
	ssh $manager "sed '11s/$/ -dns-port 53/' /etc/systemd/system/consul.service | sudo tee /etc/systemd/system/consul.service"
	ssh $manager "sudo systemctl daemon-reload"
	ssh $manager "sudo systemctl restart consul.service"
fi

run_benchmark() {
	if [ $benchmark == "hotelReservation" ]; then
		echo "Deploying hotelReservation app"
		bench_name=hotel-reservation

		# Make sure no other nomad job is running
		ssh $manager "nomad job stop -purge social-network" >/dev/null
		ssh $manager "nomad job stop -purge media-microservices" >/dev/null

		# Use the correct deployment files
		if [ $unlimited -eq 1 ]; then
			if [ $vertical -eq 0 ]; then
				echo "Running $bench_name with limited resources and vertical scaling"
				nomad_job="$bench_name-limited-vertical.nomad"
			elif [ $horizontal -eq 0 ]; then
				echo "Running $bench_name with limited resources and horizontal scaling"
				nomad_job="$bench_name-limited-horizontal.nomad"
			else
				echo "Running $bench_name with limited resources"
				nomad_job="$bench_name-limited-resources.nomad"
			fi
		elif [ $unlimited -eq 0 ]; then
			nomad_job="$bench_name.nomad"
			echo "Running hotel-reservation with unlimited resources"
		fi
		echo "Nomad job file is $nomad_job."

		# Change variables in nomad file of the jaeger/dns/hostname
		ssh $manager "cd DeathStarBench/hotelReservation/nomad && sed -e '3s/\".*\"/\"$node3_hostname\"/' -e '8s/\".*\"/\"$node3_ip\"/' -e '13s/\".*\"/\"$ip_manager\"/' $nomad_job | sudo tee $nomad_job" >/dev/null

		# Check if hotel-reservation is already deployed
		ssh $manager "nomad status" | grep "$bench_name" >/dev/null
		if [ $? -ne 0 ]; then
			# If the app is not deployed, deploy it

			# setup dns resolver on node3
			echo "Dns resolver setup on node3"
			ssh $node3 "cat /etc/systemd/resolved.conf" | grep "8.8.8.8" >/dev/null
			if [ $? -ne 0 ]; then
				echo "Setup dns resolver"
				ssh $node3 "echo 'DNS=8.8.8.8' | sudo tee -a /etc/systemd/resolved.conf && echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf"
				ssh $node3 "sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf"
				ssh $node3 "sudo systemctl restart systemd-resolved"
			fi

			# deploy hotel-reservation app
			echo "Deploying $bench_name"
			ssh $manager "cd DeathStarBench/$benchmark/nomad && nomad job run $nomad_job"

			echo "$benchmark app is ready to be experimented on."
		else
			echo "Benchmark already deployed"
		fi

		if [ $availability -eq 0 ]; then
			export nginx_ip=10.10.1.4
		elif [ $availability -eq 1 ]; then
			export nginx_ip=10.10.1.2

		fi
		echo "The frontend service is found on $node3,  $nginx_ip"
		echo "The jaeger service is found on $node3, $nginx_ip"

		echo "hotelReservation workloads are being run..."
		ssh -n $remote "cd DeathStarBench/$benchmark/wrk2 && export nginx_ip=$nginx_ip && ./workload.sh -t $t -c $c -d $d -R $R" >./results/$dir_date/nomad-hr-wrk-mixed-$output_name

		echo "$benchmark results are in."
		echo "hotelReservation iteration done."

	elif [ $benchmark == "mediaMicroservices" ]; then
		echo "Deploying mediaMicroservices app"
		bench_name=media-microservices

		# Make sure no other nomad job is running
		ssh $manager "nomad job stop -purge social-network"
		ssh $manager "nomad job stop -purge hotel-reservation"

		# Check if hotel-reservation is already deployed
		ssh $manager "nomad status" | grep "$bench_name" >/dev/null
		if [ $? -ne 0 ]; then
			# If the app is not deployed, deploy it

			# Use the correct deployment files
			if [ $unlimited -eq 1 ]; then
				if [ $vertical -eq 0 ]; then
					echo "Running $bench_name with limited resources and vertical scaling"
					nomad_job="$bench_name-limited-vertical.nomad"
				elif [ $horizontal -eq 0 ]; then
					echo "Running $bench_name with limited resources and horizontal scaling"
					nomad_job="$bench_name-limited-horizontal.nomad"
				else
					echo "Running $bench_name with limited resources"
					nomad_job="$bench_name-limited-resources.nomad"
				fi
			elif [ $unlimited -eq 0 ]; then
				nomad_job="$bench_name.nomad"
				echo "Running media-microservices with unlimited resources"
			fi

			# Change variables in nomad file of the jaeger/dns/hostname
			ssh $manager "cd DeathStarBench/mediaMicroservices/nomad && sed -e '3s/\".*\"/\"$node3_hostname\"/' -e '8s/\".*\"/\"$node3_ip\"/' -e '13s/\".*\"/\"$ip_manager\"/' $nomad_job | sudo tee $nomad_job" >/dev/null 2>&1
			pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/nomad && sed '43s/\([0-9]\{1,3\}\.\)\{1,3\}[0-9]\{1,3\}/$ip_manager/' nginx.conf | sudo tee nginx.conf" >/dev/null 2>&1

			# deploy media-microservices app
			sleep 5
			echo "Deploying $bench_name"
			ssh $manager "cd DeathStarBench/$benchmark/nomad && nomad job run $nomad_job"

			# Check if deployment succeeded
			# count=0
			# echo "resultaat"
			# ssh $manager "line_n=$(nomad job status -evals media-microservices | awk '{ print $5}' | grep -n \"Healthy\" | cut -d: -f1) && line_n_end=$((line_n+13)) && nomad job status -evals media-microservices | awk '{ print \$5}' | sed -n \$line_n,\"\$line_n_end\"p" | grep 0
			# while [ $? -eq 0 ]; do
			# 	echo "waiting for nomad to be ready"
			# 	count=$((count+1))
			# 	sleep 10
			# 	if [ $count -gt 10 ]; then
			# 		echo "$benchmark deployment is stuck, redeploying"
			# 		ssh $manager "cd DeathStarBench/$benchmark/nomad && nomad job stop -purge $bench_name"
			# 		ssh $manager "cd DeathStarBench/$benchmark/nomad && nomad job run $nomad_job"
			# 	fi
			# 	# ssh $manager 'line_n=$(nomad job status -evals media-microservices | awk "{ print $4}" | grep -n "Placed" | cut -d: -f1) && line_n_end=$((line_n+9)) && nomad job status -evals media-microservices | awk "{ print $4}" | sed -n $line_n,"$line_n_end"p' | grep 0
			# 	ssh $manager "line_n=$(nomad job status -evals media-microservices | awk '{ print $4}' | grep -n \"Healthy\" | cut -d: -f1) && line_n_end=$((line_n+13)) && nomad job status -evals media-microservices | awk '{ print \$4}' | sed -n \$line_n,\"\$line_n_end\"p" | grep 0
			# done

			# Load the dataset
			echo "Loading the dataset"
			count=0
			if [ $horizontal -eq 0 ]; then
				while [ $count -ne 10 ]; do
					echo "$count"
					ssh $node3 "cd DeathStarBench/mediaMicroservices/scripts && python3 write_movie_info.py && ./register_movies.sh && ./register_users.sh" >/dev/null 2>&1
					count=$((count + 1))
				done
			elif [ $horizontal -eq 1 ]; then
				ssh $node3 "cd DeathStarBench/mediaMicroservices/scripts && python3 write_movie_info.py && ./register_movies.sh && ./register_users.sh" >/dev/null 2>&1
			fi
			# ssh $node3 "cd DeathStarBench/mediaMicroservices/scripts && python3 write_movie_info.py && ./register_movies.sh && ./register_users.sh"
			echo "mediaMicroservices app is ready to be experimented on."

			echo "$benchmark app is ready to be experimented on."
		else
			echo "Benchmark already deployed"
		fi

		if [ $availability -eq 0 ]; then
			export nginx_ip=10.10.1.4
		elif [ $availability -eq 1 ]; then
			export nginx_ip=10.10.1.2
		fi
		echo "The nginx service is found on $node3, $nginx_ip"
		echo "The jaeger service is found on $nginx_ip"

		echo "$benchmark workloads are being run..."
		ssh -n $remote "cd DeathStarBench/$benchmark/wrk2 && export nginx_ip=$nginx_ip && ./workload.sh -t $t -c $c -d $d -R $R" >./results/$dir_date/nomad-mm-wrk-compose-$output_name

		# Stop the benchmark
		# ssh $manager "cd DeathStarBench/mediaMicroservices/nomad && nomad job stop media-microservices"

		echo "mediaMicroservices experiment cleaned up."

	elif [ $benchmark == "socialNetwork" ]; then
		echo "Deploying socialNetwork app"
		bench_name=social-network

		# Make sure no other nomad job is running
		ssh $manager "nomad job stop -purge media-microservices"
		ssh $manager "nomad job stop -purge hotel-reservation"

		# Check if social-network is already deployed
		ssh $manager "nomad status" | grep "$bench_name" >/dev/null
		if [ $? -ne 0 ]; then
			# If the app is not deployed, deploy it

			# Use the correct deployment files
			if [ $unlimited -eq 1 ]; then
				if [ $vertical -eq 0 ]; then
					echo "Running $bench_name with limited resources and vertical scaling"
					nomad_job="$bench_name-limited-vertical.nomad"
				elif [ $horizontal -eq 0 ]; then
					echo "Running $bench_name with limited resources and horizontal scaling"
					nomad_job="$bench_name-limited-horizontal.nomad"
				else
					echo "Running $bench_name with limited resources"
					nomad_job="$bench_name-limited-resources.nomad"
				fi
			elif [ $unlimited -eq 0 ]; then
				nomad_job="$bench_name.nomad"
				echo "Running social-network with unlimited resources"
			fi

			# Change the hostname
			# Change variables in nomad file of the jaeger/dns/hostname
			ssh $manager "cd DeathStarBench/socialNetwork/nomad && sed -e '3s/\".*\"/\"$node3_hostname\"/' -e '8s/\".*\"/\"$node3_ip\"/' -e '13s/\".*\"/\"$ip_manager\"/' $nomad_job | sudo tee $nomad_job" >/dev/null
			pssh -i -h $ips "cd DeathStarBench/socialNetwork/nomad/nginx-web-server/conf && sed '45s/\([0-9]\{1,3\}\.\)\{1,3\}[0-9]\{1,3\}/$ip_manager/' nginx.conf | sudo tee nginx.conf" >/dev/null

			# deploy social-network app
			echo "Deploying $bench_name"
			ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job run $nomad_job"

			# # Check if deployment succeeded
			# count=0
			# # ssh $manager "nomad job status -evals social-network | awk '{ print \$4 }' | sed -n '55,68p;'"  | grep 0
			# ssh $manager 'line_n=$(nomad job status -evals social-network | awk "{ print \$4 }" | grep -n "Placed" | cut -d: -f1) && line_n_end=$((line_n+13)) && nomad job status -evals social-network | awk "{ print \$4}" | sed -n $line_n,"$line_n_end"p' | grep 0
			# while [ $? -eq 0 ]; do
			# 	echo "waiting for nomad to be ready"
			# 	count=$((count+1))
			# 	sleep 10
			# 	if [ $count -gt 10 ]; then
			# 		echo "$benchmark deployment is stuck, redeploying"
			# 		ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job stop -purge social-network"
			# 		ssh $manager "cd DeathStarBench/socialNetwork/nomad && nomad job run $nomad_job"
			# 	fi
			# 	# ssh $manager "nomad job status -evals social-network | awk '{ print \$4 }' | sed -n '55,68p;'"  | grep 0
			# 	ssh $manager 'line_n=$(nomad job status -evals social-network | awk "{ print $4}" | grep -n "Placed" | cut -d: -f1) && line_n_end=$((line_n+13)) && nomad job status -evals social-network | awk "{ print $4}" | sed -n $line_n,"$line_n_end"p' | grep 0
			# done

			# Load the dataset
			if [ $horizontal -eq 0 ]; then
				ssh $node3 "cd DeathStarBench/socialNetwork/ && python3 scripts/init_social_graph.py" | grep Failed | wc -l
				while [ $? -ne 0 ]; do
					ssh $node3 "cd DeathStarBench/socialNetwork/ && python3 scripts/init_social_graph.py" | grep Failed | wc -l
				done
			elif [ $horizontal -eq 1 ]; then
				ssh $node3 "cd DeathStarBench/socialNetwork/ && python3 scripts/init_social_graph.py"
			fi
			echo "socialNetwork app is ready to be experimented on."
		else
			echo "Social-network already deployed"
		fi

		if [ $availability -eq 0 ]; then
			export nginx_ip=10.10.1.4
		elif [ $availability -eq 1 ]; then
			export nginx_ip=10.10.1.2
		fi
		echo "The nginx service is found on $node3, $nginx_ip"
		echo "The jaeger service is found on $nginx_ip"

		echo "socialNetwork workloads are being run..."
		ssh -n $remote "cd DeathStarBench/$benchmark/wrk2 && export nginx_ip=$nginx_ip && ./workload-mixed.sh -t $t -c $c -d $d -R $R" >./results/$dir_date/nomad-sn-wrk-mixed-$output_name

		echo "socialNetwork results are in."
		echo "SocialNetwork experiment cleaned up."
		# exit 0
	fi

}

# deploy 1 of the services
if [ -z "$benchmark" ]; then
	echo "---------------------"
	echo "No benchmark specified, running all benchmarks with specified parameters"
	echo "---------------------"
	# for benchmark in socialNetwork mediaMicroservices  hotelReservation; do
	for benchmark in socialNetwork mediaMicroservices hotelReservation; do
		echo "Running the baseline tests for $benchmark"
		run_benchmark
	done
else
	echo "---------------------"
	echo "Benchmark specified"
	echo "---------------------"
	run_benchmark
fi

exit 0
