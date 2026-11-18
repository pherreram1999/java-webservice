#!/usr/bin/env bash
# Lanza Tomcat (catalina) en modo desarrollo, en primer plano y con los logs en la terminal.
# Las variables DB_* se toman de .env (si existe) o del sistema operativo y llegan al servicio
# porque Tomcat hereda este entorno.
#
#   ./dev.sh          inicia Tomcat (Ctrl+C para detenerlo)
#   ./dev.sh stop     detiene un Tomcat iniciado en otra terminal
#   ./dev.sh front    servidor de desarrollo de Vite (http://localhost:5173) con recarga en caliente;
#                     reenvía /servicio/... al Tomcat, que debe estar corriendo en otra terminal
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/scripts/common.sh"

if [ "${1:-}" = "front" ]; then
  requiere_node
  cd "$DIR_FRONTEND"
  [ -d node_modules ] || npm install --no-fund --no-audit
  exec npm run dev
fi

requiere_tomcat
[ -n "${JAVA_HOME:-}" ] || error "No se encontró JAVA_HOME. Ejecuta ./setup.sh o defínelo en .env"

if [ "${1:-}" = "stop" ]; then
  exec "$CATALINA_HOME/bin/catalina.sh" stop
fi

[ -n "${DB_USER:-}" ] || echo "AVISO: DB_USER no está definido (.env o entorno); el servicio no podrá conectar a la base de datos." >&2
[ -f "$CATALINA_HOME/webapps/servicio.war" ] || echo "AVISO: servicio.war no está desplegado, ejecuta ./build.sh" >&2

PUERTO="$(puerto_http)"

if (exec 3<>"/dev/tcp/localhost/$PUERTO") 2>/dev/null; then
  error "El puerto $PUERTO ya está en uso (¿Tomcat ya está corriendo? prueba ./dev.sh stop)"
fi

echo "JAVA_HOME=$JAVA_HOME"
echo "CATALINA_HOME=$CATALINA_HOME"
echo "BD: ${DB_USER:-?}@$DB_HOST:$DB_PORT/$DB_NAME"
echo "Puerto HTTP: $PUERTO"

# Avisa cuando Tomcat ya esté escuchando (el proceso principal se reemplaza por catalina con exec)
(
  for _ in $(seq 1 120); do
    if (exec 3<>"/dev/tcp/localhost/$PUERTO") 2>/dev/null; then
      echo
      echo "================================================================"
      echo " Tomcat listo en el puerto $PUERTO"
      echo "   Servicio: http://localhost:$PUERTO/servicio/rest/ws"
      echo "   Cliente:  http://localhost:$PUERTO/"
      echo "================================================================"
      exit 0
    fi
    sleep 1
  done
) &

exec "$CATALINA_HOME/bin/catalina.sh" run
