#!/usr/bin/env bash
# GET /login — inicia sesión y deja la sesión en variables de entorno para los demás scripts.
#
#   source test/login.sh <email> [contraseña]          exporta API_BASE, ID_USUARIO y TOKEN en tu shell
#   eval "$(./test/login.sh <email> [contraseña])"     lo mismo, ejecutándolo como script
#
# Si no se da la contraseña se pide sin eco (así no queda en el historial). Se envía su
# SHA-256, igual que el cliente web. Cada login genera un token nuevo e invalida el anterior.
# La URL del servicio sale de la variable de entorno API_BASE; si no está definida se usa
# http://localhost:8080/servicio/rest/ws. Se exporta junto con la sesión para los demás scripts.
# Salida: 0 = sesión iniciada, 1 = el servicio respondió error, 2 = faltan datos o no hay conexión.

_login() {
  API_BASE="${API_BASE:-http://localhost:8080/servicio/rest/ws}"
  export API_BASE
  local email="$1" contrasena="$2" hash respuesta codigo cuerpo
  if [ -z "$email" ]; then
    echo "Uso: source test/login.sh <email> [contraseña]" >&2
    return 2
  fi
  if [ -z "$contrasena" ]; then
    read -rsp "Contraseña de $email: " contrasena </dev/tty || return 2
    echo >&2
  fi
  hash="$(printf '%s' "$contrasena" | sha256sum | cut -d' ' -f1)"

  echo "# API_BASE=$API_BASE   password = SHA-256 de la contraseña"
  echo "curl -G \"\$API_BASE/login\" --data-urlencode \"email=$email\" --data-urlencode \"password=$hash\""
  respuesta="$(curl -sS -w '\n%{http_code}' -G "$API_BASE/login" --data-urlencode "email=$email" --data-urlencode "password=$hash")" || return 2

  codigo="${respuesta##*$'\n'}"
  cuerpo="${respuesta%$'\n'*}"
  echo "HTTP $codigo"
  jq . <<<"$cuerpo" 2>/dev/null || printf '%s\n' "$cuerpo"
  [ "$codigo" = 200 ] || return 1

  ID_USUARIO="$(jq -r .id_usuario <<<"$cuerpo")"
  TOKEN="$(jq -r .token <<<"$cuerpo")"
  export ID_USUARIO TOKEN
}

if (return 0 2>/dev/null); then
  # Con "source": las variables quedan en el shell que lo llamó
  _login "$@"
  _rc=$?
  unset -f _login
  [ "$_rc" -eq 0 ] && echo "Exportadas: API_BASE=$API_BASE ID_USUARIO=$ID_USUARIO TOKEN=$TOKEN"
  return "$_rc"
else
  # Como script: la documentación va a stderr y los export a stdout (para usarlo con eval)
  _login "$@" >&2 || exit $?
  printf 'export API_BASE=%q ID_USUARIO=%q TOKEN=%q\n' "$API_BASE" "$ID_USUARIO" "$TOKEN"
fi
