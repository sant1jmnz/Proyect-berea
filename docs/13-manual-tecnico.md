# Manual técnico

Para quien tenga que instalar, mantener o ampliar Dermalia. Entregable de la
Semana 6 (manual técnico y de usuario). El manual de la persona que usa el
sistema está en [`14-manual-usuario.md`](14-manual-usuario.md).

## 0. Instalar y arrancar todo con un comando

En Ubuntu o Debian, desde la carpeta del proyecto:

```bash
./dermalia.sh instalar --apt   # instala MySQL, Qt, CMake y Node (pide sudo), crea la base, configura y compila
./dermalia.sh iniciar          # API + sitio en http://localhost:3000, y abre Gestión y la terminal
```

`instalar` (sin `--apt` si las dependencias ya están) hace, en orden: carga los 10 scripts de `backend/`, le pone una
contraseña nueva al usuario `dermalia_app` (solo puede ejecutar stored procedures), genera `web/.env` y
`frontend/dermalia.ini` (no se suben a git), pregunta la clave de Gemini y el WhatsApp del instituto (las dos son
opcionales), arma el sitio (`npm ci` y `npm run build`) y compila Gestión y la terminal en `frontend/build/`.

| Comando | Qué hace |
|---|---|
| `./dermalia.sh iniciar` | Arranca la API, que también sirve el sitio armado, y abre las dos apps (`--sin-apps` para solo la API) |
| `./dermalia.sh parar` | Apaga la API |
| `./dermalia.sh estado` | Muestra si andan MySQL y la API, y si el asistente usa Gemini |
| `./dermalia.sh probar` | Corre todas las pruebas: estructura (44), stored procedures (255), apps Qt (6 programas) y API (18) |
| `./dermalia.sh recargar-base` | Vuelve la base a los datos de ejemplo (por ejemplo, antes de la demo) |

Para entrar a MySQL como administrador prueba, en orden: las variables `DERMALIA_MYSQL_ADMIN_USER` y
`DERMALIA_MYSQL_ADMIN_PASS`, `sudo mysql` (lo normal en Ubuntu) y `root` pidiendo la contraseña.

## 1. Qué hay y cómo se conecta

```
 Terminal táctil (Qt)    PC de recepción (Qt)    Sitio web (Vite + three.js)
        \                      |                        /
         \                     |                       /   (llaman SOLO a stored procedures)
          +--------------------+----------------------+
                               |
                    MySQL 8 — 9 schemas (Aiven en producción)
                               |
                  n8n (VM de Google Cloud) → Telegram / WhatsApp / Google Calendar

   Asistente de IA: terminal y sitio → API del sitio (POST /api/asistente) → Gemini (o respuestas locales)
```

| Pieza | Carpeta | Tecnología |
|---|---|---|
| Base de datos | `backend/` | MySQL 8.0.16 o superior (los `CHECK` se ignoran en 5.7) |
| Gestión y Cliente | `frontend/` | C++17, Qt 6 Widgets, cliente de MySQL (`mysql.h`) |
| Sitio web | `web/` | Vite, GSAP, three.js, Lenis |
| Documentación | `docs/` | Markdown |

**Terminal y sitio hacen lo mismo.** Comparten las reglas (seña, 24 horas, cirugías, cupones, tarjetas de regalo,
máximo de 3 protocolos por turno) porque las aplica la base, y comparten los datos sin conexión: el catálogo de
ejemplo de las apps Qt (`frontend/comun/catalogogenerado.h`) y el del sitio (`web/src/datos/catalogo.generado.js`)
se generan con el mismo script (`npm run generar` en `web/`) desde `backend/02_datos.sql`. Las validaciones del
sitio (`web/src/js/validaciones.js`) repiten las de `frontend/comun/validaciones.cpp`. Si cambia el catálogo, hay
que volver a correr el script y subir los dos archivos generados.

