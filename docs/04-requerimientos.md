# Requerimientos

Se derivan de los Componentes de la MML (`docs/03-matriz-marco-logico.md`).
Cada RF referencia el componente del que sale; no hay ningún requerimiento
acá que no venga de R1-R4.

## Requerimientos funcionales

| ID | El sistema debe permitir... | Componente MML | Prioridad |
|---|---|---|---|
| RF-01 | ...a la clienta reservar un turno en 3 pasos (servicio → horario disponible → confirmación), para no tener que escribir por WhatsApp. | R1 | Must |
| RF-02 | ...sincronizar automáticamente cada reserva con el Google Calendar del dueño, para evitar superposiciones. | R1 | Must |
| RF-03 | ...mostrar únicamente los horarios realmente disponibles, actualizados en tiempo real. | R1 | Must |
| RF-04 | ...a la clienta consultar precios, horarios y protocolos a un asistente virtual, para resolver dudas sin esperar respuesta del dueño. | R2 | Must |
| RF-05 | ...derivar la consulta al WhatsApp del dueño cuando el asistente no pueda responderla, para no perder la consulta. | R2 | Must |
| RF-06 | ...a la clienta pagar la seña vía Mercado Pago al confirmar la reserva, para reducir inasistencias. | R3 | Must |
| RF-07 | ...al dueño definir el monto de la seña y su política de devolución. | R3 | Should |
| RF-08 | ...enviar un recordatorio automático de turno antes de la fecha reservada, para reducir inasistencias. | R4 | Must |
| RF-09 | ...a la clienta ver y cancelar sus turnos reservados mediante un enlace mágico, sin registro ni contraseña. | R1 | Should |
| RF-10 | ...mostrar una vitrina de fotos antes/después y reseñas de Google Maps, para atraer clientes potenciales. | — (fuera de R1-R4, ver "Vitrina" en `docs/propuestas.md`) | Could |

**Sobre las prioridades:** RF-01 a RF-06 y RF-08 son *Must* porque atacan
directamente las cuatro causas del Árbol de Problemas (C1-C4). RF-07 y RF-09
son *Should*: mejoran la experiencia pero el sistema funciona sin ellos. RF-10
es *Could* — ya estaba marcado como módulo "deseable" en `propuestas.md`, no
"núcleo".

## Requerimientos no funcionales

| ID | Categoría | Criterio medible |
|---|---|---|
| RNF-01 | Rendimiento | El asistente virtual responde en menos de 2 segundos. |
| RNF-02 | Rendimiento | La grilla de disponibilidad carga en menos de 2 segundos. |
| RNF-03 | Usabilidad | Una clienta sin instrucción previa completa una reserva en menos de 2 minutos. |
| RNF-04 | Seguridad | El backend no almacena datos de tarjeta — el cobro lo procesa Mercado Pago. |
| RNF-05 | Seguridad | Las fotos de "antes y después" requieren consentimiento explícito de la clienta antes de publicarse (dato sensible, ver riesgo en `propuestas.md`). |
| RNF-06 | Compatibilidad | El sistema funciona correctamente en un ancho de pantalla de 360 px (celular). |
| RNF-07 | Mantenibilidad | El dueño puede actualizar la base de precios y protocolos del asistente sin intervención técnica del equipo. |
| RNF-08 | Disponibilidad | El sistema de reserva está disponible 24/7, sin depender del horario de atención del dueño. |

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
- Se integra con Mercado Pago.
- El monto se ve antes de pagar.
- El sistema no guarda el número de tarjeta.
- Al pagar, se genera un comprobante visible desde "Mis Turnos".
```

```
Como dueño, quiero que el asistente resuelva las consultas repetidas,
para no responder yo cada mensaje de precio u horario.

Criterios de aceptación:
- El asistente responde solo con datos de la base de precios/protocolos.
- Si no sabe la respuesta, deriva a mi WhatsApp con el historial de la consulta.
- Puedo ver cuántas consultas resolvió el asistente sin mi intervención.
```

```
Como clienta, quiero recibir un recordatorio antes del turno,
para no faltar ni olvidarme la fecha.

Criterios de aceptación:
- El recordatorio se envía con anticipación configurable por el dueño.
- Llega por el canal definido (WhatsApp o el propio sistema).
- Queda registrado si se envió y si la clienta lo abrió.
```

```
Como clienta, quiero ver mis turnos sin crear una cuenta,
para no tener que registrarme con contraseña.

Criterios de aceptación:
- El acceso es por enlace mágico enviado al confirmar la reserva.
- Desde ahí puedo ver y cancelar mi turno.
- El enlace expira después de un tiempo definido, por seguridad.
```

## Backlog inicial

Se pasa a Trello/GitHub Projects con etiquetas **Must / Should / Could** según
la tabla de RF de arriba. Orden sugerido para el maquetado (`docs/05-maquetado.md`):
primero las pantallas de los RF *Must* (reserva, asistente, seña, recordatorio),
después "Mis Turnos" y por último la vitrina.

## Qué falta

- Definir con el dueño el monto exacto de la seña y su política de devolución
  (RF-07) — hoy es una decisión de diseño pendiente.
- Con esto cerrado, pasar a `docs/05-maquetado.md`: cada pantalla del wireframe
  se justifica contra uno o más RF de esta tabla.
