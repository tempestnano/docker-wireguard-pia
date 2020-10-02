#!/bin/sh
eth0default=$(ip route list | grep default)
eth0route=$(ip route list | grep "eth0 proto")
eth0addr=$(ip -4 -o addr show eth0 | awk '{print $4}') 
wgaddr=$(cat /etc/wireguard/pia.conf | grep Address | awk '{print $3'})
ip netns add physical
ip link set eth0 netns physical
ip -n physical link add pia type wireguard
ip -n physical link set pia netns 1
ip -n physical addr add $eth0addr dev eth0
ip -n physical link set eth0 up
ip -n physical route add $eth0default
ip -n physical route add $eth0route
ip netns exec physical echo nameserver 8.8.8.8 > /etc/resolv.conf
wg setconf pia /etc/wireguard/pia.conf
ip addr add $wgaddr dev pia
ip link set pia up
ip route add default dev pia

socat UNIX-LISTEN:/tmp/socat.sock,fork tcp:127.0.0.1:9091 &
ip netns exec physical socat TCP-LISTEN:9091,fork UNIX:/tmp/socat.sock &

#ip link add name vethpys0 type veth peer name vethvpn0
#ip link set vethpys0 netns physical
#ip addr add 10.0.0.1/24 dev vethvpn0
#ip netns exec physical ip addr add 10.0.0.2/24 dev vethpys0
#ip link set vethvpn0 up
#ip netns exec physical ip link set vethpys0 up
#echo 1 > /proc/sys/net/ipv4/conf/all/forwarding
#iptables -t nat -A PREROUTING ! -s 10.0.0.0/24 -p tcp -m tcp --dport 80 -j DNAT --to-destination 10.0.0.2
#ip netns exec physical ip route add default via 10.0.0.1
#iptables -t nat -A OUTPUT -d 192.168.1.2 -p tcp -m tcp --dport 80 -j DNAT --to-destination 10.0.0.2