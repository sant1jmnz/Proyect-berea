# Diseño conceptual (Peter Chen): entidades, atributos, relaciones y cardinalidades

Descripción escrita del modelo, sin diagramas. Es la base para dibujar el Chen
y para derivar el diseño lógico (Codd, 3FN). El detalle de las decisiones está
en [`../modelo-entidades.md`](../modelo-entidades.md).

Convenciones: **PK** = clave primaria; *opc* = admite NULL; cardinalidad
`(mín,máx)` leída desde cada entidad hacia la relación. Las relaciones no
cuentan como entidades; las N:M (*incluye*, *realiza*) se dibujan como rombo y
recién se vuelven tabla intermedia en el diseño lógico.

## Cumplimiento de la consigna

| Punto | Cómo se cumple |
|---|---|
| Mínimo 13 entidades | 27 entidades (sin contar relaciones) |
| Datos categorizables o multivaluados | Tablas maestras: Categoría de protocolo, Estado del turno, Estado del pago, Medio de pago, Resultado de evaluación, Origen, Tipo de regla, Canal / Estado / Tipo de notificación, Rol, Tipo de evento. Los multivaluados (protocolos de un turno, protocolos de un profesional) son relaciones N:M |
| Cardinalidades | Todas las relaciones las incluyen, con (mín,máx) en ambos extremos |
| Modelo de logs | Entidad **Log** + **Tipo de evento** + **Origen**: tipo de evento, fecha y hora, usuario, paciente involucrada, origen, IP, tabla y registro afectados, valor anterior y nuevo, resultado |
| Coherencia con el lógico y 3FN | Sin atributos derivados (estados, saldos, totales, retenciones y vencimientos de evaluación se calculan); sin dependencias transitivas (p. ej. `porcentaje_sena` está en la categoría, no en el protocolo) |

## Entidades y atributos (27)

### Núcleo

| Entidad | Atributos |
|---|---|
| **Paciente** | id_paciente (PK), dni (único), nombre, apellido, fecha_nacimiento, telefono, fecha_alta, email *(opc)*, telegram_chat_id *(opc)* |
| **Profesional** | id_profesional (PK), matricula (única), nombre, apellido, telefono, email, activo, google_calendar_id *(opc)* |
| **Protocolo** | id_protocolo (PK), nombre, descripcion, precio, duracion_min, activo |
| **Turno** | id_turno (PK), fecha_hora_inicio, fecha_hora_fin, fecha_creacion, google_event_id *(opc)* |
| **Disponibilidad** | id_disponibilidad (PK), fecha, hora_inicio, hora_fin, activa |
| **Pago de seña** | id_pago (PK), monto, fecha_pago, codigo_operacion, monto_reembolsado, fecha_resolucion *(opc)* |
| **Evaluación previa** | id_evaluacion (PK), observaciones *(opc)*, fecha_resultado *(opc)*, fecha_reclamo *(opc)* |
| **Notificación** | id_notificacion (PK), mensaje, fecha_programada, intentos, fecha_envio *(opc)*, detalle_error *(opc)* |
| **Consulta al asistente** | id_consulta (PK), pregunta, fecha_hora, derivada, respuesta *(opc)* |

### Cupones y tarjetas de regalo

| Entidad | Atributos |
|---|---|
| **Cupón** | id_cupon (PK), codigo (único, público), secreto (interno), porcentaje_descuento, fecha_emision, fecha_vencimiento |
| **Regla de beneficio** | id_regla (PK), nombre, umbral, porcentaje_descuento, vigencia_semanas (2 a 8), activa, ventana_dias *(opc)* |
| **Tarjeta de regalo** | id_tarjeta (PK), codigo (único), monto_inicial, fecha_compra, fecha_vencimiento, comprador_nombre, comprador_telefono *(opc)* |
| **Movimiento de tarjeta** | id_movimiento (PK), monto (negativo = devolución), fecha_movimiento |

### Tablas maestras

| Entidad | Atributos |
|---|---|
| **Categoría de protocolo** | id_categoria (PK), nombre, porcentaje_sena, requiere_evaluacion |
| **Estado del turno** | id_estado_turno (PK), nombre |
| **Estado del pago** | id_estado_pago (PK), nombre |
| **Medio de pago** | id_medio_pago (PK), nombre |
| **Resultado de evaluación** | id_resultado (PK), nombre |
| **Origen** | id_origen (PK), nombre |
| **Tipo de regla** | id_tipo_regla (PK), nombre |
| **Canal de notificación** | id_canal (PK), nombre |
| **Estado de notificación** | id_estado_notificacion (PK), nombre |
| **Tipo de notificación** | id_tipo_notificacion (PK), nombre |

