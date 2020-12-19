#!/bin/sh
#!/bin/bash
pids=$(ip netns pids physical)
if [ ${#pids} -gt 0 ]; then
        . /scripts/RemoveNS.sh
fi

ip netns delete physical
eth=$(route | grep '^default' | grep -o '[^ ]*$')
ethdefault=$(ip route list | grep default)
ethroute=$(ip route list | grep "$eth")
ethaddr=$(ip -4 -o addr show "$eth" | awk '{print $4}') 



wgaddr=$(cat /etc/wireguard/pia.conf | grep Address | awk '{print $3'})
ip netns add physical
ip link set $eth netns physical
ip -n physical link add pia type wireguard
ip -n physical link set pia netns 1
ip -n physical addr add $ethaddr dev eth0
ip -n physical link set $eth up
ip -n physical route add $ethdefault
#ip -n physical route add $ethroute
ip netns exec physical echo nameserver 8.8.8.8 > /etc/resolv.conf
wg setconf pia /etc/wireguard/pia.conf
ip addr add $wgaddr dev pia
ip link set pia up
ip route add default dev pia

ln -s /proc/1/ns/net /var/run/netns/default
ip netns exec physical socat tcp-listen:9091,fork,reuseaddr \
exec:'ip netns exec default socat STDIO "tcp-connect:127.0.0.1:9091"',nofork &

for i in ${FORWARD_PORTS//,/ }
do
    if [ $i -ne 9091 ]; then
        ip netns exec physical socat tcp-listen:"$i",fork,reuseaddr \
        exec:'ip netns exec default socat STDIO "tcp-connect:127.0.0.1:"$i""',nofork &
    fi
done
