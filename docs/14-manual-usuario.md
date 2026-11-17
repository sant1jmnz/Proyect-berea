# Manual de usuario

Cómo usar Dermalia en el día a día. Lo usan la **paciente** (en la terminal táctil del
instituto) y la **recepción** (en la PC, con el programa de Gestión); la **administración**
consulta reportes y auditoría desde Gestión. Para instalar o mantener el sistema, ver el
[manual técnico](13-manual-tecnico.md).

> **Con base y sin base.** Con la base de datos conectada, todo lo que se ve sale de la base.
> Si la base no responde, aparece una franja amarilla y los dos programas siguen andando con
> un archivo local de esta PC (lo comparten Gestión y la terminal). Los turnos que se cargan
> así se mandan solos a la base cuando vuelve la conexión.
>
> Las capturas de este manual se sacaron con la base cargada con los datos de ejemplo.

## 1. Para la paciente (terminal táctil)

### Inicio

![Pantalla de inicio de la terminal](capturas/cliente-00-inicio.png)

Tres opciones: **Sacar un turno**, **Consultar precios** y **Buscar o cancelar mi turno**.
Desde cualquier pantalla, el botón **Inicio** de arriba vuelve acá.

### Sacar un turno (3 pasos)

**1. Elegí tu protocolo.** Tocá el tratamiento: se ve la duración y el precio. *Continuar*.

![Paso 1: elegir el protocolo](capturas/cliente-01-protocolo.png)

**2. Elegí tu horario.** Tocá un día en el calendario y después una hora libre. Solo aparecen
los horarios libres de los profesionales que hacen ese protocolo.

![Paso 2: elegir el día y la hora](capturas/cliente-02-horario.png)

- Los meses que ya pasaron no se pueden elegir, y los años empiezan en 2026.
- Si tocás un día de este mes que ya pasó, el programa te pregunta si querés ese mismo día y
  horario **del año que viene**.
- Los domingos el instituto no atiende.

**3. Confirmá tu turno.** Escribí tu nombre y apellido, tu DNI y tu teléfono. A la derecha se
ve la **seña** (30% del precio; 40% en cirugías). *Pagar seña (simulado)* la marca como paga: no
se pide tarjeta ni se cobra dinero. Tocá *Confirmar turno*.

![Paso 3: datos y seña](capturas/cliente-03-confirmar.png)

- Si es tu primera vez, el programa te pregunta la **fecha de nacimiento** para darte de alta.
- Mientras escribís, el nombre no acepta números y el DNI y el teléfono no aceptan letras.
- Si otra persona tomó ese horario un segundo antes, te avisa y te deja elegir otro.

Al confirmar ves el código de la seña (`SIM-…`) y el programa te lleva a tu turno.

### Consultar precios

![Buscador de precios](capturas/cliente-04-precios.png)

Escribí el nombre de un tratamiento y aparecen el precio y la duración. Si no encuentra nada,
ofrece consultar por WhatsApp con el instituto.

### Buscar o cancelar mi turno

![Buscar mi turno](capturas/cliente-05-mi-turno.png)

Escribí tu **DNI** o tu **teléfono** (sin contraseña) y tocá *Buscar*. Se muestra tu próximo
turno con el recordatorio que vas a recibir; si no tenés turnos por venir, el último que tuviste.

Para cancelar tocá *Cancelar mi turno*. Si tenés más de un turno, primero elegís **cuál**
cancelar de una lista; después confirmás.

| Cancelás... | Qué pasa con la seña |
|---|---|
| Con **más de 24 horas** de anticipación | Se te devuelve el **100%** |
| Con **24 horas o menos**, o si no venís | La seña **queda retenida** |

## 2. Cirugías (rinoplastia, lipoescultura, mamoplastia, blefaroplastia, abdominoplastia, otoplastia, ginecomastia)

1. Primero se hace una **consulta previa** con su seña.
2. El profesional carga el resultado (en Gestión, pantalla *Consultas previas*):
   - **Apta:** la paciente puede agendar la cirugía durante **6 meses**. Al agendarla, la seña de
     la consulta se le devuelve. La seña de la cirugía es del **40%**.
   - **No apta:** se le devuelve la seña de la consulta menos el **10%**.
3. Si pasan los 6 meses sin agendar, la evaluación **vence** y el instituto se queda con la seña
   de la consulta. Si la paciente **reclama** (una sola vez), se le devuelve el 50%.

## 3. Para la recepción (programa de Gestión)

Al abrir el programa pide el **usuario y la contraseña** del personal: cada acción queda en el
registro de auditoría a nombre de quien ingresó. El menú de la izquierda lleva a cada pantalla.

