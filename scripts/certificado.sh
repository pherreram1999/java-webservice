#!/usr/bin/env bash
# Certificado HTTPS de Let's Encrypt para Tomcat:
#   1) lo obtiene con certbot: modo standalone (certbot levanta su propio servidor en el puerto 80) o,
#      si ya hay un servidor web en el puerto 80 (nginx, Apache), modo webroot con --webroot,
#   2) convierte el certificado y la llave privada a un almacén PKCS12 que Tomcat sabe leer
#      (tomcat/conf/certificado/servicio.p12, contraseña aleatoria en tomcat/conf/certificado/clave),
#   3) agrega a tomcat/conf/server.xml un conector HTTPS que usa ese almacén,
#   4) deja programada la renovación: certbot guarda este script como "deploy hook" y, en cada
#      renovación, regenera el PKCS12 y reinicia el Tomcat de scripts/inicia.sh si estaba corriendo.
#
#   scripts/certificado.sh <dominio> [--correo <correo>] [--webroot <dir>] [--staging]
#   scripts/certificado.sh --quita          quita el conector HTTPS de server.xml (no borra el certificado)
#
#   --correo    correo para avisos de Let's Encrypt (o variable CERT_CORREO); sin él se registra sin correo
#   --webroot   carpeta pública del servidor web que ya atiende el puerto 80 para ese dominio
#               (p. ej. /usr/share/nginx/html); certbot deja ahí el reto .well-known/acme-challenge/
#   --staging   usa el entorno de pruebas de Let's Encrypt (certificado no confiable, sin límites de emisión)
#   HTTPS_PUERTO  puerto del conector HTTPS (por defecto 8443; Tomcat corre sin root y no puede abrir el 443)
#
# Requisitos: certbot y openssl instalados, sudo, el dominio apuntando a esta máquina y el puerto 80
# accesible desde Internet (libre en modo standalone) durante la emisión y cada renovación.
# Uso interno (como root): --exporta <dominio> y --hook (lo ejecuta certbot tras renovar).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

SCRIPT="$RAIZ/scripts/certificado.sh"
CERT_LIVE="${CERT_LIVE:-/etc/letsencrypt/live}"
HTTPS_PUERTO="${HTTPS_PUERTO:-8443}"
ALMACEN="$DIR_CERTIFICADO/servicio.p12"
CLAVE="$DIR_CERTIFICADO/clave"
SERVER_XML="$CATALINA_HOME/conf/server.xml"
USUARIO="$(stat -c %U "$RAIZ")"   # dueño del proyecto: el usuario que corre Tomcat

uso() { error "Uso: scripts/certificado.sh <dominio> [--correo <correo>] [--webroot <dir>] [--staging]  |  scripts/certificado.sh --quita"; }

tomcat_corriendo() { [ -f "$PID_PRODUCCION" ] && kill -0 "$(cat "$PID_PRODUCCION")" 2>/dev/null; }

# (root) Genera el PKCS12 a partir de fullchain.pem + privkey.pem del dominio
exporta_pkcs12() {
  local live="$CERT_LIVE/$1"
  [ -r "$live/privkey.pem" ] || error "No se puede leer $live/privkey.pem (¿se emitió el certificado? ¿se ejecuta como root?)"
  [ -s "$CLAVE" ] || error "Falta la contraseña del almacén ($CLAVE)"
  local tmp
  tmp="$(mktemp "$DIR_CERTIFICADO/.servicio.p12.XXXXXX")"
  openssl pkcs12 -export -in "$live/fullchain.pem" -inkey "$live/privkey.pem" \
    -name tomcat -out "$tmp" -passout "file:$CLAVE"
  chmod 600 "$tmp"
  chown "$USUARIO:" "$tmp"
  mv -f "$tmp" "$ALMACEN"
  echo "Almacén PKCS12 generado: $ALMACEN"
}

# Tipo de llave del certificado (RSA o EC) para el atributo type de <Certificate>
tipo_llave() {
  if openssl pkcs12 -in "$ALMACEN" -passin "file:$CLAVE" -nokeys 2>/dev/null \
       | openssl x509 -noout -text | grep -q 'id-ecPublicKey'; then
    echo EC
  else
    echo RSA
  fi
}

