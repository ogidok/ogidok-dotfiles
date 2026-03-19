#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
layout_file="$config_home/snmenu/layout"
style_file="$config_home/snmenu/style.css"
snmenu_bin=""

if command -v snmenu >/dev/null 2>&1; then
    snmenu_bin="$(command -v snmenu)"
elif [[ -x "$HOME/.cargo/bin/snmenu" ]]; then
    snmenu_bin="$HOME/.cargo/bin/snmenu"
fi

# Primary path: use SNMenu when available.
if [[ -n "$snmenu_bin" ]]; then
    exec "$snmenu_bin" -l "$layout_file" -C "$style_file"
fi

# Fallback path if SNMenu is not installed yet.
if command -v rofi >/dev/null 2>&1; then
    lock_cmd="hyprlock"
    if ! command -v hyprlock >/dev/null 2>&1; then
        lock_cmd="swaylock"
    fi

    chosen=$(printf '%s\n' "Bloquear pantalla" "Suspender" "Reiniciar" "Apagar" "Cerrar sesion" | rofi -dmenu -p "Power")

    case "$chosen" in
        "Bloquear pantalla")
            "$lock_cmd"
            ;;
        "Suspender")
            systemctl suspend
            ;;
        "Reiniciar")
            systemctl reboot
            ;;
        "Apagar")
            systemctl poweroff
            ;;
        "Cerrar sesion")
            hyprctl dispatch exit
            ;;
        *)
            :
            ;;
    esac
    exit 0
fi

if command -v wlogout >/dev/null 2>&1; then
    exec wlogout
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send "Power menu" "Instala snmenu (AUR) o rofi para usar el menu de energia"
fi
