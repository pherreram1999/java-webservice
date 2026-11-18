#!/usr/bin/env bash
# POST /alta_articulo — agrega un artículo al stock (la fotografía es obligatoria).
#
#   ./test/alta_articulo.sh <nombre> <precio> <cantidad> [descripción] [foto]
#   ./test/alta_articulo.sh Mayonesa 42.50 10 "Frasco de 400 g" frontend/public/usuario_sin_foto.png
#
# Sin foto se usa frontend/public/usuario_sin_foto.png. La petición JSON se guarda en ${TMPDIR:-/tmp}/alta_articulo.json.
# El servicio no tiene endpoint para borrar artículos: lo que se dé de alta queda en la tabla stock.
# Toma la sesión de las variables de entorno ID_USUARIO y TOKEN (las exporta  source test/login.sh <email>).
# La URL del servicio sale de API_BASE (también la exporta login.sh). Imprime el comando curl
# (con las variables, para copiarlo en ese mismo shell), el código HTTP y la respuesta
# (los base64 largos se abrevian). Salida: 0 = HTTP 200, 1 = error del servicio, 2 = faltan datos o sin conexión.

if [ -z "${API_BASE:-}" ]; then
  echo "Falta API_BASE en el entorno (la exporta  source test/login.sh <email>, o:  export API_BASE=http://localhost:8080/servicio/rest/ws)" >&2
  exit 2
fi
if [ -z "${ID_USUARIO:-}" ] || [ -z "${TOKEN:-}" ]; then
  echo "Faltan ID_USUARIO y TOKEN en el entorno. Inicia sesión primero:  source test/login.sh <email>" >&2
  exit 2
fi
if [ $# -lt 3 ]; then echo "Uso: $0 <nombre> <precio> <cantidad> [descripción] [foto]" >&2; exit 2; fi
NOMBRE="$1"
PRECIO="$2"
CANTIDAD="$3"
DESCRIPCION="${4:-}"
FOTO="${5:-$(dirname "$0")/../frontend/public/usuario_sin_foto.png}"
[ -f "$FOTO" ] || { echo "No existe la imagen $FOTO" >&2; exit 2; }
URL="$API_BASE/alta_articulo?id_usuario=$ID_USUARIO&token=$TOKEN"
PETICION="${TMPDIR:-/tmp}/alta_articulo.json"

# fotografia = la imagen en base64 sin saltos de línea; descripción vacía = null
base64 -w0 "$FOTO" >"$PETICION.b64"
jq -n --arg nombre "$NOMBRE" --arg desc "$DESCRIPCION" --argjson precio "$PRECIO" --argjson cantidad "$CANTIDAD" \
      --rawfile foto "$PETICION.b64" \
  '{nombre: $nombre, descripcion: (if $desc == "" then null else $desc end), precio: $precio, cantidad: $cantidad, fotografia: $foto}' \
  >"$PETICION" || { echo "precio y cantidad deben ser números" >&2; exit 2; }
rm -f "$PETICION.b64"

echo "curl -X POST \"\$API_BASE/alta_articulo?id_usuario=\$ID_USUARIO&token=\$TOKEN\" -H 'Content-Type: application/json' --data-binary @$PETICION"
echo "# $PETICION (base64 abreviado):"
jq 'walk(if type == "string" and length > 80 then .[0:40] + "... (\(length) caracteres)" else . end)' "$PETICION"
respuesta="$(curl -sS -w '\n%{http_code}' -X POST "$URL" -H 'Content-Type: application/json' --data-binary @"$PETICION")" || exit 2

codigo="${respuesta##*$'\n'}"
cuerpo="${respuesta%$'\n'*}"
echo "HTTP $codigo"
jq 'walk(if type == "string" and length > 80 then .[0:40] + "... (\(length) caracteres)" else . end)' <<<"$cuerpo" 2>/dev/null || printf '%s\n' "$cuerpo"
[ -z "${RESPUESTA:-}" ] || printf '%s' "$cuerpo" >"$RESPUESTA"   # copia completa del cuerpo (la usa todos.sh)
[ "$codigo" = 200 ]
