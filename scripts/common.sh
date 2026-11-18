#!/usr/bin/env bash
# Funciones y configuración compartidas por setup.sh, build.sh, dev.sh y los scripts de producción
# de esta carpeta (se usa con "source").

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TOMCAT_VERSION="8.5.99"
JERSEY_VERSION="2.24"

# Directorios del proyecto
DIR_BACKEND="$RAIZ/backend"
DIR_DEPENDENCIAS="$RAIZ/dependecies"
DIR_FRONTEND="$RAIZ/frontend"
DIR_JDK="$RAIZ/jdk8"

# ---------------------------------------------------------------------------
# Variables de entorno: se leen del archivo .env (si existe) y, para las que no
# estén ahí, del sistema operativo. Si una variable está en ambos, gana el .env.
# ---------------------------------------------------------------------------
JAVA_HOME_EN_DOTENV=0
if [ -f "$RAIZ/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$RAIZ/.env"
  set +a
  grep -qE '^[[:space:]]*(export[[:space:]]+)?JAVA_HOME=' "$RAIZ/.env" && JAVA_HOME_EN_DOTENV=1
fi

# Valores por defecto de la base de datos (DB_USER y DB_PASSWORD no tienen default)
export DB_HOST="${DB_HOST:-localhost}"
export DB_PORT="${DB_PORT:-3306}"
export DB_NAME="${DB_NAME:-servicio_web}"

# Tomcat vive en su propio directorio dentro del proyecto
export CATALINA_HOME="${CATALINA_HOME:-$RAIZ/tomcat}"

# JAVA_HOME: 1) el definido en .env, 2) el JDK 8 local (./jdk8), 3) el del sistema
if [ "$JAVA_HOME_EN_DOTENV" -eq 0 ] && [ -x "$DIR_JDK/bin/javac" ]; then
  export JAVA_HOME="$DIR_JDK"
fi
[ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"
error() { echo "ERROR: $*" >&2; exit 1; }

requiere_jdk() {
  [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/javac" ] \
    || error "No se encontró un JDK (javac). Ejecuta ./setup.sh o define JAVA_HOME en .env"
}

requiere_node() {
  # Node instalado con nvm solo está en el PATH de shells interactivos: se carga si hace falta
  if ! command -v npm >/dev/null 2>&1 && [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
    # shellcheck disable=SC1091
    set +u; . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"; set -u
  fi
  command -v npm >/dev/null 2>&1 \
    || error "No se encontró Node.js (npm). Instálalo en el sistema (versión 20.19+ o 22.12+)"
}

requiere_tomcat() {
  [ -x "$CATALINA_HOME/bin/catalina.sh" ] \
    || error "No se encontró Tomcat en $CATALINA_HOME. Ejecuta ./setup.sh"
}

# Puerto HTTP: el primer <Connector> HTTP/1.1 de conf/server.xml (8080 por defecto)
puerto_http() {
  local p
  p="$(sed -n 's/.*<Connector port="\([0-9]*\)" protocol="HTTP\/1\.1".*/\1/p' "$CATALINA_HOME/conf/server.xml" | head -1)"
  echo "${p:-8080}"
}

# 0 si algo escucha en localhost:$1
puerto_ocupado() { (exec 3<>"/dev/tcp/localhost/$1") 2>/dev/null; }

# Archivo con el PID del Tomcat de producción (lo usan inicia.sh y detiene.sh)
# (no se exporta aquí: con CATALINA_PID definido, "./dev.sh stop" abortaría al no existir el archivo)
PID_PRODUCCION="$CATALINA_HOME/temp/catalina.pid"

# HTTPS (certificado.sh): bloque del conector marcado en conf/server.xml y archivos del certificado
MARCA_HTTPS_INICIO="<!-- servicio-web: conector HTTPS (generado por certificado.sh) -->"
MARCA_HTTPS_FIN="<!-- servicio-web: fin conector HTTPS -->"
DIR_CERTIFICADO="$CATALINA_HOME/conf/certificado"

# Puerto del conector HTTPS configurado por certificado.sh (vacío si no hay)
puerto_https() {
  awk -v i="$MARCA_HTTPS_INICIO" -v f="$MARCA_HTTPS_FIN" '
    index($0, i) { dentro = 1 } index($0, f) { dentro = 0 }
    dentro && match($0, /port="[0-9]+"/) { print substr($0, RSTART + 6, RLENGTH - 7); exit }' \
    "$CATALINA_HOME/conf/server.xml"
}