# Escribe server.xml sin el bloque HTTPS previo y, si $1 = agrega, con el bloque nuevo antes de <Engine>
reescribe_server_xml() {
  [ -f "$SERVER_XML.original" ] || cp -p "$SERVER_XML" "$SERVER_XML.original"
  local bloque="" tmp
  if [ "$1" = "agrega" ]; then
    bloque="    $MARCA_HTTPS_INICIO
    <Connector port=\"$HTTPS_PUERTO\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\"
               maxThreads=\"150\" SSLEnabled=\"true\" maxParameterCount=\"1000\">
        <SSLHostConfig protocols=\"TLSv1.2,TLSv1.3\">
            <Certificate certificateKeystoreFile=\"conf/certificado/servicio.p12\"
                         certificateKeystoreType=\"PKCS12\"
                         certificateKeystorePassword=\"$(cat "$CLAVE")\"
                         certificateKeyAlias=\"tomcat\"
                         type=\"$(tipo_llave)\" />
        </SSLHostConfig>
    </Connector>
    $MARCA_HTTPS_FIN"
  fi
  tmp="$(mktemp "$SERVER_XML.XXXXXX")"
  # El bloque va antes del primer <Engine> que no esté dentro de un comentario <!-- ... -->
  awk -v i="$MARCA_HTTPS_INICIO" -v f="$MARCA_HTTPS_FIN" -v bloque="$bloque" '
    function comentarios(l,   p) {
      while (1) {
        if (!enc) { p = index(l, "<!--"); if (!p) return; l = substr(l, p + 4); enc = 1 }
        else      { p = index(l, "-->");  if (!p) return; l = substr(l, p + 3); enc = 0 }
      }
    }
    index($0, i) { salta = 1; next }
    salta { if (index($0, f)) salta = 0; next }
    !enc && /^[[:space:]]*<Engine[[:space:]]/ && !hecho { if (bloque != "") print bloque; hecho = 1 }
    { print; comentarios($0) }
    END { if (!hecho) exit 1 }' "$SERVER_XML" > "$tmp" \
    || { rm -f "$tmp"; error "No se encontró <Engine> en $SERVER_XML"; }
  # El conector HTTP redirige al puerto HTTPS (redirectPort) cuando una app exige conexión segura
  [ "$1" = "agrega" ] && sed -i "s/redirectPort=\"[0-9]*\"/redirectPort=\"$HTTPS_PUERTO\"/" "$tmp"
  chmod 600 "$tmp"   # contiene la contraseña del almacén
  mv -f "$tmp" "$SERVER_XML"
}

reinicia_tomcat() {
  "$RAIZ/scripts/detiene.sh"
  "$RAIZ/scripts/inicia.sh"
}

case "${1:-}" in
  --hook)
    # Lo ejecuta certbot (como root) tras emitir o renovar; RENEWED_LINEAGE = /etc/letsencrypt/live/<dominio>
    [ -n "${RENEWED_LINEAGE:-}" ] || error "--hook solo lo usa certbot (falta RENEWED_LINEAGE)"
    CERT_LIVE="$(dirname "$RENEWED_LINEAGE")"
    exporta_pkcs12 "$(basename "$RENEWED_LINEAGE")"
    if tomcat_corriendo; then
      # Tomcat 8.5 no recarga el certificado en caliente: se reinicia como el usuario dueño.
      # systemd-run --scope lo saca del grupo del servicio certbot-renew, que systemd limpia al terminar.
      echo "Reiniciando Tomcat para cargar el certificado renovado..."
      if command -v systemd-run >/dev/null 2>&1; then
        systemd-run --quiet --scope --collect runuser -u "$USUARIO" -- bash -c '"$1/detiene.sh" && "$1/inicia.sh"' _ "$RAIZ"
      else
        runuser -u "$USUARIO" -- bash -c '"$1/detiene.sh" && "$1/inicia.sh"' _ "$RAIZ"
      fi
    fi
    exit 0
    ;;
  --exporta)
    [ -n "${2:-}" ] || uso
    [ "$(id -u)" -eq 0 ] || error "--exporta se ejecuta como root (lo invoca este mismo script con sudo)"
    exporta_pkcs12 "$2"
    exit 0
    ;;
  --quita)
    requiere_tomcat
    if grep -qF "$MARCA_HTTPS_INICIO" "$SERVER_XML"; then
      reescribe_server_xml quita
      echo "Conector HTTPS quitado de $SERVER_XML."
      tomcat_corriendo && reinicia_tomcat
    else
      echo "server.xml no tiene un conector HTTPS generado por este script."
    fi
    exit 0
    ;;
  ""|-*) uso ;;
