/*
  Diálogo modal global (reemplaza a alert() y confirm()).
    await alerta("Se registró el usuario", { tipo: "exito" })
    if (await confirma("¿Eliminar el perfil?", { tipo: "peligro", aceptar: "Eliminar" })) ...
  Lo pinta <ModalDialog/>, montado una sola vez en App.vue.
*/
import { reactive } from "vue";

const estado = reactive({
  abierto: false,
  titulo: "",
  mensaje: "",
  detalle: null, // texto técnico opcional (p. ej. el mensaje del servidor)
  tipo: "info", // info | exito | error | peligro
  aceptar: "Aceptar",
  cancelar: null, // texto del botón cancelar; null = diálogo de solo aviso
});

let resolver = null;

const TITULOS = { info: "Aviso", exito: "Listo", error: "Error", peligro: "Confirmar" };

function abrir(mensaje, opciones, esConfirmacion) {
  // Si hubiera uno abierto, se resuelve como cancelado antes de abrir el nuevo
  if (resolver) resolver(false);
  const tipo = opciones.tipo ?? (esConfirmacion ? "peligro" : "info");
  Object.assign(estado, {
    abierto: true,
    mensaje,
    detalle: opciones.detalle ?? null,
    tipo,
    titulo: opciones.titulo ?? TITULOS[tipo],
    aceptar: opciones.aceptar ?? "Aceptar",
    cancelar: esConfirmacion ? opciones.cancelar ?? "Cancelar" : null,
  });
  return new Promise((r) => (resolver = r));
}

export function cerrarDialogo(resultado) {
  estado.abierto = false;
  const r = resolver;
  resolver = null;
  if (r) r(resultado);
}

export function useDialogo() {
  return {
    estado,
    alerta: (mensaje, opciones = {}) => abrir(mensaje, opciones, false),
    confirma: (mensaje, opciones = {}) => abrir(mensaje, opciones, true),
  };
}