### Inicio

![Inicio de Gestión](capturas/gestion-01-inicio.png)

La agenda del día con el estado de cada turno y accesos rápidos a *Cargar turno* y *Buscar turnos*.

### Cargar turno (cuando la paciente llama o se acerca)

![Cargar turno](capturas/gestion-02-cargar-turno.png)

1. Datos de la paciente (nombre y apellido, DNI, teléfono) y el protocolo.
2. Día y horario libre (con el profesional que atiende).
3. Resumen, seña y *Confirmar turno*. Si es una paciente nueva, el programa pide la fecha de nacimiento.

### Buscar turnos

![Buscar turnos](capturas/gestion-05-buscar-turnos.png)

Por nombre, DNI o teléfono. Al elegir un turno se ve su recordatorio y se puede **cancelar** (misma
regla de las 24 horas).

### Protocolos, Profesionales y Pacientes

![Protocolos](capturas/gestion-06-protocolos.png)

- **Protocolos:** alta, cambio de precio y duración, y baja. Los turnos ya reservados conservan el
  precio con el que se sacaron.

![Profesionales](capturas/gestion-07-profesionales.png)

- **Profesionales:** qué protocolos hace cada uno y sus franjas de atención. Dos franjas no se
  pueden superponer.

![Pacientes](capturas/gestion-08-pacientes.png)

- **Pacientes:** alta, búsqueda y modificación. Desde una paciente se puede ir directo a cargarle un turno.

### Avisos

![Avisos](capturas/gestion-09-avisos.png)

Cada turno programa un recordatorio 24 horas antes. Sin Telegram, la recepción lo manda por
WhatsApp con *Abrir WhatsApp con el mensaje*.

### Cupones

![Cupones](capturas/gestion-10-cupones.png)

1. Escribí el DNI de la paciente y tocá *Buscar cupones*.
2. Elegí un cupón:
   - *Ver token del QR* muestra el token que tiene la paciente en el teléfono (cambia cada 5 minutos).
   - *Validar cupón*: escribís el token que te muestra la paciente y el programa dice si vale y
     cuánto descuenta.
3. *Emitir cupones* revisa las reglas (visitas, gasto acumulado, promociones) y emite los que
   correspondan. Normalmente lo hace el sistema solo.

### Tarjetas de regalo

![Tarjetas de regalo](capturas/gestion-11-tarjetas.png)

- **Vender:** monto (de $20.000 a $5.000.000), quién la compra, teléfono (opcional) y medio de
  pago. El programa da el **código** de la tarjeta: se le entrega a quien compra. Vale 12 meses.
- **Consultar saldo:** escribí el código y se ve el saldo, el vencimiento y cada gasto o devolución.

### Consultas previas de cirugía

![Consultas previas](capturas/gestion-12-consultas-previas.png)

- Elegí una consulta y tocá **Apta** o **No apta** (se pueden agregar observaciones).
- *Registrar reclamo*: para una evaluación vencida que la paciente reclama.
- *Vencer las de más de 6 meses*: la tarea del día (normalmente la corre el sistema solo).
- *Ver solo las que esperan resultado* deja solo las pendientes.

### Sin conexión

Si aparece la franja amarilla **"sin conexión con la base de datos"**, el programa sigue andando:
guarda los turnos en la PC y avisa cuántos esperan. *Reintentar* vuelve a conectar y, al
conectar, los turnos guardados **se envían solos**. Cupones, tarjetas, consultas previas y
reportes necesitan la base: sin conexión quedan deshabilitados.

## 4. Para la administración

![Reportes](capturas/gestion-13-reportes.png)

En la pantalla **Reportes** se elige el reporte, el rango de fechas y *Consultar*:

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

También se pueden correr desde Workbench, por ejemplo:
`CALL pagos.sp_reporte_ingresos_sena('2026-10-01', '2026-10-31');`
Parámetros y columnas de cada uno: [`12-contrato-sp.md`](12-contrato-sp.md).

## 5. Preguntas frecuentes

- **¿Puedo reservar sin cuenta?** Sí, con el DNI. La cuenta es opcional y da cupones, avisos e historial.
- **¿Qué es un cupón?** Un descuento personal de un solo uso. Se gana por visitas, por gasto o en
  promociones. Tiene un código y un QR con un token que **cambia cada 5 minutos**: no sirve una
  captura vieja.
- **¿Y una tarjeta de regalo?** Tiene un monto y un saldo que se gasta en varios turnos, también por
  otra persona. **No se puede usar junto con un cupón** en el mismo turno.
- **¿La seña es real?** No: es una simulación. Nunca se pide ni se guarda información de tarjetas.
