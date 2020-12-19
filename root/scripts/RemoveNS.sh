#!/bin/sh
ip link del pia
ip netns pids physical | xargs kill
sleep 1
ip netns pids physical | xargs kill -9
ip link set $eth netns default
rm /var/run/netns/default
ip netns delete physical


