#!/usr/bin/env sh

TARGET_FILE="$HOME/.config/waybar/target.txt"
GREEN="#a6e3a1"
RED="#f38ba8"

if [ ! -f "$TARGET_FILE" ]; then
    printf '<span color="%s">none</span>\n' "$RED"
    exit 0
fi

value="$(tr -d '\r' < "$TARGET_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ -z "$value" ] || [ "$value" = "none" ]; then
    printf '<span color="%s">none</span>\n' "$RED"
else
    printf '<span color="%s">%s</span>\n' "$GREEN" "$value"
fi
