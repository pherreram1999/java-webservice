#!/usr/bin/env bash
# Instala (una sola vez) lo necesario para desarrollar sin permisos de administrador:
#   - JDK 8 (Temurin) en ./jdk8            (solo si no hay uno definido con JAVA_HOME en .env)
#   - Tomcat 8.5.99 en ./tomcat            (con webapps vacío + webapps/ROOT)
#   - Jersey 2.24 (JAX-RS) en backend/WEB-INF/lib
#   - Dependencias del frontend en frontend/node_modules (requiere Node.js instalado en el sistema)
# Es idempotente: lo que ya existe no se vuelve a descargar.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/scripts/common.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

descarga() { echo ">> Descargando $1"; curl -fsSL --retry 3 -o "$2" "$1"; }

# --- JDK 8 -----------------------------------------------------------------
if [ "$JAVA_HOME_EN_DOTENV" -eq 1 ]; then
  echo ">> JAVA_HOME viene de .env ($JAVA_HOME), se omite la instalación del JDK"
elif [ -x "$DIR_JDK/bin/javac" ]; then
  echo ">> JDK 8 ya instalado en $DIR_JDK"
else
  descarga "https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jdk/hotspot/normal/eclipse" "$TMP/jdk8.tar.gz"
  mkdir -p "$DIR_JDK"
  tar -xzf "$TMP/jdk8.tar.gz" -C "$DIR_JDK" --strip-components=1
fi

# --- Tomcat ----------------------------------------------------------------
if [ -x "$CATALINA_HOME/bin/catalina.sh" ]; then
  echo ">> Tomcat ya instalado en $CATALINA_HOME"
else
  descarga "https://archive.apache.org/dist/tomcat/tomcat-8/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.zip" "$TMP/tomcat.zip"
  unzip -q "$TMP/tomcat.zip" -d "$TMP"
  mkdir -p "$CATALINA_HOME"
  cp -a "$TMP/apache-tomcat-$TOMCAT_VERSION/." "$CATALINA_HOME/"
  chmod +x "$CATALINA_HOME"/bin/*.sh
  # Por seguridad se eliminan las aplicaciones que trae Tomcat (webapps y webapps/ROOT)
  rm -rf "$CATALINA_HOME/webapps"
  mkdir -p "$CATALINA_HOME/webapps/ROOT"
fi

# --- Jersey (JAX-RS) -------------------------------------------------------
mkdir -p "$DIR_BACKEND/WEB-INF/lib" "$DIR_BACKEND/WEB-INF/classes/servicio"
if ls "$DIR_BACKEND"/WEB-INF/lib/jersey-server.jar >/dev/null 2>&1; then
  echo ">> Jersey ya está en WEB-INF/lib"
else
  descarga "https://repo1.maven.org/maven2/org/glassfish/jersey/bundles/jaxrs-ri/$JERSEY_VERSION/jaxrs-ri-$JERSEY_VERSION.zip" "$TMP/jersey.zip"
  unzip -q "$TMP/jersey.zip" -d "$TMP/jersey"
  find "$TMP/jersey" -name '*.jar' -exec cp {} "$DIR_BACKEND/WEB-INF/lib/" \;
fi
# Incompatibilidad entre Tomcat y Jersey: se borra el servlet-api que trae Jersey
rm -f "$DIR_BACKEND/WEB-INF/lib/javax.servlet-api-3.0.1.jar"

# --- Jackson + driver MySQL (carpeta dependecies/) ---------------------------
cp -u "$DIR_DEPENDENCIAS"/*.jar "$DIR_BACKEND/WEB-INF/lib/"

# --- Dependencias del frontend (Vite, Vue, Tailwind); Node.js lo instala el usuario ---
requiere_node
echo ">> Instalando dependencias del frontend (npm install)"
(cd "$DIR_FRONTEND" && npm install --no-fund --no-audit)

echo
echo "Listo. Siguientes pasos:"
echo "  1. cp .env.example .env   (y editar DB_USER / DB_PASSWORD)"
echo "  2. Ejecutar database/schema.sql en MySQL"
echo "  3. ./build.sh  y  ./dev.sh"
