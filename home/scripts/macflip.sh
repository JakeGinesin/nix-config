#!/usr/bin/env bash
newmac=$1
sudo ip link set wlan0 down
sudo macchanger wlan0 --mac "$1"
sudo ip link set wlan0 up
