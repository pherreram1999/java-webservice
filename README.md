# Servicio web de usuarios

Arquitectura de tres capas para desarrollo local:

- **Cliente** (`frontend/`): SPA con Vue 3 + Vue Router, compilada con Vite y estilizada con Tailwind CSS (PostCSS). El cliente original (`prueba.html`) quedó como referencia en `frontend/legacy/`.
- **Servicio REST** (`backend/`): Java 8, Jersey 2.24 y Jackson sobre Tomcat 8.5.99.
- **Base de datos** (`database/`): MySQL, base `servicio_web`.

## Puesta en marcha

```bash
./setup.sh                 # una sola vez: descarga JDK 8, Tomcat 8.5.99 y Jersey (sin sudo) y hace npm install del cliente
cp .env.example .env       # y editar DB_USER / DB_PASSWORD
mysql -u <usuario> -p < database/schema.sql    # crea la base y las tablas
./build.sh                 # compila servicio y cliente, y despliega ambos en tomcat/webapps
./dev.sh                   # inicia Tomcat en primer plano (Ctrl+C para detener)
```

| Script | Qué hace |
|---|---|
| `./setup.sh` | Instala JDK 8 en `jdk8/`, Tomcat en `tomcat/`, las bibliotecas en `backend/WEB-INF/lib` y las dependencias del cliente (`frontend/node_modules`). Es idempotente. Requiere Node.js 20.19+ instalado en el sistema (se detecta también si viene de nvm). |
| `./build.sh` | Compila, empaca `servicio.war`, reemplaza el despliegue anterior, compila el cliente (`npm run build`) y publica `frontend/dist` en `webapps/ROOT`. Con Tomcat corriendo, se redespliega solo. `./build.sh back` compila solo el servicio y `./build.sh front` solo el cliente. Si está corriendo el Tomcat de **producción** (en segundo plano: `scripts/inicia.sh` o `catalina.sh start`), solo compila y no toca `webapps`; para publicar ahí hay que agregar `--despliega` (p. ej. `./build.sh back --despliega`). |
| `./dev.sh` | Inicia Tomcat y muestra el puerto en el que corre. Falla con un aviso si el puerto está ocupado. |
| `./dev.sh stop` | Detiene un Tomcat iniciado en otra terminal. |
| `scripts/` | Scripts de producción: `inicia.sh` / `detiene.sh` (Tomcat en segundo plano), `arranque.sh` (inicio automático con cron), `certificado.sh` (HTTPS con Let's Encrypt → PKCS12 → `server.xml`) y `puertos.sh` (iptables 80 → 8080, 443 → 8443). Ver [scripts/README.md](scripts/README.md). |
| `./dev.sh front` | Servidor de desarrollo de Vite en `http://localhost:5173` con recarga en caliente; reenvía `/servicio/...` al Tomcat (que debe estar corriendo con `./dev.sh` en otra terminal). |

Después de modificar `backend/servicio/*.java` basta con ejecutar `./build.sh`. Para trabajar en el cliente conviene `./dev.sh` en una terminal y `./dev.sh front` en otra.

## Producción

Para dejar el servicio en un servidor (Tomcat en segundo plano, inicio automático, HTTPS con Let's Encrypt y puertos 80/443) ver **[scripts/README.md](scripts/README.md)**, que explica cada script y trae la secuencia completa de puesta en marcha.

## Cliente (frontend/)

| Ruta | Contenido |
|---|---|
| `src/main.js`, `src/App.vue` | Arranque de la app; `App.vue` monta el enrutador y el diálogo modal global. |
| `src/router/index.js` | Rutas `#/login`, `#/registro`, `#/inicio`, `#/perfil`, `#/captura-articulo`, `#/compra-articulos`, `#/carrito` (historial con hash, porque Tomcat no redirige rutas desconocidas a `index.html`). Las rutas con sesión redirigen al login. |
| `src/layouts/MainLayout.vue` | Encabezado, navegación y `RouterView` con transición entre páginas. |
| `src/views/` | Una vista por pantalla del cliente original (acceso, registro, menú principal, perfil). |
| `src/components/ModalDialog.vue` + `src/composables/dialogo.js` | Diálogo modal que reemplaza a `alert()` / `confirm()`: `await alerta(msg)`, `await confirma(msg)`. |
| `src/api/servicio.js` | Llamadas al servicio REST con `fetch` (reemplaza a `WSClient.js`). |
| `src/utils/sha256.js` | Hash SHA-256 de la contraseña (mismo resultado que el cliente original). |
| `src/styles.css` | Tailwind v4 (vía `@tailwindcss/postcss`) y tokens de diseño: acento `blue-800`, fondos blanco roto. |

## Variables de entorno

Se leen del archivo `.env` (en la raíz) si existe, y si no, del sistema operativo. Si una variable está en los dos lugares, **gana `.env`**. `dev.sh` las exporta y el servicio las lee al iniciar, por lo que **Tomcat debe iniciarse con `dev.sh`** (o desde un shell que ya tenga las variables).

| Variable | Obligatoria | Por defecto | Descripción |
|---|---|---|---|
| `DB_USER` | Sí | — | Usuario de MySQL. |
| `DB_PASSWORD` | No | vacía | Contraseña del usuario de MySQL. |
| `DB_HOST` | No | `localhost` | Servidor de MySQL. |
| `DB_PORT` | No | `3306` | Puerto de MySQL. |
| `DB_NAME` | No | `servicio_web` | Nombre de la base de datos. |
| `JAVA_HOME` | No | `./jdk8` | JDK a usar (si se define en `.env`, `setup.sh` no descarga el JDK 8). |
| `CATALINA_HOME` | No | `./tomcat` | Directorio de Tomcat. |
| `HTTPS_PUERTO` | No | `8443` | Puerto del conector HTTPS que configura `scripts/certificado.sh` (≥ 1024). |
| `CERT_CORREO` | No | — | Correo para los avisos de Let's Encrypt (equivale a `--correo` de `scripts/certificado.sh`). |
| `VITE_HOST_SERVICIO` | No | mismo origen | Host del servicio REST que usa el cliente, p. ej. `http://mi-servidor:8080` (la ruta `/servicio/rest/ws` es fija). Vite lo incrusta al compilar (`./build.sh front`) o al iniciar `./dev.sh front`, así que hay que recompilar al cambiarlo. Si es otro origen, el servicio debe permitir CORS. También puede ir en `frontend/.env` al usar `npm` directamente. |

## Endpoints del servicio REST

Base: `http://localhost:8080/servicio/rest/ws` (el prefijo `/servicio` lo fija el nombre de `servicio.war`; `/rest` sale de `web.xml` y `/ws` del `@Path` de la clase `Servicio`). Todos los endpoints regresan JSON.

| Método | Ruta | Requiere sesión | Qué hace |
|---|---|---|---|
| `GET` | [`/login`](#get-login) | no | Inicia sesión y devuelve `id_usuario` y `token`. |
| `POST` | [`/alta_usuario`](#post-alta_usuario) | no | Registra un usuario (con foto opcional). |
| `GET` | [`/consulta_usuario`](#get-consulta_usuario) | sí | Devuelve los datos del usuario. |
| `PUT` | [`/modifica_usuario`](#put-modifica_usuario) | sí | Modifica los datos, la contraseña y la foto. |
| `DELETE` | [`/borra_usuario`](#delete-borra_usuario) | sí | Borra el usuario, su foto y devuelve su carrito al stock. |
| `POST` | [`/alta_articulo`](#post-alta_articulo) | sí | Da de alta un artículo en el stock con su fotografía. |
| `GET` | [`/consulta_articulos`](#get-consulta_articulos) | sí | Busca artículos por nombre o descripción. |
| `PUT` | [`/compra_articulo`](#put-compra_articulo) | sí | Pasa unidades del stock al carrito del usuario. |
| `GET` | [`/consulta_carrito_compra`](#get-consulta_carrito_compra) | sí | Lista los artículos del carrito del usuario. |
| `DELETE` | [`/elimina_articulo_carrito_compra`](#delete-elimina_articulo_carrito_compra) | sí | Quita un artículo del carrito y lo regresa al stock. |
| `DELETE` | [`/elimina_carrito_compra`](#delete-elimina_carrito_compra) | sí | Vacía el carrito y lo regresa al stock. |

La descripción formal (parámetros, esquemas y respuestas) está en [`openapi.json`](openapi.json) (OpenAPI 3.0.3); se puede abrir en Swagger Editor o importar en Postman/Insomnia. Debe actualizarse siempre que cambie un endpoint.

### Convenciones

- **Sesión.** `GET /login` devuelve `id_usuario` y `token`; los endpoints marcados «sí» reciben ambos como parámetros de consulta (`?id_usuario=1&token=...`). Cada login genera un token nuevo e **invalida el anterior** (un token por usuario). Si no coinciden, el servicio responde «Acceso denegado».
- **Éxito:** HTTP 200. **Error** (incluido «Acceso denegado»): HTTP 400 con `{"mensaje": "<texto del error>"}`.
- **Contraseña:** el cliente envía el **hash SHA-256 en hexadecimal** (64 caracteres) y el servidor lo guarda y compara tal cual. Nunca se devuelve en las respuestas.
- **Imágenes** (`foto`, `fotografia`): base64 sin el prefijo `data:...;base64,`.
- **Fechas:** se envían en ISO 8601 (`2000-01-31T00:00:00.000Z`).
- **Transacciones:** las operaciones que tocan más de una tabla se ejecutan en una transacción; si algo falla se deshace todo.
- **Orden de comprobaciones:** en `alta_articulo` se validan los datos y luego se verifica el acceso; en `modifica_usuario` es al revés.

### Usuarios

#### `GET /login`

Verifica el email y la contraseña y escribe un token aleatorio de 20 caracteres en `usuarios.token`.

- **Parámetros:** `email`, `password` (hash SHA-256 hexadecimal).
- **200:** `{"id_usuario": 1, "token": "aB3dE5gH7jK9mN1pQ3sT"}`
- **400:** `Acceso denegado` (email inexistente o contraseña incorrecta).

#### `POST /alta_usuario`

Registra un usuario. No requiere sesión. Si viene `foto`, se guarda en `fotos_usuarios` dentro de la misma transacción.

- **Cuerpo JSON:**

  ```json
  {
    "email": "ana@example.com", "password": "<sha256>", "nombre": "Ana",
    "apellido_paterno": "Pérez", "apellido_materno": null,
    "fecha_nacimiento": "2000-01-31T00:00:00.000Z",
    "telefono": 5512345678, "genero": "F", "foto": "<base64 o null>"
  }
  ```

  Obligatorios: `email`, `password`, `nombre`, `apellido_paterno`, `fecha_nacimiento`. Opcionales: `apellido_materno`, `telefono`, `genero` (`M` o `F`), `foto`.
- **200:** `{"mensaje": "Se dio de alta el usuario"}`
- **400:** `Se debe ingresar el email` / `la contraseña` / `el nombre` / `el apellido paterno` / `la fecha de nacimiento`; o el error de MySQL si el email ya existe (índice único).

#### `GET /consulta_usuario`

Devuelve los datos del usuario de la sesión.

- **Parámetros:** `id_usuario`, `token`.
- **200:** el objeto usuario, sin contraseña (`password` siempre `null`) y con la `foto` en base64 (o `null`):

  ```json
  {"email":"ana@example.com","password":null,"nombre":"Ana","apellido_paterno":"Pérez",
   "apellido_materno":null,"fecha_nacimiento":"2000-01-31T00:00:00.000","telefono":5512345678,
   "genero":"F","foto":"iVBORw0KGgo..."}
  ```
- **400:** `Acceso denegado`.

#### `PUT /modifica_usuario`

Reemplaza los datos del usuario de la sesión.

- **Parámetros:** `id_usuario`, `token`. **Cuerpo JSON:** igual que `alta_usuario`.
- **Reglas:** `email`, `nombre`, `apellido_paterno` y `fecha_nacimiento` son obligatorios. El campo `password` **debe venir siempre**: con `""` se conserva la contraseña actual; con un hash se cambia. La foto anterior siempre se borra: si viene `foto` se guarda la nueva y con `null` el usuario se queda sin foto.
- **200:** `{"mensaje": "Se modificó el usuario"}`
- **400:** `Acceso denegado`, o `Se debe ingresar el email` / `el nombre` / `el apellido paterno` / `la fecha de nacimiento`.

#### `DELETE /borra_usuario`

Borra la cuenta del usuario de la sesión. En una sola transacción: regresa al stock lo que tuviera en el carrito, borra el carrito, su foto y el usuario.

- **Parámetros:** `id_usuario`, `token`.
- **200:** `{"mensaje": "Se borró el usuario"}`
- **400:** `Acceso denegado`.

### Artículos

#### `POST /alta_articulo`

Da de alta un artículo: inserta en `stock` y en `fotos_articulos` dentro de una transacción.

- **Parámetros:** `id_usuario`, `token`. **Cuerpo JSON:**

  ```json
  {"nombre": "Mayonesa", "descripcion": "Frasco de 400 g", "precio": 42.50,
   "cantidad": 10, "fotografia": "<base64>"}
  ```

  Obligatorios: `nombre`, `precio` (≥ 0), `cantidad` (existencias iniciales, ≥ 0) y `fotografia`. `descripcion` es opcional.
- **200:** `{"mensaje": "OK"}`
- **400:** `Se debe ingresar el nombre del artículo` / `un precio válido` / `una cantidad válida` / `la fotografía del artículo`, o `Acceso denegado`. Si falla, no se guarda nada.

#### `GET /consulta_articulos`

Busca la palabra en `nombre` y en `descripcion` con `LIKE '%palabra%'`.

- **Parámetros:** `palabra` (opcional; vacía = todos los artículos), `id_usuario`, `token`.
- **200:** arreglo ordenado por nombre (vacío si no hay coincidencias). `descripcion` y `fotografia` se omiten cuando son nulas. No incluye la cantidad en existencia.

  ```json
  [{"id_articulo": 1, "nombre": "Mayonesa", "descripcion": "Frasco de 400 g",
    "precio": 42.50, "fotografia": "<base64>"}]
  ```
- **400:** `Acceso denegado`.

### Carrito de compra

Cada usuario tiene su propio carrito (tabla `carrito_compra`); un artículo aparece una sola vez por carrito y lo que está en el carrito **ya no cuenta como existencia** en `stock`.

#### `PUT /compra_articulo`

Pasa unidades del stock al carrito del usuario.

- **Parámetros:** `id_articulo`, `cantidad` (entero > 0), `id_usuario`, `token`.
- **Qué hace**, en una transacción que bloquea el artículo (`SELECT ... FOR UPDATE`) para que dos compras simultáneas no vendan más de lo que hay: si `cantidad` ≤ existencias, inserta el artículo en el carrito (o suma la cantidad si ya estaba) y la resta de `stock`.
- **200:** `{"mensaje": "OK"}`
- **400:** `La cantidad a comprar debe ser mayor que cero`, `El artículo no existe`, `No hay suficientes artículos en el stock` o `Acceso denegado`. Si falla, el carrito y el stock quedan como estaban.

#### `GET /consulta_carrito_compra`

Lista el carrito del usuario. No estaba en los requerimientos originales: lo usa la pantalla «Artículos en el carrito». El costo (cantidad × precio) y el total los calcula el cliente.

- **Parámetros:** `id_usuario`, `token`.
- **200:** arreglo ordenado por nombre (vacío si no hay compras); `cantidad` es la cantidad comprada.

  ```json
  [{"id_articulo": 1, "nombre": "Mayonesa", "precio": 42.50, "cantidad": 3, "fotografia": "<base64>"}]
  ```
- **400:** `Acceso denegado`.

#### `DELETE /elimina_articulo_carrito_compra`

Quita un artículo del carrito del usuario: suma su cantidad de vuelta a `stock` y borra la línea del carrito, en una transacción.

- **Parámetros:** `id_usuario`, `id_articulo`, `token`.
- **200:** `{"mensaje": "OK"}`
- **400:** `El artículo no está en el carrito de compra` o `Acceso denegado`.

#### `DELETE /elimina_carrito_compra`

Vacía el carrito del usuario. En una transacción ejecuta un `UPDATE` de `stock` por cada artículo y un solo `DELETE` de las líneas del usuario; los carritos de otros usuarios no se tocan. Con el carrito vacío también responde `OK`.

- **Parámetros:** `id_usuario`, `token`.
- **200:** `{"mensaje": "OK"}`
- **400:** `Acceso denegado`.

## Rutas para probar

Tomcat escucha en el puerto **8080** (`dev.sh` lo muestra al arrancar; se lee de `tomcat/conf/server.xml`).

### Cliente web

| URL | Para qué |
|---|---|
| `http://localhost:8080/` | Cliente web (SPA): registro, acceso, perfil, modificación y borrado de usuario; captura de artículos, compra y carrito. |
| `http://localhost:5173/` | El mismo cliente servido por Vite (`./dev.sh front`), con recarga en caliente. |
| `http://localhost:8080/usuario_sin_foto.png` | Comprobación rápida de que Tomcat sirve `webapps/ROOT`. |

Flujo sugerido en el cliente: registrar un usuario → intentar registrar el mismo email (debe mostrar error) → iniciar sesión → ver el perfil → modificarlo y volver a consultarlo → eliminar el perfil → intentar iniciar sesión otra vez (debe mostrar «Acceso denegado»).

### Servicio REST

Base: `http://localhost:8080/servicio/rest/ws`. La descripción de cada endpoint está en la sección [Endpoints del servicio REST](#endpoints-del-servicio-rest).

Ejemplo con `curl` (contraseña `secreta`):

```bash
BASE=http://localhost:8080/servicio/rest/ws
HASH=$(printf 'secreta' | sha256sum | cut -d' ' -f1)

# 1. Alta
curl -X POST "$BASE/alta_usuario" -H 'Content-Type: application/json' -d "{
  \"email\":\"ana@example.com\", \"password\":\"$HASH\", \"nombre\":\"Ana\",
  \"apellido_paterno\":\"Pérez\", \"apellido_materno\":null,
  \"fecha_nacimiento\":\"2000-01-31T00:00:00.000Z\", \"telefono\":5512345678,
  \"genero\":\"F\", \"foto\":null }"

# 2. Login (anotar id_usuario y token de la respuesta)
curl "$BASE/login?email=ana@example.com&password=$HASH"

ID=1; TOKEN=<token-del-login>

# 3. Consulta
curl "$BASE/consulta_usuario?id_usuario=$ID&token=$TOKEN"

# 4. Modificación ("password":"" conserva la contraseña actual; el campo no puede omitirse)
curl -X PUT "$BASE/modifica_usuario?id_usuario=$ID&token=$TOKEN" -H 'Content-Type: application/json' -d '{
  "email":"ana@example.com", "password":"", "nombre":"Ana María",
  "apellido_paterno":"Pérez", "fecha_nacimiento":"2000-01-31T00:00:00.000Z", "foto":null }'

# 5. Borrado
curl -X DELETE "$BASE/borra_usuario?id_usuario=$ID&token=$TOKEN"
```

### Pruebas con curl: artículos y carrito

Continúa con `BASE`, `ID` y `TOKEN` del ejemplo anterior (hay que tener un usuario con sesión iniciada).

```bash
# Alta de un artículo (fotografia = imagen en base64, sin saltos de línea)
FOTO=$(base64 -w0 frontend/public/usuario_sin_foto.png)
curl -X POST "$BASE/alta_articulo?id_usuario=$ID&token=$TOKEN" -H 'Content-Type: application/json' -d "{
  \"nombre\":\"Mayonesa\", \"descripcion\":\"Frasco de 400 g\", \"precio\":42.50, \"cantidad\":10,
  \"fotografia\":\"$FOTO\" }"                                  # {"mensaje":"OK"}

# Búsqueda (palabra vacía = todos); anotar el id_articulo
curl "$BASE/consulta_articulos?palabra=mayo&id_usuario=$ID&token=$TOKEN"
ART=1

# Compra: 3 unidades (stock 10 -> 7); repetirla suma al carrito (3 -> 6, stock 7 -> 4)
curl -X PUT "$BASE/compra_articulo?id_articulo=$ART&cantidad=3&id_usuario=$ID&token=$TOKEN"
curl -X PUT "$BASE/compra_articulo?id_articulo=$ART&cantidad=3&id_usuario=$ID&token=$TOKEN"

# Más de lo que hay -> HTTP 400 {"mensaje":"No hay suficientes artículos en el stock"}
curl -i -X PUT "$BASE/compra_articulo?id_articulo=$ART&cantidad=999&id_usuario=$ID&token=$TOKEN"

# Contenido del carrito
curl "$BASE/consulta_carrito_compra?id_usuario=$ID&token=$TOKEN"

# Quitar un artículo del carrito (regresa su cantidad al stock) y vaciar todo el carrito
curl -X DELETE "$BASE/elimina_articulo_carrito_compra?id_usuario=$ID&id_articulo=$ART&token=$TOKEN"
curl -X DELETE "$BASE/elimina_carrito_compra?id_usuario=$ID&token=$TOKEN"
```

Para comprobar el stock: `SELECT id_articulo,nombre,cantidad FROM stock;` y `SELECT * FROM carrito_compra;` en MySQL.

### Pruebas automáticas con curl (`test/`)

Con Tomcat corriendo (`./dev.sh`) y la base creada:

```bash
./test/todos.sh                          # todas las pruebas y un resumen al final
./test/todos.sh login compra_articulo    # solo algunas (nombre del script sin .sh)
./test/compra_articulo.sh                # o un solo método, directamente
API_BASE=http://otro-host:8080/servicio/rest/ws ./test/todos.sh
```

Hay un script por método web (`alta_usuario`, `login`, `consulta_usuario`, `modifica_usuario`, `borra_usuario`, `alta_articulo`, `consulta_articulos`, `compra_articulo`, `consulta_carrito_compra`, `elimina_articulo_carrito_compra`, `elimina_carrito_compra`). Cada uno crea sus propios datos (prefijo `zz_test_<id>`), prueba el caso correcto y los errores (validaciones, «Acceso denegado», stock insuficiente) y verifica que el stock y el carrito queden consistentes. Al terminar borra lo que creó: los usuarios con el propio servicio y los artículos directamente en MySQL con las credenciales de `.env` (no existe un endpoint para borrar artículos; sin cliente `mysql` quedan en `stock` con el prefijo `zz_test_`). Requiere `curl` y `jq`. Código de salida: 0 todo bien, 1 alguna prueba falló, 2 no se pudo probar (servicio o base no disponibles).

### Qué errores indican qué

| Respuesta | Causa probable |
|---|---|
| `Cannot create PoolableConnectionFactory (Access denied ...)` | `DB_USER` / `DB_PASSWORD` incorrectos o no definidos. |
| `Unknown database 'servicio_web'` / `Table ... doesn't exist` | Falta ejecutar `database/schema.sql`. |
| `Acceso denegado` | Credenciales o token incorrectos (el token cambia en cada login). |
| 404 en `/servicio/...` | `servicio.war` no está desplegado: ejecutar `./build.sh`. |
