#!/usr/bin/env bash

set -euxo pipefail

# shellcheck source=/dev/null
source /app/utils.sh

cp /etc/resolv.conf /etc/resolv.conf.org
log debug '/etc/resolv.conf.org written'

exit 0
