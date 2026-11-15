<script setup>
// Selector de foto de perfil.
//   variante="tarjeta": columna con zona para soltar la imagen (registro)
//   variante="fila":    avatar + botones Cambiar / Quitar (perfil)
// v-model = base64 de la imagen (sin el prefijo "data:...;base64,") o null.
import { ref } from "vue";
import { useDialogo } from "../composables/dialogo.js";
import { srcFoto } from "../utils/usuario.js";
import Avatar from "./Avatar.vue";
import Icono from "./Icono.vue";

const foto = defineModel({ type: String, default: null });
defineProps({
  variante: { type: String, default: "tarjeta" },
  nombre: { type: String, default: "" },
  apellido: { type: String, default: "" },
});

const { alerta } = useDialogo();
const archivo = ref(null);
const arrastrando = ref(false);

function lee(file) {
  if (!file) return;
  if (!file.type.startsWith("image/")) {
    alerta("El archivo seleccionado no es una imagen.", { tipo: "error", titulo: "Archivo no válido" });
    return;
  }
  const lector = new FileReader();
  lector.onload = () => (foto.value = String(lector.result).split(",")[1]);
  lector.onerror = () => alerta("No se pudo leer la imagen.", { tipo: "error" });
  lector.readAsDataURL(file);
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

  <!-- Registro: tarjeta con zona para soltar -->
  <section
    v-if="variante === 'tarjeta'"
    class="tarjeta flex flex-col items-center gap-4 p-7 text-center"
    @dragover.prevent="arrastrando = true"
    @dragleave="arrastrando = false"
    @drop.prevent="suelta"
  >
    <div
      :class="[
        'grid size-32 place-items-center overflow-hidden rounded-full border-2 border-dashed transition',
        arrastrando ? 'border-marca bg-marca-anillo' : 'border-[#a9bbe6] bg-marca-suave',
        foto ? 'border-solid border-superficie ring-1 ring-borde' : '',
      ]"
    >
      <img v-if="foto" :src="srcFoto(foto)" alt="Foto de perfil elegida" class="size-full object-cover" />
      <Icono v-else nombre="usuario" :tam="44" class="text-marca" />
    </div>
    <div>
      <h2 class="text-base font-semibold">Foto de perfil</h2>
      <p class="mt-1.5 text-sm leading-normal text-tinta-suave">
        Opcional. Arrastra una imagen aquí o elígela desde tu equipo.
      </p>
    </div>
    <div class="flex flex-wrap justify-center gap-2">
      <button type="button" class="btn-secundario" @click="abrirSelector">
        <Icono nombre="camara" :tam="16" /> {{ foto ? "Cambiar imagen" : "Elegir imagen" }}
      </button>
      <button v-if="foto" type="button" class="btn-fantasma" @click="quita">Quitar</button>
    </div>
    <p class="text-xs text-tinta-suave">JPG o PNG</p>
  </section>

  <!-- Perfil: fila con avatar -->
  <section v-else class="tarjeta flex flex-wrap items-center gap-6 p-7" @dragover.prevent @drop.prevent="suelta">
    <Avatar :foto="foto" :nombre="nombre" :apellido="apellido" :tam="96" />
    <div class="min-w-0 flex-[1_1_200px]">
      <h2 class="text-[17px] font-semibold">Foto de perfil</h2>
      <p class="mt-1 text-sm text-tinta-suave">
        {{ foto ? "Puedes cambiarla o quitarla." : "Sin foto: se muestran tus iniciales." }}
      </p>
    </div>
    <div class="flex flex-wrap gap-2">
      <button type="button" class="btn-secundario" @click="abrirSelector">Cambiar foto</button>
      <button v-if="foto" type="button" class="btn-fantasma" @click="quita">Quitar</button>
    </div>
  </section>
</template>
