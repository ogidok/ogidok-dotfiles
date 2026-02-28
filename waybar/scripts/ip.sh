#!/bin/sh
# Script para mostrar la IP actual
ip addr | awk '/inet / && !/127.0.0.1/ { sub("/.*", "", $2); print $2; exit }'
