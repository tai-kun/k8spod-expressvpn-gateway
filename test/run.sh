#!/usr/bin/env bash

set -eu

APP_TAG='ghcr.io/tai-kun/k8spod-expressvpn-gateway:dev' # latest を使わないか、imagePullPolicy: Never にする
CLUSTER_NAME="${CLUSTER_NAME:-test}"
KIND_VERSION="${KIND_VERSION:-0.20.0}"
KUBE_VERSION="${KUBE_VERSION:-1.27.3}"
EXPRESSVPN_CODE="${1:-}"

if [[ "$EXPRESSVPN_CODE" == '' ]]; then
    echo "Usage: $0 <expressvpn_code>"
    exit 1
fi

docker buildx build --tag "$APP_TAG" .

function download() {
    local DST
    local SRC
    DST="$1"
    SRC="$2"

    mkdir -p "$(dirname "$DST")"

    echo "Downloading $SRC to $DST"

    if ! curl -f -sS -Lo "$DST" "$SRC"; then
        return 1
    fi

    echo 'Done'
}

function download_once() {
    local DST
    local SRC
    DST="$1"
    SRC="$2"

    if [[ ! -f "$DST" ]]; then
        download "$DST" "$SRC"
    fi
}

KIND=".cache/bin/kind-v$KIND_VERSION"
KUBECTL=".cache/bin/kubectl-v$KUBE_VERSION"
KUBECONFIG=".cache/kube/config-v$KUBE_VERSION"

export KUBECONFIG="$PWD/$KUBECONFIG"

download_once "$KIND" "https://kind.sigs.k8s.io/dl/v$KIND_VERSION/kind-linux-amd64"
download_once "$KUBECTL" "https://dl.k8s.io/release/v$KUBE_VERSION/bin/linux/amd64/kubectl"

chmod +x "$KIND"
chmod +x "$KUBECTL"

mkdir -p "$(dirname "$KUBECONFIG")"
touch "$KUBECONFIG"

function _kill() {
    echo

    "$KIND" delete cluster --name "$CLUSTER_NAME"
}

trap _kill ERR
trap _kill SIGINT

"$KIND" create cluster --name "$CLUSTER_NAME" --config <(cat <<EOF
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
    - role: control-plane
      image: kindest/node:v$KUBE_VERSION
    - role: worker
      image: kindest/node:v$KUBE_VERSION
EOF
)

"$KIND" load docker-image --name "$CLUSTER_NAME" "$APP_TAG"

"$KUBECTL" create namespace expressvpn
"$KUBECTL" create secret generic expressvpn --type=Opaque --from-literal=CODE="$EXPRESSVPN_CODE" -n expressvpn
"$KUBECTL" apply -f "test/gateway.yaml"

echo 'Waiting for gateway to be ready'

while [[ "$("$KUBECTL" get pods -l app=gateway -o jsonpath='{.items[0].status.phase}' -n expressvpn)" != 'Running' ]]; do
    printf '.'
    sleep 1
done

echo
sleep 3

"$KUBECTL" apply -f "test/client.yaml"

echo 'Waiting for client to be ready'

while [[ "$("$KUBECTL" get pods -l app=client -o jsonpath='{.items[0].status.phase}')" != 'Running' ]]; do
    printf '.'
    sleep 1
done

echo
sleep 3

echo
"$KUBECTL" get pods -o wide -n expressvpn

echo
"$KUBECTL" get pods -o wide

echo
echo "----------------------------- client logs -----------------------------"
echo
"$KUBECTL" exec -it client --container gateway-sidecar -- bash -c 'cat /var/log/*.log'

GATEWAY_POD_NAME="$("$KUBECTL" get pods -l app=gateway -o jsonpath='{.items[0].metadata.name}' -n expressvpn)"

echo
echo "----------------------------- $GATEWAY_POD_NAME logs -----------------------------"
echo
"$KUBECTL" exec -it "$GATEWAY_POD_NAME" -n expressvpn --container gateway-sidecar -- bash -c 'cat /var/log/*.log'

HOST_GLOBAL_IP="$(curl -fs ifconfig.me/ip)"
POD_GLOBAL_IP="$("$KUBECTL" exec client --container client-app -- curl -s ifconfig.me/ip)"

if [[ "$HOST_GLOBAL_IP" != "$POD_GLOBAL_IP" ]]; then
    echo
    echo 'Success (^^)'
else
    echo
    echo 'Failed (><)'
fi

echo "Global Host IP: $HOST_GLOBAL_IP"
echo "Global Pod IP:  $POD_GLOBAL_IP"
echo
echo 'Press Ctrl+C to stop'

sleep infinity