**Cuenta de la paciente (sitio web).** Usa `seguridad.sp_crear_cuenta_paciente` y `seguridad.sp_login`, que ya existían.
La API del sitio (`web/api/servidor.js`) manda la contraseña tal cual, igual que la terminal y Gestión: así **la misma
cuenta sirve en la terminal y en el sitio**. La sesión es un token firmado (HMAC) de 12 horas. Variable:
`DERMALIA_SECRETO_SESIONES` (si falta, las sesiones se cierran al reiniciar la API). Se guarda en `web/.env` (no se sube
a Git; la plantilla es `web/.env.ejemplo`) y `npm run api` lo lee solo. Para quedarse con la cuenta de un DNI que ya existe hay que escribir además el
teléfono que dejó al reservar. Las cuentas del personal (Gestión) siguen como estaban.

La regla central: **la lógica del negocio vive en la base**, en stored
procedures. Las aplicaciones no escriben en tablas ni arman SQL propio: llaman a
los SP del catálogo [`12-contrato-sp.md`](12-contrato-sp.md). Así los tres
apartados cumplen exactamente las mismas reglas (seña, 24 horas, cirugías...).

## 2. La base de datos

**9 schemas** (en MySQL un schema es una base): `seguridad`, `personas`,
`clinica`, `agenda`, `pagos`, `beneficios`, `notificaciones`, `auditoria`,
`asistente`. 27 entidades + 2 tablas intermedias, en 3FN. El diseño está en
`docs/modelo-entidades.md` y `docs/diagramas/`; las decisiones de las
restricciones, en `backend/REVISION.md`.

### Instalación (local)

Hace falta MySQL 8 con permiso para crear schemas. En Ubuntu: `sudo apt install mysql-server`.
Después, en este orden (cada archivo supone los anteriores):

```bash
mysql -u root -p < backend/codigobasededatossolotablas.sql   # schemas y tablas (borra y recrea todo)
mysql -u root -p < backend/02_datos.sql                      # catálogos y datos de ejemplo
mysql -u root -p < backend/02b_numero.sql                    # tabla auxiliar de números (la usan horarios libres y cupones)
mysql -u root -p < backend/03_sp_semana3.sql                 # login, ABM, horarios, alta de turno
mysql -u root -p < backend/04_sp_semana4.sql                 # seña, cancelación, cirugías, cupones, tarjetas, avisos
mysql -u root -p < backend/05_reportes_semana5.sql           # 8 reportes + auditoría
mysql -u root -p < backend/06_tuning_semana6.sql             # versiones _tuneado
mysql -u root -p < backend/09_sp_pantallas.sql               # listados de las pantallas Cupones y Consultas previas
mysql -u root -p < backend/10_sp_telegram.sql                # bot de Telegram: vincular la paciente y sus avisos
mysql -u root -p < backend/07_actividad_con_sps.sql          # (opcional) actividad de ejemplo que llena el log
mysql -u root -p < backend/08_usuarios.sql                   # usuarios de las aplicaciones (solo pueden EJECUTAR los SP); cambiar las contraseñas
```

> El primer script **borra** los 9 schemas y los vuelve a crear. No correrlo sobre datos reales.

Para verificar: `mysql -u root -p < backend/pruebas_estructura.sql` (44 pruebas de las
restricciones de las tablas) y
`python3 backend/pruebas/correr_pruebas.py --recargar` (255 casos de los SP; ver
[`11-pruebas-bbdd.md`](11-pruebas-bbdd.md)).

### Usuarios y varias PCs

Los usuarios del personal están en `seguridad.Usuario`: los crea la administración desde la
pantalla *Usuarios* de Gestión (`seguridad.sp_alta_usuario`). Para entrar con el mismo usuario
desde otra PC, esa PC tiene que conectarse a **la misma base** (`DERMALIA_DB_HOST` apuntando al
servidor, por ejemplo Aiven). Si cada PC tiene su propio MySQL local, cada una tiene sus propios
usuarios y turnos.

### En Aiven (producción)

