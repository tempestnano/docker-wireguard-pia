#!/bin/bash
# Copyright (C) 2020 Private Internet Access, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# This function allows you to check if the required tools have been installed.
function check_tool() {
  cmd=$1
  package=$2
  if ! command -v $cmd &>/dev/null
  then
    echo "$cmd could not be found"
    echo "Please install $package"
    exit 1
  fi
}
# Now we call the function to make sure we can use curl and jq.
check_tool curl curl
check_tool jq jq

# This allows you to set the maximum allowed latency in seconds.
# All servers that repond slower than this will be ignored.
# You can inject this with the environment variable MAX_LATENCY.
# The default value is 50 milliseconds.
MAX_LATENCY=${MAX_LATENCY:-0.05}
export MAX_LATENCY

serverlist_url='https://serverlist.piaservers.net/vpninfo/servers/v4'

# This function checks the latency you have to a specific region.
# It will print a human-readable message to stderr,
# and it will print the variables to stdout
printServerLatency() {
  serverIP="$1"
  regionID="$2"
  regionName="$(echo ${@:3} |
    sed 's/ false//' | sed 's/true/(geo)/')"
  time=$(curl -o /dev/null -s \
    --connect-timeout $MAX_LATENCY \
    --write-out "%{time_connect}" \
    http://$serverIP:443)
  if [ $? -eq 0 ]; then
    >&2 echo Got latency ${time}s for region: $regionName
    echo $time $regionID $serverIP
  fi
}
export -f printServerLatency

echo -n "Getting the server list... "
# Get all region data since we will need this on multiple ocasions
all_region_data=$(curl -s "$serverlist_url" | head -1)

