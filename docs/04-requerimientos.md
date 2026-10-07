# Requerimientos

Se derivan de los Componentes de la MML (`docs/03-matriz-marco-logico.md`).
Cada RF referencia el componente del que sale; no hay ningún requerimiento
acá que no venga de R1-R4.

**Restricción técnica (actualizada)**: base de datos en **MySQL**,
aplicación de escritorio en **Qt** y **sitio web** para la paciente. Ya no
rige la restricción "sin APIs externas ni web": se permiten integraciones
con servicios externos (Google Calendar, WhatsApp, un asistente de IA). El
lenguaje y el stack del backend se definen al empezar `backend/`.

El sistema tiene **tres apartados**:

- **Apartado Cliente (terminal)**: pantalla táctil instalada en el instituto,
  para que la paciente cargue su propio turno mientras está en el local.
- **Apartado Gestión**: lo usa la recepción (y los profesionales) desde la PC,
  en Qt, para cargar turnos por teléfono, administrar disponibilidad y
  resolver consultas.
- **Apartado Web**: sitio web para que la paciente reserve, consulte y cancele
  su turno desde cualquier lugar, hable con el asistente de IA y, si quiere,
  tenga su cuenta. No es opcional: es parte del alcance.

Los tres comparten los Componentes (R1-R4) y la **misma base MySQL**; cambia
quién entra por cada pantalla.

**Identificación de la paciente**: no hace falta cuenta. Se identifica con
su **DNI**. Tener cuenta es opcional y da beneficios (descuentos,
notificaciones, historial ya cargado). El personal (recepción, profesionales,
administración) **sí** tiene cuenta propia y obligatoria, para poder auditar
quién hizo cada acción.

## Requerimientos funcionales

| ID | Apartado | El sistema debe permitir... | Componente MML | Prioridad |
|---|---|---|---|---|
| RF-01 | Cliente + Web | ...a la paciente cargar su propio turno en 3 pasos (protocolo → horario disponible → confirmación), eligiendo uno o **varios protocolos** en el mismo turno. | R1 | Must |
| RF-02 | Gestión | ...a la recepción cargar un turno en 3 pasos cuando la paciente lo pide por teléfono, sin anotarlo a mano. | R1 | Must |
| RF-03 | Gestión | ...a los profesionales o a la recepción cargar y editar la disponibilidad horaria directo en el sistema, para evitar superposiciones. | R1 | Must |
| RF-04 | Todos | ...mostrar únicamente los horarios realmente disponibles, actualizados en tiempo real, sin importar desde dónde se cargue el turno. | R1 | Must |
| RF-05 | Cliente + Web | ...a la paciente consultar precios, duración y protocolos en un buscador por palabra clave. | R2 | Must |
| RF-06 | Gestión | ...a la recepción buscar lo mismo, para responder consultas por teléfono sin buscar a mano o de memoria. | R2 | Must |
| RF-07 | Todos | ...derivar la consulta al WhatsApp del instituto cuando el buscador o el asistente de IA no puedan responder, y dejarla registrada. | R2 | Must |
| RF-08 | Cliente + Web | ...a la paciente pagar la seña al confirmar su turno con un flujo **simulado que imita un pago real** (estilo Mercado Pago): el sistema registra el estado, sin procesar dinero real. | R3 | Must |
| RF-09 | Gestión | ...a la recepción registrar el pago de la seña cuando confirma un turno cargado por teléfono (mismo mock que RF-08). | R3 | Must |
| RF-10 | Todos | ...calcular (de forma simulada) una seña del 30% del valor del protocolo (mínimo $5.000), reembolsable 100% si se cancela con más de 24 h de anticipación y no reembolsable por debajo de ese plazo o por inasistencia. | R3 | Should |
| RF-11 | Todos | ...enviar un recordatorio de turno por **WhatsApp** a la paciente antes de la fecha reservada, y registrar cada aviso (canal, estado, fecha programada). | R4 | Must |
| RF-12 | Cliente + Web | ...a la paciente buscar y cancelar su propio turno con su DNI o teléfono, sin cuenta. | R1 | Should |
| RF-13 | Gestión | ...a la recepción buscar y cancelar el turno de cualquier paciente por nombre, DNI o teléfono. | R1 | Should |
| RF-14 | Cliente + Web | ...a la paciente hacer preguntas a un **asistente de IA** (precios, protocolos, cuidados) y recibir respuesta; las consultas quedan registradas. | R2 | Should |
| RF-15 | Web (+ Cliente) | ...a la paciente **crear una cuenta opcional**; con cuenta ve su historial de turnos sin volver a ingresar su DNI. | R1 | Should |
| RF-16 | Todos | ...buscar el historial de turnos de una paciente **por DNI** (sin cuenta), tanto desde el apartado Cliente como desde la Web. | R1 | Should |
| RF-17 | Todos | ...aplicar **descuentos** a las pacientes con cuenta, definidos y administrados desde Gestión. | R3 | Should |
| RF-18 | Gestión | ...registrar qué **protocolos realiza cada profesional**, y ofrecer en la reserva solo los profesionales habilitados para el protocolo elegido. | R1 | Should |
| RF-19 | Web + Gestión | ...que, al confirmar el turno, la paciente pueda agregarlo a **su Google Calendar** con un botón, y que el turno se cargue automáticamente en el calendario del **profesional**. | R4 | Should |
| RF-20 | Gestión | ...que cada integrante del personal ingrese con **cuenta propia** y que cada acción relevante (inicio de sesión, alta, cancelación, pago) quede en un **log de auditoría** consultable por rango de fechas. | Transversal | Must |
| RF-21 | Web | ...ofrecer el **sitio web** completo para la paciente: catálogo de protocolos, reserva, consulta/cancelación del turno, asistente de IA y cuenta opcional. | R1-R4 | Must |

