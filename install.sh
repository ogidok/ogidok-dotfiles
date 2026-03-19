#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# El repo se asume como el directorio padre del script (ajusta si cambias la estructura).
repo_root="$(cd -- "$script_dir/.." && pwd)"
config_root="$HOME/.config"

dry_run=false
install_packages=true
install_configs=true
use_aur=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --packages-only) install_configs=false ;;
        --config-only) install_packages=false ;;
        --no-aur) use_aur=false ;;
        --dry-run) dry_run=true ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
    shift
done

run_cmd() {
    if [[ "$dry_run" == "true" ]]; then
        echo "DRY: $*"
    else
        "$@"
    fi
}

sed_escape() {
    printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

print_packages() {
    # Muestra el plan de instalacion antes de ejecutar comandos reales.
    printf '%s\n' "Paquetes a instalar (pacman):"
    printf ' - %s\n' "${pacman_pkgs[@]}"
    if [[ "$use_aur" == "true" && ${#aur_pkgs[@]} -gt 0 ]]; then
        printf '%s\n' "Paquetes AUR:"
        printf ' - %s\n' "${aur_pkgs[@]}"
    fi
}

get_xdg_dir() {
    local key="$1"
    # Usa XDG si esta disponible; si no, se resuelve despues con un fallback.
    if command -v xdg-user-dir >/dev/null 2>&1; then
        xdg-user-dir "$key" 2>/dev/null || true
    else
        printf '%s' ""
    fi
}

update_flameshot_path() {
    local file="$1"
    local screenshots_dir="$2"
    local value_escaped

    # Flameshot no interpreta $HOME en savePath, por eso usamos ruta absoluta.
    run_cmd mkdir -p "$screenshots_dir"
    value_escaped="$(sed_escape "$screenshots_dir")"

    if grep -q '^savePath=' "$file"; then
        run_cmd sed -i "s|^savePath=.*|savePath=${value_escaped}|" "$file"
    else
        printf '\nsavePath=%s\n' "$screenshots_dir" >>"$file"
    fi
}

update_waypaper_paths() {
    local file="$1"
    local wallpapers_dir="$2"
    local home_dir="$3"
    local wallpapers_escaped
    local home_escaped

    run_cmd mkdir -p "$wallpapers_dir"
    wallpapers_escaped="$(sed_escape "$wallpapers_dir")"
    home_escaped="$(sed_escape "$home_dir")"

    # Normaliza rutas a ubicaciones del usuario actual.
    run_cmd sed -i "s|^folder\s*=.*|folder = ${wallpapers_escaped}|" "$file"
    run_cmd sed -i "s|^wallpaper\s*=.*|wallpaper = ${wallpapers_escaped}/teclas.jpg|" "$file"
    run_cmd sed -i "s|^stylesheet\s*=.*|stylesheet = ${home_escaped}/.config/waypaper/style.css|" "$file"
}

replace_home_paths() {
    local file="$1"
    local home_dir="$2"
    local home_escaped

    # Sustituye rutas del repo por rutas reales del usuario.
    home_escaped="$(sed_escape "$home_dir")"
    run_cmd sed -i "s|/home/daigo|${home_escaped}|g" "$file"
    run_cmd sed -i "s|\$HOME|${home_escaped}|g" "$file"
}

normalize_paths_in_targets() {
    local home_dir="$1"
    shift
    local targets=("$@")
    local target
    local file

    # Recorre archivos copiados y normaliza rutas dentro del contenido.
    for target in "${targets[@]}"; do
        if [[ -d "$target" ]]; then
            while IFS= read -r -d '' file; do
                replace_home_paths "$file" "$home_dir"
            done < <(grep -IlRZ -e '/home/daigo' -e '\$HOME' "$target" 2>/dev/null || true)
        elif [[ -f "$target" ]]; then
            if grep -Il -e '/home/daigo' -e '\$HOME' "$target" >/dev/null 2>&1; then
                replace_home_paths "$target" "$home_dir"
            fi
        fi
    done
}

pacman_pkgs=(
    hyprland
    xdg-desktop-portal-hyprland
    waybar
    swww
    mako
    rofi
    kitty
    dolphin
    hyprlock
    wlogout
    gnome-keyring
    networkmanager
    nm-applet
    brightnessctl
    playerctl
    pipewire
    wireplumber
    bluez
    bluez-utils
    blueman
    flameshot
    grim
    slurp
    wl-clipboard
    qt6ct
    kvantum
    papirus-icon-theme
    ttf-jetbrains-mono-nerd
    ttf-font-awesome
    noto-fonts
    libnotify
    xdg-user-dirs
)

aur_pkgs=(
    waypaper
    rofi-themes-collection
    snmenu
)

if [[ "$install_packages" == "true" ]]; then
    # No instala nada aun: solo lista y luego ejecuta segun el gestor disponible.
    print_packages
    if ! command -v pacman >/dev/null 2>&1; then
        echo "pacman no esta disponible."
        exit 1
    fi

    if command -v yay >/dev/null 2>&1; then
        run_cmd yay -S --needed --noconfirm "${pacman_pkgs[@]}"
        if [[ "$use_aur" == "true" && ${#aur_pkgs[@]} -gt 0 ]]; then
            run_cmd yay -S --needed --noconfirm "${aur_pkgs[@]}"
        fi
        
    else
        run_cmd sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
        if [[ "$use_aur" == "true" && ${#aur_pkgs[@]} -gt 0 ]]; then
            echo "AUR packages skipped (install yay): ${aur_pkgs[*]}"
        fi
    fi

    if command -v systemctl >/dev/null 2>&1; then
        run_cmd sudo systemctl enable --now NetworkManager
        run_cmd sudo systemctl enable --now bluetooth
    fi
fi



if [[ "$install_configs" == "true" ]]; then
    backup_dir="$config_root/backup-$(date +%Y%m%d-%H%M%S)"
    pictures_dir="$(get_xdg_dir PICTURES)"
    if [[ -z "$pictures_dir" ]]; then
        pictures_dir="$HOME/Pictures"
    fi
    screenshots_dir="$pictures_dir/Screenshots"
    wallpapers_dir="$pictures_dir/Wallpapers"
    home_dir="$HOME"
    copied_targets=()

    # Lista de configuraciones que se copian al perfil del usuario.
    config_items=(
        hypr
        waybar
        snmenu
        waypaper
        kitty
        rofi
        mako
        qt6ct
        Kvantum
        gtk-3.0
        gtk-4.0
        flameshot
        networkmanager-dmenu
        xsettingsd
        user-dirs.dirs
        user-dirs.locale
        mimeapps.list
    )

    for item in "${config_items[@]}"; do
        src="$repo_root/$item"
        dest="$config_root/$item"
        if [[ ! -e "$src" ]]; then
            echo "Skip missing: $src"
            continue
        fi

        if [[ -e "$dest" ]]; then
            run_cmd mkdir -p "$backup_dir/$(dirname "$item")"
            run_cmd mv "$dest" "$backup_dir/$item"
        fi

        run_cmd mkdir -p "$(dirname "$dest")"
        run_cmd cp -a "$src" "$dest"
        copied_targets+=("$dest")
    done

    if [[ -f "$config_root/flameshot/flameshot.ini" ]]; then
        update_flameshot_path "$config_root/flameshot/flameshot.ini" "$screenshots_dir"
    fi

    if [[ -f "$config_root/waypaper/config.ini" ]]; then
        update_waypaper_paths "$config_root/waypaper/config.ini" "$wallpapers_dir" "$home_dir"
    fi

    if [[ -f "$config_root/rofi/config.rasi" ]]; then
        replace_home_paths "$config_root/rofi/config.rasi" "$home_dir"
    fi

    # Normaliza rutas en todo lo copiado para evitar hardcodes de /home/usuario.
    normalize_paths_in_targets "$home_dir" "${copied_targets[@]}"

    run_cmd mkdir -p "$wallpapers_dir"
fi

printf '%s\n' "Listo."
