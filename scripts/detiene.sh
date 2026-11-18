#!/usr/bin/env bash
# Detiene el Tomcat iniciado con scripts/inicia.sh. Espera hasta 30 s a que termine
# ordenadamente y, si no, lo mata (kill -9) usando el PID guardado.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

requiere_tomcat
export CATALINA_PID="$PID_PRODUCCION"
[ -n "${JAVA_HOME:-}" ] || error "No se encontró JAVA_HOME. Ejecuta ./setup.sh o defínelo en .env"

if [ ! -f "$CATALINA_PID" ] || ! kill -0 "$(cat "$CATALINA_PID")" 2>/dev/null; then
  rm -f "$CATALINA_PID"
  echo "Tomcat no está corriendo (no hay un proceso iniciado con scripts/inicia.sh)."
  exit 0
fi

PID="$(cat "$CATALINA_PID")"
echo "Deteniendo Tomcat (PID $PID)..."
"$CATALINA_HOME/bin/catalina.sh" stop 30 -force >/dev/null 2>&1 || true

if kill -0 "$PID" 2>/dev/null; then
  error "No se pudo detener Tomcat (PID $PID)."
fi
rm -f "$CATALINA_PID"
echo "Tomcat detenido."
