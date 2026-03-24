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
3. Instala paquetes y configs:
   - `./install.sh`
4. Solo paquetes o solo configs:
   - `./install.sh --packages-only`
   - `./install.sh --config-only`

El instalador:
- Muestra el listado de paquetes antes de instalar.
- Normaliza rutas segun el usuario actual para evitar hardcodes en configs.


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
