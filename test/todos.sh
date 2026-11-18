#!/usr/bin/env bash
# Recorre los métodos de la tienda con la sesión del entorno y muestra un resumen.
#
#   source test/login.sh <email>   &&   ./test/todos.sh
#   ./test/todos.sh <email> [contraseña]          inicia sesión aquí mismo (con test/login.sh)
#
# Ejecuta, en orden: consulta_usuario, alta_articulo (crea "Prueba <fecha-hora>" con 5 piezas),
# consulta_articulos, compra_articulo (2), consulta_carrito_compra, elimina_articulo_carrito_compra,
# compra_articulo (1), elimina_carrito_compra y consulta_carrito_compra. Cada script imprime su curl.
# OJO: elimina_carrito_compra vacía TODO el carrito del usuario, y el artículo creado se queda en stock
# (no hay endpoint para borrarlo). alta_usuario, modifica_usuario y borra_usuario no se ejecutan aquí.
# Salida: 0 = todo pasó, 1 = algún paso falló, 2 = sin sesión o sin conexión.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -ge 1 ]; then
  # shellcheck source=login.sh
  source "$DIR/login.sh" "$@" || exit $?
fi
if [ -z "${API_BASE:-}" ] || [ -z "${ID_USUARIO:-}" ] || [ -z "${TOKEN:-}" ]; then
  echo "Faltan API_BASE, ID_USUARIO y TOKEN en el entorno. Inicia sesión primero:  source test/login.sh <email>" >&2
  exit 2
fi

if [ -t 1 ]; then VERDE=$'\033[32m'; ROJO=$'\033[31m'; NORMAL=$'\033[0m'; else VERDE=''; ROJO=''; NORMAL=''; fi
export RESPUESTA
RESPUESTA="$(mktemp)"
trap 'rm -f "$RESPUESTA"' EXIT
RESULTADOS=()
FALLAS=0

paso() { # descripción filtro-jq script [args...] : ejecuta el script; pasa si sale con 0 y el filtro da true
  local desc="$1" filtro="$2" rc
  shift 2
  printf '\n%s== %s ==%s\n' "$VERDE" "$desc" "$NORMAL"
  : >"$RESPUESTA"
  bash "$DIR/$1.sh" "${@:2}"
  rc=$?
  [ "$rc" -eq 2 ] && { echo "${ROJO}No se pudo ejecutar $1 (sin conexión o faltan datos).${NORMAL}" >&2; exit 2; }
  if [ "$rc" -eq 0 ] && jq -e "$filtro" "$RESPUESTA" >/dev/null 2>&1; then
    RESULTADOS+=("${VERDE}PASA ${NORMAL} $desc")
  else
    RESULTADOS+=("${ROJO}FALLA${NORMAL} $desc")
    FALLAS=$((FALLAS + 1))
  fi
}

NOMBRE="Prueba $(date '+%Y-%m-%d %H:%M:%S')"

paso "consulta el usuario de la sesión" '.email != null'                   consulta_usuario
paso "da de alta \"$NOMBRE\""          '.mensaje == "OK"'                    alta_articulo "$NOMBRE" 19.90 5 "Artículo creado por test/todos.sh"
paso "lo busca por nombre"             "any(.[]; .nombre == \"$NOMBRE\")"   consulta_articulos "$NOMBRE"
ID_ARTICULO="$(jq -r --arg n "$NOMBRE" '[.[] | select(.nombre == $n)][0].id_articulo // empty' "$RESPUESTA" 2>/dev/null)"
if [ -z "$ID_ARTICULO" ]; then
  echo "${ROJO}No se encontró el artículo recién creado; no se puede seguir.${NORMAL}" >&2
  exit 1
fi
paso "compra 2 piezas"                 '.mensaje == "OK"'                    compra_articulo "$ID_ARTICULO" 2
paso "el carrito tiene las 2 piezas"   "any(.[]; .id_articulo == $ID_ARTICULO and .cantidad == 2)" consulta_carrito_compra
paso "quita el artículo del carrito"   '.mensaje == "OK"'                    elimina_articulo_carrito_compra "$ID_ARTICULO"
paso "compra 1 pieza"                  '.mensaje == "OK"'                    compra_articulo "$ID_ARTICULO" 1
paso "vacía el carrito"                '.mensaje == "OK"'                    elimina_carrito_compra
paso "el carrito quedó vacío"          'length == 0'                         consulta_carrito_compra

echo
echo "================ RESUMEN ================"
printf '  %s\n' "${RESULTADOS[@]}"
echo "-----------------------------------------"
if [ "$FALLAS" -eq 0 ]; then
  echo "${VERDE}Todos los pasos pasaron.${NORMAL}"
  exit 0
fi
echo "${ROJO}Fallaron $FALLAS paso(s).${NORMAL}"
exit 1
