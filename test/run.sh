#!/usr/bin/env bash

set -eu

APP_TAG='ghcr.io/tai-kun/k8spod-expressvpn-gateway:dev' # latest を使わないか、imagePullPolicy: Never にする
CLUSTER_NAME="${CLUSTER_NAME:-test}"
KIND_VERSION="${KIND_VERSION:-0.17.0}"
KUBECTL_VERSION="${KUBECTL_VERSION:-1.26.0}"
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

KIND='.cache/bin/kind'
KUBECTL='.cache/bin/kubectl'

export PATH="$PWD/.cache/bin:$PATH"

download_once "$KIND" "https://kind.sigs.k8s.io/dl/v$KIND_VERSION/kind-linux-amd64"
download_once "$KUBECTL" "https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl"

chmod +x "$KIND"
chmod +x "$KUBECTL"

function _kill() {
    echo

    kind delete cluster --name "$CLUSTER_NAME"
}

trap _kill ERR
trap _kill SIGINT

kind create cluster --name "$CLUSTER_NAME" --config <(cat <<EOF
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
    - role: control-plane
    - role: worker
EOF
)

kind load docker-image --name "$CLUSTER_NAME" "$APP_TAG"

kubectl create namespace expressvpn
kubectl create secret generic expressvpn --type=Opaque --from-literal=CODE="$EXPRESSVPN_CODE" -n expressvpn
kubectl apply -f "test/gateway.yaml"

echo 'Waiting for gateway to be ready'

while [[ "$(kubectl get pods -l app=gateway -o jsonpath='{.items[0].status.phase}' -n expressvpn)" != 'Running' ]]; do
    printf '.'
    sleep 1
done

echo
sleep 3

kubectl apply -f "test/client.yaml"

echo 'Waiting for client to be ready'

while [[ "$(kubectl get pods -l app=client -o jsonpath='{.items[0].status.phase}')" != 'Running' ]]; do
    printf '.'
    sleep 1
done

echo
sleep 3

echo
kubectl get pods -o wide -n expressvpn

echo
kubectl get pods -o wide

echo
echo "----------------------------- client logs -----------------------------"
echo
kubectl exec -it client --container gateway-sidecar -- bash -c 'cat /var/log/*.log'

GATEWAY_POD_NAME="$(kubectl get pods -l app=gateway -o jsonpath='{.items[0].metadata.name}' -n expressvpn)"

echo
echo "----------------------------- $GATEWAY_POD_NAME logs -----------------------------"
echo
kubectl exec -it "$GATEWAY_POD_NAME" -n expressvpn --container gateway-sidecar -- bash -c 'cat /var/log/*.log'

HOST_GLOBAL_IP="$(curl -fs ifconfig.me/ip)"
POD_GLOBAL_IP="$(kubectl exec client --container client-app -- curl -s ifconfig.me/ip)"

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
