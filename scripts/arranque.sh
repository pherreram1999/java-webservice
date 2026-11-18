#!/usr/bin/env bash
# Programa (en el crontab del usuario actual) el inicio automático de Tomcat en modo
# producción (scripts/inicia.sh) cada vez que arranca la máquina, mediante una entrada @reboot.
#
#   scripts/arranque.sh                 habilita el inicio automático (reemplaza la entrada si ya existía)
#   scripts/arranque.sh --deshabilita   quita la entrada del crontab
#   scripts/arranque.sh --estado        indica si está habilitado
#
# La salida de cada arranque queda en tomcat/logs/arranque.log. Requiere cron (cronie)
# con el servicio crond habilitado. Las demás entradas del crontab no se tocan.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MARCA="# servicio-web: inicio automático de Tomcat ($RAIZ)"
ESPERA=30   # segundos tras el arranque antes de iniciar Tomcat (red y MySQL listos)

command -v crontab >/dev/null 2>&1 || error "No se encontró crontab. Instala cron (p. ej. sudo dnf install cronie)."

# Crontab actual sin nuestra entrada (la marca y la línea que le sigue)
crontab_sin_entrada() {
  crontab -l 2>/dev/null | awk -v m="$MARCA" '$0 == m { salta = 1; next } salta { salta = 0; next } { print }'
}

habilitado() { crontab -l 2>/dev/null | grep -qxF "$MARCA"; }

case "${1:-}" in
  "")
    [ -x "$RAIZ/scripts/inicia.sh" ] || error "No se encontró $RAIZ/scripts/inicia.sh"
    LINEA="@reboot sleep $ESPERA && $(printf '%q' "$RAIZ/scripts/inicia.sh") >> $(printf '%q' "$CATALINA_HOME/logs/arranque.log") 2>&1"
    RESTO="$(crontab_sin_entrada)"   # se lee completo antes de escribir el nuevo crontab
    { [ -z "$RESTO" ] || echo "$RESTO"; echo "$MARCA"; echo "$LINEA"; } | crontab -
    echo "Inicio automático habilitado. Entrada en el crontab de $(id -un):"
    echo "  $LINEA"
    if command -v systemctl >/dev/null 2>&1 && ! systemctl is-enabled --quiet crond 2>/dev/null \
       && ! systemctl is-enabled --quiet cron 2>/dev/null; then
      echo "AVISO: el servicio de cron no está habilitado al arranque (sudo systemctl enable --now crond)." >&2
    fi
    ;;
  --deshabilita)
    if habilitado; then
      RESTO="$(crontab_sin_entrada)"
      if [ -n "$RESTO" ]; then echo "$RESTO" | crontab -; else crontab -r; fi
      echo "Inicio automático deshabilitado."
    else
      echo "El inicio automático no estaba habilitado."
    fi
    ;;
  --estado)
    if habilitado; then
      echo "Habilitado:"; crontab -l | grep -xF -A1 "$MARCA" | tail -1 | sed 's/^/  /'
    else
      echo "Deshabilitado."
    fi
    ;;
  *)
    error "Opción desconocida: $1 (usa: scripts/arranque.sh [--deshabilita | --estado])"
    ;;
esac
