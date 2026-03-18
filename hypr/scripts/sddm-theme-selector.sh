#!/bin/bash

THEMES_DIR="/usr/share/sddm/themes"
CONFIG_FILE="/etc/sddm.conf"

if [ ! -d "$THEMES_DIR" ]; then
    echo "No existe: $THEMES_DIR"
    exit 1
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

# Actualizar /etc/sddm.conf sin romper otras secciones
if [ ! -f "$CONFIG_FILE" ]; then
    sudo tee "$CONFIG_FILE" >/dev/null <<EOF
[Theme]
Current=$theme
EOF
elif sudo grep -q '^\[Theme\]' "$CONFIG_FILE"; then
    if sudo sed -n '/^\[Theme\]/,/^\[/{/^Current=/p}' "$CONFIG_FILE" | grep -q '^Current='; then
        sudo sed -i "/^\[Theme\]/,/^\[/{s/^Current=.*/Current=$theme/}" "$CONFIG_FILE"
    else
        sudo awk -v selected_theme="$theme" '
            BEGIN { inserted=0 }
            /^\[Theme\]$/ {
                print
                print "Current=" selected_theme
                inserted=1
                next
            }
            { print }
            END {
                if (!inserted) {
                    print ""
                    print "[Theme]"
                    print "Current=" selected_theme
                }
            }
        ' "$CONFIG_FILE" | sudo tee "$CONFIG_FILE" >/dev/null
    fi
else
    sudo tee -a "$CONFIG_FILE" >/dev/null <<EOF

[Theme]
Current=$theme
EOF
fi

# Notificación
command -v notify-send >/dev/null && notify-send "SDDM" "Tema: $theme"