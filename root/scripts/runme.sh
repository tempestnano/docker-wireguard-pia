#!/bin/bash

wait_file() {
  local file="$1"; shift
  local wait_seconds="${1:-3}"; shift # 10 seconds as default timeout

  until test $((wait_seconds--)) -eq 0 -o -e "$file" ; do sleep 1; done

  ((++wait_seconds))
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

FILE=/config/settings.json
if [ ! -f "$FILE" ]; then
    cp /etc/defaults/settings.json /config/
fi

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



piaport=$(cat "$portfile") ./transmission-start.sh

now_sleep