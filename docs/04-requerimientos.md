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
| RF-10 | Todos | ...calcular (de forma simulada) una seña del 30% del precio final del protocolo (mínimo $20.000), y del **40% en cirugías**; reembolsable 100% si se cancela con más de 24 h de anticipación y no reembolsable por debajo de ese plazo o por inasistencia. | R3 | Should |
| RF-11 | Todos | ...enviar un recordatorio de turno a la paciente antes de la fecha reservada y registrar cada aviso (canal, estado, fecha programada). Canales: **Telegram** (bot, gratis y automático, se usa en el desarrollo y la demo), **Google Calendar** (invitación con recordatorio) y **WhatsApp** (API oficial en producción; mientras tanto, enlace `wa.me` asistido desde la recepción). | R4 | Must |
| RF-12 | Cliente + Web | ...a la paciente buscar y cancelar su propio turno con su DNI o teléfono, sin cuenta. | R1 | Should |
| RF-13 | Gestión | ...a la recepción buscar y cancelar el turno de cualquier paciente por nombre, DNI o teléfono. | R1 | Should |
| RF-14 | Cliente + Web | ...a la paciente hacer preguntas a un **asistente de IA** (precios, protocolos, cuidados) y recibir respuesta; las consultas quedan registradas. | R2 | Should |
| RF-15 | Web (+ Cliente) | ...a la paciente **crear una cuenta opcional**; con cuenta ve su historial de turnos sin volver a ingresar su DNI. | R1 | Should |
| RF-16 | Todos | ...buscar el historial de turnos de una paciente **por DNI** (sin cuenta), tanto desde el apartado Cliente como desde la Web. | R1 | Should |
| RF-17 | Cliente + Web + Gestión | ...que la paciente con cuenta ingrese un **cupón de descuento por código** mientras agenda ("¿Tenés un cupón de descuento?") y que el precio se actualice antes de pagar. | R3 | Should |
| RF-22 | Gestión | ...que cada cupón tenga un **código QR**, y que el profesional lo escanee antes del pago para aplicarlo si la paciente no lo cargó al agendar. El escaneo puede hacerse con el **celular del profesional**, un **escáner** o un **lector** conectado a la PC de gestión. | R3 | Should |
| RF-23 | Web + Cliente + Gestión | ...vender y canjear **tarjetas de regalo por monto** (ej. $300.000): la tarjeta tiene saldo y puede gastarse en varias compras y turnos, también por otra persona, hasta que venza. **Un cupón y una tarjeta de regalo no se pueden usar en el mismo turno.** | R3 | Should |
| RF-25 | Todos | ...que toda **cirugía** requiera una **consulta previa paga**, con su propia seña, y que solo pueda agendarse si el resultado de la evaluación es "apto": si la paciente pasa a la cirugía, el dinero de la consulta se **devuelve**; la evaluación "apta" **vale 6 meses** para agendar la cirugía; si no es apta, el instituto **retiene el 10%** y devuelve el resto. | R1, R3 | Must |
| RF-24 | Todos | ...generar **cupones automáticos por fidelidad** a las pacientes con cuenta: por frecuencia (ej. 2 visitas en 1 mes → 10%) y por gasto acumulado (ej. superar cierto monto → cupón). | R3 | Should |
| RF-18 | Gestión | ...registrar qué **protocolos realiza cada profesional**, y ofrecer en la reserva solo los profesionales habilitados para el protocolo elegido. | R1 | Should |
| RF-19 | Web + Gestión | ...que, al confirmar el turno, la paciente pueda agregarlo a **su Google Calendar** con un botón, y que el turno se cargue automáticamente en el calendario del **profesional**. | R4 | Should |
| RF-20 | Gestión | ...que cada integrante del personal ingrese con **cuenta propia** y que cada acción relevante (inicio de sesión, alta, cancelación, pago) quede en un **log de auditoría** consultable por rango de fechas. | Transversal | Must |
| RF-21 | Web | ...ofrecer el **sitio web** completo para la paciente: catálogo de protocolos, reserva, consulta/cancelación del turno, asistente de IA y cuenta opcional. | R1-R4 | Must |