Los Must son los que atacan directamente las cuatro causas del Árbol de
Problemas (C1-C4), más el log de auditoría (RF-20) y el sitio web (RF-21),
que pidió el equipo como parte del alcance. El resto (RF-10, RF-12 a RF-19)
son Should: mejoran la experiencia pero el sistema funciona sin ellos.

Se sacó del alcance la "vitrina" (fotos antes/después + reseñas de Google
Maps) que estaba anotada como Could en una versión anterior: dependía de
la API de Google Maps, que no es viable con la restricción técnica actual
(Qt, sin web ni API). Queda anotada en `docs/propuestas.md` como posible
iteración futura si el proyecto suma en algún momento un componente web.

## Requerimientos no funcionales

| ID | Categoría | Criterio medible |
|---|---|---|
| RNF-01 | Rendimiento | El buscador de precios y protocolos responde en menos de 2 segundos, en cualquiera de los tres apartados. |
| RNF-02 | Rendimiento | La grilla de disponibilidad carga en menos de 2 segundos. |
| RNF-03 | Usabilidad | Una paciente sin instrucción previa completa la carga de su turno (terminal o web) en menos de 2 minutos. |
| RNF-04 | Usabilidad | La recepción, con una capacitación breve, completa la carga de un turno en menos de 1 minuto. |
| RNF-05 | Seguridad | El sistema no maneja pagos reales ni datos de tarjeta: la seña es un mock que imita el flujo de pago y solo registra el estado en MySQL. |
| RNF-06 | Seguridad | Los datos de contacto y de salud de la paciente se guardan en la base MySQL del instituto. A servicios externos (Google Calendar, WhatsApp, IA) solo se envía lo mínimo necesario; al asistente de IA no se le envían datos personales ni de salud. |
| RNF-07 | Compatibilidad | La terminal funciona en pantalla táctil de al menos 768×1024 px; Gestión, en ventana de escritorio de 960×600 px como mínimo; la web, en celular y escritorio. |
| RNF-08 | Mantenibilidad | La recepción puede actualizar precios y protocolos sin intervención técnica del equipo. |
| RNF-09 | Disponibilidad | El apartado Gestión y la terminal funcionan durante todo el horario de atención contra MySQL; las funciones que dependen de servicios externos (WhatsApp, Calendar, IA) degradan sin frenar la carga de turnos. |
| RNF-10 | Seguridad | Las respuestas del asistente de IA se limitan a la información cargada del instituto; si no hay base para responder, deriva al WhatsApp del instituto en vez de inventar. |
| RNF-11 | Arquitectura | Base de datos MySQL dividida en schemas, aplicación de escritorio en Qt y sitio web, sobre la misma base. Las integraciones externas son Google Calendar, WhatsApp y un asistente de IA. |
| RNF-12 | Trazabilidad | Todo evento relevante genera un registro en el log (tipo de evento, fecha y hora, usuario, datos de auditoría), poblado por procedimientos almacenados y no a mano. |

## Historias de usuario

```
Como paciente, quiero cargar mi propio turno desde la terminal del instituto,
para no tener que esperar a que la recepción esté libre para atenderme.

Criterios de aceptación:
- La carga se completa en 3 pasos como máximo, en pantalla táctil.
- Solo se muestran horarios realmente disponibles.
- Al confirmar, veo un resumen del turno antes de guardarlo.
```

