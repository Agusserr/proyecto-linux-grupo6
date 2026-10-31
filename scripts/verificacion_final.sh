#!/bin/bash
# Verificación integral del proyecto - Grupo 6 (sección 8.2)
# Ejecutar como adminsys (o un usuario del grupo docker):
#   /proyecto/scripts/verificacion_final.sh

PROYECTO=/proyecto
LOG=/var/log/proyecto/reporte_sistema.log
OK=0
FALLOS=0

pasa()  { echo "  [OK]    $1"; OK=$((OK+1)); }
falla() { echo "  [FALLO] $1"; FALLOS=$((FALLOS+1)); }

echo "=============================================="
echo " VERIFICACIÓN INTEGRAL - $(hostname)"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="

# 1. Servicios web en sus puertos
echo
echo "1. SERVICIOS WEB"
for entrada in "8080:nginx-oficial" "8081:nginx-personalizado" "8082:nginx-red" "8083:nginx-volumen"; do
  puerto=${entrada%%:*}
  nombre=${entrada##*:}
  codigo=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:$puerto")
  if [ "$codigo" = "200" ]; then
    pasa "Puerto $puerto ($nombre) responde HTTP $codigo"
  else
    falla "Puerto $puerto ($nombre) respondió '$codigo'"
  fi
done

# 2. Contenedores en ejecución
echo
echo "2. CONTENEDORES"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
detenidos=$(docker ps -a -q -f status=exited -f status=created | wc -l)
if [ "$detenidos" -eq 0 ]; then
  pasa "No hay contenedores detenidos"
else
  falla "Hay $detenidos contenedor(es) detenido(s):"
  docker ps -a --filter status=exited --filter status=created --format '          - {{.Names}} ({{.Status}})'
fi

# 3. Tarea programada (cron) y log
echo
echo "3. MONITOREO AUTOMÁTICO (cron)"
if crontab -l 2>/dev/null | grep -q '^\*/30 .*reporte_sistema.sh'; then
  pasa "Cron configurado cada 30 minutos:"
  crontab -l 2>/dev/null | grep 'reporte_sistema.sh' | sed 's/^/          /'
else
  falla "No se encontró la tarea '*/30' de reporte_sistema.sh en el crontab de $(whoami)"
fi

if [ -f "$LOG" ]; then
  minutos=$(( ( $(date +%s) - $(stat -c %Y "$LOG") ) / 60 ))
  if [ "$minutos" -le 31 ]; then
    pasa "El log se actualizó hace $minutos minuto(s)"
  else
    falla "El log no se actualiza desde hace $minutos minutos"
  fi
  echo "  Últimas ejecuciones registradas:"
  grep -i 'Fecha y hora' "$LOG" | tail -n 4 | sed 's/^/          /'
else
  falla "No existe $LOG"
fi

# 4. Repositorio Git
echo
echo "4. REPOSITORIO GIT"
if [ -d "$PROYECTO/.git" ]; then
  cd "$PROYECTO" || exit 1
  git fetch --quiet 2>/dev/null || echo "  (no se pudo consultar el remoto)"
  git status -sb
  if [ -z "$(git status --porcelain)" ]; then
    pasa "Árbol de trabajo limpio (sin cambios pendientes)"
  else
    falla "Hay cambios sin commit"
  fi
  echo "  Commits por integrante:"
  git shortlog -sn --all | sed 's/^/          /'
else
  falla "$PROYECTO no es un repositorio Git"
fi

# Resumen
echo
echo "=============================================="
echo " RESUMEN: $OK correctos, $FALLOS con fallos"
echo "=============================================="
[ "$FALLOS" -eq 0 ]
