#!/usr/bin/env bash
# Funciones comunes de las pruebas del servicio REST (se usa con "source" desde cada script).
#
# Requiere: curl, jq, base64 y sha256sum. Si además hay cliente mysql y DB_USER en .env,
# al terminar se borran de la base los artículos de prueba (el servicio no tiene endpoint
# para borrar artículos). Los usuarios de prueba se borran con el propio servicio.
#
# Variables opcionales:
#   API_BASE   URL base del servicio (default http://localhost:8080/servicio/rest/ws)
#
# Todo lo que crean las pruebas lleva el prefijo zz_test_<id-de-corrida>, así que no
# choca con datos reales ni con otras corridas.

DIR_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ="$(dirname "$DIR_TEST")"

# .env del proyecto (misma convención que scripts/common.sh): credenciales de MySQL para la limpieza
if [ -f "$RAIZ/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$RAIZ/.env"
  set +a
fi

BASE="${API_BASE:-http://localhost:8080/servicio/rest/ws}"

for _c in curl jq base64 sha256sum; do
  command -v "$_c" >/dev/null 2>&1 || { echo "Falta el comando '$_c', es necesario para las pruebas." >&2; exit 2; }
done

if [ -t 1 ]; then
  VERDE=$'\033[32m'; ROJO=$'\033[31m'; GRIS=$'\033[2m'; NORMAL=$'\033[0m'
else
  VERDE=''; ROJO=''; GRIS=''; NORMAL=''
fi

TMP="$(mktemp -d)"
RUN="$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
FOTO_B64="$(base64 -w0 "$RAIZ/frontend/public/usuario_sin_foto.png")"
HASH_PRUEBA="$(printf 'secreta' | sha256sum | cut -d' ' -f1)"   # el cliente real envía el SHA-256 de la contraseña
HASH_OTRO="$(printf 'otra-clave' | sha256sum | cut -d' ' -f1)"

PASS=0
FAIL=0
TITULO="prueba"
STATUS=''
BODY=''
USUARIOS_PRUEBA=()
ARTICULOS_CREADOS=0
CONT_USR=0

# ---------------------------------------------------------------------------
# Resultado de las pruebas
# ---------------------------------------------------------------------------
ok()    { PASS=$((PASS + 1)); printf '  %s %s\n' "${VERDE}[ OK  ]${NORMAL}" "$1"; }
falla() { FAIL=$((FAIL + 1)); printf '  %s %s\n' "${ROJO}[FALLA]${NORMAL}" "$1"; [ -n "${2:-}" ] && printf '         %s%s%s\n' "$GRIS" "$2" "$NORMAL"; return 1; }
fatal() { printf '  %s %s\n' "${ROJO}[ERROR]${NORMAL}" "$1" >&2; exit 2; }

titulo() { TITULO="$1"; printf '\n== %s ==\n' "$1"; }

resumen() {
  printf '\n%s: %d correctas, %d fallidas\n' "$TITULO" "$PASS" "$FAIL"
  [ -n "${TEST_RESUMEN:-}" ] && printf '%s %d %d\n' "$TITULO" "$PASS" "$FAIL" >>"$TEST_RESUMEN"
  [ "$FAIL" -eq 0 ] && exit 0
  exit 1
}

# ---------------------------------------------------------------------------
# HTTP: deja el código en $STATUS y el cuerpo en $BODY
# ---------------------------------------------------------------------------
http() { # metodo ruta [argumentos de curl...]
  local metodo="$1" ruta="$2"
  shift 2
  STATUS="$(curl -sS -m 30 -o "$TMP/cuerpo" -w '%{http_code}' -X "$metodo" "$BASE/$ruta" "$@" 2>"$TMP/error")"
  BODY="$(cat "$TMP/cuerpo")"
  if [ "$STATUS" = "000" ]; then
    BODY="{\"mensaje\":\"sin respuesta del servidor: $(tr -d '\n"' <"$TMP/error")\"}"
  fi
}

http_json() { # metodo ruta json
  printf '%s' "$3" >"$TMP/peticion.json"
  http "$1" "$2" -H 'Content-Type: application/json' --data-binary @"$TMP/peticion.json"
}

jget() { jq -r "$1" <<<"$BODY"; }   # valor de un campo del último cuerpo

# Un envoltorio por endpoint (los parámetros de sesión son siempre id_usuario y token)
api_login()              { http GET "login?email=$1&password=$2"; }                                   # email hash
api_alta_usuario()       { http_json POST "alta_usuario" "$1"; }                                      # json
api_consulta_usuario()   { http GET "consulta_usuario?id_usuario=$1&token=$2"; }                      # id token
api_modifica_usuario()   { http_json PUT "modifica_usuario?id_usuario=$1&token=$2" "$3"; }            # id token json
api_borra_usuario()      { http DELETE "borra_usuario?id_usuario=$1&token=$2"; }                      # id token
api_alta_articulo()      { ARTICULOS_CREADOS=1; http_json POST "alta_articulo?id_usuario=$1&token=$2" "$3"; }  # id token json
api_consulta_articulos() { http GET "consulta_articulos?palabra=$1&id_usuario=$2&token=$3"; }         # palabra id token
api_compra()             { http PUT "compra_articulo?id_articulo=$3&cantidad=$4&id_usuario=$1&token=$2"; }     # id token articulo cantidad
api_carrito()            { http GET "consulta_carrito_compra?id_usuario=$1&token=$2"; }               # id token
api_elimina_articulo()   { http DELETE "elimina_articulo_carrito_compra?id_usuario=$1&id_articulo=$3&token=$2"; }  # id token articulo
api_elimina_carrito()    { http DELETE "elimina_carrito_compra?id_usuario=$1&token=$2"; }             # id token

# ---------------------------------------------------------------------------
# Aserciones
# ---------------------------------------------------------------------------
espera() { # codigo-http mensaje|- descripcion     ("-" = no comparar el mensaje)
  local codigo="$1" msg="$2" desc="$3" real
  if [ "$STATUS" != "$codigo" ]; then
    falla "$desc" "esperaba HTTP $codigo y se recibió HTTP $STATUS: ${BODY:0:300}"; return 1
  fi
  if [ "$msg" != "-" ]; then
    real="$(jq -r '.mensaje' <<<"$BODY" 2>/dev/null)"
    if [ "$real" != "$msg" ]; then
      falla "$desc" "esperaba el mensaje \"$msg\" y se recibió: ${BODY:0:300}"; return 1
    fi
    ok "$desc (HTTP $STATUS, \"$msg\")"
  else
    ok "$desc (HTTP $STATUS)"
  fi
}

espera_jq() { # filtro-jq descripcion : el filtro debe dar true sobre el último cuerpo
  if jq -e "$1" <<<"$BODY" >/dev/null 2>&1; then
    ok "$2"
  else
    falla "$2" "no se cumple «$1» en: ${BODY:0:300}"; return 1
  fi
}

espera_igual() { # esperado real descripcion
  if [ "$1" = "$2" ]; then ok "$3"; else falla "$3" "esperaba «$1» y se obtuvo «$2»"; return 1; fi
}

# ---------------------------------------------------------------------------
# Datos de prueba
# ---------------------------------------------------------------------------
json_usuario() { # email hash [nombre=Ana] [con_foto=1]
  jq -n --arg email "$1" --arg pw "$2" --arg nombre "${3:-Ana}" --arg foto "$FOTO_B64" --argjson conFoto "${4:-1}" \
    '{email:$email, password:$pw, nombre:$nombre, apellido_paterno:"Perez", apellido_materno:null,
      fecha_nacimiento:"2000-01-31T00:00:00.000Z", telefono:5512345678, genero:"F",
      foto:(if $conFoto==1 then $foto else null end)}'
}