# If the server list has less than 1000 characters, it means curl failed.
if [[ ${#all_region_data} < 1000 ]]; then
  echo "Could not get correct region data. To debug this, run:"
  echo "$ curl -v $serverlist_url"
  echo "If it works, you will get a huge JSON as a response."
  exit 1
fi
# Notify the user that we got the server list.
echo "OK!"

# Test one server from each region to get the closest region.
# If port forwarding is enabled, filter out regions that don't support it.
if [[ $PIA_PF == "true" ]]; then
  echo Port Forwarding is enabled, so regions that do not support
  echo port forwarding will get filtered out.
  summarized_region_data="$( echo $all_region_data |
    jq -r '.regions[] | select(.port_forward==true) |
    .servers.meta[0].ip+" "+.id+" "+.name+" "+(.geo|tostring)' )"
else
  summarized_region_data="$( echo $all_region_data |
    jq -r '.regions[] |
    .servers.meta[0].ip+" "+.id+" "+.name+" "+(.geo|tostring)' )"
fi
echo Testing regions that respond \
  faster than $MAX_LATENCY seconds:
bestRegion="$(echo "$summarized_region_data" |
  xargs -i bash -c 'printServerLatency {}' |
  sort | head -1 | awk '{ print $2 }')"

if [ -z "$bestRegion" ]; then
  echo ...
  echo No region responded within ${MAX_LATENCY}s, consider using a higher timeout.
  echo For example, to wait 1 second for each region, inject MAX_LATENCY=1 like this:
  echo $ MAX_LATENCY=1 ./get_region_and_token.sh
  exit 1
fi

# Get all data for the best region
regionData="$( echo $all_region_data |
  jq --arg REGION_ID "$bestRegion" -r \
  '.regions[] | select(.id==$REGION_ID)')"

echo -n The closest region is "$(echo $regionData | jq -r '.name')"
if echo $regionData | jq -r '.geo' | grep true > /dev/null; then 
  echo " (geolocated region)."
else 
  echo "."
fi
echo
bestServer_meta_IP="$(echo $regionData | jq -r '.servers.meta[0].ip')"
bestServer_meta_hostname="$(echo $regionData | jq -r '.servers.meta[0].cn')"
bestServer_WG_IP="$(echo $regionData | jq -r '.servers.wg[0].ip')"
bestServer_WG_hostname="$(echo $regionData | jq -r '.servers.wg[0].cn')"
bestServer_OT_IP="$(echo $regionData | jq -r '.servers.ovpntcp[0].ip')"
bestServer_OT_hostname="$(echo $regionData | jq -r '.servers.ovpntcp[0].cn')"
bestServer_OU_IP="$(echo $regionData | jq -r '.servers.ovpnudp[0].ip')"
bestServer_OU_hostname="$(echo $regionData | jq -r '.servers.ovpnudp[0].cn')"

echo "The script found the best servers from the region closest to you.
When connecting to an IP (no matter which protocol), please verify
the SSL/TLS certificate actually contains the hostname so that you
are sure you are connecting to a secure server, validated by the
PIA authority. Please find bellow the list of best IPs and matching
hostnames for each protocol:
Meta Services: $bestServer_meta_IP // $bestServer_meta_hostname
WireGuard: $bestServer_WG_IP // $bestServer_WG_hostname
OpenVPN TCP: $bestServer_OT_IP // $bestServer_OT_hostname
OpenVPN UDP: $bestServer_OU_IP // $bestServer_OU_hostname
"

if [[ ! $PIA_USER || ! $PIA_PASS ]]; then
  echo If you want this script to automatically get a token from the Meta
  echo service, please add the variables PIA_USER and PIA_PASS. Example:
  echo $ PIA_USER=p0123456 PIA_PASS=xxx ./get_region_and_token.sh
  exit 1
fi

echo "The ./get_region_and_token.sh script got started with PIA_USER and PIA_PASS,
so we will also use a meta service to get a new VPN token."

echo "Trying to get a new token by authenticating with the meta service..."
generateTokenResponse=$(curl -s -u "$PIA_USER:$PIA_PASS" \
  --connect-to "$bestServer_meta_hostname::$bestServer_meta_IP:" \
  --cacert "ca.rsa.4096.crt" \
  "https://$bestServer_meta_hostname/authv3/generateToken")
echo "$generateTokenResponse"

if [ "$(echo "$generateTokenResponse" | jq -r '.status')" != "OK" ]; then
  echo "Could not get a token. Please check your account credentials."
  echo "You can also try debugging by manually running the curl command:"
  echo $ curl -vs -u "$PIA_USER:$PIA_PASS" --cacert ca.rsa.4096.crt \
    --connect-to "$bestServer_meta_hostname::$bestServer_meta_IP:" \
    https://$bestServer_meta_hostname/authv3/generateToken
  exit 1
fi

token="$(echo "$generateTokenResponse" | jq -r '.token')"
echo "This token will expire in 24 hours.
"

WG_TOKEN="$token" 
WG_SERVER_IP=$bestServer_WG_IP 
WG_HOSTNAME=$bestServer_WG_hostname

# Now we call the function to make sure we can use wg-quick, curl and jq.
check_tool wg-quick wireguard-tools
check_tool curl curl
check_tool jq jq

# PIA currently does not support IPv6. In order to be sure your VPN
# connection does not leak, it is best to disabled IPv6 altogether.
if [ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -ne 1 ] ||
  [ $(sysctl -n net.ipv6.conf.default.disable_ipv6) -ne 1 ]
then
  echo 'You should consider disabling IPv6 by running:'
  echo 'sysctl -w net.ipv6.conf.all.disable_ipv6=1'
  echo 'sysctl -w net.ipv6.conf.default.disable_ipv6=1'
fi

# Check if the mandatory environment variables are set.
if [[ ! $WG_SERVER_IP || ! $WG_HOSTNAME || ! $WG_TOKEN ]]; then
  echo This script requires 3 env vars:
  echo WG_SERVER_IP - IP that you want to connect to
  echo WG_HOSTNAME  - name of the server, required for ssl
  echo WG_TOKEN     - your authentication token
  echo
  echo You can also specify optional env vars:
  echo "PIA_PF                - enable port forwarding"
  echo "PAYLOAD_AND_SIGNATURE - In case you already have a port."
  echo
  echo An easy solution is to just run get_region_and_token.sh
  echo as it will guide you through getting the best server and 
  echo also a token. Detailed information can be found here:
  echo https://github.com/pia-foss/manual-connections
  exit 1
fi

# Create ephemeral wireguard keys, that we don't need to save to disk.
privKey="$(wg genkey)"
export privKey
pubKey="$( echo "$privKey" | wg pubkey)"
export pubKey

# Authenticate via the PIA WireGuard RESTful API.
# This will return a JSON with data required for authentication.
# The certificate is required to verify the identity of the VPN server.
# In case you didn't clone the entire repo, get the certificate from:
# https://github.com/pia-foss/manual-connections/blob/master/ca.rsa.4096.crt
# In case you want to troubleshoot the script, replace -s with -v.
echo Trying to connect to the PIA WireGuard API on $WG_SERVER_IP...
wireguard_json="$(curl -s -G \
  --connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" \
  --cacert "ca.rsa.4096.crt" \
  --data-urlencode "pt=${WG_TOKEN}" \
  --data-urlencode "pubkey=$pubKey" \
  "https://${WG_HOSTNAME}:1337/addKey" )"
export wireguard_json
echo "$wireguard_json"

# Check if the API returned OK and stop this script if it didn't.
if [ "$(echo "$wireguard_json" | jq -r '.status')" != "OK" ]; then
  >&2 echo "Server did not return OK. Stopping now."
  exit 1
fi

# Create the WireGuard config based on the JSON received from the API
# The config does not contain a DNS entry, since some servers do not
# have resolvconf, which will result in the script failing.
# We will enforce the DNS after the connection gets established.
echo -n "Trying to write /etc/wireguard/pia.conf... "
mkdir -p /etc/wireguard
echo "
[Interface]
#Address = $(echo "$wireguard_json" | jq -r '.peer_ip')
PrivateKey = $privKey
## If you want wg-quick to also set up your DNS, uncomment the line below.
#DNS = $(echo "$wireguard_json" | jq -r '.dns_servers[0]')

[Peer]
PublicKey = $(echo "$wireguard_json" | jq -r '.server_key')
AllowedIPs = 0.0.0.0/0
Endpoint = ${WG_SERVER_IP}:$(echo "$wireguard_json" | jq -r '.server_port')
PersistentKeepalive = 25
" > /etc/wireguard/pia.conf || exit 1
echo OK!