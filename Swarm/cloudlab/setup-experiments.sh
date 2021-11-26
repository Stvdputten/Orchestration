#!/usr/bin/env bash

# This part is running seperately 
ips="configs/ips"
manager=$(head -n 1 configs/ips)

# Make sure prometheus isn't installed in home directory
# pssh -i -h $ips "git clone https://github.com/Stvdputten/DeathStarBench"

# update the DSB after updating the files
# pssh -i -h $ips "cd DeathStarBench && git pull && git reset --hard origin/local"


# Setup wrk2 etc
# pssh -i -h $ips "sudo apt-get install -y pip luarocks libz-dev libssl-dev"
# pssh -i -h $ips "pip install --no-input asyncio aiohttp"
# pssh -i -h $ips "sudo luarocks install luasocket"


# benchmark="socialNetwork"
# benchmark="mediaMicroservices"
benchmark="hotelReservation"

# deploy 1 of the services
if [ $benchmark == "hotelReservation" ]; then
	echo "Deploying hotelReservation app"
	pssh -i -h $ips "cd DeathStarBench/hotelReservation/wrk2 && make clean && make"
	# Assumes you have portforwarded the service, e.g. ssh -L 5000:localhost:5000 user@server
	pssh -i -h $ips "cd DeathStarBench/hotelReservation && docker-compose build"
	ssh $manager "cd DeathStarBench/hotelReservation && docker stack deploy -c docker-compose-swarm-local.yml hotel-reservation"
	echo "hotelReservation app is ready to be experimented on."
	exit 0

elif [ $benchmark == "mediaMicroservices" ]; then
	echo "Deploying mediaMicroservices app"
	pssh -i -h $ips "cd DeathStarBench/mediaMicroservices/wrk2 && make clean && make"
	ssh $manager "cd DeathStarBench/mediaMicroservices && docker stack deploy -c docker-compose.yml media-microservices"

	echo "mediaMicroservices app is ready to be experimented on."
	exit 0
elif [ $benchmark == "socialNetwork" ]; then
	echo "Deploying socialNetwork app"
	pssh -i -h $ips "cd DeathStarBench/socialNetwork/wrk2 && make clean && make"
	ssh $manager "cd DeathStarBench/socialNetwork && docker stack deploy -c docker-compose-swarm-jaeger.yml social-network"
	echo "socialNetwork app is ready to be experimented on."
	exit 0
fi
