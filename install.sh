#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

DRY_RUN=false
INSTALL_PACKAGES=true
INSTALL_CONFIGS=true
INSTALL_SYSTEM=false
INSTALL_SECURITY_PACKAGES=false
SECURITY_OPTION_EXPLICIT=false
USE_AUR=true
MODE="link"
TARGET_USER_OVERRIDE=""

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

SECURITY_PACMAN_PKGS=(
    ufw
    firewalld
    wireshark-qt
    nmap
    whatweb
    sqlmap
    nikto
    metasploit
    tcpdump
    traceroute
    bind
)

SECURITY_AUR_PKGS=(
    burpsuite
    airgeddon
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
    snmenu
    xsettingsd
    user-dirs.dirs
    user-dirs.locale
    mimeapps.list
)

TARGET_USER=""
TARGET_HOME=""
CONFIG_ROOT=""
BACKUP_ROOT=""

COLOR_RESET=""
COLOR_BOLD=""
COLOR_DIM=""
COLOR_RED=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_BLUE=""
COLOR_CYAN=""

init_colors() {
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        COLOR_RESET='\033[0m'
        COLOR_BOLD='\033[1m'
        COLOR_DIM='\033[2m'
        COLOR_RED='\033[31m'
        COLOR_GREEN='\033[32m'
        COLOR_YELLOW='\033[33m'
        COLOR_BLUE='\033[34m'
        COLOR_CYAN='\033[36m'
    fi
}

print_banner() {
    printf '%b\n' "${COLOR_BLUE}${COLOR_BOLD}==>${COLOR_RESET} ${COLOR_BOLD}$*${COLOR_RESET}"
}

log() {
    printf '%b\n' "${COLOR_GREEN}[dotfiles]${COLOR_RESET} $*"
}

warn() {
    printf '%b\n' "${COLOR_YELLOW}[dotfiles][warn]${COLOR_RESET} $*" >&2
}

die() {
    printf '%b\n' "${COLOR_RED}${COLOR_BOLD}[dotfiles][error]${COLOR_RESET} $*" >&2
    exit 1
}

show_splash() {
    local splash_file="$REPO_ROOT/accsiart.txt"

    if [[ -f "$splash_file" ]]; then
        printf '\n'
        while IFS= read -r line; do
            printf '%b\n' "${COLOR_CYAN}${line}${COLOR_RESET}"
        done < "$splash_file"
        printf '\n\n'
    fi
}

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --packages-only     Install packages only
  --config-only       Install user config only
  --install-system    Install/configure SDDM from system/sddm
    --security-packages Install security toolset (firewall/auditing/pentest)
  --no-aur            Skip AUR packages
  --copy              Copy files instead of symlinks
  --link              Use symlinks (default)
  --target-user USER  Target user for ~/.config and avatar
  --dry-run           Print actions without executing
  -h, --help          Show this help
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
        return 0
    fi
    "$@"
}

run_root_cmd() {
    if [[ "$EUID" -eq 0 ]]; then
        run_cmd "$@"
    else
        run_cmd sudo "$@"
    fi
}

ensure_arch() {
    [[ -f /etc/arch-release ]] || die "Este instalador esta preparado para Arch Linux."
}

ensure_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Comando requerido no disponible: $1"
}

resolve_target_user() {
    if [[ -n "$TARGET_USER_OVERRIDE" ]]; then
        TARGET_USER="$TARGET_USER_OVERRIDE"
    elif [[ -n "${SUDO_USER:-}" ]]; then
        TARGET_USER="$SUDO_USER"
    else
        TARGET_USER="${USER:-$(id -un)}"
    fi

    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    [[ -n "$TARGET_HOME" ]] || die "No se pudo resolver HOME para usuario: $TARGET_USER"

    if [[ -n "${XDG_CONFIG_HOME:-}" && "$TARGET_USER" == "${USER:-}" ]]; then
        CONFIG_ROOT="$XDG_CONFIG_HOME"
    else
        CONFIG_ROOT="$TARGET_HOME/.config"
    fi

    BACKUP_ROOT="$TARGET_HOME/.local/state/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
}

