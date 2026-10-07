# Modelo de entidades (borrador)

Primer paso del diseño conceptual de la base (consigna en
[`consigna-bbdd.md`](consigna-bbdd.md)). Acá solo se define **qué entidades hay**;
los atributos y cardinalidades se van cerrando por grupos (abajo); el diagrama
de Chen se arma al final.

Mínimo pedido: 13 entidades (las relaciones no cuentan). Este borrador tiene 27.

## Decisiones tomadas

- La paciente **no necesita cuenta**: se identifica por DNI. La cuenta es
  **opcional** y da cupones, notificaciones e historial ya cargado.
- El personal tiene **cuenta propia obligatoria**, para auditar errores.
- Un turno puede tener **varios protocolos**.
- Cada protocolo se registra **por profesional** (qué protocolos hace cada uno).
- La seña es un **mock** que imita un pago real.
- Los recordatorios salen por **Telegram** (bot gratuito y automático, para
  desarrollo y demo), **Google Calendar** y, en producción, la **API oficial
  de WhatsApp**. Mientras tanto, la recepción puede avisar con un enlace
  `wa.me`. La paciente guarda su identificador de Telegram al vincular el
  bot (atributo de *Paciente*).
- Hay un **asistente de IA**; sus consultas se registran.
- Obra social: **no entra**. **Tipo de evento** queda como tabla aparte.
- Es un instituto de **estética médica**: el catálogo incluye desde
  tratamientos faciales hasta **cirugías** (precios en `04-requerimientos.md`).

## Descuentos, cupones y tarjetas de regalo

**Cupones de descuento**
- Los reciben/usan las pacientes **con cuenta** (login).
- Se aplican de dos maneras: (1) **por código**, en el campo "¿Tenés un
  cupón de descuento?" mientras agenda; (2) **por QR**: cada cupón genera un
  QR y, si no se cargó al agendar, la profesional lo **escanea antes del
  pago**.
- Tienen **vigencia** y se usan una sola vez.

**Cupones por fidelidad** (los genera el sistema según reglas)
- Por **frecuencia**: ej. 2 visitas en 1 mes → cupón del 10%.
- Por **gasto acumulado**: ej. superar cierto monto → cupón.
- Cada regla define el porcentaje y la vigencia, entre **2 y 8 semanas**.

**Tarjetas de regalo**
- Son por **monto** (ej. $300.000) y tienen **saldo**: se pueden gastar en
  varias compras y turnos hasta agotarlo.
- Las compra una persona y las usa otra, con su código.
- Tienen **vigencia**.

## Cirugías

- **Seña del 40%** (el resto de los protocolos, 30%).
- **Consulta previa obligatoria y paga**, con su propia seña.
- Si la evaluación es **apta** y la paciente pasa a la cirugía, el dinero de
  la consulta se **devuelve**.
- Si **no es apta**, el instituto se queda con el **10%** y devuelve el
  resto.
- Sin evaluación "apta" no se puede agendar la cirugía.
- La evaluación "apta" **vale 6 meses** para agendar la cirugía.
- Pasados los 6 meses sin agendar: sin reclamo de la paciente, el instituto
  se queda con el dinero de las consultas; con reclamo, retiene el 50% del
  total de las consultas. La *Evaluación previa* necesita
  guardar si hubo reclamo y cuándo.

## Reglas cerradas

- Un **cupón no se puede usar junto con una tarjeta de regalo** en el mismo
  turno.
- Los **estados** (de cupón, tarjeta, vigencia) **se calculan**, no se
  guardan: vigente/vencido sale de la fecha; usado, de que exista un uso;
  el saldo de la tarjeta, de la suma de sus movimientos.
- El **QR** se escanea con el celular del profesional, un escáner o un
  lector en la PC de gestión (las tres opciones valen).

## Entidades (27)

### Núcleo
1. **Paciente** (cuenta opcional)
2. **Profesional**
3. **Protocolo** (tratamientos y cirugías)
4. **Turno**: tabla principal del sistema (50+ registros)
5. **Disponibilidad** (franjas horarias del profesional)
6. **Pago de seña**
7. **Notificación** (recordatorios y avisos)
8. **Consulta al asistente** (preguntas a la IA y derivaciones)
9. **Evaluación previa** (consulta prequirúrgica: paciente, cirugía,
   turno de la consulta, profesional, fecha, resultado y observaciones)

