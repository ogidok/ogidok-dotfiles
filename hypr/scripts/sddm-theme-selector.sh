#!/bin/bash

THEMES_DIR="/usr/share/sddm/themes"
CONFIG_DIR="/etc/sddm.conf.d"
CONFIG_FILE="$CONFIG_DIR/theme.conf"

install_packages() {
    if [ $# -eq 0 ]; then
        return 0
    fi

    sudo pacman -S --needed --noconfirm "$@" || return 1
}

install_aur_packages() {
    if [ $# -eq 0 ]; then
        return 0
    fi

    if command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm "$@" || return 1
    else
        echo "Falta yay para instalar paquetes AUR: $*"
        return 1
    fi
}

install_theme_dependencies() {
    local selected="$1"

    case "$selected" in
        makima)
            install_packages sddm noto-fonts-cjk qt5-graphicaleffects qt5-quickcontrols2 || return 1
            install_aur_packages otf-ipafont || return 1
            ;;
        silent)
            install_packages sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg || return 1
            ;;
        pixie)
            install_packages sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt5-graphicaleffects qt5-quickcontrols2 || return 1
            ;;
        *)
            install_packages sddm || return 1
            ;;
    esac
}

install_all_dependencies() {
    local d t
    for d in "$THEMES_DIR"/*; do
        [ -d "$d" ] || continue
        t=$(basename "$d")
        echo "Instalando dependencias para: $t"
        install_theme_dependencies "$t" || return 1
    done
}

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

if [ "$1" = "--install-all-deps" ]; then
    install_all_dependencies || exit 1
    echo "Dependencias de themes instaladas"
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

install_theme_dependencies "$theme" || exit 1

echo "Aplicando tema: $theme"

# Escribir config correcta (forma limpia)
sudo tee "$CONFIG_FILE" >/dev/null <<EOF
[Theme]
Current=$theme
EOF

# Notificación
command -v notify-send >/dev/null && notify-send "SDDM" "Tema: $theme"