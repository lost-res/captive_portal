#!/bin/bash

#variables
readonly OutputDevice=/dev/null
readonly WorkspacePath=$(dirname $(readlink -f "$0"))

CaptivePortalGatewayAddress="192.169.254.1"
CaptivePortalGatewayNetwork=${CaptivePortalGatewayAddress%.*}

CaptivePortalAccessInterface=wlan0
APServiceSSID="My_Portal"
APServiceChannel=5
APKey=""

while [ -n "$1" ]; do
    case "$1" in
    -i) CaptivePortalAccessInterface="$2"
        shift;;
    -p) APKey="$2"
        shift;;
    -s) APServiceSSID="$2"
        shift;;
    -c)  APServiceChannel="$2"
        shift;;
    *)  echo "Option $1 not recognised"
        shift;;

    esac
    shift

done

#more variables
APServiceInterface=$CaptivePortalAccessInterface


#exit Function
function cleanup(){
    kill $APServicePID
    echo "Killed AP"
    kill $CaptivePortalDHCPServiceXtermPID
    echo "Killed DHCP"
    kill $CaptivePortalDNSServiceXtermPID
    echo "Killed DNS"
    kill $CaptivePortalWebServiceXtermPID
    echo "Killed Web logger"
    killall lighttpd
    echo "Killed lighttpd"
    #start network-manager and systemd-resolve
    systemctl start NetworkManager
    systemctl start systemd-resolved.service
    systemctl start apache2
    echo "Services Restored"
    #del ip addr
    ip addr del $CaptivePortalGatewayAddress/24 dev $CaptivePortalAccessInterface 2>/dev/null
    sleep 0.5
    ip link set $CaptivePortalAccessInterface up
    echo "IP Addr Deleted"
    
}
trap cleanup EXIT




#hold parameter
XtermHold=""

#stop services
systemctl stop NetworkManager
systemctl stop systemd-resolved.service
systemctl stop named.service
systemctl stop apache2
ip link set $CaptivePortalAccessInterface down

#create an empty leases file
touch "$WorkspacePath/dhcpd.leases"

# Generate configuration for a lighttpd web-server.
echo "\
server.document-root = \"$WorkspacePath/webpage/\"

server.modules = (
    \"mod_access\",
    \"mod_alias\",
    \"mod_accesslog\",
    \"mod_fastcgi\",
    \"mod_redirect\",
    \"mod_rewrite\"
)

accesslog.filename = \"$WorkspacePath/lighttpd.log\"

fastcgi.server = (
    \".php\" => (
        (
            \"bin-path\" => \"/usr/bin/php-cgi\",
            \"socket\" => \"$WorkspacePath/php.socket\"
        )
    )
)

server.port = 80
server.pid-file = \"/var/run/lighttpd.pid\"
# server.username = \"www\"
# server.groupname = \"www\"

mimetype.assign = (
    \".html\" => \"text/html\",
    \".htm\" => \"text/html\",
    \".txt\" => \"text/plain\",
    \".jpg\" => \"image/jpeg\",
    \".png\" => \"image/png\",
    \".css\" => \"text/css\"
)


server.error-handler-404 = \"/\"

static-file.exclude-extensions = (
    \".fcgi\",
    \".php\",
    \".rb\",
    \"~\",
    \".inc\"
)

index-file.names = (
    \"index.htm\",
    \"index.html\",
    \"index.php\"
)
" >"$WorkspacePath/lighttpd.conf"

echo "\
# Redirect all traffic to the captive portal when not emulating a connection.
\$HTTP[\"host\"] != \"captive.gateway.lan\" {
    url.redirect-code = 307
    url.redirect  = (
        \"^/(.*)\" => \"http://captive.gateway.lan/\",
    )
}
" >>"$WorkspacePath/lighttpd.conf"


