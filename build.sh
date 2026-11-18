#!/usr/bin/env bash
# Compila y despliega en ./tomcat/webapps (reemplazando el despliegue anterior):
#   - servicio (backend/): javac -> servicio.war -> webapps/servicio.war
#   - cliente (frontend/): Vite (npm run build) -> frontend/dist -> webapps/ROOT
# Si Tomcat está corriendo, redespliega solo (autoDeploy).
#
# Si está corriendo el Tomcat de producción (scripts/inicia.sh), solo compila: deja
# backend/servicio.war y frontend/dist listos pero NO toca webapps, para no publicar por
# accidente. Para desplegar ahí hay que pedirlo explícitamente con --despliega.
#
#   ./build.sh                compila servicio y cliente
#   ./build.sh back           solo el servicio
#   ./build.sh front          solo el cliente
#   ./build.sh --despliega    despliega aunque producción esté corriendo (combinable con back/front)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/scripts/common.sh"

# PID del Tomcat de producción, o vacío. Producción = Tomcat en segundo plano ("catalina.sh start":
# scripts/inicia.sh, o tomcat/bin/startup.sh aunque no deje archivo de PID); ./dev.sh usa "run".
pid_produccion() {
  if [ -f "$PID_PRODUCCION" ] && kill -0 "$(cat "$PID_PRODUCCION")" 2>/dev/null; then
    cat "$PID_PRODUCCION"
  else
    pgrep -f -- "-Dcatalina.base=$CATALINA_HOME .*org.apache.catalina.startup.Bootstrap start" | head -1 || true
  fi
}

# Decide si se copia a webapps; si no, avisa y deja lo compilado donde está
OMITIDO=0
puede_desplegar() {
  local pid
  pid="$(pid_produccion)"
  if [ "$DESPLIEGA" = 0 ] && [ -n "$pid" ]; then
    echo ">> Producción corriendo (PID $pid): $1 NO se despliega (usa --despliega)"
    OMITIDO=1
    return 1
  fi
}

compila_servicio() {
  requiere_jdk
  requiere_tomcat
  [ -f "$DIR_BACKEND/WEB-INF/lib/jersey-server.jar" ] \
    || error "Faltan las bibliotecas de Jersey en WEB-INF/lib. Ejecuta ./setup.sh"

  cd "$DIR_BACKEND"

  # Mantener WEB-INF/lib al día con la carpeta dependecies/
  cp -u "$DIR_DEPENDENCIAS"/*.jar WEB-INF/lib/

  echo ">> Compilando el servicio"
  rm -rf WEB-INF/classes/servicio
  mkdir -p WEB-INF/classes
  # tomcat-dbcp.jar (pool de conexiones) lo provee Tomcat en tiempo de ejecución
  javac -encoding UTF-8 -d WEB-INF/classes \
    -cp "WEB-INF/lib/*:$CATALINA_HOME/lib/tomcat-dbcp.jar" servicio/*.java

  echo ">> Empacando servicio.war"
  rm -f servicio.war Servicio.war
  jar cf servicio.war WEB-INF META-INF

  puede_desplegar "servicio.war" || return 0
  echo ">> Desplegando en $CATALINA_HOME/webapps"
  # También se quita el despliegue anterior con mayúscula (Servicio), que respondía en /Servicio
  rm -rf "$CATALINA_HOME/webapps/Servicio.war" "$CATALINA_HOME/webapps/Servicio" \
         "$CATALINA_HOME/webapps/servicio.war" "$CATALINA_HOME/webapps/servicio"
  cp servicio.war "$CATALINA_HOME/webapps/"
}

compila_cliente() {
  requiere_tomcat
  requiere_node

  echo ">> Compilando el cliente (Vite)"
  cd "$DIR_FRONTEND"
  [ -d node_modules ] || npm install --no-fund --no-audit
  npm run build

  puede_desplegar "frontend/dist" || return 0
  echo ">> Publicando cliente en webapps/ROOT"
  rm -rf "$CATALINA_HOME/webapps/ROOT"
  mkdir -p "$CATALINA_HOME/webapps/ROOT"
  cp -r "$DIR_FRONTEND"/dist/. "$CATALINA_HOME/webapps/ROOT/"
}

DESPLIEGA=0
PARTE=""
for arg in "$@"; do
  case "$arg" in
    --despliega) DESPLIEGA=1 ;;
    back|front)  [ -z "$PARTE" ] || error "Indica solo una parte: back o front"; PARTE="$arg" ;;
    *)           error "Opción desconocida: $arg (usa: ./build.sh [back|front] [--despliega])" ;;
  esac
done

case "$PARTE" in
  "")    compila_servicio; compila_cliente ;;
  back)  compila_servicio ;;
  front) compila_cliente ;;
esac

if [ "$OMITIDO" = 1 ]; then
  echo "Compilado sin desplegar: producción sigue con la versión anterior. Para publicar: ./build.sh $PARTE --despliega"
else
  echo "Listo. Servicio: http://localhost:8080/servicio/rest/ws   Cliente: http://localhost:8080/"
fi