safe_backup_path() {
    local dst="$1"
    printf '%s/%s' "$BACKUP_ROOT" "${dst#/}"
}

backup_path() {
    local dst="$1"
    [[ -e "$dst" || -L "$dst" ]] || return 0

    local backup
    backup="$(safe_backup_path "$dst")"

    run_cmd mkdir -p "$(dirname "$backup")"
    run_cmd cp -a "$dst" "$backup"
    log "Backup: $dst -> $backup"
}

install_file_644() {
    local src="$1"
    local dst="$2"
    local root_mode="$3"

    [[ -f "$src" ]] || die "Archivo fuente no existe: $src"

    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        log "OK (sin cambios): $dst"
        return 0
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        backup_path "$dst"
    fi

    if [[ "$root_mode" == "true" ]]; then
        run_root_cmd install -D -m 644 "$src" "$dst"
    else
        run_cmd install -D -m 644 "$src" "$dst"
    fi

    log "Instalado: $dst"
}

sync_dir_with_backup() {
    local src="$1"
    local dst="$2"

    [[ -d "$src" ]] || die "Directorio fuente no existe: $src"

    if [[ -d "$dst" ]] && diff -qr "$src" "$dst" >/dev/null 2>&1; then
        log "OK (sin cambios): $dst"
        return 0
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        backup_path "$dst"
        run_root_cmd rm -rf "$dst"
    fi

    run_root_cmd mkdir -p "$(dirname "$dst")"
    run_root_cmd cp -a "$src" "$dst"
    log "Directorio sincronizado: $dst"
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

is_pkg_installed() {
    local pkg="$1"
    pacman -Qi "$pkg" >/dev/null 2>&1
}

install_pkg_if_missing() {
    local pkg="$1"
    local aur_helper="${2:-}"

    if is_pkg_installed "$pkg"; then
        log "Paquete ya instalado: $pkg"
        return 0
    fi

    if [[ -n "$aur_helper" ]]; then
        run_cmd "$aur_helper" -S --needed --noconfirm "$pkg"
    else
        run_root_cmd pacman -S --needed --noconfirm "$pkg"
    fi

    log "Paquete instalado: $pkg"
}

install_snmenu_binary() {
    local aur_helper="${1:-}"

    if command -v snmenu >/dev/null 2>&1; then
        log "snmenu ya esta disponible en PATH."
        return 0
    fi

    if [[ -z "$aur_helper" ]]; then
        warn "snmenu no esta instalado y no hay helper AUR disponible."
        warn "Instala manualmente snmenu o snmenu-git para habilitar el menu de energia."
        return 0
    fi

    local candidate
    for candidate in snmenu snmenu-git; do
        if [[ "$DRY_RUN" == "true" ]]; then
            run_cmd "$aur_helper" -S --needed --noconfirm "$candidate"
            return 0
        fi

        if "$aur_helper" -S --needed --noconfirm "$candidate"; then
            log "snmenu instalado mediante paquete AUR: $candidate"
            return 0
        fi

        warn "No se pudo instalar paquete AUR: $candidate"
    done

    warn "No fue posible instalar snmenu automaticamente."
}

install_packages() {
    ensure_arch
    ensure_cmd pacman
    print_banner "Instalando paquetes"

    log "Paquetes pacman a instalar:"
    printf ' - %s\n' "${PACMAN_PKGS[@]}"

    local aur_helper=""
    if aur_helper="$(find_aur_helper)"; then
        log "Paquetes AUR a instalar:"
        printf ' - %s\n' "${AUR_PKGS[@]}"
    elif [[ "$USE_AUR" == "true" ]]; then
        warn "No se encontro yay/paru. Se omite AUR."
    fi

    run_root_cmd pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

    if [[ -n "$aur_helper" ]]; then
        run_cmd "$aur_helper" -S --needed --noconfirm "${AUR_PKGS[@]}"
    fi

    install_snmenu_binary "$aur_helper"

    if command -v systemctl >/dev/null 2>&1; then
        run_root_cmd systemctl enable --now NetworkManager
        run_root_cmd systemctl enable --now bluetooth
    fi
}

install_security_packages() {
    ensure_arch
    ensure_cmd pacman
    print_banner "Instalando toolset de seguridad"

    log "Paquetes de seguridad (pacman):"
    printf ' - %s\n' "${SECURITY_PACMAN_PKGS[@]}"

    run_root_cmd pacman -S --needed --noconfirm "${SECURITY_PACMAN_PKGS[@]}"

    local aur_helper=""
    if [[ "$USE_AUR" == "true" ]]; then
        if aur_helper="$(find_aur_helper)"; then
            log "Paquetes de seguridad (AUR):"
            printf ' - %s\n' "${SECURITY_AUR_PKGS[@]}"
            run_cmd "$aur_helper" -S --needed --noconfirm "${SECURITY_AUR_PKGS[@]}"
        else
            warn "No se encontro yay/paru. Se omite instalacion AUR de seguridad."
        fi
    fi

    if command -v systemctl >/dev/null 2>&1; then
        run_root_cmd systemctl enable --now ufw
    fi
}

ensure_user_ownership() {
    local path="$1"
    if [[ "$EUID" -eq 0 && "$TARGET_USER" != "root" ]]; then
        if [[ -L "$path" ]]; then
            run_root_cmd chown -h "$TARGET_USER:$TARGET_USER" "$path"
        else
            run_root_cmd chown -R "$TARGET_USER:$TARGET_USER" "$path"
        fi
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
    local src_real
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
        if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$src_real" ]]; then
            log "OK (link): $dst"
            return 0
        fi
        if [[ -e "$dst" || -L "$dst" ]]; then
            backup_path "$dst"
            remove_existing_path "$dst"
        fi
        run_cmd ln -s "$src" "$dst"
        ensure_user_ownership "$dst"
        log "Link: $dst -> $src"
        return 0
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        backup_path "$dst"
        remove_existing_path "$dst"
    fi

    run_cmd cp -a "$src" "$dst"
    ensure_user_ownership "$dst"
    log "Copy: $src -> $dst"
}

install_user_configs() {
    local item src dst
    local repo_real config_real

    print_banner "Desplegando dotfiles de usuario"

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

    if [[ "$MODE" == "copy" && "$repo_real" == "$config_real" ]]; then
        warn "Repo y destino son el mismo directorio; no se modificaron rutas en archivos para evitar ensuciar git."
    fi
}

detect_repo_theme() {
    local src_root="$1"
    local conf
    local current=""

    for conf in "$src_root/conf.d/theme.conf" "$src_root/sddm.conf"; do
        [[ -f "$conf" ]] || continue
        current="$(awk -F'=' '/^[[:space:]]*Current[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "$conf")"
        if [[ -n "$current" ]]; then
            printf '%s' "$current"
            return 0
        fi
    done

    if [[ -d "$src_root/themes" ]]; then
        current="$(find "$src_root/themes" -mindepth 1 -maxdepth 1 -type d | sort | head -n1 | xargs -r basename)"
        if [[ -n "$current" ]]; then
            printf '%s' "$current"
            return 0
        fi
    fi

    return 1
}

write_active_theme_conf() {
    local theme="$1"
    local tmp
    tmp="$(mktemp)"

    cat >"$tmp" <<EOF
[Theme]
Current=$theme
EOF

    install_file_644 "$tmp" "/etc/sddm.conf.d/10-theme.conf" true
    run_cmd rm -f "$tmp"
}

install_sddm() {
    local src_root="$REPO_ROOT/system/sddm"
    local aur_helper=""

    print_banner "Instalando y configurando SDDM"

    [[ -d "$src_root" ]] || die "No existe carpeta requerida: $src_root"
    ensure_arch
    ensure_cmd pacman

    aur_helper="$(find_aur_helper || true)"

    install_pkg_if_missing "sddm" "$aur_helper"

    run_root_cmd install -d /etc/sddm.conf.d
    run_root_cmd install -d /usr/share/sddm/themes
    run_root_cmd install -d /var/lib/AccountsService/icons

    if [[ -f "$src_root/sddm.conf" ]]; then
        install_file_644 "$src_root/sddm.conf" "/etc/sddm.conf" true
    fi

    if [[ -d "$src_root/conf.d" ]]; then
        local conf
        while IFS= read -r -d '' conf; do
            install_file_644 "$conf" "/etc/sddm.conf.d/$(basename "$conf")" true
        done < <(find "$src_root/conf.d" -maxdepth 1 -type f -name '*.conf' -print0)
    fi

    if [[ -d "$src_root/themes" ]]; then
        local theme_dir
        while IFS= read -r -d '' theme_dir; do
            sync_dir_with_backup "$theme_dir" "/usr/share/sddm/themes/$(basename "$theme_dir")"
        done < <(find "$src_root/themes" -mindepth 1 -maxdepth 1 -type d -print0)
    fi

    local active_theme
    if active_theme="$(detect_repo_theme "$src_root")"; then
        write_active_theme_conf "$active_theme"
        log "Theme activo configurado: $active_theme"
    else
        warn "No se pudo detectar tema activo desde system/sddm."
    fi

    if [[ -f "$src_root/avatar.png" ]]; then
        install_file_644 "$src_root/avatar.png" "/var/lib/AccountsService/icons/$TARGET_USER" true
    else
        warn "No se encontro avatar en: $src_root/avatar.png"
    fi

    if command -v systemctl >/dev/null 2>&1; then
        run_root_cmd systemctl enable sddm
    else
        warn "systemctl no disponible; habilita sddm manualmente."
    fi
}

prompt_security_packages() {
    if [[ "$SECURITY_OPTION_EXPLICIT" == "true" ]]; then
        return 0
    fi

    if [[ ! -t 0 || ! -t 1 ]]; then
        return 0
    fi

    printf '%b' "${COLOR_BLUE}${COLOR_BOLD}==>${COLOR_RESET} ${COLOR_BOLD}Ademas desea instalar paquetes de auditoria y seguridad?${COLOR_RESET} ${COLOR_DIM}[s/N]${COLOR_RESET} "
    local answer=""
    read -r answer || true

    case "${answer,,}" in
        s|si|y|yes)
            INSTALL_SECURITY_PACKAGES=true
            log "Se habilito la instalacion de paquetes de seguridad."
            ;;
        *)
            log "Se omitira la instalacion de paquetes de seguridad."
            ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --packages-only) INSTALL_CONFIGS=false ;;
        --config-only) INSTALL_PACKAGES=false ;;
        --install-system) INSTALL_SYSTEM=true ;;
        --security-packages)
            INSTALL_SECURITY_PACKAGES=true
            SECURITY_OPTION_EXPLICIT=true
            ;;
        --no-aur) USE_AUR=false ;;
        --copy) MODE="copy" ;;
        --link) MODE="link" ;;
        --target-user)
            shift
            [[ $# -gt 0 ]] || die "Falta valor para --target-user"
            TARGET_USER_OVERRIDE="$1"
            ;;
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

resolve_target_user
init_colors
show_splash
prompt_security_packages
print_banner "Inicio de instalacion"
log "Usuario objetivo: $TARGET_USER"
log "HOME objetivo: $TARGET_HOME"
log "Config root: $CONFIG_ROOT"

if [[ "$INSTALL_PACKAGES" == "true" ]]; then
    install_packages
fi

if [[ "$INSTALL_CONFIGS" == "true" ]]; then
    install_user_configs
fi

if [[ "$INSTALL_SYSTEM" == "true" ]]; then
    install_sddm
fi

if [[ "$INSTALL_SECURITY_PACKAGES" == "true" ]]; then
    install_security_packages
fi

log "Listo."