1. Crear el servicio **MySQL** (plan gratuito) y copiar host, puerto, usuario y contraseña.
2. Conectarse **con SSL** (Aiven lo exige) y correr los mismos archivos en el mismo orden.
3. Aiven tiene el registro binario activo: por eso las funciones del proyecto declaran
   `NOT DETERMINISTIC`/`NO SQL`/`READS SQL DATA` (sin eso MySQL rechaza `CREATE FUNCTION`
   con el error 1418).
4. Usar los usuarios de `backend/08_usuarios.sql` (`dermalia_app`, `dermalia_n8n`, `dermalia_reportes`): solo
   tienen `EXECUTE` sobre los schemas, sin permisos sobre las tablas (se probó: `SELECT` directo da error 1142).

### Convenciones de los stored procedures

- Los que **escriben** validan con `IF`: cada regla guarda su código (`52xxx`) y su mensaje en `v_codigo` y
  `v_mensaje` si no se cumple; si todas se cumplen, se escribe y se responde `OK`, y si no, se responde `ERROR`. Abren una transacción (`COMMIT`/`ROLLBACK`) y tienen
  un `EXIT HANDLER FOR SQLEXCEPTION` para los errores del motor, como en el PPT 006 de la cátedra.
- Todos devuelven 6 columnas: `estado, codigo, mensaje, id, valor, dato`.
- **El log solo se escribe desde los SP** (`auditoria.sp_registrar_log`); nunca con `INSERT` a mano.
- **Los estados y saldos no se guardan, se calculan**: el precio final y la seña de cada turno salen
  de la vista `agenda.PrecioTurno`; el saldo de una tarjeta, de sus movimientos; la vigencia de cupones
  y evaluaciones, de sus fechas.
- **Lo que usan varios SP está en una vista**, escrita una sola vez al principio de `03_sp_semana3.sql`:
  `agenda.PrecioTurno`, `agenda.DetalleTurno` (lo que muestran las pantallas de un turno; la usan
  `sp_buscar_turnos` y `sp_turnos_del_periodo`) y `personas.PrimerTelefonoPaciente`.
- La hora es `COALESCE(@ahora_simulado, NOW())`: la de la PC, salvo que la sesión defina
  `@ahora_simulado` (para pruebas y para cargar historia).

### Agregar un SP nuevo

1. Escribirlo en el archivo de su semana, con un comentario arriba que diga qué hace.
2. Seguir la plantilla de un SP existente (por ejemplo `agenda.sp_cancelar_turno`).
3. Sumar sus 4 casos a `backend/05_pruebas_sp.sql` (éxito, rechazo, nulos y límites, consistencia).
4. Regenerar la fila en `docs/12-contrato-sp.md`.

### Seguridad

- Las contraseñas se guardan y se comparan tal cual, sin encriptar (decisión del equipo para este trabajo).
- La seña es un mock: no se guardan datos de tarjetas (RNF-05).
- Al asistente de IA no le llegan datos personales: la API (`web/api/asistente.js`, `filtrarDatosPersonales`)
  borra los emails y los números de 7 o más dígitos (DNI, teléfonos, tarjetas) **antes** de mandar la pregunta a
  Gemini y antes de guardarla con `asistente.sp_registrar_consulta`. Se hace en la API y no en la base porque el
  material de la cátedra no enseña expresiones regulares en SQL (`asistente.fn_filtrar_datos_personales` quedó
  sin tachar nada). La clave de Gemini está solo en `web/.env`, en el servidor: ni el navegador ni la terminal la ven.
- Los códigos de cupón rotan cada 5 minutos (una cuenta simple de suma y resto con el secreto y el tramo
  de tiempo). Los códigos de seña y de tarjeta de regalo los genera la aplicación y la base solo los guarda.

### Usuarios de ejemplo

Contraseña de todos: `dermalia2026`.

| Usuario | Rol |
|---|---|
| `admin` | administrador |
| `recepcion1`, `recepcion2` | recepción |
| `dr.<apellido>` (por ejemplo `dr.marino`, `dr.quiroga`) | profesional |
| `<nombre>.<apellido>` (por ejemplo `maria.sosa`) | paciente con cuenta |

