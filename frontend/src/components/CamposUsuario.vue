<script setup>
// Secciones "Cuenta" y "Datos personales" del formulario de usuario.
// Edita el objeto de v-model (ver usuarioVacio() en utils/usuario.js).
//   modo="alta":   contraseña obligatoria, secciones numeradas
//   modo="perfil": contraseña opcional (vacía = no cambiarla)
import { computed } from "vue";

const usuario = defineModel({ type: Object, required: true });
const props = defineProps({
  modo: { type: String, default: "alta" },
});

const esPerfil = computed(() => props.modo === "perfil");
const hoy = new Date().toISOString().slice(0, 10);

// Solo dígitos en el teléfono (el servicio lo guarda como número)
function soloDigitos(e) {
  usuario.value.telefono = e.target.value.replace(/\D/g, "").slice(0, 15);
  e.target.value = usuario.value.telefono;
}
</script>

<template>
  <section id="seccion-cuenta" class="tarjeta scroll-mt-24 p-7">
    <div class="flex items-center gap-3">
      <span v-if="!esPerfil" class="grid size-7 place-items-center rounded-full bg-marca text-[13px] font-bold text-white">1</span>
      <h2 class="text-[17px] font-semibold">Cuenta</h2>
    </div>
    <div class="mt-5 grid gap-x-5 gap-y-4 sm:grid-cols-2">
      <div>
        <label class="etiqueta" for="f-email">Email <span class="requerido">*</span></label>
        <input
          id="f-email"
          v-model="usuario.email"
          type="email"
          class="campo"
          required
          autocomplete="email"
          placeholder="nombre@ejemplo.com"
        />
      </div>
      <div>
        <label class="etiqueta" for="f-password">
          <template v-if="esPerfil">Nueva contraseña</template>
          <template v-else>Contraseña <span class="requerido">*</span></template>
        </label>
        <input
          id="f-password"
          v-model="usuario.password"
          type="password"
          class="campo"
          :required="!esPerfil"
          :placeholder="esPerfil ? 'Déjala vacía para no cambiarla' : ''"
          autocomplete="new-password"
          aria-describedby="f-password-ayuda"
        />
        <p v-if="!esPerfil" id="f-password-ayuda" class="mt-2 text-xs text-tinta-suave">
          Se cifra en tu navegador antes de enviarse.
        </p>
      </div>
    </div>
  </section>

  <section id="seccion-datos" class="tarjeta scroll-mt-24 p-7">
    <div class="flex items-center gap-3">
      <span v-if="!esPerfil" class="grid size-7 place-items-center rounded-full bg-marca text-[13px] font-bold text-white">2</span>
      <h2 class="text-[17px] font-semibold">Datos personales</h2>
    </div>
    <div class="mt-5 grid gap-x-5 gap-y-4 sm:grid-cols-2">
      <div class="sm:col-span-2">
        <label class="etiqueta" for="f-nombre">Nombre <span class="requerido">*</span></label>
        <input id="f-nombre" v-model="usuario.nombre" type="text" class="campo" required autocomplete="given-name" />
      </div>
      <div>
        <label class="etiqueta" for="f-paterno">Apellido paterno <span class="requerido">*</span></label>
        <input id="f-paterno" v-model="usuario.apellido_paterno" type="text" class="campo" required autocomplete="family-name" />
      </div>
      <div>
        <label class="etiqueta" for="f-materno">Apellido materno</label>
        <input id="f-materno" v-model="usuario.apellido_materno" type="text" class="campo" />
      </div>
      <div>
        <label class="etiqueta" for="f-fecha">Fecha de nacimiento <span class="requerido">*</span></label>
        <input id="f-fecha" v-model="usuario.fecha_nacimiento" type="date" :max="hoy" class="campo" required />
      </div>
      <div>
        <label class="etiqueta" for="f-telefono">Teléfono</label>
        <input
          id="f-telefono"
          :value="usuario.telefono"
          type="tel"
          inputmode="numeric"
          class="campo"
          autocomplete="tel"
          @input="soloDigitos"
        />
      </div>
    </div>

    <fieldset class="mt-5">
      <legend class="text-sm font-medium">Género</legend>
      <div class="mt-2 flex flex-wrap gap-2">
        <label class="pildora"><input v-model="usuario.genero" type="radio" name="f-genero" value="" /> Sin especificar</label>
        <label class="pildora"><input v-model="usuario.genero" type="radio" name="f-genero" value="M" /> Masculino</label>
        <label class="pildora"><input v-model="usuario.genero" type="radio" name="f-genero" value="F" /> Femenino</label>
      </div>
    </fieldset>
  </section>
</template>
