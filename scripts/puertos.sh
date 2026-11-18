#!/usr/bin/env bash
# Redirige con iptables (tabla nat) los puertos estándar a los de Tomcat, que corre sin root:
#   80  -> puerto HTTP de Tomcat  (8080, leído de tomcat/conf/server.xml)
#   443 -> puerto HTTPS de Tomcat (8443, el que configuró scripts/certificado.sh o HTTPS_PUERTO)
# Equivale a: sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
#
#   scripts/puertos.sh                   aplica las redirecciones (IPv4 e IPv6; no duplica si ya están)
#   scripts/puertos.sh --local           además redirige las conexiones desde esta misma máquina
#                                  (http://localhost/ llegaría a Tomcat en vez de a nginx u otro servidor)
#   scripts/puertos.sh --quita           quita todas las reglas que puso este script
#   scripts/puertos.sh --estado          muestra las reglas activas
#   scripts/puertos.sh --persistente     instala un servicio systemd que aplica las reglas al arrancar
#   scripts/puertos.sh --no-persistente  quita ese servicio (y las reglas)
#
# Las reglas llevan el comentario "servicio-web" para poder identificarlas y quitarlas.
# Sin --persistente, las reglas se pierden al reiniciar la máquina. Usa sudo.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

COMENTARIO="servicio-web"
UNIDAD="servicio-web-puertos.service"
SCRIPT="$RAIZ/scripts/puertos.sh"

requiere_tomcat
command -v iptables >/dev/null 2>&1 || error "No se encontró iptables (sudo dnf install iptables-nft)"

# Como root no hace falta sudo (p. ej. desde el servicio systemd)
if [ "$(id -u)" -eq 0 ]; then SUDO=(); else SUDO=(sudo); fi

COMANDOS=(iptables)
command -v ip6tables >/dev/null 2>&1 && COMANDOS+=(ip6tables)

PUERTO_HTTP="$(puerto_http)"
PUERTO_HTTPS="$(puerto_https)"
PUERTO_HTTPS="${PUERTO_HTTPS:-${HTTPS_PUERTO:-8443}}"

# Agrega la regla si no existe (-C la busca, -A la añade al final de la cadena)
regla() {
  local cmd="$1" cadena="$2" desde="$3" hacia="$4"; shift 4
  local args=(-t nat "$cadena" -p tcp "$@" --dport "$desde" -m comment --comment "$COMENTARIO" -j REDIRECT --to-ports "$hacia")
  if "${SUDO[@]}" "$cmd" -C "${args[@]}" 2>/dev/null; then
    echo "  [$cmd] ya existe: $cadena $desde -> $hacia"
  else
    "${SUDO[@]}" "$cmd" -A "${args[@]}"
    echo "  [$cmd] agregada:  $cadena $desde -> $hacia"
  fi
}

# Borra todas las reglas con nuestro comentario (convierte cada "-A ..." del listado en "-D ...")
quita_reglas() {
  local cmd linea n=0
  for cmd in "${COMANDOS[@]}"; do
    while IFS= read -r linea; do
      [ -n "$linea" ] || continue
      eval "set -- $linea"   # respeta las comillas del comentario
      shift                   # quita el "-A"
      "${SUDO[@]}" "$cmd" -t nat -D "$@"
      n=$((n + 1))
    done < <("${SUDO[@]}" "$cmd" -t nat -S 2>/dev/null | grep -F -- "--comment $COMENTARIO" || true)
  done
  echo "Reglas quitadas: $n"
}