esac

# ---------------------------------------------------------------------------
# Emisión + configuración (como usuario normal; certbot y la exportación usan sudo)
# ---------------------------------------------------------------------------
DOMINIO="$1"; shift
CORREO="${CERT_CORREO:-}"
STAGING=()
WEBROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --correo) [ -n "${2:-}" ] || uso; CORREO="$2"; shift 2 ;;
    --webroot) [ -n "${2:-}" ] || uso; WEBROOT="$2"; shift 2 ;;
    --staging) STAGING=(--staging); shift ;;
    *) uso ;;
  esac
done

[ "$(id -u)" -ne 0 ] || error "Ejecuta scripts/certificado.sh como el usuario que corre Tomcat, no como root (usa sudo por dentro)"
requiere_tomcat
command -v openssl >/dev/null 2>&1 || error "No se encontró openssl (sudo dnf install openssl)"
command -v certbot >/dev/null 2>&1 || error "No se encontró certbot (Fedora: sudo dnf install certbot · Debian/Ubuntu: sudo apt install certbot)"
[[ "$HTTPS_PUERTO" =~ ^[0-9]+$ ]] || error "HTTPS_PUERTO no es un número: $HTTPS_PUERTO"
[ "$HTTPS_PUERTO" -ge 1024 ] || error "Tomcat corre sin root y no puede abrir el puerto $HTTPS_PUERTO; usa uno ≥ 1024 (ver README, sección HTTPS)"
[ "$HTTPS_PUERTO" != "$(puerto_http)" ] || error "HTTPS_PUERTO ($HTTPS_PUERTO) es el mismo que el puerto HTTP de Tomcat"
if [ -n "$WEBROOT" ]; then
  [ -d "$WEBROOT" ] || error "No existe la carpeta --webroot $WEBROOT"
  MODO=(--webroot -w "$WEBROOT")
else
  puerto_ocupado 80 && error "El puerto 80 está ocupado (¿nginx/Apache?). certbot standalone lo necesita libre; usa --webroot <carpeta pública de ese servidor>"
  MODO=(--standalone)
fi

# Contraseña aleatoria del almacén (se conserva entre renovaciones)
mkdir -p "$DIR_CERTIFICADO"
chmod 700 "$DIR_CERTIFICADO"
if [ ! -s "$CLAVE" ]; then
  (umask 077; openssl rand -hex 24 | tr -d '\n' > "$CLAVE")
fi

if [ -n "$CORREO" ]; then CUENTA=(-m "$CORREO"); else CUENTA=(--register-unsafely-without-email); fi

echo "Solicitando el certificado para $DOMINIO con certbot (pide la contraseña de sudo)..."
sudo certbot certonly "${MODO[@]}" --non-interactive --agree-tos "${CUENTA[@]}" "${STAGING[@]}" \
  --cert-name "$DOMINIO" -d "$DOMINIO" \
  --deploy-hook "$(printf '%q' "$SCRIPT") --hook"

# El hook solo corre si certbot emitió uno nuevo; si ya existía, el PKCS12 se genera aquí
sudo "$SCRIPT" --exporta "$DOMINIO"

reescribe_server_xml agrega
echo "Conector HTTPS (puerto $HTTPS_PUERTO) configurado en $SERVER_XML (copia original: server.xml.original)."

# Renovación automática: certbot trae un timer de systemd que ejecuta "certbot renew" dos veces al día
for TIMER in certbot-renew.timer certbot.timer snap.certbot.renew.timer; do
  if systemctl cat "$TIMER" >/dev/null 2>&1; then
    sudo systemctl enable --now "$TIMER" >/dev/null 2>&1 && echo "Renovación automática activa ($TIMER)."
    break
  fi
done

if tomcat_corriendo; then
  echo "Reiniciando Tomcat para cargar el certificado..."
  reinicia_tomcat
elif puerto_ocupado "$(puerto_http)"; then
  echo "AVISO: hay un Tomcat corriendo que no se inició con scripts/inicia.sh (¿./dev.sh?); reinícialo para activar HTTPS." >&2
else
  echo "Inicia Tomcat con scripts/inicia.sh para activar HTTPS."
fi
echo "HTTPS: https://$DOMINIO:$HTTPS_PUERTO/   (servicio: https://$DOMINIO:$HTTPS_PUERTO/servicio/rest/ws)"