Tras 5 intentos fallidos en 15 minutos la cuenta se bloquea 15 minutos.

## 3. Aplicaciones de escritorio (Qt)

Requisitos en Ubuntu: `sudo apt install qt6-base-dev libmysqlclient-dev cmake ninja-build`.

```bash
cmake -S frontend -B build -G Ninja && cmake --build build
QT_QPA_PLATFORM=offscreen ctest --test-dir build      # pruebas automáticas
./build/dermalia_gestion                               # recepción
./build/dermalia_cliente                               # terminal de la paciente
```

**Conexión a la base:** variables de entorno `DERMALIA_DB_HOST`, `_PORT`, `_USER`, `_PASS`,
`_NAME`, `_SSL` o un archivo `dermalia.ini` (ver `docs/conexion-base.md`). Sin conexión,
las aplicaciones avisan con una franja amarilla y trabajan en **modo contingencia**.

**Cómo está organizado el código.** `frontend/comun/` es una biblioteca (`dermalia_comun`) que usan
las dos aplicaciones; `gestion/` y `cliente/` solo tienen sus pantallas (`dermalia_gestion_pantallas` y
`dermalia_cliente_pantallas`). El `CMakeLists.txt` arma esas bibliotecas una vez y cada programa y cada
prueba las usa, sin repetir la lista de archivos.

| Archivo de `comun/` | Responsabilidad |
|---|---|
| `basedatos.*` | Conexión con `mysql.h` como en el PPT 006 (`mysql_init`, `mysql_real_connect`, `mysql_query`, `mysql_store_result`, `mysql_fetch_row`) y `llamar("sp", {parámetros})`, que arma el `CALL` |
| `repositorio.*` | Un método por cada SP que usan las pantallas; devuelve datos ya interpretados |
| `modelo.h` | Las entidades que muestran las pantallas: protocolo, profesional, paciente, turno |
| `datosbase.*` | Pasa las filas de los SP al modelo |
| `almacenlocal.*`, `datosprueba.*` | Sin base: el archivo local de la PC y el catálogo inicial (el mismo de la base y la web) |
| `reglasturno.*` | Reglas de un turno que comparten las dos aplicaciones: horarios libres sin base, turno vigente, código de la seña, qué pasa con la seña al cancelar |
| `formato.*` | Cómo se muestran los datos: pesos, fechas, nombres; encabezado de las pantallas, filas de tabla, cartel de errores |
| `conexionapp.*`, `avisoconexion.*`, `contingencia.*` | Aviso "sin conexión" y turnos guardados en el equipo |
| `validaciones.*`, `sena.h`, `reembolso.h` | Reglas que también valida la base (la pantalla las avisa antes) |
| `buscadorprecios.*`, `resumentratamiento.*` | Buscador de precios y resumen de cada tratamiento (los dos programas) |

**Cómo funcionan con la base.** Al arrancar, cada aplicación prueba la conexión (`ConexionApp::probar`):

- **Gestión:** si hay conexión pide el **ingreso del personal** (`dialogologin`; para demos y pruebas, las
  variables `DERMALIA_USUARIO` y `DERMALIA_CLAVE` ingresan sin abrir la ventana) y lee de la base protocolos,
  pacientes, profesionales con sus franjas, turnos (±60 días) y avisos (`comun/datosbase.*`). Desde ahí,
  cargar turno, seña, cancelación, protocolos, pacientes, profesionales, avisos y reportes llaman a los
  stored procedures, con el usuario que ingresó en el log.
- **Cliente (terminal):** no pide ingreso (la paciente se identifica con el DNI): el catálogo y los
  horarios libres salen de la base; la reserva da de alta a la paciente nueva (pide la fecha de
  nacimiento), crea el turno y paga la seña simulada; buscar y cancelar también usan los SP.
- **Cupones, Tarjetas de regalo y Consultas previas** (Gestión) solo funcionan con la base: sin conexión
  quedan deshabilitadas y lo avisan.
