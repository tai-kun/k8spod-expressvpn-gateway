#!/usr/bin/env bash

set -euo pipefail

export APP_LOG_LV="${APP_LOG_LV:-info}"
export APP_LOG_DIR="${APP_LOG_DIR:-/var/log}"
export APP_LOG_FILE_PREFIX="${APP_LOG_FILE_PREFIX:-app}"
export APP_VXLAN_IP_NETWORK="${APP_VXLAN_IP_NETWORK:-172.29.0}"
export APP_GATEWAY_VXLAN_IP="${APP_VXLAN_IP_NETWORK}.1"
export APP_LOCAL_CIDRS="${APP_LOCAL_CIDRS:-192.168.0.0/16 10.0.0.0/8}"
export APP_RECONNECT_INTERVAL="${APP_RECONNECT_INTERVAL:-10}" # 10 seconds

function _to_log_level_num() {
    case "$1" in
        'error') echo 40;;
        'warn')  echo 30;;
        'info')  echo 20;;
        'debug') echo 10;;
        *)       echo  0;;
    esac
}

APP_LOG_LV="${APP_LOG_LV,,}"
APP_LOG_LV_NUM=$(_to_log_level_num "$APP_LOG_LV")
APP_LOG_FILE_DATETIME="$(date -u '+%Y%m%d')"

if [[ "$APP_LOG_LV_NUM" -le 10 ]]; then
    APP_DEBUG=true
else
    APP_DEBUG=false
fi

function _get_log_file() {
    local DATETIME

    DATETIME="$(date -u '+%Y%m%d')"
    DATETIME="$(( DATETIME - 7 ))"

    if [[ "$DATETIME" -ge "$APP_LOG_FILE_DATETIME" ]]; then
        APP_LOG_FILE_DATETIME="$DATETIME"
    fi

    echo "${APP_LOG_DIR}/${APP_LOG_FILE_PREFIX}_${APP_LOG_FILE_DATETIME}.log"
}

function log() {
    local TIMESTAMP
    local RAW_LABEL
    local LOG_FILE

    LOG_FILE="$(_get_log_file)"

    if [[ "$#" -lt 2 ]]; then
        echo "$1" >> "$LOG_FILE" || true

        return 0
    fi

    if [[ $(_to_log_level_num "${1,,}") -lt "$APP_LOG_LV_NUM" ]]; then
        return 0
    fi

    TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%S')Z"
    RAW_LABEL="$TIMESTAMP $(printf '%-5s\n' "${1^^}")"

    shift

    echo "$RAW_LABEL $*" >> "$LOG_FILE" || true
}

IPV4_REGEX='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'

function is_ipv4() {
    [[ "$1" =~ $IPV4_REGEX ]]
}

function is_cidr() {
    local IP
    local MASK

    IFS='/' read -r IP MASK <<< "$1"

    if ! is_ipv4 "$IP"; then
        return 1
    fi

    if  ! [[ "$MASK" == 0 || "$MASK" =~ ^[1-9][0-9]*$ ]]; then
        return 1
    fi

    [[ "$MASK" -ge 0 && "$MASK" -le 32 ]]
}

function is_uint32() {
    if ! [[ "$1" == 0 || "$1" =~ ^[1-9][0-9]*$ ]]; then
        return 1
    fi

    [[ "$1" -ge 0 && "$1" -le 4294967295 ]]
}

function assert_ipv4() {
    if ! is_ipv4 "$1"; then
        log error "Invalid IPv4 address: $1"
        exit 1
    fi
}

function assert_cidrs() {
    local cidr

    for cidr in $1; do
        if ! is_cidr "$cidr"; then
            log error "Invalid CIDR: $cidr"
            exit 1
        fi
    done
}

function assert_uint32() {
    if ! is_uint32 "$1"; then
        log error "Invalid uint32 value: $1"
        exit 1
    fi
}

assert_ipv4 "$APP_GATEWAY_VXLAN_IP"
assert_cidrs "$APP_LOCAL_CIDRS"
assert_uint32 "$APP_RECONNECT_INTERVAL"

if [[ "$APP_DEBUG" = true ]]; then
    set -x
fi

mkdir -p /var/run/app
