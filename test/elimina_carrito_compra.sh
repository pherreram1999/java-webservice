#!/usr/bin/env bash
# DELETE /elimina_carrito_compra — vacía el carrito y regresa todo al stock.
#
#   ./test/elimina_carrito_compra.sh
#
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

URL="$API_BASE/elimina_carrito_compra?id_usuario=$ID_USUARIO&token=$TOKEN"

echo "curl -X DELETE \"\$API_BASE/elimina_carrito_compra?id_usuario=\$ID_USUARIO&token=\$TOKEN\""
respuesta="$(curl -sS -w '\n%{http_code}' -X DELETE "$URL")" || exit 2

codigo="${respuesta##*$'\n'}"
cuerpo="${respuesta%$'\n'*}"
echo "HTTP $codigo"
jq 'walk(if type == "string" and length > 80 then .[0:40] + "... (\(length) caracteres)" else . end)' <<<"$cuerpo" 2>/dev/null || printf '%s\n' "$cuerpo"
[ -z "${RESPUESTA:-}" ] || printf '%s' "$cuerpo" >"$RESPUESTA"   # copia completa del cuerpo (la usa todos.sh)
[ "$codigo" = 200 ]
