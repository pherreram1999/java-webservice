#!/usr/bin/env bash
# Inicia Tomcat (catalina) en modo producción: en segundo plano, con los logs en
# tomcat/logs/catalina.out y el PID en tomcat/temp/catalina.pid. Detenerlo con scripts/detiene.sh.
# Las variables DB_* se toman de .env (si existe) o del sistema operativo; Tomcat las hereda.
# Opcional: CATALINA_OPTS (p. ej. "-Xms256m -Xmx1g") para las opciones de la JVM.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

requiere_tomcat
export CATALINA_PID="$PID_PRODUCCION"
[ -n "${JAVA_HOME:-}" ] || error "No se encontró JAVA_HOME. Ejecuta ./setup.sh o defínelo en .env"
[ -n "${DB_USER:-}" ] || error "DB_USER no está definido (.env o entorno); el servicio no podría conectar a la base de datos."
[ -f "$CATALINA_HOME/webapps/servicio.war" ] || error "servicio.war no está desplegado, ejecuta ./build.sh"

if [ -f "$CATALINA_PID" ] && kill -0 "$(cat "$CATALINA_PID")" 2>/dev/null; then
  error "Tomcat ya está corriendo (PID $(cat "$CATALINA_PID")). Usa scripts/detiene.sh para detenerlo."
fi
rm -f "$CATALINA_PID"

PUERTO="$(puerto_http)"
puerto_ocupado "$PUERTO" && error "El puerto $PUERTO ya está en uso (¿hay otro Tomcat, p. ej. ./dev.sh?)"

echo "JAVA_HOME=$JAVA_HOME"
echo "CATALINA_HOME=$CATALINA_HOME"
echo "BD: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"

# Proceso independiente de la terminal: sigue corriendo al cerrar la sesión
nohup "$CATALINA_HOME/bin/catalina.sh" start >/dev/null 2>&1 </dev/null

for _ in $(seq 1 120); do
  if puerto_ocupado "$PUERTO"; then
    echo "Tomcat iniciado (PID $(cat "$CATALINA_PID" 2>/dev/null || echo '?')) en el puerto $PUERTO"
    echo "  Servicio: http://localhost:$PUERTO/servicio/rest/ws"
    echo "  Cliente:  http://localhost:$PUERTO/"
    PUERTO_HTTPS="$(puerto_https)"
    [ -z "$PUERTO_HTTPS" ] || echo "  HTTPS:    https://<dominio>:$PUERTO_HTTPS/  (configurado con scripts/certificado.sh)"
    echo "  Logs:     $CATALINA_HOME/logs/catalina.out"
    exit 0
  fi
  if [ -f "$CATALINA_PID" ] && ! kill -0 "$(cat "$CATALINA_PID")" 2>/dev/null; then
    break
  fi
  sleep 1
done

echo "ERROR: Tomcat no quedó escuchando en el puerto $PUERTO. Últimas líneas del log:" >&2
tail -n 30 "$CATALINA_HOME/logs/catalina.out" >&2 || true
exit 1
