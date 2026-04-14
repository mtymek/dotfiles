#!/bin/bash
set -e

SOCKET_DIR="$HOME/.ssh/sockets"

if [ ! -d "$SOCKET_DIR" ]; then
    mkdir -p "$SOCKET_DIR"
    chmod 700 "$SOCKET_DIR"
    echo "Created $SOCKET_DIR"
else
    echo "$SOCKET_DIR already exists"
fi
