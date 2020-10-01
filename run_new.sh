#!/bin/bash

if [ $FIREWALL -eq 1 ]; then
  # Block everything by default
  ip6tables -P OUTPUT DROP &> /dev/null
  ip6tables -P INPUT DROP &> /dev/null
  ip6tables -P FORWARD DROP &> /dev/null
  iptables -P OUTPUT DROP &> /dev/null
  iptables -P INPUT DROP &> /dev/null
  iptables -P FORWARD DROP &> /dev/null

  # Temporarily allow DNS queries
  iptables -A OUTPUT -o lo -j ACCEPT
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

  # We also need to temporarily allow the following
  iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
  iptables -A OUTPUT -p tcp --dport 1337 -j ACCEPT
fi

configdir="/pia"
tokenfile="$configdir/.token"
pf_persistfile="$configdir/portsig.json"

sharedir="/pia-shared"
portfile="$sharedir/port.dat"

pia_cacrt="/rsa_4096.crt"
wg_conf="/etc/wireguard/wg0.conf"

# Handle shutdown behavior
finish () {
    [ $PORT_FORWARDING -eq 1 ] && pkill -f 'pf.sh'
    echo "$(date): Shutting down WireGuard"
    [ -w "$portfile" ] && rm "$portfile"
    wg-quick down wg0
    exit 0
}

trap finish SIGTERM SIGINT SIGQUIT

# All done. Sleep and wait for termination.
now_sleep () {
  sleep infinity &
  wait $!
}

# An error with no recovery logic occured. Either go to sleep or exit.
fatal_error () {
  echo "$(date): Fatal error"
  [ $EXIT_ON_FATAL -eq 1 ] && exit 1
  sleep infinity &
  wait $!
}