- **Sin conexión:** las dos siguen con el archivo local (`frontend/comun/almacenlocal.*`: un
  `datos_local.json` en la carpeta de datos de la aplicación, o la ruta de `DERMALIA_DATOS_LOCAL`, que
  comparten Gestión y Terminal) y la franja amarilla. Los turnos que se cargan
  quedan en `pendientes.json` y, **al volver la conexión, se envían solos** (`ConexionApp::sincronizar`): los
  que la base no acepta (horario ocupado, paciente que no existe) siguen guardados y se avisa el motivo.
- Cada pantalla tiene un método `usarBase(Repositorio*)`: con `nullptr` trabaja en memoria como antes.

Pruebas: `DERMALIA_DB_USER=root DERMALIA_DB_PASS=... ctest --test-dir build` (ver `11-pruebas-bbdd.md`).
Sin las variables, las pruebas que usan la base se saltean. Los nombres de los controles siguen la
convención de la cátedra (`btnConfirmar`, `editDni`, `lblSaldo`...).

## 4. Sitio web

```bash
cd web && npm install
cp .env.ejemplo .env      # completar la base, el secreto de sesiones y (opcional) GEMINI_API_KEY
npm run build             # arma el sitio en web/dist
npm run api               # API en http://localhost:3000; si existe web/dist, también sirve el sitio
npm run dev               # (desarrollo) sitio en http://localhost:5173 con recarga en vivo; /api va a la API
npm run test:api          # pruebas de la API (con la base si están las DERMALIA_DB_*) y del asistente
```

El navegador no puede hablar con MySQL: `web/api/servidor.js` recibe pedidos HTTP y llama a los stored
procedures (`/api/protocolos`, `/api/horarios`, `/api/turnos`, `/api/turnos/:id/cancelar`, `/api/cupones`,
`/api/tarjetas`, `/api/cuenta`, `/api/sesion`, `/api/mi-cuenta`, `/api/asistente`, `/api/estado`). Cuando existe
`web/dist`, la misma API sirve el sitio: con un solo programa anda todo en `http://localhost:3000`.

### Asistente de IA (RF-14, RF-07, RNF-06, RNF-10)

Lo usan el sitio (botón flotante *¿Dudas? Preguntame*, `web/src/js/asistente.js`) y la terminal (*Preguntale al
asistente*, `frontend/cliente/dialogoasistente.cpp`). Los dos llaman a `POST /api/asistente` con
`{ pregunta, historial, origen }`; la lógica está una sola vez, en `web/api/asistente.js`:

1. Borra los datos personales de la pregunta (ver *Seguridad*).
2. Arma el contexto con el catálogo de la base (`clinica.sp_listar_protocolos`, guardado 5 minutos), los cuidados
   de cada protocolo (`web/src/datos/fichas.js`, los mismos de la ficha del sitio) y las reglas del instituto
   (seña, 24 horas, cirugías, cupones, tarjetas, horarios).
3. Si hay `GEMINI_API_KEY`, le pregunta a Gemini (modelo `GEMINI_MODELO`, por defecto `gemini-flash-lite-latest`,
   y si falla `gemini-flash-latest`) con la instrucción de responder **solo** con ese contexto y devolver
   `{ respuesta, derivar }` en JSON. Temperatura 0,2 y 12 segundos de espera como mucho.
4. Si no hay clave, no hay internet o Gemini falla (cuota, error), responde el **asistente local**: busca palabras
   del catálogo (con sinónimos: "botox" → toxina botulínica, "lipo" → lipoescultura) y de las reglas. Así la demo
   nunca queda sin respuesta.
5. Si no sabe, `derivada = true`: el sitio ofrece *Seguir por WhatsApp* con la pregunta escrita y la terminal
   manda a la recepción.
6. Registra la consulta con `asistente.sp_registrar_consulta` (con la paciente si tiene sesión iniciada).