Los Must son los que atacan directamente las cuatro causas del Árbol de
Problemas (C1-C4), más el log de auditoría (RF-20), el sitio web (RF-21) y la consulta previa de cirugías (RF-25),
que pidió el equipo como parte del alcance. El resto (RF-10, RF-12 a RF-19, RF-22 a RF-24)
son Should: mejoran la experiencia pero el sistema funciona sin ellos.

La "vitrina" (fotos antes/después + reseñas de Google Maps) sigue fuera
de este alcance. Con web y APIs ahora permitidas podría reconsiderarse como
iteración futura (`docs/propuestas.md`).

## Requerimientos no funcionales

| ID | Categoría | Criterio medible |
|---|---|---|
| RNF-01 | Rendimiento | El buscador de precios y protocolos responde en menos de 2 segundos, en cualquiera de los tres apartados. |
| RNF-02 | Rendimiento | La grilla de disponibilidad carga en menos de 2 segundos. |
| RNF-03 | Usabilidad | Una paciente sin instrucción previa completa la carga de su turno (terminal o web) en menos de 2 minutos. |
| RNF-04 | Usabilidad | La recepción, con una capacitación breve, completa la carga de un turno en menos de 1 minuto. |
| RNF-05 | Seguridad | El sistema no maneja pagos reales ni datos de tarjeta: la seña es un mock que imita el flujo de pago y solo registra el estado en MySQL. |
| RNF-06 | Seguridad | Los datos de contacto y de salud de la paciente se guardan en la base MySQL del instituto. A servicios externos (Google Calendar, Telegram/WhatsApp, IA) solo se envía lo mínimo necesario; al asistente de IA no se le envían datos personales ni de salud. |
| RNF-07 | Compatibilidad | La terminal funciona en pantalla táctil de al menos 768×1024 px; Gestión, en ventana de escritorio de 960×600 px como mínimo; la web, en celular y escritorio. |
| RNF-08 | Mantenibilidad | La recepción puede actualizar precios y protocolos sin intervención técnica del equipo. |
| RNF-09 | Disponibilidad | La base MySQL corre en la nube (Aiven) y el instituto no puede dejar de atender por un corte de luz o de internet: hay no-break, conexión de respaldo y un **modo contingencia** que guarda los turnos localmente y los sincroniza al volver la conexión. Las funciones que dependen de servicios externos (Telegram/WhatsApp, Calendar, IA) degradan sin frenar la carga de turnos. Ver `docs/arquitectura.md`. |
| RNF-10 | Seguridad | Las respuestas del asistente de IA se limitan a la información cargada del instituto; si no hay base para responder, deriva al WhatsApp del instituto en vez de inventar. |
| RNF-11 | Arquitectura | Base de datos MySQL dividida en schemas, aplicación de escritorio en Qt y sitio web, sobre la misma base. Las integraciones externas son Google Calendar, Telegram/WhatsApp (orquestados con n8n) y un asistente de IA. Ver `docs/arquitectura.md`. |
| RNF-13 | Continuidad | La base tiene respaldos automáticos fuera del servidor, y n8n se reinicia solo si la VM se cae. |
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
- El monto se ve antes de confirmar (30% del precio final, mínimo $20.000).
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
- El recordatorio me llega por Telegram (o WhatsApp en producción) con anticipación configurable.
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
Como paciente con cuenta, quiero usar un cupón de descuento al agendar,
para pagar menos en mi turno.

Criterios de aceptación:
- Hay un campo "¿Tenés un cupón de descuento?" durante la reserva.
- El precio y la seña se recalculan con el descuento antes de pagar.
- Si no lo cargué, puedo mostrar mi QR y la profesional lo escanea antes del pago.
- El cupón tiene vigencia (entre 2 y 8 semanas según el tipo) y se usa una sola vez.
```

```
Como paciente, quiero comprar una tarjeta de regalo por un monto,
para que otra persona pueda hacerse tratamientos en el instituto.

Criterios de aceptación:
- La tarjeta tiene un monto en pesos y un código; el saldo se descuenta a medida que se usa.
- Se puede usar en más de un turno hasta agotar el saldo.
- La tarjeta tiene vigencia; vencida, no se puede usar.
```

```
Como administración, quiero que el sistema premie a las pacientes frecuentes,
para fidelizarlas.

