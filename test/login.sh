#!/usr/bin/env bash
# Prueba de GET /login
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "login"

nuevo_usuario U
TOKEN_1="$U_TOKEN"

api_login "$U_EMAIL" "$U_HASH"
espera 200 - "login con credenciales correctas"
espera_jq ".id_usuario == $U_ID" "devuelve el id_usuario del usuario"
espera_jq '(.token | type == "string") and (.token | length == 20)' "devuelve un token de 20 caracteres"
TOKEN_2="$(jget .token)"

if [ "$TOKEN_1" != "$TOKEN_2" ]; then ok "cada login genera un token distinto"; else falla "cada login genera un token distinto"; fi

api_consulta_usuario "$U_ID" "$TOKEN_1"
espera 400 "Acceso denegado" "el token anterior queda invalidado por el nuevo login"
api_consulta_usuario "$U_ID" "$TOKEN_2"
espera 200 - "el token nuevo sí es válido"

api_login "$U_EMAIL" "$HASH_OTRO"
espera 400 "Acceso denegado" "contraseña incorrecta"
api_login "zz_test_${RUN}_no_existe@example.com" "$U_HASH"
espera 400 "Acceso denegado" "email inexistente"

resumen
