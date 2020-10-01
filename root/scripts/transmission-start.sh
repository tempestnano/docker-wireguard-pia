#!/bin/sh

# Source our persisted env variables from container startup

# Settings
TRANSMISSION_PASSWD_FILE=/config/transmission-credentials.txt

transmission_username=$(head -1 $TRANSMISSION_PASSWD_FILE)
transmission_passwd=$(tail -1 $TRANSMISSION_PASSWD_FILE)
transmission_settings_file=${TRANSMISSION_HOME}/settings.json

if [[ "true" = "$DOCKER_LOG" ]]; then
  LOGFILE=/dev/stdout
else
  LOGFILE=${TRANSMISSION_HOME}/transmission.log
fi

echo "STARTING TRANSMISSION"
/usr/bin/transmission-daemon -g ${TRANSMISSION_HOME} --logfile $LOGFILE &