#!/bin/bash

# reporte_sistema.sh - Reporte de estado del servidor
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo "=============================================="
echo " REPORTE DEL SISTEMA"
echo "=============================================="
echo "Fecha y hora          : $(date '+%Y-%m-%d %H:%M:%S')"
echo "Nombre del host       : $(hostname)"
echo "Usuarios conectados   : $(who | wc -l)"
echo "Espacio libre en /    : $(df -h / | awk 'NR==2 {print $4}')"
echo "Memoria RAM disponible: $(free -h | awk '/^Mem:/ {print $7}')"
if command -v docker >/dev/null 2>&1; then
  echo "Contenedores activos  : $(docker ps -q | wc -l)"
else
  echo "Contenedores activos  : docker no instalado"
fi
echo "----------------------------------------------"
