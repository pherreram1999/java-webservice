#!/usr/bin/env bash
# Ejecuta las pruebas de todos los métodos del servicio y muestra un resumen.
#
#   ./test/todos.sh                 todas, en el orden de abajo
#   ./test/todos.sh login compra_articulo     solo las indicadas (nombre del script sin .sh)
#   API_BASE=http://host:8080/servicio/rest/ws ./test/todos.sh
#
# Requiere Tomcat corriendo (./dev.sh) y la base creada con database/schema.sql.
# Código de salida: 0 si todo pasó, 1 si alguna prueba falló, 2 si no se pudo probar (entorno).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TODAS=(
  alta_usuario
  login
  consulta_usuario
  modifica_usuario
  alta_articulo
  consulta_articulos
  compra_articulo
  consulta_carrito_compra
  elimina_articulo_carrito_compra
  elimina_carrito_compra
  borra_usuario
)
PRUEBAS=("${@:-${TODAS[@]}}")

export TEST_RESUMEN
TEST_RESUMEN="$(mktemp)"
trap 'rm -f "$TEST_RESUMEN"' EXIT

if [ -t 1 ]; then VERDE=$'\033[32m'; ROJO=$'\033[31m'; NORMAL=$'\033[0m'; else VERDE=''; ROJO=''; NORMAL=''; fi

fallidas=()
for p in "${PRUEBAS[@]}"; do
  if [ ! -f "$DIR/$p.sh" ]; then
    echo "No existe la prueba '$p' (busqué $DIR/$p.sh)" >&2
    exit 2
  fi
  bash "$DIR/$p.sh"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    echo >&2
    echo "${ROJO}No se pudo ejecutar '$p' (problema de entorno); se detiene la corrida.${NORMAL}" >&2
    exit 2
  fi
  [ "$rc" -eq 0 ] || fallidas+=("$p")
done

echo
echo "================ RESUMEN ================"
total_ok=0
total_mal=0
while read -r nombre ok mal; do
  total_ok=$((total_ok + ok))
  total_mal=$((total_mal + mal))
  if [ "$mal" -eq 0 ]; then marca="${VERDE}PASA ${NORMAL}"; else marca="${ROJO}FALLA${NORMAL}"; fi
  printf '  %s  %-34s %3d correctas, %d fallidas\n' "$marca" "$nombre" "$ok" "$mal"
done <"$TEST_RESUMEN"
echo "-----------------------------------------"
printf '  Total: %d correctas, %d fallidas en %d scripts\n' "$total_ok" "$total_mal" "${#PRUEBAS[@]}"

if [ "${#fallidas[@]}" -eq 0 ]; then
  echo "${VERDE}Todas las pruebas pasaron.${NORMAL}"
  exit 0
fi
echo "${ROJO}Fallaron: ${fallidas[*]}${NORMAL}"
exit 1
