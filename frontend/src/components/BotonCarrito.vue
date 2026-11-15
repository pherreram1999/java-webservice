<script setup>
// Botón de carrito del encabezado al estilo Amazon: carrito grande, número de piezas en naranja
// sobre la cesta y la palabra "Carrito" en negritas. Lee el contador del store de Pinia.
import { computed, ref, watch } from "vue";
import { useCarritoStore } from "../stores/carrito.js";

const carrito = useCarritoStore();

const cantidad = computed(() => carrito.cantidadTotal);
const texto = computed(() => (cantidad.value > 99 ? "99+" : String(cantidad.value)));
const etiqueta = computed(() =>
  cantidad.value === 1 ? "Carrito de compra, 1 pieza" : `Carrito de compra, ${cantidad.value} piezas`,
);

// Reinicia la animación cada vez que cambia la cantidad
const rebotando = ref(false);
watch(cantidad, () => {
  rebotando.value = false;
  requestAnimationFrame(() => (rebotando.value = true));
});
</script>

<template>
  <RouterLink
    to="/carrito"
    :aria-label="etiqueta"
    class="flex h-11 items-end gap-0.5 rounded-lg border border-transparent px-2 pb-1 text-tinta transition hover:border-tinta/60"
  >
    <svg viewBox="0 0 48 40" class="h-9 w-11 shrink-0 overflow-visible" fill="none" aria-hidden="true">
      <!-- Carrito: asa, cesta y ruedas -->
      <path
        d="M1.5 3.5h6.2l5 25.5h26.3l4.8-19H10.4"
        stroke="currentColor"
        stroke-width="3"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <circle cx="17" cy="36" r="2.6" fill="currentColor" />
      <circle cx="35" cy="36" r="2.6" fill="currentColor" />
      <!-- Cantidad en naranja, centrada sobre la cesta -->
      <text
        x="26"
        y="25"
        text-anchor="middle"
        font-weight="700"
        :font-size="texto.length > 2 ? 14 : 18"
        class="fill-contador font-display"
        :class="{ rebote: rebotando }"
      >
        {{ texto }}
      </text>
    </svg>
    <span class="hidden pb-0.5 text-sm leading-none font-bold sm:inline">Carrito</span>
  </RouterLink>
</template>
