#!/usr/bin/env bash

# shellcheck source=/dev/null
source /app/utils.sh

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

_kill_procs() {
    echo "Signal received -> killing processes"

    kill -TERM $sidecar || true
    wait $sidecar
    rc=$?

    rc=$(( $rc || $? ))
    echo "Terminated with RC: $rc"
    exit $rc
}

trap _kill_procs SIGTERM

wait -n

echo "TERMINATING"

_kill_procs
