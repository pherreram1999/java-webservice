#!/usr/bin/env bash
# PUT /modifica_usuario — reemplaza los datos del usuario con sesión iniciada.
#
#   ./test/modifica_usuario.sh <email> <contraseña|""> [nombre] [apellido_paterno] [AAAA-MM-DD] [apellido_materno] [teléfono] [M|F] [foto.png]
#   ./test/modifica_usuario.sh ana@example.com "" "Ana María" Pérez 2000-01-31
#
# Se envían TODOS los campos: lo que no se indique queda con el default (nombre Ana, apellido paterno Pérez,
# fecha 2000-01-31) o en null (sin foto = se quita la foto). Contraseña "" = conservar la actual; si se da,
# se envía su SHA-256. La petición JSON se guarda en ${TMPDIR:-/tmp}/modifica_usuario.json.
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
if [ $# -lt 2 ]; then echo "Uso: $0 <email> <contraseña|\"\"> [nombre] [apellido_paterno] [AAAA-MM-DD] [apellido_materno] [teléfono] [M|F] [foto]" >&2; exit 2; fi
EMAIL="$1"
CONTRASENA="$2"
NOMBRE="${3-Ana}"
APELLIDO_PATERNO="${4-Pérez}"
FECHA="${5-2000-01-31}"
APELLIDO_MATERNO="${6:-}"
TELEFONO="${7:-}"
GENERO="${8:-}"
FOTO="${9:-}"
HASH=""
[ -z "$CONTRASENA" ] || HASH="$(printf '%s' "$CONTRASENA" | sha256sum | cut -d' ' -f1)"
URL="$API_BASE/modifica_usuario?id_usuario=$ID_USUARIO&token=$TOKEN"
PETICION="${TMPDIR:-/tmp}/modifica_usuario.json"

# fecha_nacimiento en ISO-8601; teléfono, género, apellido materno y foto vacíos = null
if [ -n "$FOTO" ]; then
  [ -f "$FOTO" ] || { echo "No existe la imagen $FOTO" >&2; exit 2; }
  base64 -w0 "$FOTO" >"$PETICION.b64"
else
  : >"$PETICION.b64"
fi
jq -n --arg email "$EMAIL" --arg password "$HASH" --arg nombre "$NOMBRE" --arg ap "$APELLIDO_PATERNO" \
      --arg am "$APELLIDO_MATERNO" --arg fecha "${FECHA}T00:00:00.000Z" --arg tel "$TELEFONO" --arg genero "$GENERO" \
      --rawfile foto "$PETICION.b64" \
  '{email: $email, password: $password, nombre: $nombre, apellido_paterno: $ap,
    apellido_materno: (if $am == "" then null else $am end), fecha_nacimiento: $fecha,
    telefono: (if $tel == "" then null else ($tel | tonumber) end), genero: (if $genero == "" then null else $genero end),
    foto: (if $foto == "" then null else $foto end)}' >"$PETICION" || exit 2
rm -f "$PETICION.b64"

echo "curl -X PUT \"\$API_BASE/modifica_usuario?id_usuario=\$ID_USUARIO&token=\$TOKEN\" -H 'Content-Type: application/json' --data-binary @$PETICION"
echo "# $PETICION (base64 abreviado):"
jq 'walk(if type == "string" and length > 80 then .[0:40] + "... (\(length) caracteres)" else . end)' "$PETICION"
respuesta="$(curl -sS -w '\n%{http_code}' -X PUT "$URL" -H 'Content-Type: application/json' --data-binary @"$PETICION")" || exit 2

codigo="${respuesta##*$'\n'}"
cuerpo="${respuesta%$'\n'*}"
echo "HTTP $codigo"
jq 'walk(if type == "string" and length > 80 then .[0:40] + "... (\(length) caracteres)" else . end)' <<<"$cuerpo" 2>/dev/null || printf '%s\n' "$cuerpo"
[ -z "${RESPUESTA:-}" ] || printf '%s' "$cuerpo" >"$RESPUESTA"   # copia completa del cuerpo (la usa todos.sh)
[ "$codigo" = 200 ]