# Generate the dhcpd configuration file, which is
# used to provide DHCP service to rogue AP clients.
echo "\
{
\"Dhcp4\": {
    \"valid-lifetime\": 4000,
    \"renew-timer\": 1000,
    \"rebind-timer\": 2000,
    \"interfaces-config\": {
        \"interfaces\": [ \"$CaptivePortalAccessInterface\" ]
    },
    \"option-data\": [
      {
        \"name\": \"domain-name-servers\",
        \"data\": \"$CaptivePortalGatewayNetwork.1\",
        \"always-send\": true
      }
    ],
    \"lease-database\": {
        \"type\": \"memfile\",
        \"persist\": true,
        \"name\": \"$WorkspacePath/dhcpd.leases\"
    },
 // Finally, we list the subnets from which we will be leasing addresses.
    \"subnet4\": [
        {
            \"subnet\": \"$CaptivePortalGatewayNetwork.0/24\",
            \"pools\": [
                {
                     \"pool\": \"$CaptivePortalGatewayNetwork.100 - $CaptivePortalGatewayNetwork.254\"
                }
            
            ]
        }
    ]
}
}\
" >"$WorkspacePath/dhcpd.conf"

echo "Interface -- $APServiceInterface"
echo "SSID -- $APServiceSSID"
echo "WPA-PSK -- $APKey"
echo "Channel -- $APServiceChannel"

# Prepare the hostapd config file.
if [ -z "$APKey" ]
then
    echo "\
interface=$APServiceInterface
driver=nl80211
ssid=$APServiceSSID
channel=$APServiceChannel" \
  > "$WorkspacePath/hostapd.conf"

else
    echo "\
interface=$APServiceInterface
driver=nl80211
ssid=$APServiceSSID
channel=$APServiceChannel
auth_algs=1
wpa=1
wpa_passphrase=$APKey
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP" \
  > "$WorkspacePath/hostapd.conf"

fi


xterm $XtermHold -bg "#000000" -fg "#FFFFFF" \
    -title "AP Service [hostapd]" -e \
    hostapd "$WorkspacePath/hostapd.conf" &
 parentPID=$!

  # Wait till hostapd has started and its virtual interface is ready.
  while [ ! "$APServicePID" ]; do
    sleep 1
    APServicePID=$(pgrep -P $parentPID)
  done
echo "Hostapd:  $APServicePID"
sleep 1

# Give an address to the gateway interface in the rogue network.
# This makes the interface accessible from the rogue network.
ip addr add $CaptivePortalGatewayAddress/24 dev $CaptivePortalAccessInterface

#create an empty leases file
touch "$WorkspacePath/dhcpd.leases"
touch "$WorkspacePath/clients.txt"

xterm $XtermHold -bg black -fg "#CCCC00" \
    -title "AP DHCP Service" -e \
    "kea-dhcp4 -c "$WorkspacePath/dhcpd.conf" 2>&1 | tee -a \"$WorkspacePath/clients.txt\"" &
# Save parent's pid, to get to child later.
CaptivePortalDHCPServiceXtermPID=$!
echo "DHCP Service: $CaptivePortalDHCPServiceXtermPID" 
    

xterm $XtermHold -bg black -fg "#99CCFF" \
    -title "AP DNS Service" -e \
    "$WorkspacePath/fakedns.py $CaptivePortalGatewayAddress " &
  # Save parent's pid, to get to child later.
  CaptivePortalDNSServiceXtermPID=$!
echo "DNS Service: $CaptivePortalDNSServiceXtermPID" 
    
lighttpd -f "$WorkspacePath/lighttpd.conf" \
    &> $OutputDevice
  CaptivePortalWebServicePID=$!

echo "Web Server: $CaptivePortalWebServicePID"

xterm $XtermHold -bg black -fg "#00CC00" \
    -title "Web Server Logs" -e \
    "tail -f \"$WorkspacePath/lighttpd.log\"" &
  CaptivePortalWebServiceXtermPID=$!
echo "Web Server Log: $CaptivePortalWebServiceXtermPID" 

while true; do sleep 2; done

