#!/usr/bin/env bash

DATA="$(ip address show eth0 | awk '/inet / { print $2 }' | cut -d'/' -f1)"

echo 'HTTP/1.1 200 OK'
echo 'Content-Type: text/plain'
echo "Content-Length: $(echo -n "$DATA" | wc -c)"
echo ''
echo -n "$DATA"
