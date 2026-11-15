/*
  Enrutador de la SPA. Se usa historial con hash (/#/perfil) porque Tomcat sirve
  los archivos estáticos desde webapps/ROOT y no redirige rutas desconocidas a index.html.
*/
import { createRouter, createWebHashHistory } from "vue-router";
import { useSesion } from "../composables/sesion.js";
import MainLayout from "../layouts/MainLayout.vue";

const routes = [
  {
    path: "/",
    component: MainLayout,
    children: [
      { path: "", redirect: "/inicio" },
      {
        path: "login",
        name: "login",
        component: () => import("../views/LoginView.vue"),
        meta: { titulo: "Acceso al sistema", soloInvitado: true, sinEncabezado: true },
      },
      {
        path: "registro",
        name: "registro",
        component: () => import("../views/RegistroView.vue"),
        meta: { titulo: "Registro de usuario", soloInvitado: true },
      },
      {
        path: "inicio",
        name: "inicio",
        component: () => import("../views/InicioView.vue"),
        meta: { titulo: "Menú principal", requiereSesion: true },
      },
      {
        path: "perfil",
        name: "perfil",
        component: () => import("../views/PerfilView.vue"),
        meta: { titulo: "Perfil del usuario", requiereSesion: true },
      },
      {
        path: "captura-articulo",
        name: "captura-articulo",
        component: () => import("../views/CapturaArticuloView.vue"),
        meta: { titulo: "Captura de artículo", requiereSesion: true },
      },
      {
        path: "compra-articulos",
        name: "compra-articulos",
        component: () => import("../views/CompraArticulosView.vue"),
        meta: { titulo: "Compra de artículos", requiereSesion: true },
      },
      {
        path: "carrito",
        name: "carrito",
        component: () => import("../views/CarritoView.vue"),
        meta: { titulo: "Artículos en el carrito", requiereSesion: true },
      },
    ],
  },
  { path: "/:pathMatch(.*)*", redirect: "/inicio" },
];

const router = createRouter({
  history: createWebHashHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 }),
});

router.beforeEach((to) => {
  const { autenticado } = useSesion();
  if (to.meta.requiereSesion && !autenticado.value)
    return { name: "login", query: to.fullPath !== "/inicio" ? { redirect: to.fullPath } : {} };
  if (to.meta.soloInvitado && autenticado.value) return { name: "inicio" };
});

router.afterEach((to) => {
  document.title = to.meta.titulo ? `${to.meta.titulo} · Servicio de usuarios` : "Servicio de usuarios";
});

export default router;
