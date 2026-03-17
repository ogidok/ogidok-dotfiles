#!/bin/bash

THEMES_DIR="/usr/share/sddm/themes"
CONFIG_DIR="/etc/sddm.conf.d"
CONFIG_FILE="$CONFIG_DIR/theme.conf"

mkdir -p "$CONFIG_DIR"

# Obtener lista limpia
themes=$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n")

# Selector
if command -v rofi >/dev/null 2>&1; then
    theme=$(printf '%s\n' "$themes" | rofi -dmenu -i -p "SDDM Theme")
elif command -v wofi >/dev/null 2>&1; then
    theme=$(printf '%s\n' "$themes" | wofi --dmenu --prompt "SDDM Theme")
elif command -v fzf >/dev/null 2>&1; then
    theme=$(printf '%s\n' "$themes" | fzf --prompt="SDDM Theme > ")
else
    echo "Instala rofi, wofi o fzf"
    exit 1
fi

[ -z "$theme" ] && exit 0

echo "Aplicando tema: $theme"

# Escribir config correcta (forma limpia)
sudo tee "$CONFIG_FILE" >/dev/null <<EOF
[Theme]
Current=$theme
EOF

# Notificación
command -v notify-send >/dev/null && notify-send "SDDM" "Tema: $theme"