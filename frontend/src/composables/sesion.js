/*
  Sesión del usuario (id_usuario + token devueltos por login).
  Se guarda en sessionStorage para sobrevivir a una recarga de la página;
  si el navegador no lo permite, la sesión vive solo en memoria.
*/
import { computed, reactive, ref } from "vue";

const CLAVE = "sesion";

function leer() {
  try {
    const s = JSON.parse(sessionStorage.getItem(CLAVE));
    if (s && s.id_usuario != null && s.token) return s;
  } catch {
    /* sin almacenamiento disponible */
  }
  return { id_usuario: null, token: null };
}

const estado = reactive(leer());

// Últimos datos del usuario devueltos por consulta_usuario (para el avatar del encabezado)
const usuario = ref(null);

function guardar() {
  try {
    if (estado.token) sessionStorage.setItem(CLAVE, JSON.stringify(estado));
    else sessionStorage.removeItem(CLAVE);
  } catch {
    /* sin almacenamiento disponible */
  }
}

export function useSesion() {
  return {
    sesion: estado,
    usuario,
    autenticado: computed(() => estado.token != null),
    // Parámetros que exigen los endpoints protegidos
    credenciales: () => ({ id_usuario: estado.id_usuario, token: estado.token }),
    iniciar(id_usuario, token) {
      estado.id_usuario = id_usuario;
      estado.token = token;
      guardar();
    },
    cerrar() {
      estado.id_usuario = null;
      estado.token = null;
      usuario.value = null;
      guardar();
    },
  };
}