```
Como recepción, quiero cargar un turno cuando la paciente llama por teléfono,
para no perder tiempo ni cometer errores al pasarlo después a la agenda.

Criterios de aceptación:
- La carga se completa en 3 pasos como máximo.
- Solo se muestran horarios realmente disponibles.
- Funciona en una ventana de escritorio de 960×600 px como mínimo.
```

```
Como paciente, quiero pagar la seña al confirmar mi turno en la terminal,
para asegurar mi reserva y saber cuánto se cobra por adelantado.

Criterios de aceptación:
- El pago es simulado (mock): imita el flujo de un pago real pero no se conecta a ninguna pasarela.
- El monto se ve antes de confirmar (30%, mínimo $5.000).
- El sistema no pide ni guarda ningún dato de tarjeta.
```

```
Como recepción o paciente, quiero que el buscador resuelva las consultas de precios y protocolos,
para no tener que memorizarlos ni buscarlos en una planilla aparte.

Criterios de aceptación:
- El buscador responde solo con coincidencias de la base de precios/protocolos.
- Si no encuentra coincidencia, deriva al WhatsApp del instituto y deja registrada la consulta.
- Funciona igual desde la terminal (paciente) y desde la PC de recepción.
```

```
Como paciente, quiero ver un recordatorio antes de mi turno,
para no faltar ni olvidarme la fecha.

Criterios de aceptación:
- El recordatorio me llega por WhatsApp con anticipación configurable.
- Después de agendar, puedo agregar el turno a mi Google Calendar con un botón.
```

```
Como paciente, quiero buscar y cancelar mi turno desde la terminal con mi DNI o teléfono,
para no tener que pedirle nada a la recepción ni recordar ninguna contraseña.

Criterios de aceptación:
- Puedo buscar por DNI o teléfono.
- Veo el estado del turno (confirmado, realizado, cancelado) y si la seña está pagada.
- Puedo cancelar el turno desde la misma búsqueda.
```

```
Como recepción, quiero buscar el turno de cualquier paciente por nombre, DNI o teléfono,
para poder confirmarle o cancelarle un turno cuando llama por WhatsApp o teléfono.

Criterios de aceptación:
- Puedo buscar por cualquiera de los tres datos (nombre, DNI, teléfono).
- Veo el estado del turno y si la seña está pagada.
- Puedo cancelar el turno desde la misma búsqueda.
```

```
Como recepción o profesional, quiero cargar y editar la disponibilidad directo en el sistema,
para no depender de ningún calendario externo.

Criterios de aceptación:
- Puedo marcar y desmarcar horarios disponibles desde el sistema.
- Los cambios se reflejan de inmediato en la grilla de reserva, en los dos apartados.
```

```
Como paciente, quiero poder crear una cuenta opcional,
para tener mi historial y mis descuentos sin escribir mi DNI cada vez.

Criterios de aceptación:
- Puedo reservar y consultar mi turno con solo mi DNI, sin cuenta.
- Con cuenta, veo mi historial al ingresar.
- Con cuenta, se me aplican los descuentos vigentes.
```

```
Como paciente, quiero hacerle preguntas a un asistente de IA,
para resolver dudas de precios y tratamientos sin llamar al instituto.

Criterios de aceptación:
- El asistente responde solo con información cargada del instituto.
- Si no puede responder, me deriva al WhatsApp del instituto.
```

```
Como administración, quiero que cada acción del personal quede registrada,
para auditar errores y saber quién hizo qué.

Criterios de aceptación:
- Cada integrante del personal ingresa con su propia cuenta.
- El log guarda tipo de evento, fecha y hora y usuario.
- Puedo consultar el log por rango de fechas.
```

## Backlog inicial

Se pasa a Trello/GitHub Projects con etiquetas Must / Should y el apartado
(Cliente / Gestión / Web) según la tabla de RF de arriba. Orden sugerido para el
maquetado (`docs/05-maquetado.md`): primero las pantallas Must de cada
apartado (carga de turno, buscador, seña), después las búsquedas Should.

## Qué falta

- **WhatsApp**: definir cómo se envían los avisos (API oficial de WhatsApp
  Business, un proveedor intermedio o simulación) y qué entra en el alcance
  del bimestre.
- Actualizar `docs/05-maquetado.md` con las pantallas del apartado Web y las
  nuevas (cuenta, asistente de IA, descuentos).

- Pasar a `docs/05-maquetado.md`: cada pantalla del wireframe se justifica
  contra uno o más RF de esta tabla, separadas por apartado.
- Diseñar la pantalla de administración de disponibilidad (RF-03), que
  todavía no tiene wireframe.