La clave de Gemini se saca gratis en https://aistudio.google.com/apikey y va en `web/.env`. La terminal busca la
API en `DERMALIA_API_URL` o en `[asistente] url=` de `dermalia.ini` (por defecto `http://127.0.0.1:3000`).
El sitio (`web/src/datos/api.js`) usa la API cuando responde y, si no, los datos fijos del maquetado y el
`localStorage`. La reserva pide la fecha de nacimiento solo la primera vez (la base la necesita para dar de alta
a la paciente). `npm run build` genera el sitio estático; en producción la API y el sitio se publican bajo el
mismo dominio (`/api`).

**Catálogo:** el sitio ofrece todos los protocolos de la base (`web/src/datos/catalogo.generado.js`, generado desde
`backend/02_datos.sql`) y se relacionan con la base por nombre. El cupón del formulario se envía a la base, que
valida los cupones reales; el código de ejemplo `BIENVENIDA` solo baja el precio en pantalla cuando no hay API.

**Compus lentas.** El sitio se ve y anda igual en todas las PCs: todo se descarga y todas las animaciones
corren. Lo que cambia por dentro: las escenas 3D (`web/src/js/tres/escena.js`) miden cada 30 cuadros cuántos
dibujan por segundo y, si no llegan a 45, bajan la resolución interna del 3D de a 0,25 (hasta 0,75 por píxel):
la animación sigue completa y fluida, apenas menos nítida. Además, las líneas de la piel miden la página solo
cuando algo cambia de tamaño (antes la medían en cada cuadro, lo que traba a una compu lenta) y solo tocan el
SVG si la línea se movió. Las escenas se pausan cuando no están en pantalla o la pestaña está oculta.

### Bot de Telegram (RF-11)

Corre dentro de la API (`web/api/telegram.js`, lanzada con `npm run api` o `./dermalia.sh iniciar`) cuando se configura `TELEGRAM_BOT_TOKEN` en `web/.env`. Tiene dos modos. Por defecto usa **long polling** (`getUpdates` con `timeout: 25`): no necesita dirección pública ni HTTPS, y sirve igual en una notebook de demo. En producción (Vercel) usa **webhook**: Telegram avisa de cada mensaje con `POST /api/telegram`, que solo acepta a Telegram si trae el secreto de `TELEGRAM_WEBHOOK_SECRET` en la cabecera (sin él responde 403). Con `TELEGRAM_MENSAJES=webhook` la API de una PC deja de preguntar mensajes y solo manda avisos.

La memoria de la charla (últimos 6 mensajes para Gemini, se guardan 20 por chat, ventana de lectura de 6 h) y el paso de `/start` (vence a los 30 min) viven en las tablas `asistente.MensajeTelegram` y `asistente.EstadoTelegram`, porque en Vercel no hay proceso que recuerde. El bot saluda por el nombre de la paciente vinculada y `/limpiar` borra la charla (`asistente.sp_limpiar_historial_telegram`). En producción la base es Aiven con SSL: el certificado va en `DERMALIA_DB_CA`.

**Comandos y conversación:**
- `/start`: inicia la vinculación en dos pasos. Solicita el DNI (solo dígitos, 7 a 9 números) y luego el teléfono registrado al reservar (con código de área, sin 0 ni 15; ej. `1155550102`). Ejecuta `personas.sp_vincular_telegram(dni, telefono, chat_id, 'sistema')`. Si los datos coinciden, guarda el chat en la paciente y pasa los avisos pendientes de sus turnos futuros a Telegram. Si ya estaba vinculada, la saluda por su nombre y muestra la ayuda.
- `/turnos`: consulta turnos próximos (`pendiente` o `confirmado` en fecha futura) mediante `personas.sp_paciente_por_telegram(chat_id)` y `agenda.sp_buscar_turnos(dni, 0)`.
- `/salir`: desvincula el chat llamando a `personas.sp_desvincular_telegram(chat_id, 'sistema')`. Los avisos pendientes vuelven al canal WhatsApp asistido para que los gestione la recepción.
- `/ayuda` o `/help`: muestra los comandos disponibles.
- `/cancelar`: aborta el proceso de vinculación en curso.
- Cualquier otra consulta la responde el asistente de IA con el catálogo y las reglas del instituto (igual que en el sitio y la terminal), registrándola en `asistente.sp_registrar_consulta`.

