#!/usr/bin/env bash
# Dermalia: instalar, arrancar y probar todo el sistema con un solo comando.
#
#   ./dermalia.sh instalar   crea la base con datos de ejemplo, configura todo, compila las apps y arma el sitio
#   ./dermalia.sh iniciar    arranca la API + el sitio (http://localhost:3000) y abre Gestión y la terminal
#   ./dermalia.sh parar      apaga la API
#   ./dermalia.sh probar     corre todas las pruebas (base, apps Qt y API)
#   ./dermalia.sh estado     muestra qué está andando
#
# Requisitos (Ubuntu/Debian):
#   sudo apt install mysql-server qt6-base-dev qt6-multimedia-dev libmysqlclient-dev cmake g++ nodejs npm
# Con "./dermalia.sh instalar --apt" se instalan solos (pide la contraseña de sudo).
#
# Lo que se genera y NO se sube a git: web/.env (claves), frontend/dermalia.ini (conexión),
# frontend/build/ (programas compilados), web/dist/ (sitio armado).

set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB="$RAIZ/web"
FRONT="$RAIZ/frontend"
BUILD="$FRONT/build"
ENV_WEB="$WEB/.env"
INI="$FRONT/dermalia.ini"
PID_API="$RAIZ/.api.pid"
LOG_API="$RAIZ/.api.log"
PUERTO="${PUERTO_API:-3000}"

verde() { printf '\033[32m%s\033[0m\n' "$*"; }
amarillo() { printf '\033[33m%s\033[0m\n' "$*"; }
rojo() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
paso() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
hay() { command -v "$1" >/dev/null 2>&1; }

# Lee una variable de web/.env (si existe).
de_env() { [ -f "$ENV_WEB" ] && grep -E "^$1=" "$ENV_WEB" | tail -1 | cut -d= -f2- || true; }

# Escribe o reemplaza VARIABLE=valor en web/.env.
poner_env() {
  local clave="$1" valor="$2"
  touch "$ENV_WEB"
  if grep -qE "^$clave=" "$ENV_WEB"; then
    local tmp; tmp="$(mktemp)"
    awk -v k="$clave" -v v="$valor" -F= '$1==k {print k"="v; next} {print}' "$ENV_WEB" > "$tmp" && mv "$tmp" "$ENV_WEB"
  else
    echo "$clave=$valor" >> "$ENV_WEB"
  fi
}

aleatorio() { node -e "console.log(require('crypto').randomBytes(${1:-24}).toString('hex'))"; }

# ---------- MySQL como administrador ----------
# Prueba, en orden: DERMALIA_MYSQL_ADMIN_USER/PASS, "sudo mysql" (Ubuntu) y root pidiendo la contraseña.
MYSQL_ADMIN=()
conectar_admin() {
  if [ -n "${DERMALIA_MYSQL_ADMIN_USER:-}" ]; then
    MYSQL_ADMIN=(mysql -h "${DERMALIA_DB_HOST:-127.0.0.1}" -P "${DERMALIA_DB_PORT:-3306}" -u "$DERMALIA_MYSQL_ADMIN_USER")
    export MYSQL_PWD="${DERMALIA_MYSQL_ADMIN_PASS:-}"   # así mysql no avisa "using a password on the command line"
  elif mysql -e 'SELECT 1' >/dev/null 2>&1; then
    MYSQL_ADMIN=(mysql)
  elif hay sudo && sudo -n true 2>/dev/null && sudo mysql -e 'SELECT 1' >/dev/null 2>&1; then
    MYSQL_ADMIN=(sudo mysql)
  else
    read -rsp "Contraseña de root de MySQL (Enter si no tiene): " clave; echo
    MYSQL_ADMIN=(mysql -u root)
    export MYSQL_PWD="$clave" DERMALIA_MYSQL_ADMIN_PASS="$clave"
  fi
  "${MYSQL_ADMIN[@]}" -e 'SELECT 1' >/dev/null || { rojo "No pude entrar a MySQL como administrador."; exit 1; }
}

asegurar_mysql_andando() {
  if ! mysqladmin ping >/dev/null 2>&1 && ! (hay sudo && sudo -n true 2>/dev/null && sudo mysqladmin ping >/dev/null 2>&1); then
    amarillo "MySQL no responde; intento arrancarlo..."
    (sudo service mysql start || sudo systemctl start mysql || service mysql start) >/dev/null 2>&1 || true
    sleep 2
  fi
}

