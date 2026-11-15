/*
  Conversión entre el formulario de artículo y el objeto Articulo del servicio REST,
  más utilidades de presentación (moneda, costo).
*/
import { FOTO_POR_DEFECTO } from "./usuario.js";

export function articuloVacio() {
  return {
    nombre: "",
    descripcion: "",
    precio: "",
    cantidad: "",
    fotografia: null, // base64 sin el prefijo "data:...;base64,"
  };
}

const vacioANull = (v) => (v == null || String(v).trim() === "" ? null : String(v).trim());

// Formulario -> cuerpo JSON de alta_articulo
export function aArticuloServicio(f) {
  return {
    nombre: f.nombre.trim(),
    descripcion: vacioANull(f.descripcion),
    precio: f.precio === "" || f.precio == null ? null : Number(f.precio),
    cantidad: f.cantidad === "" || f.cantidad == null ? null : Number(f.cantidad),
    fotografia: f.fotografia,
  };
}

export function srcFotoArticulo(fotografia) {
  return fotografia ? `data:image/jpeg;base64,${fotografia}` : FOTO_POR_DEFECTO;
}

const formatoMoneda = new Intl.NumberFormat("es-MX", { style: "currency", currency: "MXN" });
export const moneda = (n) => formatoMoneda.format(n ?? 0);

// Costo de una partida (cantidad x precio) calculado en centavos para evitar errores de coma flotante
export const costo = (precio, cantidad) => Math.round(Number(precio) * 100) * Number(cantidad) / 100;
