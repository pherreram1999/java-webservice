#!/usr/bin/env bash
# Prueba de DELETE /borra_usuario
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
titulo "borra_usuario"

# --- Usuario simple (con foto, sin carrito)
nuevo_usuario W
api_borra_usuario "$W_ID" "token_falso"
espera 400 "Acceso denegado" "token inválido: no borra nada"
api_consulta_usuario "$W_ID" "$W_TOKEN"
espera 200 - "el usuario sigue existiendo tras el intento inválido"

api_borra_usuario "$W_ID" "$W_TOKEN"
espera 200 "Se borró el usuario" "borra el usuario (y su foto)"
api_login "$W_EMAIL" "$W_HASH"
espera 400 "Acceso denegado" "ya no puede iniciar sesión"
api_consulta_usuario "$W_ID" "$W_TOKEN"
espera 400 "Acceso denegado" "su token ya no es válido"

# --- Usuario con artículos en el carrito: deben regresar al stock
nuevo_usuario U
nuevo_usuario V
nuevo_articulo A "$V_ID" "$V_TOKEN" borra 10.5 5

api_compra "$U_ID" "$U_TOKEN" "$A" 5
espera 200 OK "U compra todo el stock del artículo (5 de 5)"
api_compra "$V_ID" "$V_TOKEN" "$A" 1
espera 400 "No hay suficientes artículos en el stock" "el stock quedó en 0"

api_borra_usuario "$U_ID" "$U_TOKEN"
espera 200 "Se borró el usuario" "borra al usuario que tenía el carrito lleno"

api_compra "$V_ID" "$V_TOKEN" "$A" 5
espera 200 OK "las 5 unidades del carrito del usuario borrado regresaron al stock"

resumen