### Cupones y tarjetas
10. **Cupón** (código, QR, % de descuento, vigencia, paciente destinatario,
    uso en un turno)
11. **Regla de beneficio** (frecuencia o gasto acumulado, umbral, % y
    vigencia de 2 a 8 semanas)
12. **Tarjeta de regalo** (código, monto inicial, saldo, vigencia, quién la
    compró)
13. **Movimiento de tarjeta** (cada gasto del saldo, ligado a un turno o
    compra)

### Tablas maestras
14. **Estado del turno**
15. **Estado del pago**
16. **Categoría de protocolo** (faciales, aparatología, medicina estética,
    cirugías)
17. **Canal de notificación** (Telegram, WhatsApp, Google Calendar, WhatsApp asistido)
18. **Resultado de evaluación** (apto, no apto)
19. **Origen** (terminal, web, gestión, sistema): desde dónde se hizo algo
20. **Medio de pago** (tarjeta simulada, transferencia, efectivo, tarjeta de regalo)
21. **Tipo de regla** (frecuencia de visitas, gasto acumulado, promoción general)
22. **Estado de notificación** (pendiente, enviada, fallida)
23. **Tipo de notificación** (recordatorio de turno, confirmación, cancelación, cupón nuevo)

### Seguridad y auditoría
24. **Usuario** (credenciales; paciente opcional, personal obligatorio)
25. **Rol**
26. **Log**
27. **Tipo de evento**

Además, dos relaciones N:M que se vuelven **tablas intermedias** en el diseño
lógico (en el Chen son relaciones, no entidades): *Turno–Protocolo* ("incluye")
y *Profesional–Protocolo* ("realiza").

*Especialidad* quedó afuera: la relación profesional-protocolo la reemplaza.

## Grupo 1 (cerrado): Paciente, Profesional, Protocolo, Turno

### Decisiones
1. **La seña vive en la categoría.** `porcentaje_sena` (30% o 40%) y
   `requiere_evaluacion` (cirugías) son atributos de *Categoría de protocolo*,
   no de *Protocolo*: dependen de la categoría, y ponerlos en el protocolo
   rompería la 3FN.
2. **N:M como relaciones en el Chen.** *incluye* y *realiza* se dibujan como
   rombos; se vuelven tablas recién en el diseño lógico.
3. **Se guarda el precio del momento.** *incluye* tiene el atributo
   `precio_aplicado`, así un cambio posterior en el catálogo no altera los
   turnos viejos. El total del turno **no se guarda**: se calcula sumando los
   `precio_aplicado` (evita redundancia).
4. **Origen es tabla maestra** (terminal, web, gestión, sistema): es dato
   categorizable, sirve para reportes y lo comparten el turno, la consulta al
   asistente y el log.
5. **Quién cargó el turno queda en el log**, no como relación del turno: un
   turno cargado por una paciente sin cuenta no tiene usuario, y duplicaría
   lo que ya registra la auditoría.

### Atributos
(PK = clave primaria, *opc* = admite NULL)

| Entidad | Atributos |
|---|---|
| **Paciente** | id_paciente (PK), dni (único), nombre, apellido, fecha_nacimiento, telefono, fecha_alta, email *(opc)*, telegram_chat_id *(opc)* |
| **Profesional** | id_profesional (PK), matricula (única), nombre, apellido, telefono, email, activo, google_calendar_id *(opc)* |
| **Protocolo** | id_protocolo (PK), nombre, descripcion, precio, duracion_min, activo |
| **Categoría de protocolo** | id_categoria (PK), nombre, porcentaje_sena, requiere_evaluacion |
| **Estado del turno** | id_estado_turno (PK), nombre |
| **Origen** | id_origen (PK), nombre |
| **Turno** | id_turno (PK), fecha_hora_inicio, fecha_hora_fin, fecha_creacion, google_event_id *(opc)* |