json_articulo() { # nombre precio cantidad [descripcion] [con_foto=1]
  jq -n --arg nombre "$1" --argjson precio "$2" --argjson cantidad "$3" --arg desc "${4-Articulo de prueba}" \
        --arg foto "$FOTO_B64" --argjson conFoto "${5:-1}" \
    '{nombre:$nombre, descripcion:$desc, precio:$precio, cantidad:$cantidad,
      fotografia:(if $conFoto==1 then $foto else null end)}'
}

nuevo_usuario() { # prefijo : crea y loguea un usuario; deja <P>_ID, <P>_TOKEN, <P>_EMAIL y <P>_HASH
  local p="$1" email="zz_test_${RUN}_$((CONT_USR + 1))@example.com"
  CONT_USR=$((CONT_USR + 1))
  api_alta_usuario "$(json_usuario "$email" "$HASH_PRUEBA")"
  [ "$STATUS" = 200 ] || fatal "no se pudo crear el usuario de prueba: $BODY"
  USUARIOS_PRUEBA+=("$email")
  api_login "$email" "$HASH_PRUEBA"
  [ "$STATUS" = 200 ] || fatal "no se pudo iniciar sesión con el usuario de prueba: $BODY"
  printf -v "${p}_EMAIL" '%s' "$email"
  printf -v "${p}_HASH" '%s' "$HASH_PRUEBA"
  printf -v "${p}_ID" '%s' "$(jget .id_usuario)"
  printf -v "${p}_TOKEN" '%s' "$(jget .token)"
}

