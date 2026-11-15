#!/usr/bin/env bash
# Prueba de PUT /modifica_usuario
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "modifica_usuario"

nuevo_usuario U

# password "" = conservar la contraseña; foto null = quitar la foto
api_modifica_usuario "$U_ID" "$U_TOKEN" "$(json_usuario "$U_EMAIL" "" "Ana Maria" 0)"
espera 200 "Se modificó el usuario" "modifica el nombre y quita la foto"
api_consulta_usuario "$U_ID" "$U_TOKEN"
espera_jq '.nombre == "Ana Maria" and .foto == null' "la consulta refleja el cambio de nombre y la foto quitada"
api_login "$U_EMAIL" "$U_HASH"
espera 200 - "password vacío: la contraseña anterior sigue funcionando"
U_TOKEN="$(jget .token)"

api_modifica_usuario "$U_ID" "$U_TOKEN" "$(json_usuario "$U_EMAIL" "" "Ana Maria" 1)"
espera 200 "Se modificó el usuario" "agrega una foto"
api_consulta_usuario "$U_ID" "$U_TOKEN"
espera_jq '.foto != null' "la foto nueva quedó guardada"

api_modifica_usuario "$U_ID" "$U_TOKEN" "$(json_usuario "$U_EMAIL" "$HASH_OTRO" "Ana Maria" 1)"
espera 200 "Se modificó el usuario" "cambia la contraseña"
api_login "$U_EMAIL" "$HASH_OTRO"
espera 200 - "la contraseña nueva funciona"
api_login "$U_EMAIL" "$U_HASH"
espera 400 "Acceso denegado" "la contraseña anterior ya no funciona"
api_login "$U_EMAIL" "$HASH_OTRO"
U_TOKEN="$(jget .token)"

# Campos obligatorios
BASE_JSON="$(json_usuario "$U_EMAIL" "" "Ana Maria")"
api_modifica_usuario "$U_ID" "$U_TOKEN" "$(jq 'del(.email)' <<<"$BASE_JSON")"
espera 400 "Se debe ingresar el email" "falta el email"
api_modifica_usuario "$U_ID" "$U_TOKEN" "$(jq 'del(.nombre)' <<<"$BASE_JSON")"
espera 400 "Se debe ingresar el nombre" "falta el nombre"
api_modifica_usuario "$U_ID" "$U_TOKEN" "$(jq 'del(.apellido_paterno)' <<<"$BASE_JSON")"
espera 400 "Se debe ingresar el apellido paterno" "falta el apellido paterno"
api_modifica_usuario "$U_ID" "$U_TOKEN" "$(jq 'del(.fecha_nacimiento)' <<<"$BASE_JSON")"
espera 400 "Se debe ingresar la fecha de nacimiento" "falta la fecha de nacimiento"

api_modifica_usuario "$U_ID" "token_falso" "$BASE_JSON"
espera 400 "Acceso denegado" "token inválido"

resumen