### Relaciones y cardinalidades (mín,máx)
- Paciente (0,N) **agenda** (1,1) Turno
- Profesional (0,N) **atiende** (1,1) Turno
- Turno (1,N) **incluye** (0,N) Protocolo, con `precio_aplicado`
- Profesional (1,N) **realiza** (0,N) Protocolo
- Protocolo (1,1) **pertenece a** (0,N) Categoría de protocolo
- Turno (1,1) **tiene estado** (0,N) Estado del turno
- Turno (1,1) **se origina en** (0,N) Origen
- Paciente (0,1) **tiene cuenta** (0,1) Usuario
- Profesional (1,1) **tiene cuenta** (0,1) Usuario
- Profesional (0,N) **tiene** (1,1) Disponibilidad *(franjas horarias del profesional; sus atributos faltan definir)*

## Grupo 2 (propuesto): pagos y evaluación previa

### Decisiones
1. **La consulta previa es un turno.** Se agenda y se paga como cualquier
   otro turno (con su seña); la *Evaluación previa* es el resultado médico de
   ese turno.
2. **Un turno tiene como máximo un pago de seña.** Si se cancela y se reserva
   de nuevo, es otro turno y otro pago.
3. **Lo retenido no se guarda, se calcula.** El pago guarda `monto` y
   `monto_reembolsado`; lo retenido es la diferencia. Así sirven todas las
   reglas (10% si no es apta, 50% al vencer con reclamo, 100% al vencer sin
   reclamo, sin devolución por cancelar con menos de 24 h) sin duplicar datos.
4. **Medio de pago es tabla maestra** (nueva): permite saber con qué se pagó la
   seña, incluida una tarjeta de regalo, sin guardar datos de tarjeta.
5. **La vigencia de 6 meses se calcula** desde `fecha_resultado`; no se guarda
   la fecha de vencimiento.
6. **El gasto acumulado para los cupones de fidelidad se calcula** sumando
   los precios de los turnos realizados; no hace falta un campo aparte.

### Atributos
| Entidad | Atributos |
|---|---|
| **Pago de seña** | id_pago (PK), monto, fecha_pago, codigo_operacion *(simulado)*, monto_reembolsado, fecha_resolucion *(opc: cuando se devuelve o retiene)* |
| **Estado del pago** | id_estado_pago (PK), nombre *(pendiente, pagada, reembolsada, reembolsada parcial, retenida)* |
| **Medio de pago** | id_medio_pago (PK), nombre |
| **Evaluación previa** | id_evaluacion (PK), observaciones *(opc)*, fecha_resultado *(opc, hasta que se resuelve)*, fecha_reclamo *(opc)* |
| **Resultado de evaluación** | id_resultado (PK), nombre *(pendiente, apto, no apto)* |

### Relaciones y cardinalidades (mín,máx)
- Turno (0,1) **tiene seña** (1,1) Pago de seña
- Pago de seña (1,1) **tiene estado** (0,N) Estado del pago
- Pago de seña (1,1) **se paga con** (0,N) Medio de pago
- Turno de consulta (1,1) **genera** (1,1) Evaluación previa *(solo en consultas prequirúrgicas: en el resto de los turnos no existe)*
- Evaluación previa (1,1) **evalúa** (0,N) Protocolo *(la cirugía para la que se evalúa)*
- Evaluación previa (1,1) **tiene resultado** (0,N) Resultado de evaluación
- Turno de cirugía (0,1) **se basa en** (0,N) Evaluación previa

La paciente y el profesional de la evaluación no se repiten como atributos:
salen del turno de la consulta.

## Grupo 3 (propuesto): cupones, reglas y tarjetas de regalo

### Decisiones
1. **Todo cupón es personal y de un solo uso.** Una promoción para "todas las
   pacientes con cuenta" no es un código compartido: el sistema genera **un
   cupón por paciente**. Así cada cupón se usa una vez y se evita contar usos.
2. **Las reglas emiten los cupones.** *Regla de beneficio* define cuándo y
   cuánto: por frecuencia (ej. 2 visitas en 1 mes → 10%), por gasto acumulado,
   o por promoción general. Su tipo es una tabla maestra (*Tipo de regla*).
3. **El estado no se guarda**: un cupón está *usado* si está ligado a un turno,
   *vencido* si pasó su fecha y *vigente* en otro caso.
4. **El vencimiento sí se guarda en el cupón** (la regla puede cambiar después
   y no debe alterar cupones ya emitidos). Se calcula al emitirlo con la
   vigencia de la regla (2 a 8 semanas).
