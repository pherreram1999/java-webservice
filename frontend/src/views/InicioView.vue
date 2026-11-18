<script setup>
// Menú principal: resumen del perfil, accesos y zona para eliminar la cuenta.
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { servicio } from "../api/servicio.js";
import { useSesion } from "../composables/sesion.js";
import { useDialogo } from "../composables/dialogo.js";
import { useAccesoProtegido } from "../composables/accesoProtegido.js";
import { fechaLarga, GENEROS, telefonoLegible } from "../utils/usuario.js";
import Avatar from "../components/Avatar.vue";
import Icono from "../components/Icono.vue";

const router = useRouter();
const { credenciales, cerrar, usuario } = useSesion();
const { alerta, confirma } = useDialogo();
const { reportaError } = useAccesoProtegido();

const cargando = ref(!usuario.value);
const borrando = ref(false);

onMounted(async () => {
  const r = await servicio.consultaUsuario(credenciales());
  cargando.value = false;
  if (r.ok) usuario.value = r.datos;
  else await reportaError(r.datos, "No se pudieron obtener tus datos");
});

const datos = computed(() => {
  const u = usuario.value;
  if (!u) return [];
  return [
    { etiqueta: "Fecha de nacimiento", valor: fechaLarga(u.fecha_nacimiento) },
    { etiqueta: "Teléfono", valor: telefonoLegible(u.telefono) },
    { etiqueta: "Género", valor: GENEROS[u.genero] ?? "" },
    { etiqueta: "Apellido materno", valor: u.apellido_materno ?? "" },
  ];
});

async function eliminar() {
  const ok = await confirma("Se borrarán tu cuenta y tu foto. Esta acción no se puede deshacer.", {
    titulo: "¿Eliminar tu perfil?",
    tipo: "peligro",
    aceptar: "Eliminar perfil",
  });
  if (!ok) return;
  borrando.value = true;
  const r = await servicio.borraUsuario(credenciales());
  borrando.value = false;
  if (!r.ok) {
    await reportaError(r.datos, "No se pudo eliminar el perfil");
    return;
  }
  cerrar();
  await alerta("Se eliminó el perfil del usuario.", { tipo: "exito", titulo: "Perfil eliminado" });
  router.replace({ name: "login" });
}

function salir() {
  cerrar();
  router.push({ name: "login" });
}
</script>

