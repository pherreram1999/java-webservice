<script setup>
// Layout de la SPA: encabezado (oculto en el login) y contenido con transición entre páginas.
import { computed, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useSesion } from "../composables/sesion.js";
import Avatar from "../components/Avatar.vue";
import BotonCarrito from "../components/BotonCarrito.vue";
import { useCarritoStore } from "../stores/carrito.js";
import Icono from "../components/Icono.vue";

const route = useRoute();
const router = useRouter();
const { autenticado, usuario, cerrar } = useSesion();
const carrito = useCarritoStore();

// El contador del encabezado necesita el carrito en cuanto hay sesión (también tras recargar la página);
// al cerrarla se vacía. Un "Acceso denegado" aquí es silencioso: ya lo reportará la vista que se use.
watch(autenticado, (activa) => (activa ? carrito.carga() : carrito.reinicia()), { immediate: true });

const conEncabezado = computed(() => !route.meta.sinEncabezado);

function salir() {
  cerrar();
  router.push({ name: "login" });
}

const claseNav = (activo) =>
  [
    "inline-flex h-10 items-center gap-2 rounded-lg px-3.5 text-sm transition",
    activo ? "bg-marca-suave font-semibold text-marca" : "font-medium text-tinta-suave hover:bg-hundido hover:text-tinta",
  ].join(" ");
</script>

<template>
  <div class="flex min-h-dvh flex-col">
    <header v-if="conEncabezado" class="sticky top-0 z-30 border-b border-borde bg-superficie/90 backdrop-blur-md">
      <div class="mx-auto flex min-h-16 max-w-[1120px] flex-wrap items-center justify-between gap-3 px-4 sm:px-6">
        <RouterLink :to="autenticado ? '/inicio' : '/login'" class="flex items-center gap-2.5 rounded-lg">
          <span class="grid size-[34px] place-items-center rounded-[10px] bg-marca text-white">
            <Icono nombre="escudo" :tam="18" />
          </span>
          <span class="font-display text-base font-semibold">Servicio de usuarios</span>
        </RouterLink>

        <nav v-if="autenticado" class="flex items-center gap-1" aria-label="Principal">
          <RouterLink v-slot="{ href, navigate, isActive }" to="/inicio" custom>
            <a :href="href" :class="claseNav(isActive)" :aria-current="isActive ? 'page' : undefined" @click="navigate">
              Inicio
            </a>
          </RouterLink>
          <RouterLink v-slot="{ href, navigate, isActive }" to="/perfil" custom>
            <a :href="href" :class="claseNav(isActive)" :aria-current="isActive ? 'page' : undefined" @click="navigate">
              Perfil
            </a>
          </RouterLink>
          <span class="mx-2 h-6 w-px bg-borde" aria-hidden="true" />
          <BotonCarrito />
          <Avatar
            v-if="usuario"
            :foto="usuario.foto"
            :nombre="usuario.nombre"
            :apellido="usuario.apellido_paterno"
            :tam="36"
            class="hidden sm:grid"
          />
          <button type="button" :class="claseNav(false)" class="px-3" @click="salir">
            <Icono nombre="salir" :tam="16" /> Salir
          </button>
        </nav>
        <p v-else class="text-sm text-tinta-suave">
          <span class="hidden sm:inline">¿Ya tienes cuenta?</span>
          <RouterLink to="/login" class="font-semibold text-marca hover:text-marca-fuerte">Inicia sesión</RouterLink>
        </p>
      </div>
    </header>

    <!-- overflow-x-clip (no hidden): hidden crearía un contenedor de scroll y rompería los elementos sticky -->
    <main class="flex flex-1 flex-col overflow-x-clip">
      <RouterView v-slot="{ Component }">
        <Transition name="pagina" mode="out-in">
          <component :is="Component" :key="route.path" />
        </Transition>
      </RouterView>
    </main>
  </div>
</template>
