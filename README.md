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
| Buscar turnos | Por DNI o teléfono, sin cuenta; con cuenta opcional se guarda el historial |
| Asistente de IA | Responde consultas con la información del instituto |
| Cupones y tarjetas de regalo | Cupones por código o QR, tarjetas con saldo y cupones por fidelidad |

Tres apartados: una **terminal táctil** en el instituto, que usa la
paciente para cargar su propio turno; la **PC de recepción**, para los
turnos que llegan por teléfono; y un **sitio web** para reservar desde
cualquier lugar. Detalle completo en
[`docs/04-requerimientos.md`](docs/04-requerimientos.md).

**Stack técnico**: base de datos **MySQL**, aplicación de escritorio en
**Qt** y **sitio web**; se permiten APIs externas (Google Calendar,
WhatsApp, asistente de IA). El backend se está rehaciendo desde cero.

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
| 4 | Requerimientos funcionales y no funcionales | [`docs/04-requerimientos.md`](docs/04-requerimientos.md) | Actualizado al nuevo alcance (RF-01 a RF-25, RNF-01 a RNF-14, tres apartados) |
| 5 | Maquetado (wireframes) | [`docs/05-maquetado.md`](docs/05-maquetado.md) | Escritorio (Cliente y Gestión) hecho; Web con primer maquetado en `web/` (inicio, reserva, mi turno) |
| 6 | Pitch | [`docs/06-pitch.md`](docs/06-pitch.md) | Guion del bimestre anterior (7 a 10 min); hay que recortarlo al formato de 5 a 7 min |
| 7 | Consigna de Bases de Datos | [`docs/consigna-bbdd.md`](docs/consigna-bbdd.md) | Transcripta |
| 8 | Modelo de entidades (27 entidades) | [`docs/modelo-entidades.md`](docs/modelo-entidades.md) | Escrito (grupos 1 a 4) |
| 9 | Arquitectura y contingencia | [`docs/arquitectura.md`](docs/arquitectura.md) | Borrador (Aiven, n8n, Telegram, modo contingencia) |
| 10 | Diagramas (Peter Chen, luego Edgar Codd) | [`docs/diagramas/`](docs/diagramas/) | Descripción escrita del Chen: entidades, atributos, relaciones y cardinalidades |

Documentos de apoyo: [`docs/propuestas.md`](docs/propuestas.md) (las diez
propuestas relevadas y por qué se eligió esta), [`docs/foda.md`](docs/foda.md)
(FODA del equipo), [`docs/plan-de-aprendizaje.md`](docs/plan-de-aprendizaje.md)
(cronograma del 3er bimestre), [`docs/plan-4to-bimestre.md`](docs/plan-4to-bimestre.md)
(cronograma del 4° bimestre, transcripción del PDF), [`docs/reparto-4to-bimestre.md`](docs/reparto-4to-bimestre.md)
(tareas de Santiago y Bautista semana a semana, martes de frontend y miércoles y jueves de base de datos) y [`docs/material-catedra.md`](docs/material-catedra.md)
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
  catedra/               # material de cátedra transcripto (con ejemplos de conexión C y MySQL)
  diagramas/             # diseño conceptual escrito (Peter Chen)
backend/                 # vacío: el backend y la base MySQL se rehacen desde cero
frontend/                # interfaz en Qt Widgets (apartados Gestión y Cliente)
web/                     # sitio web para la paciente (Vite, GSAP, Three.js)
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

Arrancó con el frontend de escritorio y el diseño de la base de datos:

- `backend/`: vacío a propósito. Se rehace desde cero junto con la base
  MySQL (consigna en `docs/consigna-bbdd.md`, entidades en
  `docs/modelo-entidades.md`).
- `frontend/`: interfaz en Qt 6 (Widgets). Gestión (`dermalia_gestion`, PC de
  recepción) carga y cancela turnos (seña simulada y reembolso de 24 h),
  administra protocolos, profesionales con su disponibilidad y pacientes, y
  registra los avisos de turno; Cliente (`dermalia_cliente_bautista`,
  terminal táctil) tiene la carga de turno en 3 pasos, el buscador y buscar y
  cancelar el turno. Todo trabaja con **datos de prueba** hasta que exista la
  base. La conexión a MySQL (con `mysql.h`, como pide la cátedra) y el
  **modo contingencia** (aviso "sin conexión" y turnos guardados en el
  equipo) ya están: ver `docs/conexion-base.md`. El buscador de precios es un
  widget compartido (`frontend/comun/`). Se abre `frontend/CMakeLists.txt` con
  Qt Creator, o por consola:
  `cmake -S frontend -B <carpeta> -DCMAKE_PREFIX_PATH=<carpeta de Qt>/gcc_64 && cmake --build <carpeta> && <carpeta>/dermalia_gestion`.
  Las pruebas automáticas corren con `QT_QPA_PLATFORM=offscreen ctest` dentro
  de la carpeta de compilación. La estética de las pantallas está explicada
  en `diseno-dermalia/SKILL.md`.
- **Base de datos**: modelo de 27 entidades escrito, con el diagrama de Peter
  Chen en curso. Después vienen el diseño lógico (Codd, 3FN), la
  implementación en MySQL dividida en schemas, los datos, los stored
  procedures (funcionalidades, 8 reportes, auditoría, 2 `_tuneado`) y las
  pruebas. El plan semanal está en `docs/reparto-4to-bimestre.md`.
- `web/`: el sitio para la paciente (apartado Web). Inicio con un modelo 3D
  de las capas de la piel (tocás una capa y ves qué protocolos actúan ahí),
  catálogo con buscador y una vitrina 3D donde cada objeto es un protocolo
  (tocalo para ver su ficha y reservarlo), calculadora de seña con gráfico,
  reserva en 3 pasos con un reloj que muestra cuánto dura el turno, cupón y
  pago simulado, y "Mi turno" para buscar y cancelar por DNI, con un anillo
  que marca el plazo de 24 h para el reembolso. Por ahora con datos fijos (los
  mismos de `frontend/gestion/datosprueba.cpp`). Para verlo:
  `cd web && npm install && npm run dev`, y abrir `http://localhost:5173`.
- **Arquitectura**: la base va en Aiven (MySQL gratuito), los recordatorios
  salen con n8n desde una VM gratuita de Google Cloud, con Telegram en
  desarrollo y WhatsApp en producción (ver `docs/arquitectura.md`).
- Siguiente: terminar el diagrama de Chen, el diseño lógico, implementar la
  base, conectar las pantallas y conectar el sitio web a la base.

## Qué falta

- Diseño de la base de datos: diagrama de Chen con atributos, diseño lógico,
  implementación, datos, stored procedures y pruebas (ver el plan semanal).
- Apartado Web: conectarlo a la base; faltan la cuenta, las tarjetas de regalo,
  el asistente de IA y el número real de WhatsApp (`web/src/js/movimiento/comun.js`).
- Análisis de competencia, presupuesto y pitch de venta de 5 a 7 minutos.
- Revisión cruzada (peer review) del maquetado y de los árboles con otro
  equipo: sigue pendiente. Sin fecha concreta por ahora; se retoma si
  aparece otro equipo con quien coordinarla.
- Armar la presentación de Canva ("Proyecto Informático 1"): recorrido
  semana a semana de lo que se fue haciendo, más los problemas que se
  encontraron. Es lo último que se arma.