# ---------- instalar ----------
instalar() {
  if [ "${1:-}" = "--apt" ]; then
    paso "Instalando dependencias con apt"
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server qt6-base-dev qt6-multimedia-dev libmysqlclient-dev cmake g++ nodejs npm
  fi

  paso "Revisando lo que hace falta"
  local falta=0
  for c in mysql node npm cmake g++; do
    if hay "$c"; then verde "  ✓ $c"; else rojo "  ✗ falta $c"; falta=1; fi
  done
  [ "$falta" = 1 ] && { rojo "Instalá lo que falta (o corré: ./dermalia.sh instalar --apt)"; exit 1; }
  local version_node; version_node="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$version_node" -ge 20 ] || { rojo "Hace falta Node 20 o más nuevo (tenés $(node -v))."; exit 1; }

  paso "Base de datos (borra y recrea los 9 schemas con datos de ejemplo)"
  asegurar_mysql_andando
  conectar_admin
  cd "$RAIZ/backend"
  for f in codigobasededatossolotablas.sql 02_datos.sql 02b_numero.sql 03_sp_semana3.sql 04_sp_semana4.sql \
           05_reportes_semana5.sql 06_tuning_semana6.sql 09_sp_pantallas.sql 10_sp_telegram.sql 07_actividad_con_sps.sql 08_usuarios.sql; do
    printf '  %-40s' "$f"
    "${MYSQL_ADMIN[@]}" --default-character-set=utf8mb4 < "$f" >/dev/null && verde "ok"
  done
  # el usuario de las aplicaciones solo puede ejecutar los stored procedures; se le pone una clave nueva
  local clave_app; clave_app="$(de_env DERMALIA_DB_PASS)"
  [ -z "$clave_app" ] || [ "$(de_env DERMALIA_DB_USER)" != "dermalia_app" ] && clave_app="$(aleatorio 12)"
  "${MYSQL_ADMIN[@]}" -e "ALTER USER 'dermalia_app'@'%' IDENTIFIED BY '$clave_app'; FLUSH PRIVILEGES;"
  verde "  usuario de la base: dermalia_app (solo EXECUTE)"

  paso "Configuración (web/.env y frontend/dermalia.ini)"
  [ -f "$ENV_WEB" ] || cp "$WEB/.env.ejemplo" "$ENV_WEB"
  [ -n "$(de_env DERMALIA_SECRETO_SESIONES)" ] || poner_env DERMALIA_SECRETO_SESIONES "$(aleatorio 32)"
  poner_env DERMALIA_DB_HOST "${DERMALIA_DB_HOST:-127.0.0.1}"
  poner_env DERMALIA_DB_PORT "${DERMALIA_DB_PORT:-3306}"
  poner_env DERMALIA_DB_USER dermalia_app
  poner_env DERMALIA_DB_PASS "$clave_app"
  if [ -z "$(de_env GEMINI_API_KEY)" ] && [ -t 0 ]; then
    echo "Asistente de IA: pegá tu clave de Gemini (https://aistudio.google.com/apikey)."
    read -rsp "  Clave (Enter para seguir sin IA: responde con el catálogo y las reglas): " clave_gemini; echo
    [ -n "$clave_gemini" ] && poner_env GEMINI_API_KEY "$clave_gemini"
  fi
  if [ -z "$(de_env TELEGRAM_BOT_TOKEN)" ] && [ -t 0 ]; then
    echo "Bot de Telegram: pegá el token que te da @BotFather (/newbot)."
    read -rsp "  Token (Enter para seguir sin Telegram: los avisos quedan en Gestión): " token_tg; echo
    [ -n "$token_tg" ] && poner_env TELEGRAM_BOT_TOKEN "$token_tg"
  fi
  if [ -z "$(de_env VITE_WHATSAPP_INSTITUTO)" ] && [ -t 0 ]; then
    read -rp "  WhatsApp del instituto con código de país, sin + (Enter para dejarlo vacío): " wa
    [ -n "$wa" ] && poner_env VITE_WHATSAPP_INSTITUTO "$wa"
  fi
  cat > "$INI" <<EOF
; Generado por dermalia.sh. NO se sube a git.
[base]
host=${DERMALIA_DB_HOST:-127.0.0.1}
puerto=${DERMALIA_DB_PORT:-3306}
usuario=dermalia_app
clave=$clave_app
base=
ssl=false

[asistente]
url=http://127.0.0.1:$PUERTO
EOF
  verde "  listo"

  paso "Sitio web (npm ci y npm run build)"
  cd "$WEB"
  npm ci --no-audit --no-fund --loglevel=error
  npm run build --silent >/dev/null && verde "  sitio armado en web/dist"

  paso "Apps de escritorio (Gestión y terminal) con CMake"
  cmake -S "$FRONT" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release >/dev/null
  cmake --build "$BUILD" -j"$(nproc 2>/dev/null || echo 2)" --target dermalia_gestion dermalia_cliente >/dev/null
  verde "  compiladas en frontend/build"

  paso "Listo"
  echo "Arrancá todo con:  ./dermalia.sh iniciar"
  echo "Usuarios de ejemplo (contraseña dermalia2026): admin, recepcion1, maria.sosa (paciente)"
}

# ---------- iniciar / parar ----------
api_andando() { [ -f "$PID_API" ] && kill -0 "$(cat "$PID_API")" 2>/dev/null; }

