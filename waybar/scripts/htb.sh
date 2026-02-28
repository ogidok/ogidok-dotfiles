#!/bin/sh
# Script para mostrar el estado de Hack The Box (HTB)

if ! command -v ip >/dev/null 2>&1; then
    echo "Offline"
    exit 0
fi

if ! ip link show dev tun0 >/dev/null 2>&1; then
    echo "Offline"
    exit 0
fi

if ! ip link show dev tun0 | grep -q "UP"; then
    echo "Offline"
    exit 0
fi

echo "Online"
