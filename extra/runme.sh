#!/bin/bash
TransmissionPort=51413
. /scripts/create_conf.sh
. /scripts/SetupNS.sh

PIA_TOKEN=$WG_TOKEN \
  PF_GATEWAY="$(echo "$wireguard_json" | jq -r '.server_vip')" \
  PF_HOSTNAME="$WG_HOSTNAME" \
  ./port_forwarding.sh &

sleep 5

file="/tmp/piaport"
piaport=$(cat "$file")