iniciar() {
  [ -f "$ENV_WEB" ] && [ -d "$WEB/dist" ] && [ -x "$BUILD/dermalia_gestion" ] || { rojo "Primero: ./dermalia.sh instalar"; exit 1; }
  asegurar_mysql_andando
  if api_andando; then
    amarillo "La API ya estaba andando."
  else
    cd "$WEB"
    PUERTO_API="$PUERTO" nohup node --env-file=.env api/servidor.js > "$LOG_API" 2>&1 &
    echo $! > "$PID_API"
  fi
  for _ in $(seq 1 20); do curl -fs "http://localhost:$PUERTO/api/estado" >/dev/null 2>&1 && break; sleep 0.5; done
  local estado; estado="$(curl -fs "http://localhost:$PUERTO/api/estado" || echo '{}')"
  echo "API y sitio: http://localhost:$PUERTO   ($estado)"
  echo "$estado" | grep -q '"base":true' || amarillo "Ojo: la API no llega a la base. Mirá $LOG_API"

  if [ "${1:-}" != "--sin-apps" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    (hay xdg-open && xdg-open "http://localhost:$PUERTO" >/dev/null 2>&1 &) || true
    # las apps buscan dermalia.ini en la carpeta desde donde se abren: frontend/
    (cd "$FRONT" && nohup "$BUILD/dermalia_gestion" >/dev/null 2>&1 &)
    (cd "$FRONT" && nohup "$BUILD/dermalia_cliente" >/dev/null 2>&1 &)
    verde "Abiertos: el sitio, Gestión (recepcion1 / dermalia2026) y la terminal."
  fi
  echo "Para apagar la API: ./dermalia.sh parar"
}

parar() {
  if api_andando; then kill "$(cat "$PID_API")" && verde "API apagada."; else amarillo "La API no estaba andando."; fi
  rm -f "$PID_API"
}

estado() {
  mysqladmin ping >/dev/null 2>&1 && verde "MySQL: andando" || amarillo "MySQL: no responde (o hace falta sudo)"
  if api_andando; then verde "API: andando en http://localhost:$PUERTO  $(curl -fs "http://localhost:$PUERTO/api/estado" || true)"; else amarillo "API: apagada"; fi
  [ -n "$(de_env GEMINI_API_KEY)" ] && verde "Asistente: Gemini" || amarillo "Asistente: local (sin clave de Gemini)"
}

# ---------- probar ----------
probar() {
  [ -f "$ENV_WEB" ] || { rojo "Primero: ./dermalia.sh instalar"; exit 1; }
  conectar_admin
  local ok=0
  paso "Estructura de la base (44 casos, sobre tablas vacías: después se recarga todo)"
  "${MYSQL_ADMIN[@]}" < "$RAIZ/backend/codigobasededatossolotablas.sql"
  "${MYSQL_ADMIN[@]}" < "$RAIZ/backend/pruebas_estructura.sql" | tail -1

  paso "Stored procedures (255 casos)"
  hay python3 && python3 -c 'import pymysql' 2>/dev/null || pip install --user -q pymysql 2>/dev/null || true
  # el script de pruebas usa root; se le pasan los datos del administrador si los hay
  MYSQL_USER="${DERMALIA_MYSQL_ADMIN_USER:-root}" MYSQL_PASSWORD="${DERMALIA_MYSQL_ADMIN_PASS:-}" \
    python3 "$RAIZ/backend/pruebas/correr_pruebas.py" --recargar | tail -1 || ok=1

  paso "Recargando la base de ejemplo"
  instalar_solo_base

  paso "Apps Qt (incluye pruebas contra la base)"
  cmake -S "$FRONT" -B "$BUILD" >/dev/null && cmake --build "$BUILD" -j"$(nproc 2>/dev/null || echo 2)" >/dev/null
  (cd "$BUILD" && set -a && . "$ENV_WEB" && set +a && QT_QPA_PLATFORM=offscreen ctest --output-on-failure | tail -3) || ok=1

  paso "API del sitio y asistente"
  (cd "$WEB" && node --env-file=.env --test api/servidor.test.js api/asistente.test.js 2>&1 | grep -E '^# (pass|fail)') || ok=1
  [ "$ok" = 0 ] && verde "Todo OK" || rojo "Hubo fallas (ver arriba)"
}

instalar_solo_base() {
  cd "$RAIZ/backend"
  for f in codigobasededatossolotablas.sql 02_datos.sql 02b_numero.sql 03_sp_semana3.sql 04_sp_semana4.sql \
           05_reportes_semana5.sql 06_tuning_semana6.sql 09_sp_pantallas.sql 10_sp_telegram.sql 07_actividad_con_sps.sql 08_usuarios.sql; do
    "${MYSQL_ADMIN[@]}" --default-character-set=utf8mb4 < "$f" >/dev/null
  done
  "${MYSQL_ADMIN[@]}" -e "ALTER USER 'dermalia_app'@'%' IDENTIFIED BY '$(de_env DERMALIA_DB_PASS)'; FLUSH PRIVILEGES;"
  verde "  base recargada"
}

case "${1:-}" in
  instalar) shift; instalar "$@" ;;
  iniciar) shift; iniciar "$@" ;;
  parar) parar ;;
  probar) probar ;;
  estado) estado ;;
  recargar-base) conectar_admin; instalar_solo_base ;;
  *) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