**Envío de avisos automáticos:**
- Cada minuto consulta los avisos pendientes del canal Telegram llamando a `notificaciones.sp_notificaciones_telegram(500)` (hasta 500 avisos cuya hora ya llegó).
- Envía cada mensaje por Telegram (`sendMessage`) y reporta a la base el resultado con `notificaciones.sp_marcar_notificacion(id, 'enviada' | 'fallida', detalle)`. Los chats de formato inválido (por ejemplo los de prueba como `tg00001`) se marcan como fallidos directamente sin llamar a la API de Telegram. Ante errores de red o envío, la base reintenta hasta 3 veces antes de dejarlos definitivamente como fallidos.

**Tareas diarias (3:00):**
- Todos los días a las 3:00 de la madrugada ejecuta automáticamente `clinica.sp_vencer_evaluaciones('sistema')` (vence evaluaciones quirúrgicas aptas de más de 6 meses sin cirugía) y `beneficios.sp_emitir_cupones('sistema')` (emite cupones de fidelidad por visitas o gasto acumulado).

**Variables de entorno (`web/.env`):**
- `TELEGRAM_BOT_TOKEN`: token provisto por @BotFather. Sin este valor el bot permanece apagado y los avisos se gestionan desde la pantalla Avisos de Gestión.
- `TELEGRAM_ENVIOS=n8n`: desactiva el bucle de envío de avisos de la API (`avisos: false`). La API solo mantiene la conversación del bot y delega el envío de recordatorios a n8n para no duplicar mensajes.
- `TAREAS_DIARIAS=n8n`: desactiva la ejecución de tareas diarias a las 3:00 en la API (`tareas: false`), dejándolas a cargo de n8n.

## 5. Recordatorios con n8n

Las plantillas están en [`n8n/`](../n8n/README.md) (importar en n8n, poner las credenciales de MySQL y de
Telegram). **No se probaron contra una instancia de n8n.** El flujo hace, cada 5 minutos:

1. `CALL notificaciones.sp_notificaciones_pendientes(50)` → lista de avisos cuya hora llegó.
2. Envía cada uno por su canal (Telegram; WhatsApp y Calendar quedan para la recepción o la API oficial).
3. `CALL notificaciones.sp_marcar_notificacion(id, 'enviada' | 'fallida', detalle)`.

Un fallo se reintenta hasta 3 veces. Una vez por día corre `CALL clinica.sp_vencer_evaluaciones('sistema')` y
`CALL beneficios.sp_emitir_cupones('sistema')` (`n8n/tareas-diarias.workflow.json`).

## 6. Respaldos y problemas comunes

| Problema | Causa y solución |
|---|---|
| `ERROR 1418 ... DETERMINISTIC, NO SQL, or READS SQL DATA` | El servidor tiene registro binario: las funciones del proyecto ya declaran la característica; si se agrega una función, hay que declararla |
| Los `CHECK` no rechazan nada | MySQL 5.7 los ignora. Usar 8.0.16 o superior |
| Tildes que salen como `Ã¡` | Los datos se cargaron con un cliente en `latin1`. Todos los scripts empiezan con `SET NAMES utf8mb4;`: volver a cargarlos desde el primero |
| `ERROR 1055 ... ONLY_FULL_GROUP_BY` al probar consultas propias | Todo campo del `SELECT` debe estar en el `GROUP BY` o dentro de un agregado |
| `Access denied for user 'root'@'localhost'` desde Python o Qt | `root` entra por socket; crear un usuario con contraseña o `ALTER USER ... IDENTIFIED WITH mysql_native_password` |
| El programa dice "sin conexión" | Revisar variables `DERMALIA_DB_*`, el servidor y, en Aiven, `DERMALIA_DB_SSL=1` |
| Respaldo | Aiven hace copias automáticas; además `mysqldump --routines --events --databases seguridad personas clinica agenda pagos beneficios notificaciones auditoria asistente > respaldo.sql` copiado fuera de la nube |