5. **La tarjeta de regalo tiene saldo calculado**: `monto_inicial` menos la
   suma de sus movimientos. El comprador puede no ser paciente, por eso se
   guardan sus datos como atributos y no como relación.
6. **Cupón y tarjeta no se mezclan en un mismo turno.** Es una regla de
   negocio que se valida en el stored procedure, no una restricción del modelo.
8. **Códigos y QR de los cupones, rotativos (cada 5 minutos).** Lo que se
   muestra o se escanea no es un código fijo sino un **token temporal** que se
   renueva cada 5 minutos, como una segunda capa de seguridad contra robo o
   reuso de una captura. El token **no se guarda**: se calcula a partir de un
   `secreto` propio de cada cupón y de la ventana de tiempo actual (por
   ejemplo, un hash del secreto y del tiempo dividido en tramos de 5 minutos).
   Al validar, el stored procedure lo recalcula y acepta el tramo actual y el
   anterior (margen por diferencias de reloj). El `codigo` queda como
   identificador público y no sirve solo. Ver "Qué hace el token" más abajo.
7. **El monto de un movimiento puede ser negativo**: negativo = devolución de
   saldo a la tarjeta (por ejemplo al cancelar con reembolso).

### Atributos
| Entidad | Atributos |
|---|---|
| **Tipo de regla** | id_tipo_regla (PK), nombre |
| **Regla de beneficio** | id_regla (PK), nombre, umbral *(visitas o monto, según el tipo)*, porcentaje_descuento, vigencia_semanas *(2 a 8)*, activa, ventana_dias *(opc: solo frecuencia)* |
| **Cupón** | id_cupon (PK), codigo (único, público), secreto (interno, nunca se muestra), porcentaje_descuento, fecha_emision, fecha_vencimiento |
| **Tarjeta de regalo** | id_tarjeta (PK), codigo (único, fijo), monto_inicial, fecha_compra, fecha_vencimiento, comprador_nombre, comprador_telefono *(opc)* |
| **Movimiento de tarjeta** | id_movimiento (PK), monto *(negativo = devolución)*, fecha_movimiento |

9. **La tarjeta de regalo tiene código fijo.** No rota: se va vaciando a
   medida que se gasta, hasta agotar el saldo. Como el código fijo funciona
   como un "billete", se usa un código largo y aleatorio, y los intentos
   fallidos de validación quedan en el log.

### Qué hace el token (solo cupones)
- **Protege contra** el uso de una captura de pantalla vieja o de un código
  copiado: a los 5 minutos deja de servir.
- **No reemplaza** al uso único: un cupón ya usado se rechaza igual, aunque el
  token sea válido.
- Se pide al sistema con un stored procedure (por ejemplo,
  `generar_token_cupon`) y se valida con otro (`validar_cupon`), que además
  deja registrado en el log cada validación aceptada o rechazada.
- MySQL no trae un HMAC formal; para el trabajo alcanza con un hash con
  clave (`SHA2` sobre el secreto y el tramo de tiempo). Se aclara en la
  defensa.

### Relaciones y cardinalidades (mín,máx)
- Regla de beneficio (1,1) **es de tipo** (0,N) Tipo de regla
- Regla de beneficio (0,N) **emite** (1,1) Cupón
- Paciente (0,N) **recibe** (1,1) Cupón *(solo pacientes con cuenta)*
- Cupón (0,1) **se aplica en** (0,1) Turno
- Tarjeta de regalo (1,1) **se compra con** (0,N) Medio de pago
- Tarjeta de regalo (0,N) **registra** (1,1) Movimiento de tarjeta *(la carga inicial es el atributo `monto_inicial`, no un movimiento)*
- Movimiento de tarjeta (1,1) **cubre** (0,N) Turno

## Grupo 4 (propuesto): avisos, asistente, cuentas y log

### Decisiones
1. **Cada aviso es una fila de `Notificación`.** Guarda a quién va, por qué
   canal, de qué tipo es, cuándo se programó y cómo terminó. Es lo que lee y
   actualiza n8n con los stored procedures.
2. **Estado y tipo de la notificación son tablas maestras** (nuevas): son datos
   categorizables (pendiente/enviada/fallida; recordatorio, confirmación,
   cancelación, cupón nuevo).
