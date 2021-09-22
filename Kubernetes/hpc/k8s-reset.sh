#!/usr/bin/env bash

ips="configs/ips"
pssh -i -h $ips "sudo kubeadm reset --force"