Criterios de aceptación:
- Con 2 visitas en 1 mes, la paciente con cuenta recibe un cupón del 10%.
- Al superar cierto gasto acumulado, recibe otro cupón.
- Cada regla define su porcentaje y su vigencia (2 a 8 semanas).
```

```
Como administración, quiero que cada acción del personal quede registrada,
para auditar errores y saber quién hizo qué.

Criterios de aceptación:
- Cada integrante del personal ingresa con su propia cuenta.
- El log guarda tipo de evento, fecha y hora y usuario.
- Puedo consultar el log por rango de fechas.
```

```
Como paciente que quiere una cirugía, quiero hacerme primero una consulta de evaluación,
para saber si estoy apta antes de reservar la operación.

Criterios de aceptación:
- La consulta previa se paga con su seña y es obligatoria para toda cirugía.
- Solo puedo agendar la cirugía con una evaluación "apta".
- Si paso a la cirugía, se me devuelve el dinero de la consulta; si no soy apta, el instituto retiene el 10%.
- La seña de la cirugía es del 40%.
```

## Catálogo y precios de referencia

Dermalia es un instituto de **estética médica**: el catálogo va de
tratamientos faciales y corporales a procedimientos médicos y cirugías.
Los precios de referencia que se usan en el sistema y en los cálculos son
un **supuesto de equipo** (no un dato relevado) y se ajustan al cargar el
catálogo real. Valores en pesos argentinos (orden de magnitud 2026):

| Categoría | Ejemplos | Rango de referencia |
|---|---|---|
| Faciales y corporales | Limpieza profunda, peeling, hidratación | $60.000 – $180.000 |
| Aparatología | Láser, radiofrecuencia, criolipólisis (por sesión) | $120.000 – $450.000 |
| Medicina estética | Toxina botulínica, rellenos, bioestimuladores | $250.000 – $900.000 |
| Cirugías | Rinoplastia, lipoescultura, mamoplastia, blefaroplastia | $2.500.000 – $9.000.000 |

El **ticket promedio por turno** que usan los cálculos es **$150.000**.
### Cirugías

- **Seña del 40%** del precio final (el resto de los protocolos, 30%).
- **Consulta previa obligatoria y paga**, con su propia seña. Sin
  evaluación "apta" no se puede agendar la cirugía.
- Si la evaluación es apta y la paciente pasa a la cirugía, el dinero de la
  consulta se **devuelve**.
- La evaluación "apta" **vale 6 meses**: la cirugía se puede agendar dentro
  de ese plazo.
- Si pasan los 6 meses sin agendar: si la paciente **no reclama** (no apela),
  el instituto **se queda con el dinero** de las consultas; si reclama, el
  instituto retiene el **50% del total de las consultas** y devuelve el
  resto.
- Si no es apta, el instituto **se queda con el 10%** de la consulta y
  devuelve el resto.
- Como todo el pago es mock, la devolución y la retención son cambios de
  estado y de monto en el sistema, no movimientos de dinero real.

## Backlog inicial

Se pasa a Trello/GitHub Projects con etiquetas Must / Should y el apartado
(Cliente / Gestión / Web) según la tabla de RF de arriba. Orden sugerido para el
maquetado (`docs/05-maquetado.md`): primero las pantallas Must de cada
apartado (carga de turno, buscador, seña), después las búsquedas Should.

## Qué falta

- **Mensajería**: se usa **Telegram** (bot gratuito) mientras se desarrolla,
  porque permite automatizar sin pagar. Al pasar a producción se cambia a
  la **API oficial de WhatsApp**, que es más cómoda para las pacientes. La
  base no cambia: solo el canal de envío.
- Actualizar `docs/05-maquetado.md` con las pantallas del apartado Web y las
  nuevas (cuenta, asistente de IA, descuentos).

- Pasar a `docs/05-maquetado.md`: cada pantalla del wireframe se justifica
  contra uno o más RF de esta tabla, separadas por apartado.
- Diseñar la pantalla de administración de disponibilidad (RF-03), que
  todavía no tiene wireframe.
