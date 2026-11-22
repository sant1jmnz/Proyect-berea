# Dermalia

Sistema de gestión de turnos (escritorio y web) para **Dermalia, Instituto de
Estética Médica** (barrio de Flores, CABA). Repositorio del proyecto de
*Proyecto Informático I* y de la sección de **Bases de Datos** (Prof.
Cynthia Berea y Pablo Linares), 4to año, especialidad Computación, Escuela
Técnica de CABA. Marco pedagógico: **Buenos Aires Aprende**.

El trabajo se divide en dos bimestres:

- **3er bimestre**: la **Carpeta de Proyecto V1** (formulación y diseño: árboles,
  MML, requerimientos, maquetado y pitch). Quedó archivada en la rama
  `dermalia-carpeta-proyecto-v1`.
- **4° bimestre (actual)**: construir el sistema (frontend en Qt, base de datos
  MySQL, sitio web), el análisis de competencia y el pitch de venta. Arrancó
  el **6 de octubre de 2026**.

## Probarlo en 2 comandos

En Ubuntu o Debian, desde esta carpeta:

```bash
./dermalia.sh instalar --apt
```

```bash
./dermalia.sh iniciar
```

El primero instala lo que falte (MySQL, Qt, CMake, Node), crea la base con datos de ejemplo, configura todo y
compila. El segundo abre el sitio en `http://localhost:3000`, Gestión (usuario `recepcion1`, contraseña
`dermalia2026`) y la terminal táctil. Para el asistente con IA, pegá una clave de Gemini cuando la pida
(gratis en https://aistudio.google.com/apikey); sin clave responde igual, con el catálogo y las reglas del
instituto. `./dermalia.sh probar` corre todas las pruebas. Detalle en
[`docs/13-manual-tecnico.md`](docs/13-manual-tecnico.md).

## Desafío integrador

> ¿De qué manera podemos identificar y analizar una problemática real de
> nuestra comunidad o escuela para diseñar una propuesta de solución de
> software viable, justificada y bien estructurada?

En el 4° bimestre el objetivo es traducir los requerimientos y la planificación
del bimestre anterior en un producto de software funcional, con persistencia en
una base de datos relacional, y validar su viabilidad comercial frente a la
competencia (ver [`docs/plan-4to-bimestre.md`](docs/plan-4to-bimestre.md)).

## Propuesta elegida

La gestión de turnos y consultas del instituto depende hoy de la atención
manual de la recepción por WhatsApp: 95 minutos diarios respondiendo
consultas repetidas, 6 turnos perdidos por semana por inasistencia (≈
$900.000) y 5 superposiciones de agenda por mes. El sistema propuesto
ataca esas cuatro causas con:

| Módulo | Función |
|---|---|
| Cargar turno en 3 pasos | Protocolo → horario disponible → confirmación, con agenda propia de los profesionales en el sistema |
| Buscador de precios y protocolos | Búsqueda por palabra clave; deriva a WhatsApp si no encuentra coincidencia |
| Registro de seña | Simulado (mock que imita un pago real), sin procesar dinero real |
| Recordatorio de turno | Por Telegram (gratis, en desarrollo) y WhatsApp en producción; botón para agregar el turno a Google Calendar |
| Cirugías | Consulta previa paga obligatoria; solo se agenda con evaluación "apta" vigente (6 meses) |
| Buscar turnos | Por DNI o teléfono, sin cuenta; con cuenta opcional se guarda el historial |
| Asistente de IA | Responde consultas con el catálogo, los cuidados y las reglas del instituto (Gemini, o respuestas locales sin internet); deriva a WhatsApp si no sabe y no recibe datos personales |
| Cupones y tarjetas de regalo | Cupones por código o QR, tarjetas con saldo y cupones por fidelidad |

Tres apartados: una **terminal táctil** en el instituto, que usa la
paciente para cargar su propio turno; la **PC de recepción**, para los
turnos que llegan por teléfono; y un **sitio web** para reservar desde
cualquier lugar. Detalle completo en
[`docs/04-requerimientos.md`](docs/04-requerimientos.md).

**Stack técnico**: base de datos **MySQL**, aplicación de escritorio en
**Qt** y **sitio web**; se permiten APIs externas (Google Calendar,
WhatsApp, asistente de IA con Gemini).

El equipo relevó diez propuestas en `docs/propuestas.md`. Esta quedó como
principal frente a otras cuatro (POS de kiosco, adopción de mascotas,
reserva de laboratorios, reclamos de mantenimiento) porque tenía más
evidencia disponible y era viable de terminar en el bimestre.

## Cadena lógica

```
Causas del Árbol de Problemas  →  Medios del Árbol de Objetivos
                               →  Componentes y Actividades de la MML
                               →  Requerimientos funcionales
                               →  Pantallas del maquetado
```

Ejemplo de un camino completo, de principio a fin: *C1.1 (WhatsApp no
integrado a agenda digital) → M1 (integrar WhatsApp con agenda digital) →
R1 (módulo de reserva con agenda propia) → RF-01/RF-02/RF-03 → Pantallas 1
y 2 del maquetado ("Elegir protocolo", "Elegir horario")*.

## Entregable final: estado de cada pieza

| # | Pieza | Documento | Estado |
|---|---|---|---|
| 1 | Diagnóstico, Árbol de Problemas | [`docs/01-arbol-de-problemas.md`](docs/01-arbol-de-problemas.md) | Hecho |
| 2 | Propuesta estratégica, Árbol de Objetivos | [`docs/02-arbol-de-objetivos.md`](docs/02-arbol-de-objetivos.md) | Hecho |
| 3 | Matriz de Marco Lógico (MML) | [`docs/03-matriz-marco-logico.md`](docs/03-matriz-marco-logico.md) | Hecho |
| 4 | Requerimientos funcionales y no funcionales | [`docs/04-requerimientos.md`](docs/04-requerimientos.md) | Hecho (RF-01 a RF-25, RNF-01 a RNF-14) |
| 5 | Maquetado y pantallas | [`docs/05-maquetado.md`](docs/05-maquetado.md) | Hecho: todas las pantallas construidas (capturas en `docs/capturas/`) |
| 6 | Software: Gestión, terminal y sitio web | `frontend/`, `web/` | Hecho, conectado a la base, con asistente de IA; se instala con `./dermalia.sh` |
| 7 | Base de datos (consigna de Bases de Datos) | `backend/`, [`docs/consigna-bbdd.md`](docs/consigna-bbdd.md) | Hecho: 9 schemas, stored procedures, 8 reportes, auditoría y tuning; entrega en `entrega-hito-2/` |
| 8 | Diagramas Chen y Codd | [`docs/diagramas/`](docs/diagramas/) | Hecho (`.drawio` y `.png`) |
| 9 | Pruebas | [`docs/09`](docs/09-casos-de-prueba.md), [`docs/10`](docs/10-casos-de-prueba-cliente.md), [`docs/11`](docs/11-pruebas-bbdd.md) | 239 casos de stored procedures, 44 de estructura, 6 programas de prueba Qt y 12 de la API: todo OK |
| 10 | Análisis de competencia y PUV | [`docs/07-competencia.md`](docs/07-competencia.md) | Hecho |
| 11 | Presupuesto, monetización y retorno | [`docs/08-presupuesto.md`](docs/08-presupuesto.md) | Hecho |
| 12 | Pitch de venta (5 a 7 min) con demo | [`docs/06-pitch.md`](docs/06-pitch.md) | Guion, demo y objeciones listos; falta ensayar |
| 13 | Manual técnico y de usuario | [`docs/13`](docs/13-manual-tecnico.md), [`docs/14`](docs/14-manual-usuario.md) | Hecho |
| 14 | Arquitectura y contingencia | [`docs/arquitectura.md`](docs/arquitectura.md), [`docs/conexion-base.md`](docs/conexion-base.md) | Hecho |

Documentos de apoyo: [`docs/propuestas.md`](docs/propuestas.md) (las diez
propuestas relevadas y por qué se eligió esta), [`docs/foda.md`](docs/foda.md)
(FODA del equipo), [`docs/plan-de-aprendizaje.md`](docs/plan-de-aprendizaje.md)
(cronograma del 3er bimestre), [`docs/plan-4to-bimestre.md`](docs/plan-4to-bimestre.md)
(cronograma del 4° bimestre, transcripción del PDF), [`docs/reparto-4to-bimestre.md`](docs/reparto-4to-bimestre.md)
(tareas de Santiago y Bautista semana a semana, martes de frontend y miércoles y jueves de base de datos) y [`docs/metodologia-sql.md`](docs/metodologia-sql.md) (cómo se trabaja en SQL: metodología de Bases de Datos, rúbricas y técnica de optimización, con los scripts de profundización 02 en `docs/catedra/profundizacion-02/`), [`docs/material-catedra.md`](docs/material-catedra.md)
(resumen de los videos de cátedra, alojados como [release `material-catedra`](https://github.com/sant1jmnz/Proyect-berea/releases/tag/material-catedra)),
[`docs/catedra/bbdd-006-conectar-c-con-mysql.md`](docs/catedra/bbdd-006-conectar-c-con-mysql.md) (PPT de la cátedra para conectar C/C++ con MySQL, con sus ejemplos),
[`docs/conexion-base.md`](docs/conexion-base.md) (cómo se conecta la aplicación a MySQL o a Aiven, y el modo contingencia) y los casos de prueba funcional de Gestión y Cliente
([`docs/09-casos-de-prueba.md`](docs/09-casos-de-prueba.md), [`docs/10-casos-de-prueba-cliente.md`](docs/10-casos-de-prueba-cliente.md)).

## Indicadores principales (MML: Propósito)

Todos medidos a las 4 semanas de uso del sistema:

- Reducción del 60% en el tiempo diario de atención manual (de 95 a 38 min/día).
- Reducción del 50% en turnos perdidos por inasistencia (de 6 a 3/semana).
- 0 superposiciones de agenda por mes (de 5 actuales).
- ≥ 70% de consultas resueltas con el buscador interno, sin buscar a mano.

El riesgo más alto: que la recepción no use el sistema como herramienta
principal y siga anotando turnos a mano en paralelo. Para evitarlo, la
transición es gradual, con una capacitación breve al iniciar.

## Estructura del repositorio

```
docs/
  01-arbol-de-problemas.md
  02-arbol-de-objetivos.md
  03-matriz-marco-logico.md
  04-requerimientos.md
  05-maquetado.md
  06-pitch.md
  foda.md
  plan-de-aprendizaje.md
  plan-4to-bimestre.md
  reparto-4to-bimestre.md
  material-catedra.md
  propuestas.md
  consigna-bbdd.md       # consigna de la sección Bases de Datos
  modelo-entidades.md    # entidades, atributos y cardinalidades
  arquitectura.md        # base en la nube, n8n, contingencia
  conexion-base.md       # conexión de la app a MySQL/Aiven y modo contingencia
  09-casos-de-prueba.md          # casos de prueba funcional de Gestión
  10-casos-de-prueba-cliente.md  # casos de prueba funcional de Cliente
  07-competencia.md      # análisis de competencia y PUV (Semana 4)
  08-presupuesto.md      # presupuesto, monetización y retorno (Semana 5)
  11-pruebas-bbdd.md     # documentación de pruebas de la base y tuning
  12-contrato-sp.md      # catálogo de stored procedures y códigos de error
  13-manual-tecnico.md   14-manual-usuario.md
  15-guia-por-semana.md  # qué traer de esta rama cada semana
  bitacora-*.md          # bitácoras del equipo (la del cierre: bitacora-cierre.md)
  catedra/               # material de cátedra transcripto (con ejemplos de conexión C y MySQL)
  diagramas/             # diseño conceptual escrito (Peter Chen)
dermalia.sh              # instalar, iniciar, parar y probar todo con un comando
backend/                 # base MySQL: tablas en 9 schemas, datos, stored procedures, reportes, tuning y pruebas
  01 codigobasededatossolotablas.sql  02_datos.sql  02b_numero.sql  03_sp_semana3.sql  04_sp_semana4.sql
  05_reportes_semana5.sql  06_tuning_semana6.sql  09_sp_pantallas.sql  07_actividad_con_sps.sql
  08_usuarios.sql  05_pruebas_sp.sql
  medir_tuning.sql  pruebas/correr_pruebas.py
frontend/                # interfaz en Qt Widgets (apartados Gestión y Cliente)
web/                     # sitio web para la paciente (Vite, GSAP, Three.js) y su API (Node), con el asistente de IA
diseno-dermalia/         # guía de estética de las pantallas
README.md                # este archivo, portada de la Carpeta de Proyecto V1
```

Todo se escribe en **Markdown**, en español. Los diagramas de árboles y flujos
van en Mermaid dentro del propio `.md` para que se vean en GitHub; los del
modelo de datos se describen por escrito en `docs/diagramas/`. El
maquetado vigente es una página interactiva enlazada desde
`docs/05-maquetado.md`; el maquetado móvil original sigue en
[Figma](https://www.figma.com/design/qEWMXwg68LQOtj9PzRnh1A/Untitled).

## Equipo y roles

En el 3er bimestre se formalizaron cuatro roles como issues del repo (#1 a
#4), asignados el 1° de septiembre. En el **4° bimestre** el trabajo técnico lo
reparten **Santiago y Bautista** (frontend los martes, base de datos los
miércoles y jueves; ver [`docs/reparto-4to-bimestre.md`](docs/reparto-4to-bimestre.md)):

| Integrante | Rol | Issue |
|---|---|---|
| Santiago Jiménez | Marco Lógico y coordinación (árboles, MML, trazabilidad) | [#1](../../issues/1) |
| Bautista | Requerimientos y viabilidad (RF/RNF, FODA) | [#2](../../issues/2) |
| Nicolás | Diseño y maquetado (Figma histórico, mockup Qt vigente) | [#3](../../issues/3) |
| Clovis | Pitch y comunicación (guion, defensa oral) | [#4](../../issues/4) |

## Herramientas

Miro / FigJam (árboles y MML) · draw.io (diagramas de Chen y Codd) · MySQL y
MySQL Workbench · Aiven (base en la nube) · n8n y Telegram (recordatorios) ·
Figma (maquetado original, reemplazado) ·
Trello o GitHub Projects (backlog) · GitHub con documentación Markdown ·
Google Workspace / Classroom · Canva (presentación final).

## Cómo trabajar (leer antes de empezar)

Cada integrante trabaja en **su propia rama** (`santiago`, `bautista`), nunca
directo en `main`. `main` es la versión de todos y se actualiza con Pull
Requests. La rama `claude-bbdd` es la del asistente (documentación de la base
de datos) y `dermalia-carpeta-proyecto-v1` guarda la carpeta del 3er bimestre.

### 1. Primera vez: bajar el repo

```
git clone https://github.com/sant1jmnz/Proyect-berea.git
cd Proyect-berea
git checkout <tu-rama>          # santiago o bautista
```

### 2. Cada vez que te sentás a trabajar

```
git checkout <tu-rama>
git branch                      # el * tiene que estar en tu rama
git pull                        # trae lo último de tu rama
```

`git pull` es lo que actualiza tu PC: GitHub se actualiza solo, tu copia
local no. Si en `main` hubo cambios que tu rama todavía no tiene:

```
git pull origin main
```

### 3. Mientras trabajás

Editá los archivos y guardá cambios seguido, con commits chicos:

```
git status                      # ver qué cambiaste
git add .
git commit -m "Una frase de qué cambiaste"
git push
```

### 4. Al cerrar la semana

Tildá las tareas hechas en `docs/reparto-4to-bimestre.md` y abrí un Pull
Request de tu rama hacia `main` en GitHub (botón "Compare & pull request").
Antes de mergear, avisá al equipo.

### Reglas

- Trabajá solo en tu rama; confirmá con `git branch` antes de editar.
- Nunca uses `git push --force`. Si `git push` da error, avisá.
- No subas contraseñas, tokens ni archivos con datos reales de pacientes.

### Si estás en una PC de laboratorio sin Git ni permisos

Instalá Git solo en tu carpeta de usuario:

```
mkdir -p ~/git-local
cd /tmp
apt download git git-man liberror-perl
dpkg -x git_*.deb ~/git-local/
dpkg -x git-man_*.deb ~/git-local/
dpkg -x liberror-perl_*.deb ~/git-local/
echo 'export PATH="$HOME/git-local/usr/bin:$PATH"' >> ~/.bashrc
echo 'export GIT_EXEC_PATH="$HOME/git-local/usr/lib/git-core"' >> ~/.bashrc
source ~/.bashrc
git --version
```

- Si al día siguiente `git` no anda, repetí solo los dos `echo` y el `source`
  (algunas PCs borran el `~/.bashrc`).
- Para `git push`, GitHub pide un **token de acceso personal** en lugar de la
  contraseña (Settings → Developer settings → Personal access tokens). No lo
  guardes en la PC compartida ni en un archivo del proyecto.
- **Sin instalar nada**: en GitHub elegí tu rama en el selector, abrí el
  archivo, tocá el lápiz, y al final "Commit changes" sobre tu rama. Alcanza
  para editar los `.md` de `docs/`.

## Desarrollo técnico (4° bimestre)

Todo está construido, conectado a la misma base y probado:

- `backend/`: la base MySQL. 31 tablas en 9 schemas (`seguridad`, `personas`, `clinica`, `agenda`, `pagos`,
  `beneficios`, `notificaciones`, `auditoria`, `asistente`), datos de ejemplo, stored procedures con todas las
  reglas del negocio (seña, 24 horas, cirugías con consulta previa, cupones con token de 5 minutos, tarjetas de
  regalo, avisos), 8 reportes, auditoría por fechas y dos reportes `_tuneado` con la medición antes y después.
  Las aplicaciones solo llaman a stored procedures, con un usuario que solo tiene `EXECUTE`.
- `frontend/`: Qt 6 (Widgets) y `mysql.h`, como pide la cátedra. **Gestión** (`dermalia_gestion`, PC de
  recepción): cargar, buscar y cancelar turnos con seña simulada y reembolso, protocolos, profesionales con su
  disponibilidad, pacientes, avisos, cupones con QR, tarjetas de regalo, consultas previas de cirugía, reportes,
  auditoría y usuarios. **Terminal** (`dermalia_cliente`, táctil): turno en 3 pasos (hasta 3 protocolos),
  cupón o tarjeta de regalo, Google Calendar, buscar y cancelar, cuenta opcional y **asistente de IA**. Si la
  base no responde, **modo contingencia**: guarda los turnos en el equipo y los sincroniza solo al volver.
- `web/`: el sitio para la paciente (Vite, GSAP, three.js) con un modelo 3D de las capas de la piel, el catálogo
  completo con fichas y comparador, reserva en 3 pasos, mi turno, cuenta con historial y cupones, y el
  **asistente de IA**. `web/api/servidor.js` es la API (Node) que llama a los stored procedures y sirve el sitio.
- **Asistente de IA** (`web/api/asistente.js`): responde con Gemini usando solo el catálogo de la base, los
  cuidados de cada protocolo y las reglas del instituto; sin clave o sin internet contesta un asistente local.
  Borra los datos personales antes de enviar o guardar la pregunta y deriva a WhatsApp si no sabe.
- `n8n/`: plantillas de los recordatorios por Telegram y las tareas diarias (vencer evaluaciones, emitir
  cupones).
- **Arquitectura**: la base va en Aiven (MySQL administrado, USD 5/mes), los recordatorios salen con n8n desde
  una VM gratuita de Google Cloud, con Telegram en desarrollo y WhatsApp en producción (ver
  `docs/arquitectura.md`).

## Entrega del Hito 2 de Bases de Datos

Carpeta `entrega-hito-2/` (la arma `python3 backend/armar_entrega.py --grupo <número>` a partir de los
scripts de `backend/`, que son la fuente única):

| Archivo | Qué es |
|---|---|
| `03_ModeloSQL_Grupo<N>.sql` | Punto 3: 9 schemas y 31 tablas con todas las restricciones. Recrea todo, se puede repetir |
| `04_DatosSQL_Grupo<N>.sql` | Punto 4: datos de ejemplo (66 pacientes, 163 turnos). El log queda vacío: lo llenan los stored procedures |
| `05_Backend_Grupo<N>.sql` | Punto 5: stored procedures y funciones, 8 reportes, auditoría con parámetros y los dos `_tuneado` |
| `06_PruebasSQL.xlsx` | Punto 6: 239 casos con la planilla de la cátedra (`python3 backend/armar_planilla_pruebas.py`) |
| `Diagrama_Chen_Grupo<N>.png`, `Diagrama_Codd_Grupo<N>.png` | Diagramas conceptual y lógico, con fondo blanco |

El orden correcto es 03, 04 y 05, y la secuencia completa se puede repetir. El backend usa solo lo que
enseña el material de la cátedra y pide la consigna: la lista de lo que se reemplazó y cómo está en
[`docs/metodologia-sql.md`](docs/metodologia-sql.md) y [`docs/12-contrato-sp.md`](docs/12-contrato-sp.md).

## Qué falta

- **Ensayar el pitch** con cronómetro (5 a 7 minutos) y la demo con `./dermalia.sh recargar-base` antes.
- **Número de grupo** para la entrega del Hito 2: `python3 backend/armar_entrega.py --grupo <número>`
  (hoy los archivos dicen `GrupoXX`).
- Para producción, fuera del alcance del bimestre: pasarela de pagos real (hoy la seña es simulada), WhatsApp con
  la API oficial de Meta (hoy enlace `wa.me` y Telegram) y probar las plantillas de n8n en una instancia real.
- Al agregar un protocolo a la base, correr `npm run generar` en `web/` para que el sitio y las apps lo tengan
  sin conexión.
- Las celdas "a verificar" que quedan en `docs/07-competencia.md` se confirman con la demo de cada producto.
