#!/usr/bin/env bash

# shellcheck source=/dev/null
source /app/utils.sh

log info "Starting init"

POD_GATEWAY_SERVICE="$1"
POD_GATEWAY_IP="$(curl -fs "http://$POD_GATEWAY_SERVICE")"

assert_ipv4 "$POD_GATEWAY_IP"

echo -n "$POD_GATEWAY_SERVICE" > /var/run/app/gw-svc

log info "Pod gateway service: $POD_GATEWAY_SERVICE"
log info "Pod gateway IP: $POD_GATEWAY_IP"

ip addr
ip route

if ip addr | grep -q vxlan11298; then
    ip link del vxlan11298
    K8S_GATEWAY_IP=''
else
    K8S_GATEWAY_IP="$(ip route | awk '/default/ { print $3 }')"
fi

ip route del 0/0 || true

if is_ipv4 "$K8S_GATEWAY_IP"; then
    log info "K8s gateway IP: $K8S_GATEWAY_IP"

    ip route add "$POD_GATEWAY_IP" via "$K8S_GATEWAY_IP" || true

    for local_cidr in $APP_LOCAL_CIDRS; do
        ip route add "$local_cidr" via "$K8S_GATEWAY_IP" || true
    done
fi

if ping -c 1 8.8.8.8; then
    log error 'Should not be able to ping'
    exit 1
fi

ip addr
ip route

ip link add vxlan11298 type vxlan id 11298 remote "$POD_GATEWAY_IP" dstport 4789 dev eth0 || true
ip link set up dev vxlan11298

cat << EOF > /etc/dhclient.conf
backoff-cutoff 2;
initial-interval 1;
reboot 0;
retry 10;
select-timeout 0;
timeout 30;

interface "vxlan11298"
 {
  request subnet-mask,
          broadcast-address,
          routers;
          #domain-name-servers;
  require routers,
          subnet-mask;
          #domain-name-servers;
 }
EOF

dhclient -v -cf /etc/dhclient.conf vxlan11298

log info "VXLAN IP: $(ip addr show vxlan11298 | awk '/inet / { print $2 }')"

ip addr
ip route

log info "IP addresses:
$(ip addr)"
log info "IP routes:
$(ip route)"

ping -c 1 "$APP_GATEWAY_VXLAN_IP"
ping -c 1 8.8.8.8

log info "Init done"
