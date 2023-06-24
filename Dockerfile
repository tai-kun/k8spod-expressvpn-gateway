FROM alpine:3.18.2

# iproute2 : ip コマンド (BusyBox の ip コマンドではうまく行かない)
RUN apk add --no-cache \
    bash \
    curl \
    socat \
    dnsmasq-dnssec \
    dhclient \
    inotify-tools \
    iproute2 \
    iptables
COPY ./app/ /app/
RUN chmod +x /app/*.sh
ENTRYPOINT ["/app/entrypoint.sh"]
