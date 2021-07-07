#!/usr/bin/env bash

template=16435
managers=$1
workers=$2
while getopts "m:w:" arg; do
  case $arg in
    m) managers=$OPTARG;;
    w) workers=$OPTARG;;
  esac
done

echo "Make sure no similar named vm exists"
ready=$(onevm list -f NAME~hashi -l STAT --no-header | grep "runn" | wc -l)
while [ ! $ready -eq 0 ]; do
  sleep 5
  ready=$(onevm list -f NAME~hashi -l STAT --no-header | grep "runn" | wc -l)
  echo "Waiting till all similar named vms are gone"
done

if [[ $# -eq 0 ]]; then
    echo "No arguments supplied"
    exit 1
fi

echo "Starting Hashi cluster with $managers managers and $workers workers."
# exit 1

i=1
while [ "$i" -le "$managers" ]; do
    onetemplate instantiate ${template} --name "hashi-manager-${i}"
    # echo "$i"
    i=$(($i + 1))
done

i=1
while [ "$i" -le "$workers" ]; do
    onetemplate instantiate ${template} --name "hashi-worker-${i}"
    # echo "$i"
    i=$(($i + 1))
done

# set up check that status of all is ready?
ready=$(onevm list -f NAME~hashi -l STAT --no-header | grep "runn" | wc -l)
ready_count=$((managers+workers))
# echo $ready_count
while [ ! $ready -eq $ready_count ]; do
  sleep 5
  ready=$(onevm list -f NAME~hashi -l STAT --no-header | grep "runn" | wc -l)
  echo "All vms are not ready: $ready"
done

echo "All vms are ready!"