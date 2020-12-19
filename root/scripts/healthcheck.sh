#!/bin/bash

if [ -n "$(ifconfig | grep eth)" ]
then
  echo "Something is amiss with the network"
  exit 1
fi


output="$(transmission-remote -n "$TRANSUSER:$TRANSPASS" -pt)"

if [[ "$output" != "Port is open: Yes" ]]
then
    transmission-remote -n "$TRANSUSER:$TRANSPASS" -p $(cat /tmp/piaport)
    sleep 5
    if [[ "$output" != "Port is open: Yes" ]]
    then
        echo "Port Forwarding Failed"
        exit 1
    fi
fi

if [[ -z "$HOST" ]]
then
    echo "Host  not set! Set env 'HEALTH_CHECK_HOST'. For now, using default google.com"
    HOST="google.com"
fi

ping -c 1 $HOST
STATUS=$?
if [[ ${STATUS} -ne 0 ]]
then
    echo "Network is down"
    exit 1
fi

echo "Network is up"


exit 0
