#!/bin/bash

THEMES_DIR="/usr/share/sddm/themes"
CONFIG_DIR="/etc/sddm.conf.d"
CONFIG_FILE="$CONFIG_DIR/theme.conf"

if [ ! -d "$THEMES_DIR" ]; then
    echo "No existe: $THEMES_DIR"
    exit 1
fi

if [ ! -d "$CONFIG_DIR" ]; then
    sudo mkdir -p "$CONFIG_DIR" || exit 1
fi

# Obtener lista limpia
themes=$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)

if [ "$1" = "--list" ]; then
    printf '%s\n' "$themes"
    exit 0
fi

if [ -n "$1" ]; then
    theme=$(basename "$1")
else
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
fi

[ -z "$theme" ] && exit 0

if [ ! -d "$THEMES_DIR/$theme" ]; then
    echo "Tema no valido: $theme"
    exit 1
fi

echo "Aplicando tema: $theme"

# Escribir config correcta (forma limpia)
sudo tee "$CONFIG_FILE" >/dev/null <<EOF
[Theme]
Current=$theme
EOF

# Notificación
command -v notify-send >/dev/null && notify-send "SDDM" "Tema: $theme"