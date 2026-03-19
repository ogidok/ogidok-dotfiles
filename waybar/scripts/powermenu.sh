#!/bin/bash

# Power menu para Waybar

chosen=$(echo -e "Apagar\nReiniciar\nCerrar sesión\nBloquear pantalla" | rofi -dmenu -p "Power")

case "$chosen" in
    "Apagar")
        systemctl poweroff
        ;;
    "Reiniciar")
        systemctl reboot
        ;;
    "Cerrar sesión")
        hyprctl dispatch exit
        ;;
    "Bloquear pantalla")
        swaylock
        ;;
    *)
        :
        ;;
esac
