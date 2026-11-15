<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { mensajeDeError, servicio } from "../api/servicio.js";
import { useDialogo } from "../composables/dialogo.js";
import { aUsuarioServicio, usuarioVacio } from "../utils/usuario.js";
import FotoPerfil from "../components/FotoPerfil.vue";
import CamposUsuario from "../components/CamposUsuario.vue";

const router = useRouter();
const { alerta } = useDialogo();

const usuario = ref(usuarioVacio());
const ocupado = ref(false);

async function registrar() {
  ocupado.value = true;
  const r = await servicio.altaUsuario(aUsuarioServicio(usuario.value));
  ocupado.value = false;
  if (!r.ok) {
    await alerta(mensajeDeError(r.datos), { tipo: "error", titulo: "No se pudo registrar", aceptar: "Entendido" });
    return;
  }
  await alerta("Se registró el usuario. Ya puedes iniciar sesión con tu email y contraseña.", {
    tipo: "exito",
    titulo: "Cuenta creada",
    aceptar: "Ir a iniciar sesión",
  });
  router.push({ name: "login" });
}
</script>

<template>
  <div class="mx-auto w-full max-w-[1120px] px-4 pt-12 pb-16 sm:px-6">
    <p class="antetitulo">Nueva cuenta</p>
    <h1 class="titulo mt-2">Registro de usuario</h1>
    <p class="mt-2 text-[15px] text-tinta-suave">
      Los campos marcados con <span class="text-marca">*</span> son obligatorios.
    </p>

    <form class="mt-8 flex flex-wrap items-start gap-6" @submit.prevent="registrar">
      <div class="w-full min-w-0 md:max-w-[340px] md:flex-[1_1_280px]">
        <FotoPerfil v-model="usuario.foto" variante="tarjeta" />
      </div>

      <div class="flex min-w-0 flex-[999_1_560px] flex-col gap-6">
        <CamposUsuario v-model="usuario" modo="alta" />

        <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <RouterLink to="/login" class="btn-secundario h-12 px-[22px] text-[15px]">Cancelar</RouterLink>
          <button type="submit" class="btn-primario h-12 px-7 text-[15px]" :disabled="ocupado">
            <span v-if="ocupado" class="size-4 animate-spin rounded-full border-2 border-white/40 border-t-white" />
            Registrar usuario
          </button>
        </div>
      </div>
    </form>
  </div>
</template>
