<script setup>
// Selector de la fotografía de un artículo (tarjeta con vista previa cuadrada).
// v-model = base64 JPEG (sin el prefijo "data:...;base64,") o null.
// En un celular, accept="image/*" ofrece tomar la foto con la cámara.
import { ref } from "vue";
import { useDialogo } from "../composables/dialogo.js";
import { reduceImagen } from "../utils/imagen.js";
import { srcFotoArticulo } from "../utils/articulo.js";
import Icono from "./Icono.vue";

const foto = defineModel({ type: String, default: null });

const { alerta } = useDialogo();
const archivo = ref(null);
const arrastrando = ref(false);
const procesando = ref(false);

async function lee(file) {
  if (!file) return;
  if (!file.type.startsWith("image/")) {
    alerta("El archivo seleccionado no es una imagen.", { tipo: "error", titulo: "Archivo no válido" });
    return;
  }
  procesando.value = true;
  try {
    foto.value = await reduceImagen(file);
  } catch {
    alerta("No se pudo leer la imagen.", { tipo: "error" });
  } finally {
    procesando.value = false;
  }
}

function eligeArchivo(e) {
  lee(e.target.files[0]);
  e.target.value = "";
}

function suelta(e) {
  arrastrando.value = false;
  lee(e.dataTransfer?.files?.[0]);
}

const abrirSelector = () => archivo.value?.click();
const quita = () => (foto.value = null);
</script>

<template>
  <input ref="archivo" type="file" accept="image/*" class="sr-only" tabindex="-1" aria-hidden="true" @change="eligeArchivo" />

  <section
    class="tarjeta flex flex-col items-center gap-4 p-7 text-center"
    @dragover.prevent="arrastrando = true"
    @dragleave="arrastrando = false"
    @drop.prevent="suelta"
  >
    <div
      :class="[
        'grid aspect-square w-full max-w-[240px] place-items-center overflow-hidden rounded-2xl border-2 border-dashed transition',
        arrastrando ? 'border-marca bg-marca-anillo' : 'border-[#a9bbe6] bg-marca-suave',
        foto ? 'border-solid border-superficie ring-1 ring-borde' : '',
      ]"
    >
      <img v-if="foto" :src="srcFotoArticulo(foto)" alt="Fotografía del artículo" class="size-full object-cover" />
      <span v-else-if="procesando" class="size-6 animate-spin rounded-full border-2 border-marca/30 border-t-marca" />
      <Icono v-else nombre="caja" :tam="44" class="text-marca" />
    </div>
    <div>
      <h2 class="text-base font-semibold">Fotografía <span class="text-marca">*</span></h2>
      <p class="mt-1.5 text-sm leading-normal text-tinta-suave">Toma una foto o elige una imagen del artículo.</p>
    </div>
    <div class="flex flex-wrap justify-center gap-2">
      <button type="button" class="btn-secundario" :disabled="procesando" @click="abrirSelector">
        <Icono nombre="camara" :tam="16" /> {{ foto ? "Cambiar imagen" : "Elegir imagen" }}
      </button>
      <button v-if="foto" type="button" class="btn-fantasma" @click="quita">Quitar</button>
    </div>
  </section>
</template>
