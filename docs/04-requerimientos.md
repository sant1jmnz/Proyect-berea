# Requerimientos

Se derivan de los Componentes de la MML (`docs/03-matriz-marco-logico.md`).
Cada RF referencia el componente del que sale; no hay ningún requerimiento
acá que no venga de R1-R4.

**Restricción técnica**: backend en C con SQL Server, frontend en Qt, sin
integraciones por API externa. El sistema es una herramienta interna: lo
opera la recepción desde la PC del instituto, no es self-service para la
paciente (no hay web ni app del lado de la paciente). Donde antes había un
tercero (Mercado Pago, Google Calendar, un modelo de lenguaje), el
requerimiento describe una versión mockeada dentro del propio sistema.

## Requerimientos funcionales

| ID | El sistema debe permitir... | Componente MML | Prioridad |
|---|---|---|---|
| RF-01 | ...a la recepción cargar un turno en 3 pasos (protocolo → horario disponible → confirmación) cuando la paciente lo pide por teléfono o en persona, sin anotarlo a mano. | R1 | Must |
| RF-02 | ...a los profesionales o a la recepción cargar y editar la disponibilidad horaria directo en el sistema (agenda propia en SQL Server, sin integración externa), para evitar superposiciones. | R1 | Must |
| RF-03 | ...mostrar únicamente los horarios realmente disponibles, actualizados en tiempo real. | R1 | Must |
| RF-04 | ...a la recepción buscar precios, duración y protocolos en un buscador interno por palabra clave, para responder consultas por teléfono sin buscar a mano o de memoria. | R2 | Must |
| RF-05 | ...marcar la consulta para derivar a WhatsApp del instituto (enlace `wa.me`, no envío automático) cuando el buscador no encuentra coincidencia en la base, para que la recepción la escale sin perderla. | R2 | Must |
| RF-06 | ...a la recepción registrar el pago de la seña al confirmar la reserva (mock: el sistema marca el estado como pagado, sin procesar dinero real ni conectarse a una pasarela), para reducir inasistencias. | R3 | Must |
| RF-07 | ...registrar (de forma simulada) una seña del 30% del valor del protocolo (mínimo $5.000), reembolsable 100% si se cancela con más de 24 h de anticipación y no reembolsable por debajo de ese plazo o por inasistencia. | R3 | Should |
| RF-08 | ...generar un recordatorio de turno antes de la fecha reservada, visible para la recepción en el sistema (sin envío real por WhatsApp o email), para reducir inasistencias. | R4 | Must |
| RF-09 | ...a la recepción buscar y cancelar los turnos de una paciente por nombre, DNI o teléfono, sin depender de un enlace o de una cuenta. | R1 | Should |

RF-01 a RF-06 y RF-08 son Must porque atacan directamente las cuatro causas
del Árbol de Problemas (C1-C4). RF-07 y RF-09 son Should: mejoran la
experiencia pero el sistema funciona sin ellos.

Se sacó del alcance la "vitrina" (fotos antes/después + reseñas de Google
Maps) que estaba anotada como RF-10 Could en una versión anterior: dependía
de la API de Google Maps y de que la paciente la viera desde un canal
propio (self-service), ninguna de las dos cosas es viable con la
restricción técnica actual (Qt de escritorio, sin web ni API) ni con el
sistema pensado como herramienta interna de la recepción. Queda anotada
en `docs/propuestas.md` como posible iteración futura si el proyecto suma
en algún momento un componente web.

## Requerimientos no funcionales

