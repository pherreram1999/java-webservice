#!/usr/bin/env bash
# Prueba de GET /consulta_carrito_compra
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "consulta_carrito_compra"

nuevo_usuario U
nuevo_usuario V
nuevo_articulo A "$U_ID" "$U_TOKEN" aaa 10.5 5
nuevo_articulo B "$U_ID" "$U_TOKEN" bbb 4 5

api_carrito "$U_ID" "$U_TOKEN"
espera 200 - "carrito recién creado"
espera_jq 'type == "array" and length == 0' "un carrito sin compras regresa un arreglo vacío"

api_compra "$U_ID" "$U_TOKEN" "$B" 3
api_compra "$U_ID" "$U_TOKEN" "$A" 2
api_carrito "$U_ID" "$U_TOKEN"
espera 200 - "carrito con dos artículos"
espera_jq 'length == 2' "regresa los 2 artículos comprados"
espera_jq '.[0].nombre < .[1].nombre' "vienen ordenados por nombre"
espera_jq ".[0].id_articulo == $A and .[0].cantidad == 2 and .[0].precio == 10.5" "primer artículo: id, cantidad y precio"
espera_jq ".[1].id_articulo == $B and .[1].cantidad == 3 and .[1].precio == 4" "segundo artículo: id, cantidad y precio"
espera_jq 'all(.[]; has("nombre") and has("fotografia") and (.fotografia | length > 0))' "cada línea trae nombre y fotografía"
espera_jq '(map(.precio * .cantidad) | add) == 33' "el total (cantidad x precio) es 2x10.5 + 3x4 = 33"

api_carrito "$V_ID" "$V_TOKEN"
espera_jq 'length == 0' "el carrito de otro usuario no se mezcla con el mío"

api_carrito "$U_ID" "token_falso"
espera 400 "Acceso denegado" "token inválido"

resumen
