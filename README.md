________          .__    .___      __               
\_____  \    ____ |__| __| _/____ |  | __           
 /   |   \  / ___\|  |/ __ |/  _ \|  |/ /           
/    |    \/ /_/  >  / /_/ (  <_> )    <            
\_______  /\___  /|__\____ |\____/|__|_ \           
        \//_____/         \/           \/           
________          __    _____.__.__                 
\______ \   _____/  |__/ ____\__|  |   ____   ______
 |    |  \ /  _ \   __\   __\|  |  | _/ __ \ /  ___/
 |    `   (  <_> )  |  |  |  |  |  |_\  ___/ \___ \ 
/_______  /\____/|__|  |__|  |__|____/\___  >____  >
        \/                                \/     \/ 

# Configuracion de Hyprland en Arch Linux

Repositorio de dotfiles para Hyprland y componentes clave de un entorno grafico moderno en Arch Linux. Incluye configuraciones, scripts y un instalador para aplicar todo de forma reproducible. Estos dotfiles estan en constante actualizacion.

## Estructura principal

- **~/.config/hypr/hyprland.conf**: Archivo principal de Hyprland.
- **~/.config/hypr/hyprlock.conf**: Configuracion de Hyprlock (pantalla de bloqueo).
- **Flameshot**: Capturas en Wayland via portal.
- **~/.config/waypaper/config.ini**: Configuracion de Waypaper para wallpapers.
- **~/.config/waybar/**: Configuracion y estilos de Waybar.
- **~/.config/kitty/kitty.conf**: Configuracion de Kitty.
- **~/.config/rofi/config.rasi**: Configuracion de Rofi y temas.

## Caracteristicas destacadas

### Hyprland
- Monitores, gaps, bordes, animaciones y reglas de ventanas.
- Keybindings para gestion de ventanas, multimedia y utilidades.
- Integracion con Waybar y notificaciones.

### Wallpapers
- Carpeta de wallpapers: `~/Pictures/Wallpapers` (se normaliza al usuario actual).
- Waypaper se inicia automaticamente al iniciar Hyprland junto con `swww`.
- Seleccion y cambio de fondo en tiempo real usando Rofi.

### Waybar
- Barra superior con modulos personalizados: musica, IP, HTB, menu de red, menu de energia, bateria, volumen, hora.
- Estilos con colores y fuentes modernas.
- Modulo bluetooth nativo (requiere blueman).
- Icono de bateria cargando (se muestra cuando esta en carga).

### Otros componentes
- Kitty como terminal por defecto.
- Dolphin como gestor de archivos.
- Rofi como lanzador de aplicaciones y menu de seleccion.
- Hyprlock para bloqueo de pantalla con blur del ultimo frame.

## Instalacion rapida
1. Clona el repositorio dentro de `~/.config`.
2. Previsualiza la instalacion sin cambios:
   - `./install.sh --dry-run`
3. Instala paquetes y configs de usuario:
   - `./install.sh`
4. Opciones utiles:
   - `./install.sh --packages-only`
   - `./install.sh --config-only`
   - `./install.sh --install-system` (SDDM en `/etc` y `/usr/share`)
   - `./install.sh --copy` (copia) o `./install.sh --link` (symlinks)
   - `./install.sh --no-aur`

El instalador:
- Muestra el listado de paquetes antes de instalar.
- Soporta AUR con `yay` o `paru`.
- Intenta instalar `snmenu` automaticamente (`snmenu` o `snmenu-git` en AUR).
- Despliega `~/.config/snmenu/layout.json` cuando existe en el repo.
- Permite instalar archivos de sistema SDDM con `--install-system`.

> Nota de alcance actual: este script todavia no alcanza a configurar al 100% SDDM ni SNMenu.
> Esa configuracion completa se implementara en futuros releases.

## Flujo recomendado (100% reproducible)
1. `./install.sh --packages-only`
2. `./install.sh --config-only --link`
3. `./install.sh --install-system` (si usas los temas SDDM del repo)
4. Cierra sesion y vuelve a entrar en Hyprland.

Si no tienes helper AUR (`yay`/`paru`), instala `snmenu` manualmente para que funcionen:
- el keybind de apagado en Hyprland
- el boton de energia en Waybar

## install.sh (detalle completo)

### Que hace el script
- Ejecuta en modo seguro con `set -euo pipefail`.
- Muestra splash ASCII (`accsiart.txt`) al iniciar.
- Detecta usuario objetivo en este orden:
   - `--target-user USER`
   - `SUDO_USER`
   - usuario actual (`$USER` / `id -un`)
- Resuelve `HOME` y `~/.config` del usuario objetivo.
- Soporta modo simulacion (`--dry-run`) para ver todas las acciones.
- Crea backups antes de sobrescribir (ruta base):
   - `~/.local/state/dotfiles-backups/<timestamp>/...`

### Opciones disponibles
- `--packages-only`: instala paquetes, no despliega configs.
- `--config-only`: despliega configs de usuario, no instala paquetes.
- `--install-system`: instala/configura SDDM desde `system/sddm`.
- `--no-aur`: omite instalacion AUR.
- `--copy`: copia archivos/directorios.
- `--link`: crea symlinks (default).
- `--target-user USER`: define usuario objetivo.
- `--dry-run`: no ejecuta cambios reales.
- `-h`, `--help`: ayuda.

### Paquetes que instala (pacman)
- hyprland
- xdg-desktop-portal-hyprland
- waybar
- swww
- mako
- rofi
- kitty
- dolphin
- hyprlock
- wlogout
- gnome-keyring
- networkmanager
- network-manager-applet
- brightnessctl
- playerctl
- pipewire
- wireplumber
- bluez
- bluez-utils
- blueman
- flameshot
- grim
- slurp
- wl-clipboard
- qt6ct
- kvantum
- papirus-icon-theme
- ttf-jetbrains-mono-nerd
- ttf-font-awesome
- noto-fonts
- libnotify
- xdg-user-dirs
- polkit-gnome

### Paquetes AUR
- waypaper
- rofi-themes-collection


### Paquete extra AUR (snmenu)
- Si `snmenu` no existe en `PATH`, intenta instalar:
   - `snmenu`
   - fallback: `snmenu-git`
- Si no hay helper AUR (`yay`/`paru`), muestra warning.

### Servicios que habilita
- `systemctl enable --now NetworkManager`
- `systemctl enable --now bluetooth`
- Si usas `--install-system`:
   - `systemctl enable sddm`

### Dotfiles que despliega en ~/.config
- `autostart`
- `hypr`
- `waybar`
- `waypaper`
- `kitty`
- `rofi`
- `mako`
- `qt6ct`
- `Kvantum`
- `gtk-3.0`
- `gtk-4.0`
- `flameshot`
- `networkmanager-dmenu`
- `snmenu`
- `xsettingsd`
- `user-dirs.dirs`
- `user-dirs.locale`
- `mimeapps.list`

### Instalacion de SDDM (con --install-system)
- Verifica entorno Arch Linux.
- Verifica/instala paquete `sddm`.
- Crea directorios:
   - `/etc/sddm.conf.d`
   - `/usr/share/sddm/themes`
   - `/var/lib/AccountsService/icons`
- Copia configuracion:
   - `system/sddm/sddm.conf` -> `/etc/sddm.conf`
   - `system/sddm/conf.d/*.conf` -> `/etc/sddm.conf.d/`
- Copia themes:
   - `system/sddm/themes/*` -> `/usr/share/sddm/themes/`
- Detecta y fija theme activo en:
   - `/etc/sddm.conf.d/10-theme.conf`
- Copia avatar:
   - `system/sddm/avatar.png` -> `/var/lib/AccountsService/icons/<usuario>`
- Usa permisos `644` para archivos de config y avatar.

### Idempotencia y seguridad
- Si destino ya apunta al mismo origen, hace `skip`.
- Si archivo no cambia (comparacion binaria), no sobrescribe.
- Antes de reemplazar, crea backup.
- No rompe si se ejecuta varias veces.


## Vista Principal

![Vista Principal](https://github.com/user-attachments/assets/04ef906f-aa00-4bf3-87b4-6a4c2da74f23)

## Rofi

![Rofi](https://github.com/user-attachments/assets/626f5436-33f6-40f8-97c7-79cb5afcebed)


## Fondo de pantalla
Si te gusta este fondo, puedes descargarlo aquí:  
[Descargar wallpaper](https://preview.redd.it/the-keycap-wallpaper-3840x2160-v0-387c295vkh1a1.jpg?width=1080&crop=smart&auto=webp&s=b68ee890330f74aa7273a21ce4e8217146facc87)

## Personalizacion
Puedes modificar scripts, atajos y configuraciones segun tus preferencias. Todo esta organizado para facilitar la edicion y extension.

## Notas de portabilidad
- Las rutas a usuario se normalizan al instalar.
- Evita subir caches, historiales o perfiles de apps al repo.

---

**Autor:** [Ogidok](https://github.com/ogidok)

Para dudas o mejoras, abre un issue o contacta directamente.
