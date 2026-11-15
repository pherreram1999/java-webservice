/*
  Store (Pinia) del carrito de compra.
  Es la única fuente de verdad del carrito: la usan el encabezado (contador estilo Amazon),
  la vista de compra (agregar) y la vista del carrito (listar / eliminar).
  Las acciones devuelven { ok, datos } para que cada vista decida cómo mostrar el error.
*/
import { defineStore } from "pinia";
import { computed, ref } from "vue";
import { servicio } from "../api/servicio.js";
import { useSesion } from "../composables/sesion.js";
import { costo } from "../utils/articulo.js";

export const useCarritoStore = defineStore("carrito", () => {
  const { credenciales } = useSesion();

  const articulos = ref([]);
  const cargando = ref(false);
  const cargado = ref(false); // true tras la primera consulta correcta

  // Número de piezas (suma de cantidades), como el globo naranja de Amazon
  const cantidadTotal = computed(() => articulos.value.reduce((s, a) => s + Number(a.cantidad), 0));
  const total = computed(
    () => articulos.value.reduce((s, a) => s + Math.round(costo(a.precio, a.cantidad) * 100), 0) / 100,
  );

  async function carga() {
    cargando.value = true;
    const r = await servicio.consultaCarritoCompra(credenciales());
    cargando.value = false;
    if (r.ok) {
      articulos.value = r.datos;
      cargado.value = true;
    }
    return r;
  }

  // Ejecuta una operación del servicio y, si tuvo éxito, vuelve a consultar el carrito
  async function conRecarga(operacion) {
    const r = await operacion();
    if (r.ok) await carga();
    return r;
  }

  const agrega = (id_articulo, cantidad) =>
    conRecarga(() => servicio.compraArticulo(credenciales(), id_articulo, cantidad));
  const eliminaArticulo = (id_articulo) =>
    conRecarga(() => servicio.eliminaArticuloCarritoCompra(credenciales(), id_articulo));
  const vacia = () => conRecarga(() => servicio.eliminaCarritoCompra(credenciales()));

  // Al cerrar sesión no debe quedar nada del carrito anterior
  function reinicia() {
    articulos.value = [];
    cargando.value = false;
    cargado.value = false;
  }

  return { articulos, cargando, cargado, cantidadTotal, total, carga, agrega, eliminaArticulo, vacia, reinicia };
});
