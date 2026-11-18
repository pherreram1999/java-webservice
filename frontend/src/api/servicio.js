/*
  Cliente del servicio REST (reemplaza a WSClient.js).
  Cada función devuelve una promesa con { ok, codigo, datos }:
    - ok:     true si el servicio respondió HTTP 200
    - datos:  cuerpo de la respuesta ya convertido de JSON (en error: { mensaje })
  Nunca lanza excepciones: un fallo de red se reporta como ok=false.
*/
// Host del servicio (p. ej. http://mi-servidor:8080), definido al compilar con la variable
// VITE_HOST_SERVICIO; si no se define, se usa el mismo origen que sirve el cliente.
// La ruta /servicio/rest/ws es fija.
const HOST_SERVICIO = (import.meta.env.VITE_HOST_SERVICIO || "").replace(/\/+$/, "");
const URL_BASE = `${HOST_SERVICIO}/servicio/rest/ws`;

async function consulta(metodo, recurso, parametros, cuerpo) {
  let url = `${URL_BASE}/${recurso}`;
  if (parametros) {
    const qs = new URLSearchParams();
    for (const [nombre, valor] of Object.entries(parametros))
      if (valor !== undefined && valor !== null) qs.append(nombre, valor);
    const texto = qs.toString();
    if (texto) url += `?${texto}`;
  }

  let respuesta;
  try {
    respuesta = await fetch(url, {
      method: metodo,
      headers: cuerpo !== undefined ? { "Content-Type": "application/json" } : undefined,
      body: cuerpo !== undefined ? JSON.stringify(cuerpo) : undefined,
    });
  } catch {
    return { ok: false, codigo: 0, datos: { mensaje: "No se pudo conectar con el servidor" } };
  }

  const texto = await respuesta.text();
  let datos;
  try {
    datos = JSON.parse(texto);
  } catch {
    datos = { mensaje: texto || `Error HTTP ${respuesta.status}` };
  }
  return { ok: respuesta.status === 200, codigo: respuesta.status, datos };
}

export const servicio = {
  login: (email, passwordHash) => consulta("GET", "login", { email, password: passwordHash }),
  altaUsuario: (usuario) => consulta("POST", "alta_usuario", null, usuario),
  consultaUsuario: (sesion) => consulta("GET", "consulta_usuario", sesion),
  modificaUsuario: (sesion, usuario) => consulta("PUT", "modifica_usuario", sesion, usuario),
  borraUsuario: (sesion) => consulta("DELETE", "borra_usuario", sesion),

  altaArticulo: (sesion, articulo) => consulta("POST", "alta_articulo", sesion, articulo),
  consultaArticulos: (sesion, palabra) => consulta("GET", "consulta_articulos", { ...sesion, palabra }),
  compraArticulo: (sesion, id_articulo, cantidad) =>
    consulta("PUT", "compra_articulo", { ...sesion, id_articulo, cantidad }),
  consultaCarritoCompra: (sesion) => consulta("GET", "consulta_carrito_compra", sesion),
  eliminaArticuloCarritoCompra: (sesion, id_articulo) =>
    consulta("DELETE", "elimina_articulo_carrito_compra", { ...sesion, id_articulo }),
  eliminaCarritoCompra: (sesion) => consulta("DELETE", "elimina_carrito_compra", sesion),
};

// Mensaje legible de una respuesta de error
export function mensajeDeError(datos) {
  if (datos && typeof datos.mensaje === "string" && datos.mensaje) return datos.mensaje;
  return "Ocurrió un error inesperado";
}
