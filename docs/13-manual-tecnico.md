# Manual técnico

Para quien tenga que instalar, mantener o ampliar Dermalia. Entregable de la
Semana 6 (manual técnico y de usuario). El manual de la persona que usa el
sistema está en [`14-manual-usuario.md`](14-manual-usuario.md).

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
```

| Pieza | Carpeta | Tecnología |
|---|---|---|
| Base de datos | `backend/` | MySQL 8.0.16 o superior (los `CHECK` se ignoran en 5.7) |
| Gestión y Cliente | `frontend/` | C++17, Qt 6 Widgets, cliente de MySQL (`mysql.h`) |
| Sitio web | `web/` | Vite, GSAP, three.js, Lenis |
| Documentación | `docs/` | Markdown |

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
mysql -u root -p < backend/03_sp_semana3.sql                 # login, ABM, horarios, alta de turno
mysql -u root -p < backend/04_sp_semana4.sql                 # seña, cancelación, cirugías, cupones, tarjetas, avisos
mysql -u root -p < backend/05_reportes_semana5.sql           # 8 reportes + auditoría
mysql -u root -p < backend/06_tuning_semana6.sql             # índices y versiones _tuneado
mysql -u root -p < backend/07_actividad_con_sps.sql          # (opcional) actividad de ejemplo que llena el log
```

> El primer script **borra** los 9 schemas y los vuelve a crear. No correrlo sobre datos reales.

Para verificar: `mysql -u root -p < backend/pruebas_estructura.sql` (44 pruebas de las
restricciones de las tablas) y
`python3 backend/pruebas/correr_pruebas.py --recargar` (198 casos de los SP; ver
[`11-pruebas-bbdd.md`](11-pruebas-bbdd.md)).

### En Aiven (producción)

1. Crear el servicio **MySQL** (plan gratuito) y copiar host, puerto, usuario y contraseña.
2. Conectarse **con SSL** (Aiven lo exige) y correr los mismos archivos en el mismo orden.
3. Aiven tiene el registro binario activo: por eso las funciones del proyecto declaran
   `NOT DETERMINISTIC`/`NO SQL`/`READS SQL DATA` (sin eso MySQL rechaza `CREATE FUNCTION`
   con el error 1418).
4. El usuario de las aplicaciones solo necesita `EXECUTE` sobre los schemas (no permisos
   sobre las tablas). Conviene crear uno para Qt y otro para n8n.

### Convenciones de los stored procedures

- Los que **escriben** abren una transacción, validan con `SIGNAL` (códigos `52xxx`),
  y tienen un `EXIT HANDLER FOR SQLEXCEPTION` que hace `ROLLBACK`, deja el fallo en el log y
  devuelve una fila `ERROR` (así lo muestra el PPT 006 de la cátedra).
- Todos devuelven 6 columnas: `estado, codigo, mensaje, id, valor, dato`.
- **El log solo se escribe desde los SP** (`auditoria.sp_registrar_log`); nunca con `INSERT` a mano.
- **Los estados y saldos no se guardan, se calculan** (`fn_sena`, `fn_saldo_tarjeta`,
  vigencia de cupones y evaluaciones).
- La hora sale de `auditoria.fn_ahora()`: es `NOW()`, salvo que la sesión defina
  `@ahora_simulado` (para pruebas y para cargar historia).

### Agregar un SP nuevo

1. Escribirlo en el archivo de su semana, con un comentario arriba que diga qué hace.
2. Seguir la plantilla de un SP existente (por ejemplo `agenda.sp_cancelar_turno`).
3. Sumar sus 4 casos a `backend/05_pruebas_sp.sql` (éxito, rechazo, nulos y límites, consistencia).
4. Regenerar la fila en `docs/12-contrato-sp.md`.

### Seguridad

- Las contraseñas se guardan como **SHA-256** sin sal: alcanza para el proyecto, pero en
  producción hay que pasar a un algoritmo lento con sal (bcrypt/argon2) en la aplicación.
- La seña es un mock: no se guardan datos de tarjetas (RNF-05).
- Al asistente de IA no se le mandan datos personales: `asistente.fn_filtrar_datos_personales`
  tacha emails y números largos antes de guardar.