<template>
  <div class="w-full">
    <!-- Franja de bienvenida: continúa el azul del encabezado; las tarjetas montan sobre ella -->
    <div class="sobre-marca bg-marca">
      <div class="mx-auto w-full max-w-[1120px] px-4 pt-10 pb-24 sm:px-6">
        <p class="antetitulo text-sobre-marca-tenue">Menú principal</p>
        <h1 class="titulo mt-2 text-white">
          <template v-if="usuario">Hola, {{ usuario.nombre }}</template>
          <span v-else class="inline-block h-10 w-56 animate-pulse rounded-lg bg-white/15 align-middle" />
        </h1>
        <p class="mt-2.5 text-base text-sobre-marca">¿Qué quieres hacer hoy?</p>
      </div>
    </div>

  <div class="mx-auto -mt-16 w-full max-w-[1120px] px-4 pb-16 sm:px-6">
    <div class="flex flex-wrap items-stretch gap-6">
      <!-- Resumen del perfil -->
      <section class="tarjeta min-w-0 flex-[999_1_520px] p-7">
        <div v-if="cargando" class="flex items-center gap-5" aria-busy="true" aria-label="Cargando perfil">
          <div class="size-20 animate-pulse rounded-full bg-hundido" />
          <div class="flex-1 space-y-2">
            <div class="h-5 w-48 animate-pulse rounded bg-hundido" />
            <div class="h-4 w-36 animate-pulse rounded bg-hundido" />
          </div>
        </div>

        <template v-else-if="usuario">
          <div class="flex flex-wrap items-center gap-5">
            <Avatar :foto="usuario.foto" :nombre="usuario.nombre" :apellido="usuario.apellido_paterno" :tam="80" />
            <div class="min-w-0 flex-[1_1_200px]">
              <h2 class="truncate text-xl font-semibold">{{ usuario.nombre }} {{ usuario.apellido_paterno }}</h2>
              <p class="mt-1 truncate text-[15px] text-tinta-suave">{{ usuario.email }}</p>
            </div>
            <RouterLink to="/perfil" class="btn-secundario">
              <Icono nombre="editar" :tam="16" /> Editar perfil
            </RouterLink>
          </div>
          <dl class="mt-7 grid gap-5 border-t border-borde pt-6 sm:grid-cols-2 lg:grid-cols-4">
            <div v-for="d in datos" :key="d.etiqueta">
              <dt class="text-[13px] text-tinta-suave">{{ d.etiqueta }}</dt>
              <dd :class="['mt-1 text-[15px] font-medium', d.valor ? '' : 'text-tinta-suave']">
                {{ d.valor || "Sin capturar" }}
              </dd>
            </div>
          </dl>
        </template>

        <p v-else class="text-sm text-tinta-suave">No se pudieron cargar tus datos.</p>
      </section>

      <!-- Accesos -->
      <aside class="flex min-w-0 flex-[1_1_300px] flex-col gap-4">
        <!-- Tarjeta clara: sobre la franja azul una tarjeta azul se perdería -->
        <RouterLink
          to="/perfil"
          class="tarjeta flex items-center gap-4 px-6 py-5 text-left transition hover:border-marca"
        >
          <span class="grid size-11 place-items-center rounded-xl bg-marca-suave text-marca">
            <Icono nombre="usuario" />
          </span>
          <span>
            <span class="block font-semibold">Perfil del usuario</span>
            <span class="mt-0.5 block text-sm text-tinta-suave">Modifica tus datos, contraseña y foto</span>
          </span>
        </RouterLink>
        <RouterLink
          to="/captura-articulo"
          class="tarjeta flex items-center gap-4 px-6 py-5 text-left transition hover:border-marca"
        >
          <span class="grid size-11 place-items-center rounded-xl bg-marca-suave text-marca">
            <Icono nombre="caja" />
          </span>
          <span>
            <span class="block font-semibold">Captura de artículo</span>
            <span class="mt-0.5 block text-sm text-tinta-suave">Da de alta un artículo en el stock</span>
          </span>
        </RouterLink>
        <RouterLink
          to="/compra-articulos"
          class="tarjeta flex items-center gap-4 px-6 py-5 text-left transition hover:border-marca"
        >
          <span class="grid size-11 place-items-center rounded-xl bg-marca-suave text-marca">
            <Icono nombre="carrito" />
          </span>
          <span>
            <span class="block font-semibold">Compra de artículos</span>
            <span class="mt-0.5 block text-sm text-tinta-suave">Busca artículos y llena tu carrito</span>
          </span>
        </RouterLink>
        <button
          type="button"
          class="tarjeta flex items-center gap-4 px-6 py-5 text-left transition hover:border-marca"
          @click="salir"
        >
          <span class="grid size-11 place-items-center rounded-xl bg-hundido text-tinta-suave">
            <Icono nombre="salir" />
          </span>
          <span>
            <span class="block font-semibold">Salir</span>
            <span class="mt-0.5 block text-sm text-tinta-suave">Cerrar la sesión actual</span>
          </span>
        </button>
      </aside>
    </div>

    <!-- Zona de peligro -->
    <section
      class="mt-10 flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-[#f1c8c8] bg-[#fbf3f3] px-7 py-6"
    >
      <div>
        <h2 class="font-semibold text-red-800">Eliminar perfil</h2>
        <p class="mt-1 text-sm text-[#8a2a2a]">Borra definitivamente tu cuenta y tu foto. No se puede deshacer.</p>
      </div>
      <button type="button" class="btn-peligro-contorno" :disabled="borrando" @click="eliminar">
        <Icono nombre="basura" :tam="16" /> Eliminar perfil
      </button>
    </section>
  </div>
  </div>
</template>
