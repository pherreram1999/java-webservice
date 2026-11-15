#!/usr/bin/env bash
# Prueba de POST /alta_usuario
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "alta_usuario"

EMAIL="zz_test_${RUN}_alta@example.com"
USUARIOS_PRUEBA+=("$EMAIL")

api_alta_usuario "$(json_usuario "$EMAIL" "$HASH_PRUEBA")"
espera 200 "Se dio de alta el usuario" "alta de un usuario con foto"

api_login "$EMAIL" "$HASH_PRUEBA"
espera 200 - "el usuario dado de alta puede iniciar sesión"
ID="$(jget .id_usuario)"; TOKEN="$(jget .token)"

api_consulta_usuario "$ID" "$TOKEN"
espera_jq ".email == \"$EMAIL\" and .nombre == \"Ana\" and .foto != null" "los datos y la foto quedaron guardados"

api_alta_usuario "$(json_usuario "$EMAIL" "$HASH_PRUEBA")"
espera 400 - "no permite repetir el email"

# Sin foto
EMAIL_2="zz_test_${RUN}_alta_sin_foto@example.com"
USUARIOS_PRUEBA+=("$EMAIL_2")
api_alta_usuario "$(json_usuario "$EMAIL_2" "$HASH_PRUEBA" Ana 0)"
espera 200 "Se dio de alta el usuario" "alta de un usuario sin foto"
api_login "$EMAIL_2" "$HASH_PRUEBA"
api_consulta_usuario "$(jget .id_usuario)" "$(jget .token)"
espera_jq '.foto == null' "sin foto: la consulta regresa foto null"

# Campos obligatorios
BASE_JSON="$(json_usuario "zz_test_${RUN}_invalido@example.com" "$HASH_PRUEBA")"
api_alta_usuario "$(jq 'del(.email)' <<<"$BASE_JSON")"
espera 400 "Se debe ingresar el email" "falta el email"
api_alta_usuario "$(jq 'del(.password)' <<<"$BASE_JSON")"
espera 400 "Se debe ingresar la contraseña" "falta la contraseña"
api_alta_usuario "$(jq 'del(.nombre)' <<<"$BASE_JSON")"
espera 400 "Se debe ingresar el nombre" "falta el nombre"
api_alta_usuario "$(jq 'del(.apellido_paterno)' <<<"$BASE_JSON")"
espera 400 "Se debe ingresar el apellido paterno" "falta el apellido paterno"
api_alta_usuario "$(jq 'del(.fecha_nacimiento)' <<<"$BASE_JSON")"
espera 400 "Se debe ingresar la fecha de nacimiento" "falta la fecha de nacimiento"

api_login "zz_test_${RUN}_invalido@example.com" "$HASH_PRUEBA"
espera 400 "Acceso denegado" "los intentos inválidos no crearon el usuario"

resumen
