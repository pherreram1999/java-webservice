#!/usr/bin/env bash
# Prueba de GET /consulta_usuario
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "consulta_usuario"

nuevo_usuario U
nuevo_usuario V

api_consulta_usuario "$U_ID" "$U_TOKEN"
espera 200 - "consulta con sesión válida"
espera_jq ".email == \"$U_EMAIL\"" "regresa el email del usuario"
espera_jq '.nombre == "Ana" and .apellido_paterno == "Perez" and .genero == "F"' "regresa nombre, apellido paterno y género"
espera_jq '.telefono == 5512345678' "regresa el teléfono"
espera_jq '(.fecha_nacimiento | type == "string") and (.fecha_nacimiento | startswith("2000-01-3"))' "regresa la fecha de nacimiento"
espera_jq '(.foto | type == "string") and (.foto | length > 0)' "regresa la foto en base64"
espera_jq '.password == null' "no regresa la contraseña"

api_consulta_usuario "$U_ID" "token_falso"
espera 400 "Acceso denegado" "token inválido"
api_consulta_usuario "$V_ID" "$U_TOKEN"
espera 400 "Acceso denegado" "el token de un usuario no sirve para consultar a otro"

resumen
