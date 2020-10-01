#!/bin/bash

wait_file() {
  local file="$1"; shift
  local wait_seconds="${1:-3}"; shift # 10 seconds as default timeout

  until test $((wait_seconds--)) -eq 0 -o -e "$file" ; do sleep 1; done

  ((++wait_seconds))
}

#TransmissionPort=51413
. /scripts/create_conf.sh
. /scripts/SetupNS.sh

portfile="/tmp/piaport"
PIA_TOKEN=$WG_TOKEN \
  PF_GATEWAY="$(echo "$wireguard_json" | jq -r '.server_vip')" \
  PF_HOSTNAME="$WG_HOSTNAME" \
  ./port_forwarding.sh &


#Wait for port forwarding to complete
wait_file "$portfile" 30 || {
  echo "Transmission port file missing after waiting for $? seconds"
  exit 1
}

piaport=$(cat "$portfile")

