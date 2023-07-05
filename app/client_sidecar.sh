#!/usr/bin/env bash

# shellcheck source=/dev/null
source /app/utils.sh

log info "Starting sidecar"

if [[ -f /var/run/app/gw-svc ]]; then
    log info "Pod gateway service: $(cat /var/run/app/gw-svc)"
else
    log info "Pod gateway service: $1"
fi

{
    while true; do
        sleep "$APP_RECONNECT_INTERVAL"

        if ping -c 1 "$APP_GATEWAY_VXLAN_IP"; then
            continue
        fi

        ip route del default || true

        log warn 'Blocked all outbound traffic.'

        if [[ -f /var/run/app/gw-svc ]]; then
            POD_GATEWAY_SERVICE="$(cat /var/run/app/gw-svc)"
        else
            POD_GATEWAY_SERVICE="$1"
        fi

        log info "Reconnecting to http://$POD_GATEWAY_SERVICE"

        /app/client_init.sh || true
    done
} &
sidecar=$!

log info "Sidecar started with PID: $sidecar"

_kill_procs() {
    log info "Signal received -> killing processes"

    kill -TERM $sidecar || true
    wait $sidecar
    rc=$?

    rc=$(( $rc || $? ))
    log info "Terminated with RC: $rc"
    exit $rc
}

trap _kill_procs SIGTERM

log info "Waiting for sidecar to terminate"

wait -n

log info "TERMINATING"

_kill_procs
