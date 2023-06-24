#!/usr/bin/env bash

set -eu

# shellcheck source=/dev/null
source /app/utils.sh

ARG_1="${1:-}"
ARG_2="${2:-}"

case "$ARG_1" in
    client)
        case "$ARG_2" in
            init)
                /app/client_init.sh "${@:3}"
            ;;

            sidecar)
                /app/client_sidecar.sh "${@:3}"
            ;;

            *)
                log error "Invalid argument: $ARG_2"
                exit 1
            ;;
        esac
    ;;

    gateway)
        case "$ARG_2" in
            init)
                /app/gateway_init.sh "${@:3}"
            ;;

            sidecar)
                /app/gateway_sidecar.sh "${@:3}"
            ;;

            *)
                log error "Invalid argument: $ARG_2"
                exit 1
            ;;
        esac
    ;;

    *)
        log error "Invalid argument: $ARG_1"
        exit 1
    ;;
esac
