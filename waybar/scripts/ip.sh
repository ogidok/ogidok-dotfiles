#!/bin/bash
# Script para mostrar la IP actual.
# Modo normal: imprime una sola vez (ideal para Waybar con "interval").
# Modo watch: ./ip.sh --watch [segundos]

get_ip() {
	/usr/bin/ip -4 route get 1.1.1.1 2>/dev/null | /usr/bin/awk '/src/ {print $7; exit}'
}

print_ip() {
	ip_value="$(get_ip)"
	if [ -n "$ip_value" ]; then
		echo "$ip_value"
	else
		echo "Sin IP"
	fi
}


if [ "$1" = "--watch" ]; then
	interval="${2:-30}"
	while true; do
		print_ip
		/usr/bin/sleep "$interval"
	done
else
	print_ip
fi
