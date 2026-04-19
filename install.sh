#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"

DRY_RUN=false
INSTALL_PACKAGES=true
INSTALL_CONFIGS=true
INSTALL_SYSTEM=false
USE_AUR=true
MODE="link"

PACMAN_PKGS=(
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
    network-manager-applet
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
    polkit-gnome
)

AUR_PKGS=(
    waypaper
    rofi-themes-collection
)

USER_ITEMS=(
    autostart
    hypr
    waybar
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

log() {
    printf '[dotfiles] %s\n' "$*"
}

warn() {
    printf '[dotfiles][warn] %s\n' "$*" >&2
}

die() {
    printf '[dotfiles][error] %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --packages-only   Install packages only
  --config-only     Install user config only
  --install-system  Install SDDM system files (/etc and /usr/share)
  --no-aur          Skip AUR packages
  --copy            Copy files instead of symlinks
  --link            Use symlinks (default)
  --dry-run         Print actions without executing
  -h, --help        Show this help
EOF
}

run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        printf 'DRY: %q' "$1"
        shift || true
        for arg in "$@"; do
            printf ' %q' "$arg"
        done
        printf '\n'
    else
        "$@"
    fi
}

ensure_arch() {
    [[ -f /etc/arch-release ]] || die "Este instalador esta preparado para Arch Linux."
}

ensure_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Comando requerido no disponible: $1"
}

find_aur_helper() {
    if [[ "$USE_AUR" != "true" ]]; then
        return 1
    fi
    if command -v yay >/dev/null 2>&1; then
        printf '%s' "yay"
        return 0
    fi
    if command -v paru >/dev/null 2>&1; then
        printf '%s' "paru"
        return 0
    fi
    return 1
}

install_packages() {
    ensure_arch
    ensure_cmd pacman

    log "Paquetes pacman a instalar:"
    printf ' - %s\n' "${PACMAN_PKGS[@]}"

    local aur_helper=""
    if aur_helper="$(find_aur_helper)"; then
        log "Paquetes AUR a instalar:"
        printf ' - %s\n' "${AUR_PKGS[@]}"
    elif [[ "$USE_AUR" == "true" ]]; then
        warn "No se encontro yay/paru. Se omite AUR."
    fi

    run_cmd sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

    if [[ -n "$aur_helper" ]]; then
        run_cmd "$aur_helper" -S --needed --noconfirm "${AUR_PKGS[@]}"
    fi

    if command -v systemctl >/dev/null 2>&1; then
        run_cmd sudo systemctl enable --now NetworkManager
        run_cmd sudo systemctl enable --now bluetooth
    fi
}

sed_escape() {
    printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

rewrite_user_paths() {
    local target_root="$1"
    local home_escaped
    home_escaped="$(sed_escape "$HOME")"

    local files=(
        "$target_root/hypr/hyprland.conf"
        "$target_root/waypaper/config.ini"
        "$target_root/flameshot/flameshot.ini"
    )

    local file
    for file in "${files[@]}"; do
        [[ -f "$file" ]] || continue
        run_cmd sed -i "s|/home/daigo|${home_escaped}|g" "$file"
    done

    local pictures_dir
    pictures_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}"
    local pictures_escaped
    pictures_escaped="$(sed_escape "$pictures_dir")"

    if [[ -f "$target_root/flameshot/flameshot.ini" ]]; then
        run_cmd sed -i "s|^savePath=.*|savePath=${pictures_escaped}|" "$target_root/flameshot/flameshot.ini"
    fi
}

remove_existing_path() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        run_cmd rm -rf "$path"
    fi
}

deploy_item() {
    local src="$1"
    local dst="$2"
    local src_real=""
    local dst_real=""

    src_real="$(readlink -f "$src")"
    if [[ -e "$dst" || -L "$dst" ]]; then
        dst_real="$(readlink -f "$dst")"
    fi

    if [[ -n "$dst_real" && "$src_real" == "$dst_real" ]]; then
        log "Skip (same path): $dst"
        return 0
    fi

    run_cmd mkdir -p "$(dirname "$dst")"

    if [[ "$MODE" == "link" ]]; then
        if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
            log "OK (link): $dst"
            return 0
        fi
        remove_existing_path "$dst"
        run_cmd ln -s "$src" "$dst"
        log "Link: $dst -> $src"
        return 0
    fi

    remove_existing_path "$dst"
    run_cmd cp -a "$src" "$dst"
    log "Copy: $src -> $dst"
}

install_user_configs() {
    local item src dst
    local repo_real config_real

    repo_real="$(readlink -f "$REPO_ROOT")"
    config_real="$(readlink -f "$CONFIG_ROOT")"

    for item in "${USER_ITEMS[@]}"; do
        src="$REPO_ROOT/$item"
        dst="$CONFIG_ROOT/$item"
        if [[ ! -e "$src" ]]; then
            warn "No existe en repo: $src"
            continue
        fi
        deploy_item "$src" "$dst"
    done

    if [[ "$MODE" == "copy" && "$repo_real" != "$config_real" ]]; then
        rewrite_user_paths "$CONFIG_ROOT"
    elif [[ "$MODE" == "copy" ]]; then
        warn "Repo y destino son el mismo directorio; se omite reescritura de rutas para no ensuciar git."
    else
        warn "Modo link activo: no se reescriben rutas hardcodeadas dentro de los archivos."
    fi
}

install_system_files() {
    local src_root="$REPO_ROOT/system/sddm"
    [[ -d "$src_root" ]] || die "No se encontro carpeta system/sddm en el repo."

    run_cmd sudo install -d /etc/sddm.conf.d
    run_cmd sudo install -d /usr/share/sddm/themes

    if [[ -f "$src_root/sddm.conf" ]]; then
        run_cmd sudo install -m 644 "$src_root/sddm.conf" /etc/sddm.conf
    fi

    if [[ -f "$src_root/conf.d/theme.conf" ]]; then
        run_cmd sudo install -m 644 "$src_root/conf.d/theme.conf" /etc/sddm.conf.d/theme.conf
    fi

    if [[ -d "$src_root/themes" ]]; then
        run_cmd sudo cp -a "$src_root/themes/." /usr/share/sddm/themes/
    fi

    if [[ -f "$src_root/avatar.png" ]]; then
        warn "avatar.png encontrado en repo. Revisa si deseas desplegarlo en /var/lib/AccountsService/icons/<usuario>."
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --packages-only) INSTALL_CONFIGS=false ;;
        --config-only) INSTALL_PACKAGES=false ;;
        --install-system) INSTALL_SYSTEM=true ;;
        --no-aur) USE_AUR=false ;;
        --copy) MODE="copy" ;;
        --link) MODE="link" ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Argumento desconocido: $1"
            ;;
    esac
    shift
done

if [[ "$INSTALL_PACKAGES" == "true" ]]; then
    install_packages
fi

if [[ "$INSTALL_CONFIGS" == "true" ]]; then
    install_user_configs
fi

if [[ "$INSTALL_SYSTEM" == "true" ]]; then
    install_system_files
fi

log "Listo."
