# Modelo de entidades (borrador)

Primer paso del diseño conceptual de la base (consigna en
[`consigna-bbdd.md`](consigna-bbdd.md)). Acá solo se define **qué entidades hay**;
los atributos, las cardinalidades y el diagrama de Chen se hacen después.

Mínimo pedido: 13 entidades (las relaciones no cuentan). Este borrador tiene 19.

## Decisiones tomadas

- La paciente **no necesita cuenta**: se identifica por DNI. La cuenta es
  **opcional** y da descuentos, notificaciones e historial ya cargado.
- El personal tiene **cuenta propia obligatoria**, para auditar errores.
- Un turno puede tener **varios protocolos**.
- Cada protocolo se registra **por profesional** (qué protocolos hace cada uno).
- Los **descuentos** son una entidad.
- La seña es un **mock** que imita un pago real.
- Los recordatorios salen por **WhatsApp** (forma de envío por definir) y por
  **Google Calendar**.
- Hay un **asistente de IA**; sus consultas se registran.
- Obra social: **no entra**.
- **Tipo de evento** queda como tabla aparte (tabla maestra del log).

## Entidades

### Núcleo
1. **Paciente** (cuenta opcional)
2. **Profesional**
3. **Protocolo**
4. **Turno**: tabla principal del sistema (50+ registros)
5. **Turno_Protocolo** (un turno, varios protocolos)
6. **Profesional_Protocolo** (qué protocolos realiza cada profesional)
7. **Disponibilidad** (franjas horarias del profesional)
8. **Pago de seña**
9. **Descuento**
10. **Notificación** (recordatorios y avisos)
11. **Consulta al asistente** (preguntas a la IA y derivaciones)

### Tablas maestras
12. **Estado del turno**
13. **Estado del pago**
14. **Categoría de protocolo**
15. **Canal de notificación** (WhatsApp, Google Calendar)

### Seguridad y auditoría
16. **Usuario** (credenciales; paciente opcional, personal obligatorio)
17. **Rol**
18. **Log**
19. **Tipo de evento**

*Especialidad* quedó afuera: la relación profesional-protocolo la reemplaza.

## Pendiente de definir

- Cómo se envía WhatsApp de verdad (API oficial, proveedor intermedio o
  simulación).
- Condiciones de los descuentos (porcentaje, vigencia, a quién aplican).
- Atributos de cada entidad y cardinalidades (el diagrama lo arma el equipo).
