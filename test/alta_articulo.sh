#!/usr/bin/env bash
# Prueba de POST /alta_articulo
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "alta_articulo"

nuevo_usuario U
P="zz_test_${RUN}"

# --- Alta válida
api_alta_articulo "$U_ID" "$U_TOKEN" "$(json_articulo "${P}_valido" 42.5 10 "Frasco de 400 g")"
espera 200 OK "alta de un artículo válido"
api_consulta_articulos "${P}_valido" "$U_ID" "$U_TOKEN"
espera_jq 'length == 1 and .[0].precio == 42.5 and .[0].descripcion == "Frasco de 400 g"' "el artículo quedó en stock con su precio y descripción"
espera_jq '(.[0].fotografia | type == "string") and (.[0].fotografia | length > 0)' "la fotografía quedó guardada"

# --- Descripción vacía es válida
api_alta_articulo "$U_ID" "$U_TOKEN" "$(json_articulo "${P}_sin_desc" 10 1 "")"
espera 200 OK "alta sin descripción"
api_consulta_articulos "${P}_sin_desc" "$U_ID" "$U_TOKEN"
espera_jq 'length == 1 and (.[0] | has("descripcion") | not)' "sin descripción: el campo no se incluye en la consulta"

# --- Validaciones (y que no se guarde nada si fallan)
api_alta_articulo "$U_ID" "$U_TOKEN" "$(json_articulo "${P}_inv_nombre" 10 1 | jq 'del(.nombre)')"
espera 400 "Se debe ingresar el nombre del artículo" "falta el nombre"
api_alta_articulo "$U_ID" "$U_TOKEN" "$(json_articulo "${P}_inv_precio" -1 1)"
espera 400 "Se debe ingresar un precio válido" "precio negativo"
api_alta_articulo "$U_ID" "$U_TOKEN" "$(json_articulo "${P}_inv_precio2" 10 1 | jq 'del(.precio)')"
espera 400 "Se debe ingresar un precio válido" "falta el precio"
api_alta_articulo "$U_ID" "$U_TOKEN" "$(json_articulo "${P}_inv_cant" 10 -1)"
espera 400 "Se debe ingresar una cantidad válida" "cantidad negativa"
api_alta_articulo "$U_ID" "$U_TOKEN" "$(json_articulo "${P}_inv_cant2" 10 1 | jq 'del(.cantidad)')"
espera 400 "Se debe ingresar una cantidad válida" "falta la cantidad"
api_alta_articulo "$U_ID" "$U_TOKEN" "$(json_articulo "${P}_inv_foto" 10 1 "Sin foto" 0)"
espera 400 "Se debe ingresar la fotografía del artículo" "falta la fotografía"

api_alta_articulo "$U_ID" "token_falso" "$(json_articulo "${P}_inv_token" 10 1)"
espera 400 "Acceso denegado" "token inválido"

api_consulta_articulos "${P}_inv" "$U_ID" "$U_TOKEN"
espera_jq 'length == 0' "ninguno de los intentos inválidos guardó un artículo"

resumen
