import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// En desarrollo (npm run dev) Vite sirve el cliente en el puerto 5173 y reenvía las
// llamadas al servicio (/servicio/...) al Tomcat local, así no hay problemas de CORS.
// En producción (npm run build) el resultado de dist/ se copia a tomcat/webapps/ROOT.
export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      "/servicio": "http://localhost:8080",
    },
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
});
