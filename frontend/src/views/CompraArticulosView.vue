<script setup>
// Compra de artículos (RF-FE-2): búsqueda en stock y compra hacia el carrito.
import { onMounted, reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { servicio } from "../api/servicio.js";
import { useSesion } from "../composables/sesion.js";
import { useCarritoStore } from "../stores/carrito.js";
import { useDialogo } from "../composables/dialogo.js";
import { useAccesoProtegido } from "../composables/accesoProtegido.js";
import { moneda, srcFotoArticulo } from "../utils/articulo.js";
import Icono from "../components/Icono.vue";

const route = useRoute();
const router = useRouter();
const { credenciales } = useSesion();
const carrito = useCarritoStore();
const { confirma } = useDialogo();
const { reportaError } = useAccesoProtegido();

const palabra = ref(typeof route.query.palabra === "string" ? route.query.palabra : "");
const articulos = ref([]);
const buscado = ref(false);
const cargando = ref(false);
const comprando = ref(null); // id_articulo en proceso de compra
const cantidades = reactive({}); // id_articulo -> cantidad a comprar (default 1)

async function busca() {
  cargando.value = true;
  const r = await servicio.consultaArticulos(credenciales(), palabra.value.trim());
  cargando.value = false;
  if (!r.ok) {
    await reportaError(r.datos, "No se pudo buscar");
    return;
  }
  articulos.value = r.datos;
  buscado.value = true;
  for (const a of r.datos) if (!(a.id_articulo in cantidades)) cantidades[a.id_articulo] = 1;
  // Se recuerda la palabra para repetir la búsqueda al volver del carrito
  router.replace({ query: palabra.value.trim() ? { palabra: palabra.value.trim() } : {} });
}

onMounted(() => {
  if (route.query.palabra !== undefined) busca();
});

function irAlCarrito() {
  router.push({ name: "carrito", query: palabra.value.trim() ? { palabra: palabra.value.trim() } : {} });
}

async function compra(a) {
  const cantidad = Number(cantidades[a.id_articulo]);
  if (!Number.isInteger(cantidad) || cantidad < 1) {
    await reportaError({ mensaje: "La cantidad debe ser un número entero mayor que cero" }, "Cantidad no válida");
    return;
  }
  comprando.value = a.id_articulo;
  const r = await carrito.agrega(a.id_articulo, cantidad);
  comprando.value = null;
  if (!r.ok) {
    await reportaError(r.datos, "No se pudo comprar");
    return;
  }
  cantidades[a.id_articulo] = 1;
  const alCarrito = await confirma(`Se agregó al carrito: ${cantidad} × ${a.nombre}.`, {
    titulo: "Artículo agregado",
    tipo: "exito",
    aceptar: "Ver carrito",
    cancelar: "Seguir comprando",
  });
  if (alCarrito) irAlCarrito();
}
</script>

<template>
  <div class="mx-auto w-full max-w-[1120px] px-4 pt-8 pb-16 sm:px-6">
    <RouterLink to="/inicio" class="btn-fantasma -ml-3 h-10 px-3">
      <Icono nombre="flecha" :tam="16" /> Regresar al menú
    </RouterLink>

    <div class="mt-3 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 class="titulo">Compra de artículos</h1>
        <p class="mt-2 text-[15px] text-tinta-suave">Busca por nombre o descripción y agrega al carrito.</p>
      </div>
      <button type="button" class="btn-secundario" @click="irAlCarrito">
        <Icono nombre="carrito" :tam="16" /> Carrito de compra
      </button>
    </div>

    <form class="mt-6 flex gap-2" role="search" @submit.prevent="busca">
      <input
        v-model="palabra"
        type="search"
        class="campo min-w-0 flex-1"
        placeholder="Ej. mayonesa (vacío = todos)"
        aria-label="Palabra a buscar"
        enterkeyhint="search"
      />
      <button type="submit" class="btn-primario h-[46px]" :disabled="cargando">
        <Icono nombre="buscar" :tam="16" /> Buscar
      </button>
    </form>

    <div class="mt-6 flex flex-col gap-4">
      <template v-if="cargando">
        <div v-for="n in 3" :key="n" class="tarjeta flex gap-4 p-5" aria-busy="true">
          <div class="size-20 animate-pulse rounded-xl bg-hundido" />
          <div class="flex-1 space-y-2">
            <div class="h-5 w-40 animate-pulse rounded bg-hundido" />
            <div class="h-4 w-64 max-w-full animate-pulse rounded bg-hundido" />
          </div>
        </div>
      </template>

      <p v-else-if="!buscado" class="tarjeta p-8 text-center text-sm text-tinta-suave">
        Escribe una palabra y presiona Buscar.
      </p>
      <p v-else-if="articulos.length === 0" class="tarjeta p-8 text-center text-sm text-tinta-suave">
        No se encontraron artículos.
      </p>

      <template v-else>
      <article
        v-for="a in articulos"
        :key="a.id_articulo"
        class="tarjeta flex flex-wrap items-center gap-x-5 gap-y-4 p-5"
      >
        <img
          :src="srcFotoArticulo(a.fotografia)"
          :alt="`Fotografía de ${a.nombre}`"
          class="size-20 shrink-0 rounded-xl border border-borde object-cover"
        />
        <div class="min-w-0 flex-[1_1_200px]">
          <h2 class="text-[17px] font-semibold">{{ a.nombre }}</h2>
          <p v-if="a.descripcion" class="mt-1 text-sm leading-normal text-tinta-suave">{{ a.descripcion }}</p>
          <p class="mt-2 font-display text-lg font-semibold text-marca">{{ moneda(a.precio) }}</p>
        </div>
        <div class="flex w-full items-end gap-2 sm:w-auto">
          <div class="w-24">
            <label class="etiqueta !mb-1 text-[13px]" :for="`c-${a.id_articulo}`">Cantidad</label>
            <input
              :id="`c-${a.id_articulo}`"
              v-model="cantidades[a.id_articulo]"
              type="number"
              class="campo"
              min="1"
              step="1"
              inputmode="numeric"
            />
          </div>
          <button
            type="button"
            class="btn-primario h-[46px] flex-1 sm:flex-none"
            :disabled="comprando === a.id_articulo"
            @click="compra(a)"
          >
            <span
              v-if="comprando === a.id_articulo"
              class="size-4 animate-spin rounded-full border-2 border-white/40 border-t-white"
            />
            Compra
          </button>
        </div>
      </article>
      </template>
    </div>
  </div>
</template>