### Seguridad y auditoría (logs)

| Entidad | Atributos |
|---|---|
| **Rol** | id_rol (PK), nombre |
| **Usuario** | id_usuario (PK), nombre_usuario (único), email (único), password_hash, activo, fecha_creacion |
| **Tipo de evento** | id_tipo_evento (PK), nombre, descripcion |
| **Log** | id_log (PK), fecha_hora, descripcion *(opc)*, ip_origen *(opc)*, tabla_afectada *(opc)*, id_registro_afectado *(opc)*, valor_anterior *(opc)*, valor_nuevo *(opc)*, exitoso |

## Relaciones y cardinalidades

Formato: `Entidad A (mín,máx) — relación — (mín,máx) Entidad B`. El (mín,máx)
de cada entidad es cuántas veces participa una instancia suya en la relación.
El tipo se lee de izquierda a derecha (N:1 = muchas de A por cada una de B) y
sale del máximo del lado opuesto. En las relaciones 1:N, el lado "N" es el que lleva la clave foránea
en el diseño lógico.

### Núcleo

| # | Relación | Cardinalidad | Tipo |
|---|---|---|---|
| 1 | Paciente **agenda** Turno | Paciente (0,N) — Turno (1,1) | 1:N |
| 2 | Profesional **atiende** Turno | Profesional (0,N) — Turno (1,1) | 1:N |
| 3 | Turno **incluye** Protocolo *(atributo: precio_aplicado)* | Turno (1,N) — Protocolo (0,N) | N:M |
| 4 | Profesional **realiza** Protocolo | Profesional (1,N) — Protocolo (0,N) | N:M |
| 5 | Protocolo **pertenece a** Categoría de protocolo | Protocolo (1,1) — Categoría (0,N) | N:1 |
| 6 | Turno **tiene estado** Estado del turno | Turno (1,1) — Estado (0,N) | N:1 |
| 7 | Turno **se origina en** Origen | Turno (1,1) — Origen (0,N) | N:1 |
| 8 | Profesional **tiene** Disponibilidad | Profesional (0,N) — Disponibilidad (1,1) | 1:N |
| 9 | Paciente **tiene cuenta** Usuario | Paciente (0,1) — Usuario (0,1) | 1:1 |
| 10 | Profesional **tiene cuenta** Usuario | Profesional (1,1) — Usuario (0,1) | 1:1 |

Un usuario es de una paciente o de un profesional, o de ninguno (recepción y
administración); la restricción se valida en la base.

### Pagos y evaluación previa

| # | Relación | Cardinalidad | Tipo |
|---|---|---|---|
| 11 | Turno **tiene seña** Pago de seña | Turno (0,1) — Pago (1,1) | 1:1 |
| 12 | Pago de seña **tiene estado** Estado del pago | Pago (1,1) — Estado (0,N) | N:1 |
| 13 | Pago de seña **se paga con** Medio de pago | Pago (1,1) — Medio (0,N) | N:1 |
| 14 | Turno **genera** Evaluación previa (el turno de la consulta prequirúrgica) | Turno (0,1) — Evaluación (1,1) | 1:1 |
| 15 | Evaluación previa **evalúa** Protocolo (la cirugía) | Evaluación (1,1) — Protocolo (0,N) | N:1 |
| 16 | Evaluación previa **tiene resultado** Resultado de evaluación | Evaluación (1,1) — Resultado (0,N) | N:1 |
| 17 | Turno **se basa en** Evaluación previa (el turno de la cirugía) | Turno (0,1) — Evaluación (0,N) | N:1 |

Turno es una sola entidad: la 14 y la 17 son dos relaciones distintas entre
las mismas entidades. En la 14 el turno es el de la consulta prequirúrgica
(solo existe en las consultas); en la 17 es el de la cirugía, que pasa por una
evaluación "apta". La paciente y el profesional de la evaluación salen del
turno de la consulta (relación 14), no se repiten.

### Cupones, reglas y tarjetas de regalo

