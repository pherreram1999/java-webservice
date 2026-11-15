/*
  Conversión entre el formulario de usuario (lo que edita la vista) y el objeto
  Usuario que espera / devuelve el servicio REST.
*/
import { sha256 } from "./sha256.js";

export const FOTO_POR_DEFECTO = "/usuario_sin_foto.png";

export function usuarioVacio() {
  return {
    email: "",
    password: "",
    nombre: "",
    apellido_paterno: "",
    apellido_materno: "",
    fecha_nacimiento: "", // "aaaa-mm-dd" (input type=date)
    telefono: "",
    genero: "", // "M", "F" o ""
    foto: null, // base64 sin el prefijo "data:...;base64,"
  };
}

const dosDigitos = (n) => String(n).padStart(2, "0");

// "aaaa-mm-dd" (hora local) -> ISO 8601, como lo enviaba prueba.html con datetime-local
function fechaAISO(valor) {
  if (!valor) return null;
  const [a, m, d] = valor.split("-").map(Number);
  return new Date(a, m - 1, d).toISOString();
}

// Fecha del servicio -> "aaaa-mm-dd" en hora local
function isoAFecha(valor) {
  if (valor == null) return "";
  const f = new Date(valor);
  if (isNaN(f)) return "";
  return `${f.getFullYear()}-${dosDigitos(f.getMonth() + 1)}-${dosDigitos(f.getDate())}`;
}

const vacioANull = (v) => (v == null || String(v).trim() === "" ? null : String(v).trim());

// Formulario -> cuerpo JSON para alta_usuario / modifica_usuario.
// Si la contraseña viene vacía se envía "" (en modifica_usuario significa "no cambiarla").
export function aUsuarioServicio(f) {
  const telefono = vacioANull(f.telefono);
  return {
    email: f.email.trim(),
    password: f.password !== "" ? sha256(f.password) : "",
    nombre: f.nombre.trim(),
    apellido_paterno: f.apellido_paterno.trim(),
    apellido_materno: vacioANull(f.apellido_materno),
    fecha_nacimiento: fechaAISO(f.fecha_nacimiento),
    telefono: telefono != null ? Number(telefono.replace(/\D/g, "")) : null,
    genero: f.genero === "M" || f.genero === "F" ? f.genero : null,
    foto: f.foto,
  };
}

// Respuesta de consulta_usuario -> formulario
export function desdeUsuarioServicio(u) {
  return {
    email: u.email ?? "",
    password: "",
    nombre: u.nombre ?? "",
    apellido_paterno: u.apellido_paterno ?? "",
    apellido_materno: u.apellido_materno ?? "",
    fecha_nacimiento: isoAFecha(u.fecha_nacimiento),
    telefono: u.telefono != null ? String(u.telefono) : "",
    genero: u.genero === "M" || u.genero === "F" ? u.genero : "",
    foto: u.foto ?? null,
  };
}

export function srcFoto(foto) {
  return foto ? `data:image/jpeg;base64,${foto}` : FOTO_POR_DEFECTO;
}

// "Ana", "Pérez" -> "AP" (se muestra cuando el usuario no tiene foto)
export function iniciales(nombre, apellido) {
  const letra = (t) => (t ?? "").trim().charAt(0).toUpperCase();
  return letra(nombre) + letra(apellido) || "?";
}

// Fecha del servicio -> "31 de enero de 2000"
export function fechaLarga(valor) {
  if (valor == null) return "";
  const f = new Date(valor);
  if (isNaN(f)) return "";
  return f.toLocaleDateString("es-MX", { day: "numeric", month: "long", year: "numeric" });
}

// 5512345678 -> "55 1234 5678" (solo para números de 10 dígitos)
export function telefonoLegible(valor) {
  if (valor == null || valor === "") return "";
  const t = String(valor);
  return t.length === 10 ? `${t.slice(0, 2)} ${t.slice(2, 6)} ${t.slice(6)}` : t;
}

export const GENEROS = { M: "Masculino", F: "Femenino" };
