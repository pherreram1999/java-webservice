<script setup>
// Acceso: solo el formulario, centrado en la página.
import { reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { mensajeDeError, servicio } from "../api/servicio.js";
import { useSesion } from "../composables/sesion.js";
import { useDialogo } from "../composables/dialogo.js";
import { sha256 } from "../utils/sha256.js";
import Icono from "../components/Icono.vue";

const router = useRouter();
const route = useRoute();
const { iniciar } = useSesion();
const { alerta } = useDialogo();

const datos = reactive({ email: "", password: "" });
const verPassword = ref(false);
const ocupado = ref(false);

async function entrar() {
  ocupado.value = true;
  const r = await servicio.login(datos.email.trim(), sha256(datos.password));
  ocupado.value = false;
  if (!r.ok) {
    datos.password = "";
    const mensaje = mensajeDeError(r.datos);
    if (mensaje === "Acceso denegado")
      await alerta("El email o la contraseña no son correctos. Revisa tus datos e inténtalo de nuevo.", {
        tipo: "error",
        titulo: "No se pudo iniciar sesión",
        detalle: `Servidor: ${mensaje}`,
        aceptar: "Entendido",
      });
    else await alerta(mensaje, { tipo: "error", titulo: "No se pudo iniciar sesión", aceptar: "Entendido" });
    return;
  }
  iniciar(r.datos.id_usuario, r.datos.token);
  const destino = typeof route.query.redirect === "string" ? route.query.redirect : "/inicio";
  router.replace(destino);
}
</script>

<template>
  <div class="flex flex-1 items-center justify-center px-4 py-12">
    <div class="w-full max-w-[420px]">
      <div class="flex flex-col items-center text-center">
        <span class="grid size-12 place-items-center rounded-[14px] bg-marca text-white">
          <Icono nombre="escudo" :tam="22" />
        </span>
        <h1 class="mt-5 font-display text-[30px] font-semibold tracking-[-0.01em]">Inicia sesión</h1>
      </div>

      <form class="tarjeta mt-7 flex flex-col gap-5 p-6 sm:p-8" @submit.prevent="entrar">
        <div>
          <label class="etiqueta" for="login-email">Email</label>
          <input
            id="login-email"
            v-model="datos.email"
            type="email"
            class="campo h-12"
            required
            autocomplete="username"
            placeholder="nombre@ejemplo.com"
          />
        </div>
        <div>
          <label class="etiqueta" for="login-password">Contraseña</label>
          <div class="relative">
            <input
              id="login-password"
              v-model="datos.password"
              :type="verPassword ? 'text' : 'password'"
              class="campo h-12 pr-12"
              required
              autocomplete="current-password"
            />
            <button
              type="button"
              class="absolute top-0.5 right-0.5 grid size-11 place-items-center rounded-lg text-tinta-suave hover:text-tinta"
              :aria-label="verPassword ? 'Ocultar contraseña' : 'Mostrar contraseña'"
              :aria-pressed="verPassword"
              @click="verPassword = !verPassword"
            >
              <Icono :nombre="verPassword ? 'ojoTachado' : 'ojo'" :tam="18" />
            </button>
          </div>
        </div>
        <button type="submit" class="btn-primario mt-1 h-12 text-[15px]" :disabled="ocupado">
          <span v-if="ocupado" class="size-4 animate-spin rounded-full border-2 border-white/40 border-t-white" />
          Entrar
        </button>
      </form>

      <p class="mt-6 text-center text-sm text-tinta-suave">
        ¿Aún no tienes cuenta?
        <RouterLink to="/registro" class="font-semibold text-marca hover:text-marca-fuerte">Crear una cuenta</RouterLink>
      </p>
    </div>
  </div>
</template>
