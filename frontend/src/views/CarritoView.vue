<script setup>
// Artículos en el carrito (RF-FE-2.3 a 2.5): lista, total, eliminar artículo / carrito.
import { onMounted, ref } from "vue";
import { storeToRefs } from "pinia";
import { useRoute, useRouter } from "vue-router";
import { useCarritoStore } from "../stores/carrito.js";
import { useDialogo } from "../composables/dialogo.js";
import { useAccesoProtegido } from "../composables/accesoProtegido.js";
import { costo, moneda, srcFotoArticulo } from "../utils/articulo.js";
import Icono from "../components/Icono.vue";

const route = useRoute();
const router = useRouter();
const { confirma } = useDialogo();
const { reportaError } = useAccesoProtegido();

const carrito = useCarritoStore();
const { articulos, total, cargado } = storeToRefs(carrito);
const ocupado = ref(false);

// Esqueleto solo mientras no hay datos; si el store ya los tiene (encabezado) se muestran al instante y se refrescan
const cargando = ref(!cargado.value);

onMounted(async () => {
  const r = await carrito.carga();
  cargando.value = false;
  if (!r.ok) await reportaError(r.datos, "No se pudo consultar el carrito");
});

async function eliminaArticulo(a) {
  const ok = await confirma(`Se quitará "${a.nombre}" del carrito y volverá al stock.`, {
    titulo: "¿Eliminar artículo?",
    tipo: "peligro",
    aceptar: "Eliminar artículo",
  });
  if (!ok) return;
  ocupado.value = true;
  const r = await carrito.eliminaArticulo(a.id_articulo);
  ocupado.value = false;
  if (!r.ok) await reportaError(r.datos, "No se pudo eliminar el artículo");
}

async function eliminaCarrito() {
  const ok = await confirma("Se vaciará el carrito y todos los artículos volverán al stock.", {
    titulo: "¿Eliminar el carrito?",
    tipo: "peligro",
    aceptar: "Eliminar carrito",
  });
  if (!ok) return;
  ocupado.value = true;
  const r = await carrito.vacia();
  ocupado.value = false;
  if (!r.ok) await reportaError(r.datos, "No se pudo eliminar el carrito");
}

function seguirComprando() {
  router.push({
    name: "compra-articulos",
    query: typeof route.query.palabra === "string" ? { palabra: route.query.palabra } : {},
  });
}
</script>

<template>
  <div class="mx-auto w-full max-w-[1120px] px-4 pt-8 pb-16 sm:px-6">
    <button type="button" class="btn-fantasma -ml-3 h-10 px-3" @click="seguirComprando">
      <Icono nombre="flecha" :tam="16" /> Seguir comprando
    </button>
    <h1 class="titulo mt-3">Artículos en el carrito</h1>

    <div class="mt-8 flex flex-col gap-4">
      <div v-if="cargando" class="tarjeta flex gap-4 p-5" aria-busy="true">
        <div class="size-20 animate-pulse rounded-xl bg-hundido" />
        <div class="flex-1 space-y-2">
          <div class="h-5 w-40 animate-pulse rounded bg-hundido" />
          <div class="h-4 w-56 max-w-full animate-pulse rounded bg-hundido" />
        </div>
      </div>

      <p v-else-if="articulos.length === 0" class="tarjeta p-8 text-center text-sm text-tinta-suave">
        Tu carrito está vacío.
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
          <dl class="mt-2 grid grid-cols-3 gap-3 text-sm">
            <div>
              <dt class="text-[13px] text-tinta-suave">Cantidad</dt>
              <dd class="font-medium">{{ a.cantidad }}</dd>
            </div>
            <div>
              <dt class="text-[13px] text-tinta-suave">Precio</dt>
              <dd class="font-medium">{{ moneda(a.precio) }}</dd>
            </div>
            <div>
              <dt class="text-[13px] text-tinta-suave">Costo</dt>
              <dd class="font-semibold text-marca">{{ moneda(costo(a.precio, a.cantidad)) }}</dd>
            </div>
          </dl>
        </div>
        <button
          type="button"
          class="btn-peligro-contorno w-full sm:w-auto"
          :disabled="ocupado"
          @click="eliminaArticulo(a)"
        >
          <Icono nombre="basura" :tam="16" /> Eliminar artículo
        </button>
      </article>
      </template>
    </div>

    <!-- Total y acciones -->
    <section class="tarjeta mt-6 flex flex-wrap items-center justify-between gap-4 p-6">
      <p class="text-[15px] text-tinta-suave">
        Total de la compra
        <span class="ml-2 font-display text-2xl font-semibold text-tinta">{{ moneda(total) }}</span>
      </p>
      <div class="flex w-full flex-col gap-2 sm:w-auto sm:flex-row">
        <button
          type="button"
          class="btn-peligro-contorno"
          :disabled="ocupado || articulos.length === 0"
          @click="eliminaCarrito"
        >
          Eliminar carrito
        </button>
        <button type="button" class="btn-primario" @click="seguirComprando">Seguir comprando</button>
      </div>
    </section>
  </div>
</template>
