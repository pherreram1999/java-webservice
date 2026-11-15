#!/usr/bin/env bash
# Prueba de DELETE /elimina_articulo_carrito_compra
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "elimina_articulo_carrito_compra"

nuevo_usuario U
nuevo_usuario V
nuevo_articulo A "$U_ID" "$U_TOKEN" aaa 10 5     # stock 5
nuevo_articulo B "$U_ID" "$U_TOKEN" bbb 20 5     # stock 5

api_compra "$U_ID" "$U_TOKEN" "$A" 5            # A: stock 0
api_compra "$U_ID" "$U_TOKEN" "$B" 2            # B: stock 3
api_compra "$V_ID" "$V_TOKEN" "$B" 1            # B: stock 2 (V también lo tiene en su carrito)

api_elimina_articulo "$U_ID" "$U_TOKEN" "$A"
espera 200 OK "elimina el artículo A del carrito"
api_carrito "$U_ID" "$U_TOKEN"
espera_jq "length == 1 and .[0].id_articulo == $B" "en el carrito solo queda el artículo B"

api_compra "$V_ID" "$V_TOKEN" "$A" 5
espera 200 OK "las 5 unidades de A regresaron al stock (otro usuario puede comprarlas)"

api_elimina_articulo "$U_ID" "$U_TOKEN" "$A"
espera 400 "El artículo no está en el carrito de compra" "A ya no está en el carrito de U"

api_elimina_articulo "$U_ID" "$U_TOKEN" "$B"
espera 200 OK "elimina el artículo B del carrito de U"
api_carrito "$V_ID" "$V_TOKEN"
espera_jq "[.[] | select(.id_articulo == $B)] | length == 1 and .[0].cantidad == 1" "el carrito de V conserva B (no se tocan artículos de otros usuarios)"
api_compra "$U_ID" "$U_TOKEN" "$B" 4
espera 200 OK "B: el stock recuperó las 2 de U (2 + 2 = 4 disponibles)"

api_elimina_articulo "$U_ID" "token_falso" "$B"
espera 400 "Acceso denegado" "token inválido"
api_elimina_articulo "$U_ID" "$U_TOKEN" 2147483000
espera 400 "El artículo no está en el carrito de compra" "artículo inexistente"

resumen
