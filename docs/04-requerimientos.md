# Requerimientos

Se derivan de los Componentes de la MML (`docs/03-matriz-marco-logico.md`).
Cada RF referencia el componente del que sale; no hay ningún requerimiento
acá que no venga de R1-R4.

**Restricción técnica**: backend en C con SQL Server, frontend en Qt, sin
integraciones por API externa. Donde antes había un tercero (Mercado Pago,
Google Calendar, un modelo de lenguaje), el requerimiento describe una
versión mockeada dentro del propio sistema.

## Requerimientos funcionales

| ID | El sistema debe permitir... | Componente MML | Prioridad |
|---|---|---|---|
| RF-01 | ...a la clienta reservar un turno en 3 pasos (servicio → horario disponible → confirmación), para no tener que escribir por WhatsApp. | R1 | Must |
| RF-02 | ...al dueño cargar y editar su disponibilidad horaria directo en el sistema (agenda propia en SQL Server, sin integración externa), para evitar superposiciones. | R1 | Must |
| RF-03 | ...mostrar únicamente los horarios realmente disponibles, actualizados en tiempo real. | R1 | Must |
| RF-04 | ...a la clienta consultar precios, horarios y protocolos a un buscador de preguntas frecuentes por palabra clave, para resolver dudas sin esperar respuesta del dueño. | R2 | Must |
| RF-05 | ...derivar la consulta al WhatsApp del dueño (enlace `wa.me`, no envío automático) cuando el buscador no encuentra coincidencia en la base, para no perder la consulta. | R2 | Must |
| RF-06 | ...a la clienta simular el pago de la seña al confirmar la reserva (mock: el sistema registra el estado como pagado, sin procesar dinero real ni conectarse a una pasarela), para reducir inasistencias. | R3 | Must |
| RF-07 | ...cobrar (simulado) una seña del 30% del valor del servicio (mínimo $5.000), reembolsable 100% si la clienta cancela con más de 24 h de anticipación y no reembolsable por debajo de ese plazo o por inasistencia. | R3 | Should |
| RF-08 | ...generar un recordatorio de turno antes de la fecha reservada, visible en el sistema (sin envío real por WhatsApp o email), para reducir inasistencias. | R4 | Must |
| RF-09 | ...a la clienta ver y cancelar sus turnos reservados mediante un enlace mágico, sin registro ni contraseña. | R1 | Should |
| RF-10 | ...mostrar una vitrina de fotos antes/después y reseñas de Google Maps, para atraer clientes potenciales. |, (fuera de R1-R4, ver "Vitrina" en `docs/propuestas.md`) | Could |

RF-01 a RF-06 y RF-08 son Must porque atacan directamente las cuatro causas
del Árbol de Problemas (C1-C4). RF-07 y RF-09 son Should: mejoran la
experiencia pero el sistema funciona sin ellos. RF-10 es Could, ya estaba
marcado como módulo "deseable" en `propuestas.md`, no "núcleo", además
depende de la API de Google Maps, así que directamente no entra bajo la
restricción técnica actual.

## Requerimientos no funcionales

| ID | Categoría | Criterio medible |
|---|---|---|
| RNF-01 | Rendimiento | El buscador de preguntas frecuentes responde en menos de 2 segundos. |
| RNF-02 | Rendimiento | La grilla de disponibilidad carga en menos de 2 segundos. |
| RNF-03 | Usabilidad | Una clienta sin instrucción previa completa una reserva en menos de 2 minutos. |
| RNF-04 | Seguridad | El sistema no maneja pagos reales ni datos de tarjeta, la seña es un mock que solo registra un estado (pagada/no pagada) en SQL Server. |
| RNF-05 | Seguridad | Las fotos de "antes y después" requieren consentimiento explícito de la clienta antes de publicarse (dato sensible, ver riesgo en `propuestas.md`). |
| RNF-06 | Compatibilidad | El sistema funciona correctamente en un ancho de pantalla de 360 px (celular). |
| RNF-07 | Mantenibilidad | El dueño puede actualizar la base de precios y protocolos del buscador sin intervención técnica del equipo. |
| RNF-08 | Disponibilidad | El sistema de reserva está disponible 24/7, sin depender del horario de atención del dueño. |
| RNF-09 | Seguridad | El buscador (R2) solo responde con coincidencias de la base de precios/protocolos cargada; si no hay coincidencia, deriva al enlace de WhatsApp del dueño en vez de dar una respuesta genérica. |
| RNF-10 | Arquitectura | Todo el backend se implementa en C sobre SQL Server; el frontend, en Qt. Ninguna funcionalidad depende de una API externa, donde una versión real usaría un tercero, el sistema implementa un mock propio. |

## Historias de usuario

```
Como clienta, quiero reservar un turno sin escribir por WhatsApp,
para no esperar a que el dueño esté disponible para contestar.

Criterios de aceptación:
- La reserva se completa en 3 pasos como máximo.
- Solo se muestran horarios realmente disponibles.
- Funciona en un ancho de 360 px.
- Al confirmar, se ve un resumen del turno antes de reservar.
```

```
Como clienta, quiero pagar la seña al reservar,
para asegurar mi turno y saber cuánto se cobra por adelantado.

Criterios de aceptación:
- El pago es simulado (mock): no se conecta a ninguna pasarela real.
- El monto se ve antes de confirmar.
- El sistema no pide ni guarda ningún dato de tarjeta.
- Al confirmar, se genera un comprobante visible desde "Mis Turnos".
```

```
Como dueño, quiero que el buscador resuelva las consultas repetidas,
para no responder yo cada mensaje de precio u horario.

Criterios de aceptación:
- El buscador responde solo con coincidencias de la base de precios/protocolos.
- Si no encuentra coincidencia, ofrece un enlace directo a mi WhatsApp.
- Puedo ver cuántas consultas resolvió el buscador sin mi intervención.
```

```
Como clienta, quiero ver un recordatorio antes del turno,
para no faltar ni olvidarme la fecha.

Criterios de aceptación:
- El recordatorio se genera con anticipación configurable por el dueño.
- Se ve dentro del sistema (en "Mis Turnos"), no es un envío real por
  WhatsApp ni email.
- Queda registrado si se generó y si la clienta lo vio.
```

```
Como clienta, quiero ver mis turnos sin crear una cuenta,
para no tener que registrarme con contraseña.

Criterios de aceptación:
- El acceso es por enlace mágico enviado al confirmar la reserva.
- Desde ahí puedo ver y cancelar mi turno.
- El enlace expira después de un tiempo definido, por seguridad.
```

```
Como dueño, quiero cargar y editar mi disponibilidad directo en el sistema,
para no depender de ningún calendario externo.

Criterios de aceptación:
- Puedo marcar y desmarcar horarios disponibles desde el sistema.
- Los cambios se reflejan de inmediato en lo que ve la clienta.
- No hay ningún paso de sincronización con Google Calendar ni otro
  calendario externo.
```

## Backlog inicial

Se pasa a Trello/GitHub Projects con etiquetas Must / Should / Could según la
tabla de RF de arriba. Orden sugerido para el maquetado (`docs/05-maquetado.md`):
primero las pantallas de los RF Must (reserva, buscador, seña, recordatorio),
después "Mis Turnos" y por último la vitrina.

## Qué falta

- Pasar a `docs/05-maquetado.md`: cada pantalla del wireframe se justifica
  contra uno o más RF de esta tabla.
