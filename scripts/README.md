# Scripts de producción

Scripts para dejar el servicio corriendo en un servidor: iniciar y detener Tomcat, arrancarlo al encender la máquina, HTTPS con Let's Encrypt y redirección de los puertos 80/443. Se pueden ejecutar desde cualquier carpeta (`scripts/inicia.sh` desde la raíz del proyecto, o con la ruta completa).

Los de desarrollo (`setup.sh`, `build.sh`, `dev.sh`) siguen en la raíz del proyecto: ver el [README principal](../README.md).

| Script | Para qué |
|---|---|
| [`inicia.sh`](#iniciash) | Inicia Tomcat en segundo plano (modo producción). |
| [`detiene.sh`](#detienesh) | Detiene el Tomcat iniciado con `inicia.sh`. |
| [`arranque.sh`](#arranquesh) | Inicia Tomcat automáticamente al encender la máquina (cron `@reboot`). |
| [`certificado.sh`](#certificadosh) | Certificado HTTPS de Let's Encrypt (certbot) → PKCS12 → conector HTTPS en `server.xml`. |
| [`puertos.sh`](#puertossh) | Redirige con iptables el 80 → 8080 y el 443 → 8443. |
| `common.sh` | Funciones y variables compartidas (lo cargan todos los scripts con `source`; no se ejecuta solo). |

## Puesta en marcha en un servidor nuevo

```bash
./setup.sh                                   # JDK 8, Tomcat, bibliotecas y dependencias del cliente
cp .env.example .env                         # y editar DB_USER / DB_PASSWORD (y HTTPS_PUERTO / CERT_CORREO si hace falta)
mysql -u <usuario> -p < database/schema.sql  # crea la base y las tablas
./build.sh                                   # compila y despliega servicio y cliente en tomcat/webapps
scripts/inicia.sh                            # Tomcat en segundo plano: http://<servidor>:8080/
scripts/arranque.sh                          # que vuelva a iniciar solo tras cada reinicio
scripts/puertos.sh --persistente             # 80 -> 8080 y 443 -> 8443, también tras reiniciar
scripts/certificado.sh midominio.com --correo admin@midominio.com --webroot "$PWD/tomcat/webapps/ROOT"
```

Para el certificado se usa `--webroot` con la carpeta pública de Tomcat porque, con la redirección de `puertos.sh` activa, la validación de Let's Encrypt en el puerto 80 llega a Tomcat (ver [certificado.sh](#certificadosh)). Si no vas a redirigir puertos, basta con `scripts/certificado.sh midominio.com`.

Variables de `.env` que usan estos scripts, además de las `DB_*` (ver el [README principal](../README.md#variables-de-entorno)):

| Variable | Por defecto | Uso |
|---|---|---|
| `HTTPS_PUERTO` | `8443` | Puerto del conector HTTPS que crea `certificado.sh` (≥ 1024). `puertos.sh` lo usa como destino del 443. |
| `CERT_CORREO` | — | Correo para los avisos de Let's Encrypt (equivale a `--correo`). |
| `CATALINA_OPTS` | — | Opciones de la JVM de Tomcat para `inicia.sh`, p. ej. `-Xms256m -Xmx1g`. |

---

## `inicia.sh`

```bash
scripts/inicia.sh
```

Inicia Tomcat con `catalina.sh start` en segundo plano (con `nohup`, así que sigue corriendo al cerrar la terminal o la sesión SSH). Espera hasta 2 minutos a que el puerto HTTP responda y muestra el PID, las URLs del servicio y del cliente, el puerto HTTPS si está configurado y la ruta del log.

- Las variables `DB_*` se leen de `.env` o del entorno, y Tomcat las hereda. Por eso Tomcat debe iniciarse con este script (o con `./dev.sh`).
- El log queda en `tomcat/logs/catalina.out` y el PID en `tomcat/temp/catalina.pid`.
- Se niega a arrancar si falta `DB_USER`, si `servicio.war` no está desplegado (`./build.sh`), si ya hay un Tomcat de `inicia.sh` corriendo o si el puerto HTTP (8080, leído de `tomcat/conf/server.xml`) está ocupado, p. ej. por `./dev.sh`.
- Si Tomcat no llega a escuchar, muestra las últimas 30 líneas del log y termina con error.

## `detiene.sh`

```bash
scripts/detiene.sh
```

Detiene el Tomcat iniciado con `inicia.sh`, usando el PID guardado. Espera hasta 30 s a que termine ordenadamente y, si no, lo mata (`catalina.sh stop 30 -force`). Si no hay ninguno corriendo, solo lo indica. No detiene un Tomcat iniciado con `./dev.sh` (ese se detiene con `./dev.sh stop`).

## `arranque.sh`

```bash
scripts/arranque.sh                 # habilita el inicio automático
scripts/arranque.sh --deshabilita   # lo quita
scripts/arranque.sh --estado        # indica si está habilitado
```

Agrega al crontab del usuario actual (sin root) una entrada `@reboot` que, al encender la máquina, espera 30 s (para que la red y MySQL estén listos) y ejecuta `inicia.sh`. La salida de cada arranque queda en `tomcat/logs/arranque.log`.

- La entrada va precedida de un comentario `# servicio-web: inicio automático de Tomcat (<ruta del proyecto>)`. Volver a ejecutarlo la reemplaza en vez de duplicarla, y `--deshabilita` quita solo esa entrada: las demás líneas del crontab se conservan.
- Requiere cron con el servicio habilitado: `sudo dnf install cronie && sudo systemctl enable --now crond` (Debian/Ubuntu: paquete `cron`, servicio `cron`). El script avisa si el servicio no está habilitado.
- Si mueves el proyecto de carpeta, vuelve a ejecutarlo para que la entrada apunte a la ruta nueva.

## `certificado.sh`

```bash
scripts/certificado.sh midominio.com --correo admin@midominio.com      # certbot levanta su propio servidor en el puerto 80
scripts/certificado.sh midominio.com --webroot <carpeta pública>       # si otro servidor ya atiende el puerto 80
scripts/certificado.sh midominio.com --staging                         # pruebas: certificado no confiable, sin límites de emisión
HTTPS_PUERTO=9443 scripts/certificado.sh midominio.com                 # otro puerto HTTPS
scripts/certificado.sh --quita                                         # quita el conector HTTPS de server.xml
```

Obtiene un certificado gratuito de Let's Encrypt con **certbot** y deja Tomcat sirviendo HTTPS. Tomcat (con JSSE) no lee directamente los `.pem` de certbot, así que el script los convierte a un **almacén PKCS12** y añade a `server.xml` el conector que lo usa.

**Requisitos**

- Un dominio público (registro DNS `A`/`AAAA`) que apunte al servidor. Let's Encrypt no emite certificados para `localhost` ni para IPs.
- certbot y openssl: `sudo dnf install certbot openssl` (Debian/Ubuntu: `sudo apt install certbot`).
- Permisos de `sudo`: certbot corre como root y deja los certificados en `/etc/letsencrypt`. El script se ejecuta como el usuario normal (no con `sudo`) y pide la contraseña solo para certbot y para leer la llave privada.
- El **puerto 80** accesible desde Internet durante la emisión y en cada renovación, y el puerto HTTPS abierto en el firewall: `sudo firewall-cmd --permanent --add-port=80/tcp --add-port=8443/tcp && sudo firewall-cmd --reload` (no hace falta si usas `puertos.sh`, que abre los suyos).

**Modos de validación**

- **Standalone** (sin `--webroot`): certbot levanta su propio servidor en el puerto 80, que tiene que estar libre. Si algo lo ocupa, el script se detiene y sugiere `--webroot`.
- **`--webroot <carpeta>`**: el servidor que ya atiende el puerto 80 sirve el reto `.well-known/acme-challenge/` desde esa carpeta. Con `puertos.sh` activo ese servidor es Tomcat, así que usa `--webroot "$PWD/tomcat/webapps/ROOT"`. Si es nginx/Apache, usa su carpeta pública para ese dominio (p. ej. `/usr/share/nginx/html`).

**Pasos que sigue**

1. `sudo certbot certonly` emite (o conserva, si sigue vigente) el certificado y registra este script como *deploy hook* para las renovaciones.
2. `openssl pkcs12 -export` une `fullchain.pem` + `privkey.pem` en `tomcat/conf/certificado/servicio.p12` (alias `tomcat`), cifrado con una contraseña aleatoria que se genera la primera vez y se reutiliza después.
3. Añade a `tomcat/conf/server.xml`, antes del `<Engine>`, un conector `Http11NioProtocol` con `SSLEnabled="true"` (TLS 1.2/1.3) que apunta a ese almacén (`certificateKeystoreType="PKCS12"`, `type` RSA o EC según la llave), y ajusta `redirectPort` del conector HTTP. El bloque va entre comentarios `servicio-web: conector HTTPS`, así que volver a ejecutar el script lo reemplaza en vez de duplicarlo, y `--quita` lo elimina.
4. Activa el timer de renovación de certbot (`certbot-renew.timer` en Fedora, `certbot.timer` en Debian).
5. Si el Tomcat de `inicia.sh` está corriendo, lo reinicia para cargar el certificado.

Resultado: `https://midominio.com:8443/` (cliente) y `https://midominio.com:8443/servicio/rest/ws/...` (servicio), o sin puerto con `puertos.sh`. El HTTP en 8080 sigue funcionando.

**Dónde queda cada cosa**

| Ruta | Contenido |
|---|---|
| `/etc/letsencrypt/live/<dominio>/` | Certificado (`fullchain.pem`) y llave privada (`privkey.pem`) de certbot. Solo los lee root. |
| `/etc/letsencrypt/renewal/<dominio>.conf` | Configuración de renovación de certbot, incluido el hook `scripts/certificado.sh --hook`. |
| `tomcat/conf/certificado/servicio.p12` | Almacén PKCS12 que usa Tomcat (permisos `600`, dueño el usuario del proyecto). |
| `tomcat/conf/certificado/clave` | Contraseña del almacén (permisos `600`). |
| `tomcat/conf/server.xml` | Conector HTTPS añadido; queda con permisos `600` porque contiene la contraseña. |
| `tomcat/conf/server.xml.original` | Copia de `server.xml` anterior a la primera modificación. |

`tomcat/` no se versiona (está en `.gitignore`), así que ni el almacén ni la contraseña acaban en git.

**Renovación**

Los certificados de Let's Encrypt duran 90 días. El timer de certbot ejecuta `certbot renew` dos veces al día y renueva cuando faltan menos de 30 días. Después de cada renovación, certbot ejecuta `scripts/certificado.sh --hook` como root, que regenera `servicio.p12` y, si Tomcat estaba corriendo con `inicia.sh`, lo reinicia como el usuario del proyecto (Tomcat 8.5 no recarga el certificado en caliente; el reinicio se lanza con `systemd-run --scope` para que no muera al terminar el servicio de certbot). Para comprobar la renovación sin esperar: `sudo certbot renew --dry-run`. Si mueves el proyecto de carpeta, vuelve a ejecutar `scripts/certificado.sh <dominio>` para que el hook apunte a la ruta nueva.

Uso interno (no se ejecutan a mano): `--hook` lo llama certbot tras renovar, y `--exporta <dominio>` lo llama el propio script con `sudo` para generar el PKCS12.

## `puertos.sh`

```bash
scripts/puertos.sh                   # aplica las redirecciones (no duplica las que ya existen)
scripts/puertos.sh --local           # también para conexiones desde el propio servidor (cadena OUTPUT, interfaz lo)
scripts/puertos.sh --estado          # reglas activas y si están persistentes
scripts/puertos.sh --quita           # quita todas las reglas del script
scripts/puertos.sh --persistente     # servicio systemd que las aplica en cada arranque (--persistente --local también vale)
scripts/puertos.sh --no-persistente  # quita ese servicio y las reglas
```

Tomcat corre sin root y no puede abrir puertos menores a 1024, por eso usa 8080 (HTTP) y 8443 (HTTPS). Este script agrega reglas `REDIRECT` en la tabla `nat` de iptables (IPv4 e IPv6) para que `http://midominio.com/` y `https://midominio.com/` lleguen a Tomcat sin indicar puerto. Es lo mismo que:

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 80  -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
```

- Los puertos de destino se leen de `tomcat/conf/server.xml`: el conector HTTP y el conector HTTPS de `certificado.sh`, o `HTTPS_PUERTO` si aún no existe.
- Las reglas llevan el comentario `servicio-web`. `--quita` borra solo esas y deja intactas las demás reglas de iptables.
- Sin `--persistente`, las reglas **se pierden al reiniciar**. `--persistente` instala `/etc/systemd/system/servicio-web-puertos.service` (oneshot), que las aplica después de la red y de firewalld y las quita al detenerse. El inicio de Tomcat (`arranque.sh`) es aparte.
- `PREROUTING` solo afecta al tráfico que llega de otras máquinas. Desde el propio servidor `http://localhost/` no se redirige, salvo que uses `--local`. Para probar en local usa `http://localhost:8080/` o `--local`.
- **firewalld** filtra después de la redirección, así que ve los puertos 8080/8443: el script los abre en la zona por defecto (en tiempo de ejecución y de forma permanente). También hay que permitir 80/443 en el router o en el firewall externo, si lo hay.
- Si en el servidor hay otro servidor web en el 80/443 (nginx, Apache), con la redirección activa el tráfico externo va a Tomcat y ya no a ese servidor, y certbot standalone deja de recibir la validación: usa `certificado.sh --webroot "$PWD/tomcat/webapps/ROOT"`. La alternativa es no redirigir y que nginx/Apache termine TLS y haga de proxy hacia `http://localhost:8080`.
- Requiere iptables (en Fedora, `iptables-nft`, que convive con firewalld) y `sudo`.

Si el cliente se sirve desde otro origen, `VITE_HOST_SERVICIO` debe usar `https://` para evitar contenido mixto.
