#!/usr/bin/env bash
set -euo pipefail

notify() {
    local message="$1"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Waybar WiFi" "$message"
    else
        printf '%s\n' "$message" >&2
    fi
}

if ! command -v nmcli >/dev/null 2>&1; then
    notify "nmcli no esta disponible."
    exit 1
fi

MENU_BIN=""
MENU_ARGS=()
MENU_PASS_ARG=""

if command -v wofi >/dev/null 2>&1; then
    MENU_BIN="wofi"
    MENU_ARGS=(--dmenu -i)
    MENU_PASS_ARG="--password"
elif command -v rofi >/dev/null 2>&1; then
    MENU_BIN="rofi"
    MENU_ARGS=(-dmenu -i)
    MENU_PASS_ARG="-password"
elif command -v rofi-wayland >/dev/null 2>&1; then
    MENU_BIN="rofi-wayland"
    MENU_ARGS=(-dmenu -i)
    MENU_PASS_ARG="-password"
else
    notify "No se encontro wofi ni rofi-wayland."
    exit 1
fi

menu_select() {
    local prompt="$1"
    shift
    printf '%s\n' "$@" | "$MENU_BIN" "${MENU_ARGS[@]}" -p "$prompt"
}

menu_input() {
    local prompt="$1"
    printf '' | "$MENU_BIN" "${MENU_ARGS[@]}" -p "$prompt"
}

menu_password() {
    local prompt="$1"
    printf '' | "$MENU_BIN" "${MENU_ARGS[@]}" -p "$prompt" "$MENU_PASS_ARG"
}

mapfile -t ifaces < <(nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2=="wifi" {print $1}')

if [[ ${#ifaces[@]} -eq 0 ]]; then
    notify "No hay interfaces WiFi disponibles."
    exit 1
fi

ifname="${ifaces[0]}"
if [[ ${#ifaces[@]} -gt 1 ]]; then
    selection=$(menu_select "Interfaz" "${ifaces[@]}") || exit 0
    if [[ -z "$selection" ]]; then
        exit 0
    fi
    ifname="$selection"
fi

networks_raw=""
if ! networks_raw=$(nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list ifname "$ifname" --rescan auto); then
    notify "nmcli fallo al listar redes."
    exit 1
fi

if [[ -z "$networks_raw" ]]; then
    notify "No se encontraron redes WiFi."
    exit 1
fi

declare -a displays=()
declare -A ssid_by_display=()
declare -A sec_by_display=()

while IFS=: read -r inuse ssid sec signal; do
    if [[ -z "$ssid" ]]; then
        ssid="<hidden>"
    fi
    if [[ -z "$sec" || "$sec" == "--" ]]; then
        sec="OPEN"
    fi
    display="$ssid  [$sec]  ${signal}%"
    if [[ "$inuse" == "*" ]]; then
        display="* $display"
    fi
    displays+=("$display")
    ssid_by_display["$display"]="$ssid"
    sec_by_display["$display"]="$sec"
done <<< "$networks_raw"

selection=$(menu_select "WiFi" "${displays[@]}") || exit 0
if [[ -z "$selection" ]]; then
    exit 0
fi

ssid="${ssid_by_display[$selection]}"
sec="${sec_by_display[$selection]}"

if [[ "$ssid" == "<hidden>" ]]; then
    ssid=$(menu_input "SSID oculto") || exit 0
    if [[ -z "$ssid" ]]; then
        exit 0
    fi
fi

connect_output=""
if [[ "$sec" == "OPEN" ]]; then
    if connect_output=$(nmcli dev wifi connect "$ssid" ifname "$ifname" 2>&1); then
        notify "Conectado a $ssid."
        exit 0
    fi
else
    password=$(menu_password "Contrasena") || exit 0
    if [[ -z "$password" ]]; then
        exit 0
    fi
    if connect_output=$(nmcli dev wifi connect "$ssid" ifname "$ifname" password "$password" 2>&1); then
        notify "Conectado a $ssid."
        exit 0
    fi
fi

notify "No se pudo conectar a $ssid."
printf '%s\n' "$connect_output" >&2
exit 1
