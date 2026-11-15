<script setup>
// Perfil: navegación lateral por secciones, formulario y barra de guardado.
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from "vue";
import { onBeforeRouteLeave } from "vue-router";
import { servicio } from "../api/servicio.js";
import { useSesion } from "../composables/sesion.js";
import { useDialogo } from "../composables/dialogo.js";
import { useAccesoProtegido } from "../composables/accesoProtegido.js";
import { aUsuarioServicio, desdeUsuarioServicio } from "../utils/usuario.js";
import FotoPerfil from "../components/FotoPerfil.vue";
import CamposUsuario from "../components/CamposUsuario.vue";
import Icono from "../components/Icono.vue";

const { credenciales, autenticado, usuario: usuarioSesion } = useSesion();
const { alerta, confirma } = useDialogo();
const { reportaError } = useAccesoProtegido();

const usuario = ref(null);
const original = ref("");
const cargando = ref(true);
const ocupado = ref(false);

const SECCIONES = [
  { id: "seccion-foto", texto: "Foto" },
  { id: "seccion-cuenta", texto: "Cuenta" },
  { id: "seccion-datos", texto: "Datos personales" },
];
const activa = ref(SECCIONES[0].id);
let observador = null;

const hayCambios = computed(() => usuario.value != null && JSON.stringify(usuario.value) !== original.value);

function fijaOriginal() {
  original.value = JSON.stringify(usuario.value);
}

async function carga() {
  const r = await servicio.consultaUsuario(credenciales());
  if (!r.ok) return r;
  usuarioSesion.value = r.datos;
  usuario.value = desdeUsuarioServicio(r.datos);
  fijaOriginal();
  return r;
}

onMounted(async () => {
  const r = await carga();
  cargando.value = false;
  if (!r.ok) {
    await reportaError(r.datos, "No se pudo consultar el perfil");
    return;
  }
  await nextTick();
  // Marca en la navegación lateral la sección visible
  observador = new IntersectionObserver(
    (entradas) => {
      const visible = entradas.find((e) => e.isIntersecting);
      if (visible) activa.value = visible.target.id;
    },
    { rootMargin: "-30% 0px -60% 0px" }
  );
  SECCIONES.forEach((s) => {
    const el = document.getElementById(s.id);
    if (el) observador.observe(el);
  });
});

onBeforeUnmount(() => observador?.disconnect());

function irA(id) {
  activa.value = id;
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
}

async function guardar() {
  ocupado.value = true;
  const r = await servicio.modificaUsuario(credenciales(), aUsuarioServicio(usuario.value));
  ocupado.value = false;
  if (!r.ok) {
    await reportaError(r.datos, "No se pudo guardar");
    return;
  }
  usuario.value.password = "";
  fijaOriginal();
  carga(); // refresca el avatar y el nombre del encabezado
  await alerta("Se modificó el perfil del usuario.", { tipo: "exito", titulo: "Cambios guardados" });
}

function descartar() {
  usuario.value = JSON.parse(original.value);
}

// Aviso al salir con cambios sin guardar (no aplica si la sesión ya se cerró)
onBeforeRouteLeave(async () => {
  if (!autenticado.value || !hayCambios.value) return true;
  return await confirma("Si sales ahora se perderán los cambios que no has guardado.", {
    titulo: "¿Salir sin guardar?",
    tipo: "peligro",
    aceptar: "Salir sin guardar",
    cancelar: "Seguir editando",
  });
});
</script>

<template>
  <div class="mx-auto w-full max-w-[1120px] px-4 pt-8 pb-16 sm:px-6">
    <RouterLink to="/inicio" class="btn-fantasma -ml-3 h-10 px-3">
      <Icono nombre="flecha" :tam="16" /> Regresar al menú
    </RouterLink>
    <h1 class="titulo mt-3">Perfil del usuario</h1>
    <p class="mt-2 text-[15px] text-tinta-suave">Actualiza tus datos y guarda los cambios.</p>

    <div class="mt-8 flex flex-wrap items-start gap-8">
      <!-- Navegación de secciones (solo en pantallas anchas) -->
      <nav aria-label="Secciones del perfil" class="sticky top-24 hidden w-[240px] shrink-0 flex-col gap-1 lg:flex">
        <button
          v-for="s in SECCIONES"
          :key="s.id"
          type="button"
          :aria-current="activa === s.id ? 'true' : undefined"
          :class="[
            'flex h-11 items-center gap-2.5 rounded-[10px] px-3.5 text-left text-sm transition',
            activa === s.id
              ? 'border border-borde bg-superficie font-semibold text-marca'
              : 'border border-transparent font-medium text-tinta-suave hover:text-tinta',
          ]"
          @click="irA(s.id)"
        >
          <span :class="['h-[18px] w-1 rounded-sm', activa === s.id ? 'bg-marca' : 'bg-transparent']" aria-hidden="true" />
          {{ s.texto }}
        </button>
      </nav>

      <div class="min-w-0 flex-[999_1_560px]">
        <div v-if="cargando" class="space-y-6" aria-busy="true" aria-label="Cargando perfil">
          <div class="tarjeta flex items-center gap-6 p-7">
            <div class="size-24 animate-pulse rounded-full bg-hundido" />
            <div class="h-4 w-48 animate-pulse rounded bg-hundido" />
          </div>
          <div class="tarjeta space-y-4 p-7">
            <div v-for="n in 3" :key="n" class="h-11 animate-pulse rounded-lg bg-hundido" />
          </div>
        </div>

        <form v-else-if="usuario" class="flex flex-col gap-6" @submit.prevent="guardar">
          <div id="seccion-foto" class="scroll-mt-24">
            <FotoPerfil
              v-model="usuario.foto"
              variante="fila"
              :nombre="usuario.nombre"
              :apellido="usuario.apellido_paterno"
            />
          </div>
          <CamposUsuario v-model="usuario" modo="perfil" />

          <!-- Barra de guardado -->
          <div
            class="sticky bottom-4 z-10 flex flex-wrap items-center justify-between gap-3 rounded-[14px] bg-tinta py-3.5 pr-4 pl-[22px] text-fondo shadow-[0_12px_32px_-12px_rgb(15_23_42/0.5)]"
          >
            <span class="inline-flex items-center gap-2.5 text-sm" aria-live="polite">
              <span :class="['size-2 rounded-full', hayCambios ? 'bg-[#f5b544]' : 'bg-[#8792a6]']" aria-hidden="true" />
              {{ hayCambios ? "Tienes cambios sin guardar" : "Sin cambios pendientes" }}
            </span>
            <div class="flex gap-2">
              <button
                type="button"
                class="btn font-medium text-[#c9d1de] hover:bg-white/10 hover:text-white"
                :disabled="!hayCambios || ocupado"
                @click="descartar"
              >
                Descartar
              </button>
              <button type="submit" class="btn bg-superficie px-5 text-tinta hover:bg-white" :disabled="!hayCambios || ocupado">
                <span v-if="ocupado" class="size-4 animate-spin rounded-full border-2 border-tinta/30 border-t-tinta" />
                Guardar cambios
              </button>
            </div>
          </div>
        </form>

        <p v-else class="tarjeta p-8 text-center text-sm text-tinta-suave">No se pudo cargar el perfil.</p>
      </div>
    </div>
  </div>
</template>
