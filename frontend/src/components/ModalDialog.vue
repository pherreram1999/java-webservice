<script setup>
// Diálogo modal accesible: role="alertdialog", foco atrapado, Esc para cerrar
// y el foco regresa al elemento que lo abrió. Se controla con useDialogo().
import { computed, nextTick, ref, watch } from "vue";
import { cerrarDialogo, useDialogo } from "../composables/dialogo.js";
import Icono from "./Icono.vue";

const { estado } = useDialogo();
const panel = ref(null);
const btnAceptar = ref(null);
const btnCancelar = ref(null);
let focoAnterior = null;

const ESTILOS = {
  info: { icono: "info", caja: "bg-marca-suave text-marca", boton: "btn-primario" },
  exito: { icono: "check", caja: "bg-marca-suave text-marca", boton: "btn-primario" },
  error: { icono: "info", caja: "bg-red-100 text-red-700", boton: "btn-primario" },
  peligro: { icono: "basura", caja: "bg-red-100 text-red-700", boton: "btn-peligro" },
};
const estilo = computed(() => ESTILOS[estado.tipo] ?? ESTILOS.info);

watch(
  () => estado.abierto,
  async (abierto) => {
    if (abierto) {
      focoAnterior = document.activeElement;
      await nextTick();
      // En acciones destructivas el foco inicial va a "Cancelar"
      (estado.tipo === "peligro" && btnCancelar.value ? btnCancelar.value : btnAceptar.value)?.focus();
    } else if (focoAnterior && document.contains(focoAnterior)) {
      focoAnterior.focus();
    }
  }
);

const cancelar = () => cerrarDialogo(false);
const aceptar = () => cerrarDialogo(true);

function teclado(e) {
  if (e.key === "Escape") {
    e.preventDefault();
    cancelar();
  } else if (e.key === "Tab") {
    const enfocables = panel.value.querySelectorAll("button");
    const primero = enfocables[0];
    const ultimo = enfocables[enfocables.length - 1];
    if (e.shiftKey && document.activeElement === primero) {
      e.preventDefault();
      ultimo.focus();
    } else if (!e.shiftKey && document.activeElement === ultimo) {
      e.preventDefault();
      primero.focus();
    }
  }
}
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="estado.abierto"
        class="fixed inset-0 z-50 flex items-end justify-center p-4 sm:items-center"
        @keydown="teclado"
      >
        <div class="absolute inset-0 bg-slate-900/50 backdrop-blur-[2px]" @click="cancelar" />

        <div
          ref="panel"
          class="modal-panel relative w-full max-w-[400px] overflow-hidden rounded-[18px] bg-superficie shadow-[0_24px_48px_-12px_rgb(15_23_42/0.45)]"
          role="alertdialog"
          aria-modal="true"
          aria-labelledby="modal-titulo"
          aria-describedby="modal-mensaje"
        >
          <div class="px-7 pt-7 pb-6">
            <span :class="['grid size-12 place-items-center rounded-[14px]', estilo.caja]">
              <Icono :nombre="estilo.icono" :tam="22" />
            </span>
            <h2 id="modal-titulo" class="mt-[18px] font-display text-xl font-semibold text-tinta">
              {{ estado.titulo }}
            </h2>
            <p id="modal-mensaje" class="mt-2 text-[15px] leading-relaxed break-words text-tinta-suave">
              {{ estado.mensaje }}
            </p>
            <p
              v-if="estado.detalle"
              class="mt-3.5 rounded-lg bg-hundido px-3 py-2 font-mono text-[13px] break-words text-tinta-suave"
            >
              {{ estado.detalle }}
            </p>
          </div>

          <div class="flex flex-col-reverse gap-2.5 border-t border-borde bg-fondo px-7 py-4 sm:flex-row sm:justify-end">
            <button
              v-if="estado.cancelar"
              ref="btnCancelar"
              type="button"
              class="btn-secundario focus-visible:border-2 focus-visible:border-marca focus-visible:shadow-[0_0_0_3px_var(--color-marca-anillo)] focus-visible:outline-none"
              @click="cancelar"
            >
              {{ estado.cancelar }}
            </button>
            <button ref="btnAceptar" type="button" :class="[estilo.boton, 'px-[22px]']" @click="aceptar">
              {{ estado.aceptar }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
