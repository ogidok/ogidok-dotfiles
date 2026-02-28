#!/bin/bash

# Script para mostrar la canción actual (playerctl)
max_len=20
if command -v playerctl >/dev/null; then
    info=$(playerctl metadata --format '{{artist}} - {{title}}')
    if [ -n "$info" ]; then
        if [ ${#info} -gt $max_len ]; then
            trimmed_len=$((max_len - 3))
            info="${info:0:$trimmed_len}..."
        fi
        echo "$info"
    else
        echo "Sin reproducción"
    fi
else
    echo "playerctl no instalado"
fi