| ID | Categoría | Criterio medible |
|---|---|---|
| RNF-01 | Rendimiento | El buscador interno de precios y protocolos responde en menos de 2 segundos. |
| RNF-02 | Rendimiento | La grilla de disponibilidad carga en menos de 2 segundos. |
| RNF-03 | Usabilidad | La recepción, sin instrucción previa más allá de una capacitación breve, completa la carga de un turno en menos de 1 minuto. |
| RNF-04 | Seguridad | El sistema no maneja pagos reales ni datos de tarjeta, la seña es un mock que solo registra un estado (pagada/no pagada) en SQL Server. |
| RNF-05 | Seguridad | Los datos de contacto y de salud de la paciente (nombre, DNI, teléfono, protocolo) se guardan solo en la base local del instituto, sin sincronizarse con ningún servicio externo. |
| RNF-06 | Compatibilidad | El sistema funciona correctamente en una ventana de escritorio de 960×600 px como mínimo, la resolución típica de la PC de recepción. |
| RNF-07 | Mantenibilidad | La recepción puede actualizar la base de precios y protocolos del buscador sin intervención técnica del equipo. |
| RNF-08 | Disponibilidad | El sistema de reserva está disponible durante todo el horario de atención del instituto, sin depender de conexión a internet (corre local contra SQL Server). |
| RNF-09 | Seguridad | El buscador (R2) solo responde con coincidencias de la base de precios/protocolos cargada; si no hay coincidencia, marca la derivación al WhatsApp del instituto en vez de dar una respuesta genérica. |
| RNF-10 | Arquitectura | Todo el backend se implementa en C sobre SQL Server; el frontend, en Qt. Ninguna funcionalidad depende de una API externa, donde una versión con más libertad técnica usaría un tercero, el sistema implementa un mock propio. |

## Historias de usuario

```
Como recepción, quiero cargar un turno sin anotarlo a mano,
para no perder tiempo ni cometer errores al pasarlo después a la agenda.

Criterios de aceptación:
- La carga se completa en 3 pasos como máximo.
- Solo se muestran horarios realmente disponibles.
- Funciona en una ventana de escritorio de 960×600 px como mínimo.
- Al confirmar, se ve un resumen del turno antes de guardarlo.
```

```
Como recepción, quiero registrar la seña al confirmar el turno,
para asegurar la reserva y que quede un registro del monto cobrado.

Criterios de aceptación:
- El registro es simulado (mock): no se conecta a ninguna pasarela real.
- El monto se calcula solo antes de confirmar (30%, mínimo $5.000).
- El sistema no pide ni guarda ningún dato de tarjeta.
- Al confirmar, el turno queda marcado como "seña pagada" en la búsqueda.
```

```
Como recepción, quiero que el buscador interno resuelva las consultas repetidas,
para no tener que memorizar precios y protocolos ni buscarlos en una planilla aparte.

Criterios de aceptación:
- El buscador responde solo con coincidencias de la base de precios/protocolos.
- Si no encuentra coincidencia, marca la derivación al WhatsApp del instituto.
- Puedo ver cuántas consultas resolvió el buscador sin tener que preguntarle a nadie más.
```

```
Como recepción, quiero ver un recordatorio antes del turno,
para avisarle a la paciente y que no falte ni se olvide la fecha.

Criterios de aceptación:
- El recordatorio se genera con anticipación configurable.
- Aparece en la búsqueda de turnos, no es un envío real por WhatsApp ni email.
- Queda registrado si se generó y si ya avisé a la paciente.
```

```
Como recepción, quiero buscar los turnos de una paciente por nombre, DNI o teléfono,
para poder confirmarle o cancelarle un turno sin pedirle ningún enlace ni contraseña.

Criterios de aceptación:
- Puedo buscar por cualquiera de los tres datos (nombre, DNI, teléfono).
- Veo el estado del turno (confirmado, realizado, cancelado) y si la seña está pagada.
- Puedo cancelar el turno desde la misma búsqueda.
```

```
Como recepción o profesional, quiero cargar y editar la disponibilidad directo en el sistema,
para no depender de ningún calendario externo.

Criterios de aceptación:
- Puedo marcar y desmarcar horarios disponibles desde el sistema.
- Los cambios se reflejan de inmediato en la grilla de reserva.
- No hay ningún paso de sincronización con Google Calendar ni otro
  calendario externo.
```

## Backlog inicial

Se pasa a Trello/GitHub Projects con etiquetas Must / Should según la
tabla de RF de arriba. Orden sugerido para el maquetado (`docs/05-maquetado.md`):
primero las pantallas de los RF Must (reserva, buscador, seña, recordatorio),
después la búsqueda de turnos por nombre/DNI/teléfono.

## Qué falta

- Pasar a `docs/05-maquetado.md`: cada pantalla del wireframe se justifica
  contra uno o más RF de esta tabla.