nuevo_articulo() { # variable id token etiqueta precio cantidad [descripcion] : deja <V> (id) y <V>_NOMBRE
  local var="$1" nombre="zz_test_${RUN}_$4"
  api_alta_articulo "$2" "$3" "$(json_articulo "$nombre" "$5" "$6" "${7-Articulo de prueba}")"
  [ "$STATUS" = 200 ] || fatal "no se pudo crear el artículo de prueba: $BODY"
  api_consulta_articulos "$nombre" "$2" "$3"
  [ "$STATUS" = 200 ] || fatal "no se pudo consultar el artículo de prueba: $BODY"
  printf -v "$var" '%s' "$(jq -r --arg n "$nombre" '[.[] | select(.nombre == $n)][0].id_articulo' <<<"$BODY")"
  printf -v "${var}_NOMBRE" '%s' "$nombre"
}

# ---------------------------------------------------------------------------
# Limpieza al terminar (también si la prueba falla o se interrumpe)
# ---------------------------------------------------------------------------
limpieza() {
  local rc=$? email hash sql
  trap - EXIT
  # Usuarios: se loguea de nuevo (puede haber cambiado la contraseña) y se borra; borra_usuario
  # también regresa al stock lo que tuvieran en el carrito. Si ya no existen, no pasa nada.
  for email in "${USUARIOS_PRUEBA[@]}"; do
    for hash in "$HASH_PRUEBA" "$HASH_OTRO"; do
      api_login "$email" "$hash"
      if [ "$STATUS" = 200 ]; then
        api_borra_usuario "$(jget .id_usuario)" "$(jget .token)"
        break
      fi
    done
  done
  # Artículos: no hay endpoint para borrarlos, se limpian directo en MySQL si es posible
  if [ "$ARTICULOS_CREADOS" -eq 1 ]; then
    if command -v mysql >/dev/null 2>&1 && [ -n "${DB_USER:-}" ]; then
      sql="DELETE FROM carrito_compra WHERE id_articulo IN (SELECT id_articulo FROM stock WHERE nombre LIKE 'zz_test_${RUN}_%');
           DELETE FROM fotos_articulos WHERE id_articulo IN (SELECT id_articulo FROM stock WHERE nombre LIKE 'zz_test_${RUN}_%');
           DELETE FROM stock WHERE nombre LIKE 'zz_test_${RUN}_%';"
      MYSQL_PWD="${DB_PASSWORD:-}" mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" -u "$DB_USER" \
        "${DB_NAME:-servicio_web}" -e "$sql" 2>"$TMP/mysql.err" \
        || echo "AVISO: no se pudieron borrar los artículos 'zz_test_${RUN}_*' de stock: $(cat "$TMP/mysql.err")" >&2
    else
      echo "AVISO: quedaron en stock artículos 'zz_test_${RUN}_*' (sin cliente mysql o sin DB_USER en .env)." >&2
    fi
  fi
  rm -rf "$TMP"
  exit "$rc"
}
trap limpieza EXIT

# ---------------------------------------------------------------------------
# Comprobación previa: ¿hay servicio y base de datos?  (login con datos inexistentes
# debe responder 400 "Acceso denegado"; cualquier otra cosa indica un problema de entorno)
# ---------------------------------------------------------------------------
api_login "zz_test_${RUN}_previo@example.com" "$HASH_PRUEBA"
if [ "$STATUS" = "000" ]; then
  echo "No se pudo conectar con $BASE" >&2
  echo "¿Está corriendo Tomcat?  (./dev.sh)  También puedes definir API_BASE." >&2
  exit 2
fi
if [ "$STATUS" != "400" ] || [ "$(jq -r '.mensaje' <<<"$BODY" 2>/dev/null)" != "Acceso denegado" ]; then
  echo "El servicio respondió algo inesperado (HTTP $STATUS): ${BODY:0:300}" >&2
  echo "Revisa DB_USER/DB_PASSWORD en .env y que se haya ejecutado database/schema.sql." >&2
  exit 2
fi
