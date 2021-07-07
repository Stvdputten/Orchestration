#!/usr/bin/env bash

# onevm
NAMES=$(onevm list -f NAME~hashi -l ID --no-header)

action=$1
while getopts "a:" arg; do
  case $arg in
    a) action=$OPTARG;;
  esac
done

echo "Perform $action action on nodes."
# Perform action, e.g. suspend/resume/terminate
for n in $NAMES
do
    # echo $n
    if [ $action = "snapshot-revert" ]; then
      onevm $action $n $2
    elif [ $action = "snapshot-delete" ]; then
      onevm $action $n $2
    else
      onevm $action $n
    fi
done
