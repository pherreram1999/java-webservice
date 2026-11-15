#!/usr/bin/env bash
# Compila y despliega en ./tomcat/webapps (reemplazando el despliegue anterior):
#   - servicio (backend/): javac -> servicio.war -> webapps/servicio.war
#   - cliente (frontend/): Vite (npm run build) -> frontend/dist -> webapps/ROOT
# Si Tomcat está corriendo, redespliega solo (autoDeploy).
#
#   ./build.sh          compila servicio y cliente
#   ./build.sh back     solo el servicio
#   ./build.sh front    solo el cliente
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/scripts/common.sh"

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

  echo ">> Publicando cliente en webapps/ROOT"
  rm -rf "$CATALINA_HOME/webapps/ROOT"
  mkdir -p "$CATALINA_HOME/webapps/ROOT"
  cp -r "$DIR_FRONTEND"/dist/. "$CATALINA_HOME/webapps/ROOT/"
}

case "${1:-}" in
  "")    compila_servicio; compila_cliente ;;
  back)  compila_servicio ;;
  front) compila_cliente ;;
  *)     error "Opción desconocida: $1 (usa: ./build.sh [back|front])" ;;
esac

echo "Listo. Servicio: http://localhost:8080/servicio/rest/ws   Cliente: http://localhost:8080/"