aplica() {
  local local_tambien="$1" cmd
  echo "Redirigiendo 80 -> $PUERTO_HTTP y 443 -> $PUERTO_HTTPS:"
  for cmd in "${COMANDOS[@]}"; do
    regla "$cmd" PREROUTING 80 "$PUERTO_HTTP"
    regla "$cmd" PREROUTING 443 "$PUERTO_HTTPS"
    if [ "$local_tambien" = 1 ]; then
      regla "$cmd" OUTPUT 80 "$PUERTO_HTTP" -o lo
      regla "$cmd" OUTPUT 443 "$PUERTO_HTTPS" -o lo
    fi
  done

  # firewalld filtra después de la redirección, así que ve los puertos de Tomcat: hay que abrirlos
  if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
    local p
    for p in "$PUERTO_HTTP" "$PUERTO_HTTPS"; do
      if ! "${SUDO[@]}" firewall-cmd --quiet --query-port="$p/tcp"; then
        "${SUDO[@]}" firewall-cmd --quiet --add-port="$p/tcp"
        "${SUDO[@]}" firewall-cmd --quiet --permanent --add-port="$p/tcp"
        echo "  firewalld: abierto $p/tcp (zona por defecto)"
      fi
    done
  fi

  if [ "$local_tambien" = 0 ] && puerto_ocupado 80; then
    echo "AVISO: hay un servidor escuchando en el puerto 80 de esta máquina (¿nginx?). El tráfico externo" >&2
    echo "       al 80 ahora va a Tomcat; desde la propia máquina, http://localhost/ sigue yendo a ese servidor." >&2
  fi
  [ -n "$(puerto_https)" ] || echo "AVISO: Tomcat aún no tiene conector HTTPS; el 443 no responderá hasta ejecutar scripts/certificado.sh" >&2
  echo "Las reglas se pierden al reiniciar; para conservarlas: scripts/puertos.sh --persistente"
}

case "${1:-}" in
  "")       aplica 0 ;;
  --local)  aplica 1 ;;
  --quita)  quita_reglas ;;
  --estado)
    for cmd in "${COMANDOS[@]}"; do
      echo "== $cmd (tabla nat)"
      "${SUDO[@]}" "$cmd" -t nat -S | grep -F -- "--comment $COMENTARIO" || echo "  (sin reglas de $COMENTARIO)"
    done
    systemctl is-enabled --quiet "$UNIDAD" 2>/dev/null \
      && echo "Persistente: sí ($UNIDAD)" || echo "Persistente: no"
    ;;
  --persistente)
    LOCAL_FLAG=""
    [ "${2:-}" = "--local" ] && LOCAL_FLAG=" --local"
    # Servicio oneshot: aplica al arrancar (después de firewalld/red) y quita al detenerse
    printf '%s\n' \
      "[Unit]" \
      "Description=Redirección de puertos 80/443 a Tomcat (servicio-web)" \
      "After=network-online.target firewalld.service" \
      "Wants=network-online.target" \
      "" \
      "[Service]" \
      "Type=oneshot" \
      "RemainAfterExit=yes" \
      "ExecStart=$SCRIPT$LOCAL_FLAG" \
      "ExecStop=$SCRIPT --quita" \
      "" \
      "[Install]" \
      "WantedBy=multi-user.target" \
      | "${SUDO[@]}" tee "/etc/systemd/system/$UNIDAD" >/dev/null
    "${SUDO[@]}" systemctl daemon-reload
    quita_reglas >/dev/null   # las vuelve a poner el servicio, sin duplicar
    "${SUDO[@]}" systemctl enable --now "$UNIDAD"
    echo "Servicio $UNIDAD instalado y habilitado: las redirecciones se aplican en cada arranque."
    ;;
  --no-persistente)
    if [ -f "/etc/systemd/system/$UNIDAD" ]; then
      "${SUDO[@]}" systemctl disable --now "$UNIDAD" || true
      "${SUDO[@]}" rm -f "/etc/systemd/system/$UNIDAD"
      "${SUDO[@]}" systemctl daemon-reload
      echo "Servicio $UNIDAD eliminado."
    else
      echo "El servicio $UNIDAD no estaba instalado."
    fi
    quita_reglas
    ;;
  *) error "Opción desconocida: $1 (usa: scripts/puertos.sh [--local | --quita | --estado | --persistente [--local] | --no-persistente])" ;;
esac
