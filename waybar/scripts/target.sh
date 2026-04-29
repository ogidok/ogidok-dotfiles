#!/usr/bin/env sh

TARGET_FILE="$HOME/.config/waybar/target.txt"

if [ ! -f "$TARGET_FILE" ]; then
    printf 'none\n'
    exit 0
fi

value="$(tr -d '\r' < "$TARGET_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ -z "$value" ]; then
    printf 'none\n'
else
    printf '%s\n' "$value"
fi
