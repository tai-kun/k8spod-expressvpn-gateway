#!/usr/bin/env bash

# shellcheck source=/dev/null
source /app/utils.sh

log info "Starting sidecar"

/app/copy_resolv.sh

K8S_DNS="$(grep nameserver /etc/resolv.conf.org | cut -d' ' -f2)"

assert_ipv4 "$K8S_DNS"

log info "K8s DNS: $K8S_DNS"

_APP_VXLAN_GATEWAY_FIRST_DYNAMIC_IP='20'

cat << EOF > /etc/dnsmasq.d/pod-gateway.conf
interface=vxlan11298
bind-interfaces
dhcp-range=${APP_VXLAN_IP_NETWORK}.${_APP_VXLAN_GATEWAY_FIRST_DYNAMIC_IP},${APP_VXLAN_IP_NETWORK}.255,12h
log-queries
log-dhcp
log-facility=-
clear-on-reload
resolv-file=/etc/resolv.conf.org
server=/local/${K8S_DNS}
EOF

dnsmasq -k &
dnsmasq=$!

log info "dnsmasq started with PID: $dnsmasq"

inotifyd /app/copy_resolv.sh /etc/resolv.conf:ce &
inotifyd=$!

log info "inotifyd started with PID: $inotifyd"

socat TCP-LISTEN:11298,fork,reuseaddr SYSTEM:/app/server.sh &
socat=$!

log info "socat started with PID: $socat"

_kill_procs() {
    log info "Signal received -> killing processes"

    kill -TERM $dnsmasq || true
    wait $dnsmasq
    rc=$?

    kill -TERM $inotifyd || true
    wait $inotifyd

    kill -TERM $socat || true
    wait $socat

    rc=$(( $rc || $? ))
    log info "Terminated with RC: $rc"
    exit $rc
}

trap _kill_procs SIGTERM

log info "Waiting for sidecar to terminate"

wait -n

log info "TERMINATING"

_kill_procs
