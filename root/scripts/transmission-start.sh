#!/bin/sh

# Source our persisted env variables from container startup

# Settings
TRANSMISSION_HOME=/config
transmission_settings_file=${TRANSMISSION_HOME}/settings.json


ippia=$(ip -f inet -o addr show pia|cut -d\  -f 7 | cut -d/ -f 1)
echo "$( jq --arg keyName bind-address-ipv4 '.[$keyName]'=\"$ippia\" $transmission_settings_file )" > $transmission_settings_file

iprpc=$(ip -f inet -o addr show eth1|cut -d\  -f 7 | cut -d/ -f 1)
echo "$( jq --arg keyName rpc-bind-address '.[$keyName]'=\"$iprpc\" $transmission_settings_file )" > $transmission_settings_file

echo "$( jq --arg keyName peer-port '.[$keyName]'=\"$piaport\" $transmission_settings_file )" > $transmission_settings_file



export TRANSMISSION_WEB_HOME="/combustion-release"

if [[ "true" = "$DOCKER_LOG" ]]; then
  LOGFILE=/dev/stdout
else
  LOGFILE=${TRANSMISSION_HOME}/transmission.log
fi

echo "STARTING TRANSMISSION"
/usr/bin/transmission-daemon -g ${TRANSMISSION_HOME} --logfile $LOGFILE &