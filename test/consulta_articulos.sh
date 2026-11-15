#!/usr/bin/env bash
# Prueba de GET /consulta_articulos
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "consulta_articulos"

nuevo_usuario U
nuevo_articulo PERA "$U_ID" "$U_TOKEN" pera 12.5 4 "fruta verde"
nuevo_articulo MANZANA "$U_ID" "$U_TOKEN" manzana 8 6 "fruta roja u${RUN}"
P="zz_test_${RUN}"

api_consulta_articulos "$PERA_NOMBRE" "$U_ID" "$U_TOKEN"
espera 200 - "búsqueda por nombre completo"
espera_jq "length == 1 and .[0].id_articulo == $PERA" "regresa solo el artículo buscado"
espera_jq '.[0] | has("id_articulo") and has("nombre") and has("descripcion") and has("precio") and has("fotografia")' "cada artículo trae id, nombre, descripción, precio y fotografía"
espera_jq '.[0] | has("cantidad") | not' "no expone la cantidad en existencia"

api_consulta_articulos "u${RUN}" "$U_ID" "$U_TOKEN"
espera_jq "length == 1 and .[0].id_articulo == $MANZANA" "la palabra también se busca en la descripción"

api_consulta_articulos "$P" "$U_ID" "$U_TOKEN"
espera_jq 'length == 2' "busca por parte del nombre (LIKE): 2 resultados"
espera_jq ".[0].id_articulo == $MANZANA and .[1].id_articulo == $PERA" "los resultados vienen ordenados por nombre"

api_consulta_articulos "inexistente_${RUN}_xx" "$U_ID" "$U_TOKEN"
espera 200 - "palabra sin coincidencias"
espera_jq 'type == "array" and length == 0' "regresa un arreglo vacío"

api_consulta_articulos "" "$U_ID" "$U_TOKEN"
espera 200 - "palabra vacía"
espera_jq "[.[] | select(.id_articulo == $PERA or .id_articulo == $MANZANA)] | length == 2" "palabra vacía: lista todos los artículos"

api_consulta_articulos "$P" "$U_ID" "token_falso"
espera 400 "Acceso denegado" "token inválido"

resumen
