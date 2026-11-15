<script setup>
// Captura de artículo (RF-FE-1): alta en stock + fotografía.
import { ref } from "vue";
import { servicio } from "../api/servicio.js";
import { useSesion } from "../composables/sesion.js";
import { useDialogo } from "../composables/dialogo.js";
import { useAccesoProtegido } from "../composables/accesoProtegido.js";
import { aArticuloServicio, articuloVacio } from "../utils/articulo.js";
import FotoArticulo from "../components/FotoArticulo.vue";
import Icono from "../components/Icono.vue";

const { credenciales } = useSesion();
const { alerta } = useDialogo();
const { reportaError } = useAccesoProtegido();

const articulo = ref(articuloVacio());
const ocupado = ref(false);

async function guardar() {
  if (!articulo.value.fotografia) {
    await alerta("Elige o toma la fotografía del artículo.", { tipo: "error", titulo: "Falta la fotografía" });
    return;
  }
  ocupado.value = true;
  const r = await servicio.altaArticulo(credenciales(), aArticuloServicio(articulo.value));
  ocupado.value = false;
  if (!r.ok) {
    await reportaError(r.datos, "No se pudo dar de alta el artículo");
    return;
  }
  articulo.value = articuloVacio();
  await alerta("Se dio de alta el artículo.", { tipo: "exito", titulo: "Artículo guardado" });
}
</script>

<template>
  <div class="mx-auto w-full max-w-[1120px] px-4 pt-8 pb-16 sm:px-6">
    <RouterLink to="/inicio" class="btn-fantasma -ml-3 h-10 px-3">
      <Icono nombre="flecha" :tam="16" /> Regresar al menú
    </RouterLink>
    <h1 class="titulo mt-3">Captura de artículo</h1>
    <p class="mt-2 text-[15px] text-tinta-suave">
      Los campos marcados con <span class="text-marca">*</span> son obligatorios.
    </p>

    <form class="mt-8 flex flex-wrap items-start gap-6" @submit.prevent="guardar">
      <div class="w-full min-w-0 md:max-w-[340px] md:flex-[1_1_280px]">
        <FotoArticulo v-model="articulo.fotografia" />
      </div>

      <div class="flex min-w-0 flex-[999_1_560px] flex-col gap-6">
        <section class="tarjeta p-7">
          <h2 class="text-[17px] font-semibold">Datos del artículo</h2>
          <div class="mt-5 grid gap-x-5 gap-y-4 sm:grid-cols-2">
            <div class="sm:col-span-2">
              <label class="etiqueta" for="a-nombre">Nombre <span class="requerido">*</span></label>
              <input id="a-nombre" v-model="articulo.nombre" type="text" class="campo" required maxlength="100" />
            </div>
            <div class="sm:col-span-2">
              <label class="etiqueta" for="a-descripcion">Descripción</label>
              <textarea
                id="a-descripcion"
                v-model="articulo.descripcion"
                rows="3"
                maxlength="500"
                class="campo h-auto py-3"
              />
            </div>
            <div>
              <label class="etiqueta" for="a-precio">Precio <span class="requerido">*</span></label>
              <input
                id="a-precio"
                v-model="articulo.precio"
                type="number"
                class="campo"
                required
                min="0"
                max="99999999.99"
                step="0.01"
                inputmode="decimal"
                placeholder="0.00"
              />
            </div>
            <div>
              <label class="etiqueta" for="a-cantidad">Cantidad en existencia <span class="requerido">*</span></label>
              <input
                id="a-cantidad"
                v-model="articulo.cantidad"
                type="number"
                class="campo"
                required
                min="0"
                step="1"
                inputmode="numeric"
                placeholder="0"
              />
            </div>
          </div>
        </section>

        <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <RouterLink to="/inicio" class="btn-secundario h-12 px-[22px] text-[15px]">Cancelar</RouterLink>
          <button type="submit" class="btn-primario h-12 px-7 text-[15px]" :disabled="ocupado">
            <span v-if="ocupado" class="size-4 animate-spin rounded-full border-2 border-white/40 border-t-white" />
            Guardar artículo
          </button>
        </div>
      </div>
    </form>
  </div>
</template>
