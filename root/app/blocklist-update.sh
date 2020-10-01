#!/bin/bash

BLOCKLIST_ENABLED=$(jq -r '.["blocklist-enabled"]' /config/settings.json)

if [ "$BLOCKLIST_ENABLED" == true ]; then
  if [ -n "$TRANSUSER" ] && [ -n "$TRANSPASS" ]; then
    /usr/bin/transmission-remote -n "$TRANSUSER":"$TRANSPASS" --blocklist-update
  else
    /usr/bin/transmission-remote --blocklist-update
  fi
fi