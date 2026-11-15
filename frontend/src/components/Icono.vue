<script setup>
// Iconos de trazo (estilo Lucide) dibujados en línea, sin dependencias externas.
defineProps({
  nombre: { type: String, required: true },
  tam: { type: [Number, String], default: 20 },
});

const TRAZOS = {
  usuario: ["M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2", "M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8z"],
  salir: ["M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4", "M16 17l5-5-5-5", "M21 12H9"],
  entrar: ["M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4", "M10 17l5-5-5-5", "M15 12H3"],
  inicio: ["M3 10.5 12 3l9 7.5", "M5 9.5V21h14V9.5"],
  basura: ["M3 6h18", "M8 6V4h8v2", "M19 6l-1 14H6L5 6", "M10 11v6", "M14 11v6"],
  editar: ["M12 20h9", "M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"],
  flecha: ["M19 12H5", "M12 19l-7-7 7-7"],
  camara: ["M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z", "M12 9a4 4 0 1 0 0 8 4 4 0 0 0 0-8z"],
  x: ["M18 6 6 18", "M6 6l12 12"],
  check: ["M20 6 9 17l-5-5"],
  alerta: ["M12 9v4", "M12 17h.01", "M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"],
  info: ["M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20z", "M12 16v-4", "M12 8h.01"],
  escudo: ["M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"],
  ojo: ["M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z", "M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"],
  ojoTachado: [
    "M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94",
    "M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19",
    "M14.12 14.12a3 3 0 1 1-4.24-4.24",
    "M1 1l22 22",
  ],
  carrito: ["M9 22a1 1 0 1 0 0-2 1 1 0 0 0 0 2z", "M20 22a1 1 0 1 0 0-2 1 1 0 0 0 0 2z", "M1 1h4l2.7 13.4a2 2 0 0 0 2 1.6h9.7a2 2 0 0 0 2-1.6L23 6H6"],
  caja: ["M21 8 12 3 3 8v8l9 5 9-5z", "M3.3 7.5 12 12.5l8.7-5", "M12 22V12.5"],
  buscar: ["M11 3a8 8 0 1 0 0 16 8 8 0 0 0 0-16z", "M21 21l-4.3-4.3"],
  agregar: ["M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M9 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8z", "M19 8v6", "M22 11h-6"],
};
</script>

<template>
  <svg
    :width="tam"
    :height="tam"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="2"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <path v-for="(d, i) in TRAZOS[nombre]" :key="i" :d="d" />
  </svg>
</template>
