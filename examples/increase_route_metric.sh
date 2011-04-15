#!/bin/sh

# Increase the metric of the route to the subnet an interface is on.
# This is another approach to solving 
# https://bugzilla.redhat.com/show_bug.cgi?id=498472
# One use case it at
# http://serverfault.com/questions/254773/specifying-a-preferred-route-when-there-are-multiple-links-to-same-network

# set PREFIX
eval `/bin/ipcalc -p $IPADDR $NETMASK`

#set NETWORK
eval `/bin/ipcalc -n $IPADDR $NETMASK`

/sbin/ip route delete to "$NETWORK/$PREFIX" dev "$DEVICE"

/sbin/ip route add to "$NETWORK/$PREFIX" dev "$DEVICE" src $IPADDR metric 1