3. **El destinatario es una paciente o un profesional** (nunca los dos): dos
   relaciones opcionales con la regla "exactamente una", que se valida con una
   restricción. El recordatorio de turno se relaciona además con el turno; el
   aviso de un cupón nuevo no.
4. **`Origen` se generaliza**: antes "Origen del turno", ahora lo usan también
   la consulta al asistente y el log (terminal, web, gestión y *sistema*, para
   lo que hace n8n).
5. **Cuentas simples.** `Usuario` tiene solo el nombre de usuario, el mail y la
   contraseña cifrada; los nombres reales ya están en `Paciente` y
   `Profesional`, y no se duplican (3FN). El personal de recepción y
   administración se identifica por su nombre de usuario. La contraseña
   **nunca** se guarda en claro, solo su hash.
6. **El último acceso y los intentos fallidos no se guardan en `Usuario`**: se
   calculan desde el log.
7. **El log guarda quién, qué, cuándo, desde dónde y sobre quién.** Para
   auditar cambios guarda el valor anterior y el nuevo de lo modificado.
   Una acción de una paciente sin cuenta queda con usuario vacío y con la
   paciente involucrada.
8. **El log solo se escribe desde stored procedures**, nunca a mano ni desde la
   app directamente (lo pide la consigna).
9. **La consulta al asistente guarda lo preguntado y respondido**, pero no se
   le envían datos personales a la IA (RNF-06); si la paciente los escribe,
   el sistema los filtra antes de enviar la pregunta.

### Atributos
| Entidad | Atributos |
|---|---|
| **Canal de notificación** | id_canal (PK), nombre *(Telegram, WhatsApp, Google Calendar, WhatsApp asistido)* |
| **Estado de notificación** | id_estado_notificacion (PK), nombre |
| **Tipo de notificación** | id_tipo_notificacion (PK), nombre |
| **Notificación** | id_notificacion (PK), mensaje, fecha_programada, intentos, fecha_envio *(opc)*, detalle_error *(opc)* |
| **Consulta al asistente** | id_consulta (PK), pregunta, fecha_hora, derivada *(sí/no: se derivó a una persona)*, respuesta *(opc)* |
| **Rol** | id_rol (PK), nombre *(paciente, recepción, profesional, administrador)* |
| **Usuario** | id_usuario (PK), nombre_usuario (único), email (único), password_hash, activo, fecha_creacion |
| **Tipo de evento** | id_tipo_evento (PK), nombre, descripcion |
| **Log** | id_log (PK), fecha_hora, descripcion *(opc)*, ip_origen *(opc)*, tabla_afectada *(opc)*, id_registro_afectado *(opc)*, valor_anterior *(opc)*, valor_nuevo *(opc)*, exitoso |

Tipos de evento previstos: inicio y cierre de sesión, intento fallido, alta y
cancelación de turno, pago registrado, reembolso o retención, cupón emitido,
validado o rechazado, uso de tarjeta de regalo, evaluación resuelta, cambio de
disponibilidad, y envío de notificación.

### Relaciones y cardinalidades (mín,máx)
- Notificación (1,1) **usa el canal** (0,N) Canal de notificación
- Notificación (1,1) **tiene estado** (0,N) Estado de notificación
- Notificación (1,1) **es de tipo** (0,N) Tipo de notificación
- Paciente (0,N) **recibe** (0,1) Notificación
- Profesional (0,N) **recibe** (0,1) Notificación *(una de las dos, exactamente)*
- Turno (0,N) **genera** (0,1) Notificación
- Paciente (0,N) **consulta** (0,1) Consulta al asistente *(vacío si es invitada)*
- Consulta al asistente (1,1) **se hace desde** (0,N) Origen
- Usuario (1,1) **tiene rol** (0,N) Rol
- Log (1,1) **es de tipo** (0,N) Tipo de evento
- Log (0,1) **lo hace** (0,N) Usuario *(vacío si lo hace una invitada o el sistema)*
- Log (0,1) **afecta a** (0,N) Paciente
- Log (1,1) **se registra desde** (0,N) Origen

## Pendiente de definir

- Atributos de **Disponibilidad** (no se definieron todavía): por ejemplo día de la semana, hora de inicio y de fin, y vigencia.
- Revisar el modelo completo (grupos 1 a 4) y cerrar las preguntas abiertas
  del grupo 3.
- Pasar el modelo cerrado a XML para draw.io (jueves).
