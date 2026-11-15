#!/usr/bin/env bash
# Prueba de PUT /compra_articulo
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "compra_articulo"

nuevo_usuario U
nuevo_articulo A "$U_ID" "$U_TOKEN" compra 15 10      # stock inicial: 10

# --- Primera compra: INSERT en el carrito
api_compra "$U_ID" "$U_TOKEN" "$A" 3
espera 200 OK "compra 3 de 10 (stock queda en 7)"
api_carrito "$U_ID" "$U_TOKEN"
espera_jq "[.[] | select(.id_articulo == $A)] | length == 1 and .[0].cantidad == 3" "el artículo entró al carrito con cantidad 3"

# --- Segunda compra del mismo artículo: suma, no duplica
api_compra "$U_ID" "$U_TOKEN" "$A" 3
espera 200 OK "compra otras 3 (stock queda en 4)"
api_carrito "$U_ID" "$U_TOKEN"
espera_jq "[.[] | select(.id_articulo == $A)] | length == 1 and .[0].cantidad == 6" "la cantidad se sumó en la misma línea del carrito (6)"

# --- Más de lo que hay
api_compra "$U_ID" "$U_TOKEN" "$A" 5
espera 400 "No hay suficientes artículos en el stock" "pedir 5 cuando quedan 4"
api_carrito "$U_ID" "$U_TOKEN"
espera_jq "[.[] | select(.id_articulo == $A)] | .[0].cantidad == 6" "la compra rechazada no cambió el carrito"

# --- Justo lo que queda
api_compra "$U_ID" "$U_TOKEN" "$A" 4
espera 200 OK "compra las 4 que quedaban (stock en 0)"
api_compra "$U_ID" "$U_TOKEN" "$A" 1
espera 400 "No hay suficientes artículos en el stock" "con stock en 0 ya no se puede comprar"

# --- Otro usuario también depende del mismo stock
nuevo_usuario V
api_compra "$V_ID" "$V_TOKEN" "$A" 1
espera 400 "No hay suficientes artículos en el stock" "el stock es compartido entre usuarios"

# --- Validaciones
api_compra "$U_ID" "$U_TOKEN" "$A" 0
espera 400 "La cantidad a comprar debe ser mayor que cero" "cantidad 0"
api_compra "$U_ID" "$U_TOKEN" "$A" -2
espera 400 "La cantidad a comprar debe ser mayor que cero" "cantidad negativa"
api_compra "$U_ID" "$U_TOKEN" 2147483000 1
espera 400 "El artículo no existe" "artículo inexistente"
api_compra "$U_ID" "token_falso" "$A" 1
espera 400 "Acceso denegado" "token inválido"

resumen