| # | Relación | Cardinalidad | Tipo |
|---|---|---|---|
| 18 | Regla de beneficio **es de tipo** Tipo de regla | Regla (1,1) — Tipo (0,N) | N:1 |
| 19 | Regla de beneficio **emite** Cupón | Regla (0,N) — Cupón (1,1) | 1:N |
| 20 | Paciente **recibe** Cupón (solo con cuenta) | Paciente (0,N) — Cupón (1,1) | 1:N |
| 21 | Cupón **se aplica en** Turno | Cupón (0,1) — Turno (0,1) | 1:1 |
| 22 | Tarjeta de regalo **se compra con** Medio de pago | Tarjeta (1,1) — Medio (0,N) | N:1 |
| 23 | Tarjeta de regalo **registra** Movimiento de tarjeta | Tarjeta (0,N) — Movimiento (1,1) | 1:N |
| 24 | Movimiento de tarjeta **cubre** Turno | Movimiento (1,1) — Turno (0,N) | N:1 |

Regla de negocio (no del modelo): un turno no puede tener a la vez cupón y
tarjeta de regalo.

### Avisos, asistente y log

| # | Relación | Cardinalidad | Tipo |
|---|---|---|---|
| 25 | Notificación **usa el canal** Canal de notificación | Notificación (1,1) — Canal (0,N) | N:1 |
| 26 | Notificación **tiene estado** Estado de notificación | Notificación (1,1) — Estado (0,N) | N:1 |
| 27 | Notificación **es de tipo** Tipo de notificación | Notificación (1,1) — Tipo (0,N) | N:1 |
| 28 | Paciente **recibe** Notificación | Paciente (0,N) — Notificación (0,1) | 1:N |
| 29 | Profesional **recibe** Notificación | Profesional (0,N) — Notificación (0,1) | 1:N |
| 30 | Turno **genera** Notificación | Turno (0,N) — Notificación (0,1) | 1:N |
| 31 | Paciente **consulta** Consulta al asistente | Paciente (0,N) — Consulta (0,1) | 1:N |
| 32 | Consulta al asistente **se hace desde** Origen | Consulta (1,1) — Origen (0,N) | N:1 |

Una notificación tiene exactamente un destinatario: paciente (28) o profesional
(29), nunca los dos ni ninguno (restricción en la base).

### Seguridad y auditoría

| # | Relación | Cardinalidad | Tipo |
|---|---|---|---|
| 33 | Usuario **tiene rol** Rol | Usuario (1,1) — Rol (0,N) | N:1 |
| 34 | Log **es de tipo** Tipo de evento | Log (1,1) — Tipo (0,N) | N:1 |
| 35 | Usuario **realiza** Log | Usuario (0,N) — Log (0,1) | 1:N |
| 36 | Log **afecta a** Paciente | Log (0,1) — Paciente (0,N) | N:1 |
| 37 | Log **se registra desde** Origen | Log (1,1) — Origen (0,N) | N:1 |

El usuario del log queda vacío cuando actúa una paciente sin cuenta o el
sistema; en ese caso la paciente involucrada va en la relación 36.

## Valores de las tablas maestras

| Tabla | Valores |
|---|---|
| Categoría de protocolo | faciales, aparatología, medicina estética, cirugías (con `porcentaje_sena` 30 % o 40 % y `requiere_evaluacion`) |
| Estado del turno | pendiente de seña, confirmado, realizado, cancelado, ausente |
| Estado del pago | pendiente, pagada, reembolsada, reembolsada parcial, retenida |
| Medio de pago | tarjeta simulada, transferencia, efectivo, tarjeta de regalo |
| Resultado de evaluación | pendiente, apto, no apto |
| Origen | terminal, web, gestión, sistema |
| Tipo de regla | frecuencia de visitas, gasto acumulado, promoción general |
| Canal de notificación | Telegram, WhatsApp, Google Calendar, WhatsApp asistido |
| Estado de notificación | pendiente, enviada, fallida |
| Tipo de notificación | recordatorio de turno, confirmación, cancelación, cupón nuevo |
| Rol | paciente, recepción, profesional, administrador |
| Tipo de evento | inicio y cierre de sesión, intento fallido, alta y cancelación de turno, pago registrado, reembolso o retención, cupón emitido / validado / rechazado, uso de tarjeta de regalo, evaluación resuelta, cambio de disponibilidad, envío de notificación |

## Atributos derivados (no se guardan)

Total del turno, estado de cupón y de tarjeta (vigente / vencido / usado),
saldo de la tarjeta, monto retenido de la seña, vencimiento de la evaluación
(6 meses desde `fecha_resultado`), gasto acumulado y token rotativo del cupón.
