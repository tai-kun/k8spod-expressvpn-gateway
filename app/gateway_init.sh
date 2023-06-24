#!/usr/bin/env bash

# shellcheck source=/dev/null
source /app/utils.sh

set -euxo pipefail

sysctl -w net.ipv4.ip_forward=1

if ip addr | grep -q vxlan11298; then
    ip link del vxlan11298
fi

ip link add vxlan11298 type vxlan id 11298 dstport 4789 dev eth0 || true
ip addr add "$APP_GATEWAY_VXLAN_IP/24" dev vxlan11298 || true
ip link set up dev vxlan11298

iptables -t nat -A POSTROUTING -j MASQUERADE
