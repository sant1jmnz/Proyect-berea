# Manual de usuario

Cómo usar Dermalia en el día a día. Hay dos personas que lo usan en el
instituto —la **paciente** (en la terminal táctil o en el sitio web) y la
**recepción** (en la PC)— y la **administración**, que consulta reportes y auditoría.
Para instalar o mantener el sistema, ver el [manual técnico](13-manual-tecnico.md).

> **Qué está en pantalla y qué solo en la base.** Gestión, la terminal y el sitio trabajan con la base: turnos,
> seña, cancelación, protocolos, pacientes, profesionales, avisos y reportes. Las reglas de **cupones con QR
> rotativo, tarjetas de regalo y consulta previa de cirugías** están hechas y probadas en la base, pero todavía
> no tienen pantalla propia (ver [`15-guia-por-semana.md`](15-guia-por-semana.md)): mientras tanto se usan
> desde Workbench con los `CALL` de [`12-contrato-sp.md`](12-contrato-sp.md).
>
> Las pantallas de este manual son las del programa. Mientras no estén conectadas a la base
> real, trabajan con datos de ejemplo (turnos de María Sosa, Carla Gómez, Lucía Fernández).

## 1. Para la paciente (terminal táctil)

La terminal es una pantalla vertical en el instituto. Tiene tres opciones en el menú:

### 📅 1. Cargar mi turno (3 pasos)

1. **Elegí el protocolo.** Tocá uno o varios (por ejemplo, peeling y mesoterapia en el mismo turno).
   Se ve el precio, la duración y cuánto es la seña. Las **cirugías** piden antes una *consulta
   previa* (ver "Cirugías" más abajo).
2. **Elegí el horario.** Aparecen solo los horarios libres, de los profesionales que hacen
   **todo** lo que elegiste. Los ocupados salen grises.
3. **Confirmá y pagá la seña.** Revisá el resumen (protocolo, fecha, hora, precio) y el monto
   de la seña. El pago es **simulado**: no te pide datos de tarjeta ni mueve dinero.
   Si tenés un **cupón**, ingresá su código antes de pagar y el precio baja.

Al terminar ves el comprobante con un código de operación y el recordatorio que vas a recibir.

### 🔍 2. Precios y protocolos

Escribí una palabra (por ejemplo "láser") y aparecen los protocolos con precio y duración. Si no
encuentra nada, te lleva al WhatsApp del instituto y queda registrada la consulta.

### 📋 3. Buscar mi turno

Ingresá tu **DNI** o tu teléfono y ves tus turnos. Podés **cancelarlos**:

| Cancelás... | Qué pasa con la seña |
|---|---|
| Con **más de 24 horas** de anticipación | Se te devuelve el **100%** |
| Con **24 horas o menos**, o si no venís | La seña **queda retenida** |

## 2. Cirugías (rinoplastia, lipoescultura, mamoplastia, blefaroplastia, abdominoplastia)

1. Primero reservás la **consulta prequirúrgica** y pagás su seña (30%).
2. El profesional te evalúa y carga el resultado:
   - **Apto:** podés agendar la cirugía durante **6 meses**. Al agendarla, la seña de la consulta
     **se te devuelve**. La seña de la cirugía es del **40%**.
   - **No apto:** se te devuelve la seña de la consulta menos el **10%**.
3. Si pasan los 6 meses sin agendar, el instituto se queda con la seña de la consulta. Si
   **reclamás**, se queda con el 50% y te devuelve el resto.

## 3. Para la recepción (programa de Gestión)

**Al abrir el programa** pide el usuario y la contraseña del personal (cada acción queda registrada a nombre de
quien ingresó). Menú de la izquierda: **Inicio, Cargar turno, Buscador de precios, Buscar turnos**, y las
pantallas de **Protocolos, Profesionales, Pacientes, Avisos y Reportes**.

- **Inicio:** agenda del día con el estado de cada turno (Pagada / Pendiente) y los horarios libres.
- **Cargar turno** (cuando la paciente llama): 1) elegir protocolo (o varios), 2) elegir horario, 3) confirmar
  y marcar la seña como pagada. Si el horario se ocupó mientras tanto, el sistema lo avisa y no
  deja pisarlo.
- **Buscar turnos:** por nombre, DNI o teléfono. Desde ahí se ve el **recordatorio** del turno y se
  puede **cancelar** (con las mismas reglas de 24 horas).
- **Protocolos:** alta, modificación de precio y duración, y baja. Los turnos ya agendados conservan
  el precio con el que se reservaron.
- **Profesionales:** quién hace qué protocolo y los **horarios de atención** (franjas). No se pueden
  superponer dos franjas, ni dar de baja una franja o un profesional con turnos pendientes.
- **Pacientes:** alta y búsqueda. Mismas validaciones que en la terminal: DNI de 7 u 8 dígitos y
  teléfono de 10 a 13 dígitos.
- **Avisos:** recordatorios enviados y pendientes.
- **Reportes:** elegí uno de los 8 reportes (o la auditoría), el rango de fechas y *Consultar*.
- **Primera vez de una paciente:** al cargar su turno el programa le pide el apellido y la fecha de nacimiento.

Si aparece la franja amarilla **"sin conexión con la base de datos"**, el programa sigue
funcionando: guarda los turnos en la PC y avisa cuántos esperan. Tocá *Reintentar* para volver a conectar: al
conectar, los turnos guardados **se envían solos** y el programa avisa cuáles no se pudieron enviar y por qué.

## 4. Para la administración

Se consultan desde la pantalla **Reportes** de Gestión o desde la base (Workbench):

| Pregunta | Reporte (stored procedure) |
|---|---|
| ¿Cuántos turnos tuvo cada profesional por mes y cuánto facturó? | `agenda.sp_reporte_turnos_por_periodo_profesional` |
| ¿Cuánto se cobró, devolvió y retuvo de señas? | `pagos.sp_reporte_ingresos_sena` |
| ¿Cuántos turnos se pierden por cancelación o inasistencia? | `agenda.sp_reporte_cancelaciones_inasistencias` |
| ¿Cómo salieron las evaluaciones de cirugía? | `clinica.sp_reporte_evaluaciones_cirugias` |
| ¿Qué protocolos se piden más? | `clinica.sp_reporte_protocolos_mas_pedidos` |
| ¿Qué tan ocupado está cada profesional? | `agenda.sp_reporte_ocupacion_profesional` |
| ¿Se usan los cupones? | `beneficios.sp_reporte_cupones` |
| ¿Cómo van las tarjetas de regalo? | `pagos.sp_reporte_tarjetas_regalo` |
| ¿Quién hizo qué, cuándo y desde dónde? | `auditoria.sp_reporte_auditoria` (siempre con rango de fechas) |

Ejemplo: `CALL pagos.sp_reporte_ingresos_sena('2026-10-01', '2026-10-31');`
Parámetros y columnas de cada uno: [`12-contrato-sp.md`](12-contrato-sp.md).

## 5. Preguntas frecuentes

- **¿Puedo reservar sin cuenta?** Sí, con el DNI. La cuenta es opcional y da cupones, avisos e historial.
- **¿Qué es un cupón?** Un descuento personal de un solo uso. Se gana por visitas o por gasto, o en
  promociones. Tiene un código y un QR que **cambian cada 5 minutos**: no sirve una captura vieja.
- **¿Y una tarjeta de regalo?** Tiene un monto y un saldo que se gasta en varios turnos, también por
  otra persona. **No se puede usar junto con un cupón** en el mismo turno.
- **¿La seña es real?** No: es una simulación. Nunca se pide ni se guarda información de tarjetas.
