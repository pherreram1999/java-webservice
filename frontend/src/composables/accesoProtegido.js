/*
  Ayuda para las vistas que llaman endpoints protegidos (id_usuario + token).
  Si el servicio responde "Acceso denegado" el token ya no es válido (por ejemplo,
  se inició sesión en otro lado): se avisa, se cierra la sesión y se vuelve al login.
*/
import { useRouter } from "vue-router";
import { mensajeDeError } from "../api/servicio.js";
import { useDialogo } from "./dialogo.js";
import { useSesion } from "./sesion.js";

export function useAccesoProtegido() {
  const router = useRouter();
  const { alerta } = useDialogo();
  const { cerrar } = useSesion();

  // Muestra el error de una respuesta fallida; devuelve true si la sesión expiró
  async function reportaError(datos, titulo) {
    const mensaje = mensajeDeError(datos);
    if (mensaje === "Acceso denegado") {
      cerrar();
      await alerta("Tu sesión ya no es válida. Vuelve a iniciar sesión.", { tipo: "error", titulo: "Sesión expirada" });
      router.replace({ name: "login" });
      return true;
    }
    await alerta(mensaje, { tipo: "error", titulo });
    return false;
  }

  return { reportaError };
}
