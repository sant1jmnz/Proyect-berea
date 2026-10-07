# Modelo de entidades (borrador)

Primer paso del diseño conceptual de la base (consigna en
[`consigna-bbdd.md`](consigna-bbdd.md)). Acá solo se define **qué entidades hay**;
los atributos, las cardinalidades y el diagrama de Chen se hacen después.

Mínimo pedido: 13 entidades (las relaciones no cuentan). Este borrador tiene 24.

## Decisiones tomadas

- La paciente **no necesita cuenta**: se identifica por DNI. La cuenta es
  **opcional** y da cupones, notificaciones e historial ya cargado.
- El personal tiene **cuenta propia obligatoria**, para auditar errores.
- Un turno puede tener **varios protocolos**.
- Cada protocolo se registra **por profesional** (qué protocolos hace cada uno).
- La seña es un **mock** que imita un pago real.
- Los recordatorios salen por **WhatsApp** (forma de envío por definir) y por
  **Google Calendar**.
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

## Reglas cerradas

- Un **cupón no se puede usar junto con una tarjeta de regalo** en el mismo
  turno.
- Los **estados** (de cupón, tarjeta, vigencia) **se calculan**, no se
  guardan: vigente/vencido sale de la fecha; usado, de que exista un uso;
  el saldo de la tarjeta, de la suma de sus movimientos.
- El **QR** se escanea con el celular del profesional, un escáner o un
  lector en la PC de gestión (las tres opciones valen).

## Entidades

### Núcleo
1. **Paciente** (cuenta opcional)
2. **Profesional**
3. **Protocolo** (tratamientos y cirugías)
4. **Turno**: tabla principal del sistema (50+ registros)
5. **Turno_Protocolo** (un turno, varios protocolos)
6. **Profesional_Protocolo** (qué protocolos realiza cada profesional)
7. **Disponibilidad** (franjas horarias del profesional)
8. **Pago de seña**
9. **Notificación** (recordatorios y avisos)
10. **Consulta al asistente** (preguntas a la IA y derivaciones)
11. **Evaluación previa** (consulta prequirúrgica: paciente, cirugía,
    turno de la consulta, profesional, fecha, resultado y observaciones)

### Cupones y tarjetas
12. **Cupón** (código, QR, % de descuento, vigencia, paciente destinatario,
    uso en un turno)
13. **Regla de beneficio** (frecuencia o gasto acumulado, umbral, % y
    vigencia de 2 a 8 semanas)
14. **Tarjeta de regalo** (código, monto inicial, saldo, vigencia, quién la
    compró)
15. **Movimiento de tarjeta** (cada gasto del saldo, ligado a un turno o
    compra)

### Tablas maestras
16. **Estado del turno**
17. **Estado del pago**
18. **Categoría de protocolo** (faciales, aparatología, medicina estética,
    cirugías)
19. **Canal de notificación** (WhatsApp, Google Calendar)
20. **Resultado de evaluación** (apto, no apto)

### Seguridad y auditoría
21. **Usuario** (credenciales; paciente opcional, personal obligatorio)
22. **Rol**
23. **Log**
24. **Tipo de evento**

*Especialidad* quedó afuera: la relación profesional-protocolo la reemplaza.

## Pendiente de definir

- Cómo se envía WhatsApp de verdad (API oficial, proveedor intermedio o
  simulación): se discute cuando terminemos de definir lo demás.
- Qué pasa con el dinero de la consulta si pasan los 6 meses sin agendar la
  cirugía.
- Atributos de cada entidad y cardinalidades (el diagrama lo arma el equipo).
