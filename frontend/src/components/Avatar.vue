<script setup>
// Foto del usuario o, si no tiene, sus iniciales sobre el color de marca.
import { computed } from "vue";
import { iniciales, srcFoto } from "../utils/usuario.js";

const props = defineProps({
  foto: { type: String, default: null },
  nombre: { type: String, default: "" },
  apellido: { type: String, default: "" },
  tam: { type: Number, default: 40 },
  // Iniciales en azul sobre fondo claro, para usarlo encima del color de marca (encabezado)
  claro: { type: Boolean, default: false },
});

const texto = computed(() => iniciales(props.nombre, props.apellido));
const estilo = computed(() => ({
  width: `${props.tam}px`,
  height: `${props.tam}px`,
  fontSize: `${Math.round(props.tam * 0.36)}px`,
}));
</script>

<template>
  <img v-if="foto" :src="srcFoto(foto)" alt="" :style="estilo" class="shrink-0 rounded-full bg-hundido object-cover" />
  <span
    v-else
    :style="estilo"
    :class="claro ? 'bg-sobre-marca text-marca' : 'bg-marca text-white'"
    class="grid shrink-0 place-items-center rounded-full font-display font-semibold select-none"
    aria-hidden="true"
    >{{ texto }}</span
  >
</template>
