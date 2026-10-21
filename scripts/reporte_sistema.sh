#!/bin/bash

# Script para consultar información básica del equipo.

echo "===== INFORMACIÓN DEL SISTEMA ====="

# Consultar el momento de ejecución
echo "Fecha y hora: $(date)"

# nombre del host del sistema
echo "Nombre del host: $(hostname)"

# Contar las sesiones de usuario abiertas
echo "Usuarios conectados: $(who | wc -l)"

#  almacenamiento disponible
echo "Espacio libre en disco: $(df -h / | tail -1 | awk '{print $4}')"

# Obtener la RAM que está disponible
echo "RAM disponible: $(free -h | awk '/Mem:/ {print $7}')"

# Contar los contenedores Docker en ejecución
echo "Contenedores activos: $(docker ps -q 2>/dev/null | wc -l)"

echo "==================================="