- Los códigos de cupón rotan cada 5 minutos (hash SHA-256 del secreto y del tramo de tiempo;
  no es un HMAC formal). La tarjeta de regalo tiene un código largo y fijo.

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
./build/dermalia_cliente_bautista                      # terminal de la paciente
```

**Conexión a la base:** variables de entorno `DERMALIA_DB_HOST`, `_PORT`, `_USER`, `_PASS`,
`_NAME`, `_SSL` o un archivo `dermalia.ini` (ver `docs/conexion-base.md`). Sin conexión,
las aplicaciones avisan con una franja amarilla y trabajan en **modo contingencia**.

**Capas del código** (`frontend/comun/`):

| Archivo | Responsabilidad |
|---|---|
| `basedatos.*` | Conexión con `mysql.h` y `llamar("sp", {parámetros})` |
| `repositorio.*` | Un método por cada SP que usan las pantallas; devuelve datos ya interpretados |
| `conexionapp.*`, `avisoconexion.*`, `contingencia.*` | Aviso "sin conexión" y turnos guardados en el equipo |
| `validaciones.*`, `sena.h`, `reembolso.h` | Reglas que también valida la base (la pantalla las avisa antes) |

**Estado de la conexión a la base:** la capa `Repositorio` está hecha y probada contra MySQL
real (`prueba_base`: `DERMALIA_DB_USER=root ./build/prueba_base`). Las pantallas todavía usan
los datos de prueba de `gestion/datosprueba.cpp`: cambiarlas a `Repositorio` es la tarea
"conectar Gestión 1-3 y 5 / Cliente 1-3, 5" del plan (ver `15-guia-por-semana.md`). Los nombres
de los controles siguen la convención de la cátedra (`btnConfirmar`, `lblResumenTexto`...).

## 4. Sitio web

`cd web && npm install && npm run dev` y abrir `http://localhost:5173`. `npm run build` genera la
versión para publicar. Hoy usa datos fijos (los mismos que los de prueba de Gestión); conectarlo a
la base exige una capa intermedia (una API) que llame a los SP, porque el navegador no puede
hablar con MySQL.

## 5. Recordatorios con n8n

n8n corre en una VM gratuita de Google Cloud y hace, cada pocos minutos:

1. `CALL notificaciones.sp_notificaciones_pendientes(50)` → lista de avisos cuya hora llegó.
2. Envía cada uno por su canal (Telegram, WhatsApp o Google Calendar).
3. `CALL notificaciones.sp_marcar_notificacion(id, 'enviada' | 'fallida', detalle)`.

Un fallo se reintenta hasta 3 veces. Una vez por día corre también:
`CALL clinica.sp_vencer_evaluaciones('sistema')` (evaluaciones de 6 meses vencidas) y,
según la regla elegida, `CALL beneficios.sp_emitir_cupones('sistema')`.

## 6. Respaldos y problemas comunes

| Problema | Causa y solución |
|---|---|
| `ERROR 1418 ... DETERMINISTIC, NO SQL, or READS SQL DATA` | El servidor tiene registro binario: las funciones del proyecto ya declaran la característica; si se agrega una función, hay que declararla |
| Los `CHECK` no rechazan nada | MySQL 5.7 los ignora. Usar 8.0.16 o superior |
| Tildes que salen como `Ã¡` | Cliente sin `utf8mb4`: correr `SET NAMES utf8mb4;` (los scripts ya lo hacen) |
| `ERROR 1055 ... ONLY_FULL_GROUP_BY` al probar consultas propias | Todo campo del `SELECT` debe estar en el `GROUP BY` o dentro de un agregado |
| `Access denied for user 'root'@'localhost'` desde Python o Qt | `root` entra por socket; crear un usuario con contraseña o `ALTER USER ... IDENTIFIED WITH mysql_native_password` |
| El programa dice "sin conexión" | Revisar variables `DERMALIA_DB_*`, el servidor y, en Aiven, `DERMALIA_DB_SSL=1` |
| Respaldo | Aiven hace copias automáticas; además `mysqldump --routines --events --databases seguridad personas clinica agenda pagos beneficios notificaciones auditoria asistente > respaldo.sql` copiado fuera de la nube |
