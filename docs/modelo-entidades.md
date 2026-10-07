# Modelo de entidades (borrador)

Primer paso del diseño conceptual de la base (consigna en
[`consigna-bbdd.md`](consigna-bbdd.md)). Acá solo se define **qué entidades hay**;
los atributos y cardinalidades se van cerrando por grupos (abajo); el diagrama
de Chen se arma al final.

Mínimo pedido: 13 entidades (las relaciones no cuentan). Este borrador tiene 24.

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

## Entidades (24)

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
19. **Origen del turno** (terminal, web, gestión)
20. **Medio de pago** (tarjeta simulada, transferencia, efectivo, tarjeta de regalo)

### Seguridad y auditoría
21. **Usuario** (credenciales; paciente opcional, personal obligatorio)
22. **Rol**
23. **Log**
24. **Tipo de evento**

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
4. **Origen del turno es tabla maestra** (terminal, web, gestión): es dato
   categorizable y sirve para reportes.
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
| **Origen del turno** | id_origen (PK), nombre |
| **Turno** | id_turno (PK), fecha_hora_inicio, fecha_hora_fin, fecha_creacion, google_event_id *(opc)* |

### Relaciones y cardinalidades (mín,máx)
- Paciente (0,N) **agenda** (1,1) Turno
- Profesional (0,N) **atiende** (1,1) Turno
- Turno (1,N) **incluye** (0,N) Protocolo, con `precio_aplicado`
- Profesional (1,N) **realiza** (0,N) Protocolo
- Protocolo (1,1) **pertenece a** (0,N) Categoría de protocolo
- Turno (1,1) **tiene estado** (0,N) Estado del turno
- Turno (1,1) **se origina en** (0,N) Origen del turno
- Paciente (0,1) **tiene cuenta** (0,1) Usuario
- Profesional (1,1) **tiene cuenta** (0,1) Usuario

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

## Pendiente de definir

- Atributos y cardinalidades de los grupos siguientes: cupones, tarjetas y
  reglas; notificaciones y asistente; usuarios y log.
