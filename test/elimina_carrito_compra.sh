#!/usr/bin/env bash
# Prueba de DELETE /elimina_carrito_compra
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "elimina_carrito_compra"

nuevo_usuario U
nuevo_usuario V
nuevo_articulo A "$U_ID" "$U_TOKEN" aaa 10 5     # stock 5
nuevo_articulo B "$U_ID" "$U_TOKEN" bbb 20 2     # stock 2

api_compra "$U_ID" "$U_TOKEN" "$A" 3            # A: stock 2
api_compra "$U_ID" "$U_TOKEN" "$B" 2            # B: stock 0
api_compra "$V_ID" "$V_TOKEN" "$A" 2            # A: stock 0 (carrito de V)

api_carrito "$U_ID" "$U_TOKEN"
espera_jq 'length == 2' "antes de borrar, U tiene 2 artículos en el carrito"

api_elimina_carrito "$U_ID" "$U_TOKEN"
espera 200 OK "vacía el carrito de U"
api_carrito "$U_ID" "$U_TOKEN"
espera_jq 'length == 0' "el carrito de U quedó vacío"

api_carrito "$V_ID" "$V_TOKEN"
espera_jq "length == 1 and .[0].id_articulo == $A and .[0].cantidad == 2" "el carrito de V no se tocó"

api_compra "$V_ID" "$V_TOKEN" "$A" 3
espera 200 OK "A: las 3 unidades de U regresaron al stock"
api_compra "$V_ID" "$V_TOKEN" "$A" 1
espera 400 "No hay suficientes artículos en el stock" "A: no regresó de más"
api_compra "$V_ID" "$V_TOKEN" "$B" 2
espera 200 OK "B: las 2 unidades de U regresaron al stock"

api_elimina_carrito "$U_ID" "$U_TOKEN"
espera 200 OK "vaciar un carrito que ya está vacío también es correcto"

api_elimina_carrito "$U_ID" "token_falso"
espera 400 "Acceso denegado" "token inválido"

resumen
