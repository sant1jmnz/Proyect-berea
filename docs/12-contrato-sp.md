# Contrato de los stored procedures

Catálogo de todo lo que la base ofrece a las aplicaciones (Gestión, Cliente, sitio
web y n8n). **Las aplicaciones no tocan las tablas: llaman a estos SP.** Este
documento sale de los comentarios de los archivos `backend/03` a `06`; si un SP
cambia, se cambia primero el comentario del `.sql` y se regenera esta tabla.

## Cómo se llama un SP y qué devuelve

```sql
CALL agenda.sp_alta_turno(1, 4, '2026-12-14 09:00:00', '1', 'gestion', 2, NULL, NULL);
```

**Los SP que escriben** (altas, modificaciones, pagos, cancelaciones...) siempre
devuelven **una fila con 6 columnas**:

| Columna | Qué es |
|---|---|
| `estado` | `OK` o `ERROR` |
| `codigo` | `0` si salió bien; si no, el código de error de la tabla de abajo |
| `mensaje` | Texto en español listo para mostrar a la persona |
| `id` | Lo que se creó o modificó (turno, pago, paciente...) |
| `valor` | Un monto (la seña a pagar, lo reembolsado...) |
| `dato` | Un texto (código de operación `SIM-...`, rol, token, código de tarjeta...) |

Si las reglas del negocio lo impiden, **no hay excepción**: vuelve la fila
`ERROR` con su código y la operación se deshace sola (`EXIT HANDLER`, como en el
PPT 006 de la cátedra). Además, el intento fallido queda en el log.
Los SP internos (`pagos.sp_aplicar_reembolso`, `auditoria.sp_registrar_log`) no
devuelven filas: los usan otros SP.

**Los SP de consulta** (listados, búsquedas, reportes) devuelven directamente
las filas de la consulta. Con parámetros `NULL`, vacíos o sin coincidencias
devuelven 0 filas y no dan error.

**Convenciones comunes de los parámetros**

- `p_origen`: desde dónde se hace la acción: `'terminal'`, `'web'`, `'gestion'` o `'sistema'`.
- `p_id_usuario`: quién lo hace (`NULL` para una paciente sin cuenta o el sistema). Va al log.
- Una lista de protocolos se pasa como texto separado por comas: `'3,7'`.
- Las contraseñas llegan **ya hasheadas** (SHA-256 en hexadecimal), nunca en claro.
- Fechas `'AAAA-MM-DD'`; fecha y hora `'AAAA-MM-DD HH:MM:SS'`.
- Reloj de pruebas: `SET @ahora_simulado = '2026-11-03 09:00:00';` hace que los SP usen esa hora (sin esto usan `NOW()`).

## Los SP, por semana del plan



### Semana 3 (`backend/03_sp_semana3.sql`): login, ABM, horarios libres, alta de turno

| SP / función | Parámetros | Qué hace |
|---|---|---|
| `agenda.fn_descuento` (función) | `p_id_turno INT` | Descuento del cupón aplicado al turno (0 si no tiene). |
| `agenda.fn_precio_final` (función) | `p_id_turno INT` | Precio final del turno: el precio de lista menos el descuento del cupón. |
| `agenda.fn_precio_total` (función) | `p_id_turno INT` | Precio de un turno: suma de lo que costaba cada protocolo al agendar. |
| `agenda.fn_sena` (función) | `p_id_turno INT` | Seña: el porcentaje más alto de las categorías de los protocolos del turno (30% en general, 40% en cirugías) sobre el precio final, redondeada al peso. |
| `agenda.sp_alta_turno` (SP) | `p_id_paciente INT, p_id_profesional INT, p_inicio DATETIME, p_protocolos_csv VARCHAR(200), p_origen VARCHAR(50), p_id_usuario INT, p_codigo_cupon VARCHAR(50), p_id_cirugia_consulta INT` | Agenda un turno (queda 'pendiente' hasta que se registre la seña). p_protocolos_csv     ids separados por coma, por ejemplo '3,7' p_origen             'terminal', 'web', 'gestion' o 'sistema' p_codigo_cupon       cupón de la paciente (opcional) p_id_cirugia_consulta si no es NULL, el turno es la CONSULTA PREVIA para esa cirugía Devuelve: id = turno, valor = seña a pagar, dato = precio final. Reglas: sin superposición del profesional ni de la paciente (RF-04), dentro de su disponibilidad, solo protocolos que el profesional hace (RF-18), una cirugía solo con una evaluación apta de menos de 6 meses (RF-25), cupón de la paciente, vigente y sin usar (RF-17). Si es una cirugía, la seña de la consulta previa se devuelve. |
| `agenda.sp_buscar_turnos` (SP) | `p_texto VARCHAR(100), p_solo_vigentes TINYINT` | Busca turnos por DNI, teléfono, nombre o apellido (RF-12, RF-13, RF-16). p_solo_vigentes = 1 muestra solo los pendientes o confirmados futuros. |
| `agenda.sp_horarios_libres` (SP) | `p_fecha DATE, p_protocolos_csv VARCHAR(200), p_id_profesional INT` | Horarios realmente disponibles de un día (cada 30 minutos) para uno o varios protocolos (p_protocolos_csv = '3,7'). Muestra solo profesionales activos que hacen todos los protocolos, dentro de su disponibilidad, sin pisar otros turnos y en el futuro. p_id_profesional NULL = todos. |
| `auditoria.fn_ahora` (función) | `—` | Reloj del sistema. Si la sesión define @ahora_simulado, los SP usan esa hora (sirve para cargar historia y para probar vencimientos sin esperar meses). |
| `auditoria.sp_registrar_log` (SP) | `p_tipo VARCHAR(50), p_id_usuario INT, p_id_paciente INT, p_origen VARCHAR(50), p_descripcion VARCHAR(2000), p_tabla VARCHAR(100), p_id_registro INT, p_anterior LONGTEXT, p_nuevo LONGTEXT, p_exitoso TINYINT, p_ip VARCHAR(45)` | Escribe una fila en el log. Nunca falla: si el tipo de evento no existe no escribe nada, y un usuario o paciente inexistente queda como NULL. |
| `clinica.sp_alta_protocolo` (SP) | `p_id_categoria INT, p_nombre VARCHAR(100), p_descripcion VARCHAR(500), p_precio DECIMAL(12,2), p_duracion_min INT, p_origen VARCHAR(50), p_id_usuario INT` | Alta de un protocolo en el catálogo (RNF-08: la recepción actualiza precios y protocolos sin ayuda técnica). Valida categoría, nombre único, precio mayor a cero y duración entre 1 y 600 minutos. Devuelve: id = protocolo nuevo, valor = su precio. |
| `clinica.sp_asignar_protocolo` (SP) | `p_id_profesional INT, p_id_protocolo INT, p_habilitar TINYINT, p_origen VARCHAR(50), p_id_usuario INT` | Habilita (o quita) un protocolo a un profesional (RF-18). |
| `clinica.sp_listar_protocolos` (SP) | `p_texto VARCHAR(100), p_id_categoria INT` | Catálogo y buscador por palabra clave (RF-05/06). Con texto vacío o NULL devuelve todo el catálogo activo; con p_id_categoria NULL, todas las categorías. |
| `clinica.sp_modificar_protocolo` (SP) | `p_id_protocolo INT, p_nombre VARCHAR(100), p_descripcion VARCHAR(500), p_precio DECIMAL(12,2), p_duracion_min INT, p_activo TINYINT, p_origen VARCHAR(50), p_id_usuario INT` | Cambia precio, duración, descripción o lo da de baja (p_activo = 0). Los turnos ya agendados conservan el precio de cuando se reservaron. |
| `pagos.sp_aplicar_reembolso` (SP) | `p_id_pago INT, p_monto_reembolsado DECIMAL(12,2), p_estado VARCHAR(50), p_motivo VARCHAR(200), p_id_usuario INT, p_origen VARCHAR(50)` | Cambia el estado de un pago de seña y, si se pagó con tarjeta de regalo, devuelve el saldo (movimiento negativo). Lo usan la cancelación, las inasistencias y las evaluaciones. No devuelve filas: es interno. p_estado: 'reembolsada', 'reembolsada parcial' o 'retenida'. |
| `personas.sp_alta_paciente` (SP) | `p_dni VARCHAR(15), p_nombre VARCHAR(50), p_apellido VARCHAR(50), p_fecha_nacimiento DATE, p_email VARCHAR(100), p_telefono VARCHAR(30), p_origen VARCHAR(50), p_id_usuario INT` | Alta de paciente. Mismas validaciones que el frontend (frontend/comun/validaciones): DNI de 7 u 8 dígitos, teléfono de 10 a 13 dígitos, nombre y apellido de 2 a 60 letras. |
| `personas.sp_alta_profesional` (SP) | `p_matricula VARCHAR(30), p_nombre VARCHAR(50), p_apellido VARCHAR(50), p_email VARCHAR(100), p_telefono VARCHAR(30), p_nombre_usuario VARCHAR(50), p_password_hash VARCHAR(255), p_origen VARCHAR(50), p_id_usuario INT` | Alta de profesional: crea su cuenta propia (rol profesional), que es obligatoria. |
| `personas.sp_baja_disponibilidad` (SP) | `p_id_disponibilidad INT, p_origen VARCHAR(50), p_id_usuario INT` | Baja (lógica) de una franja. No se puede si hay turnos activos dentro de ella. |
| `personas.sp_buscar_paciente` (SP) | `p_texto VARCHAR(100)` | Búsqueda por nombre, apellido, DNI o teléfono (RF-13). Con texto vacío o de menos de 3 caracteres no devuelve nada. |
| `personas.sp_cargar_disponibilidad` (SP) | `p_id_profesional INT, p_fecha DATE, p_hora_inicio TIME, p_hora_fin TIME, p_origen VARCHAR(50), p_id_usuario INT` | Carga una franja de disponibilidad. No puede superponerse con otra franja activa del mismo profesional ese día. |
| `personas.sp_modificar_paciente` (SP) | `p_id_paciente INT, p_nombre VARCHAR(50), p_apellido VARCHAR(50), p_email VARCHAR(100), p_telefono_nuevo VARCHAR(30), p_origen VARCHAR(50), p_id_usuario INT` | Modifica nombre, apellido, email y, si viene, agrega un teléfono nuevo. |
| `personas.sp_modificar_profesional` (SP) | `p_id_profesional INT, p_nombre VARCHAR(50), p_apellido VARCHAR(50), p_email VARCHAR(100), p_activo TINYINT, p_origen VARCHAR(50), p_id_usuario INT` | Modifica los datos del profesional o lo da de baja (p_activo = 0). No se puede dar de baja a quien tiene turnos futuros sin cancelar. |
| `personas.sp_profesionales_para_protocolos` (SP) | `p_protocolos_csv VARCHAR(200)` | Profesionales activos habilitados para TODOS los protocolos pedidos (RF-18). p_protocolos_csv: ids separados por coma, por ejemplo '3,7'. |
| `seguridad.sp_cerrar_sesion` (SP) | `p_id_usuario INT, p_origen VARCHAR(50), p_ip VARCHAR(45)` | Cierre de sesión: solo deja el evento 'cierre_sesion' en el log (la app es quien cierra la ventana). Devuelve error si el usuario no existe. |
| `seguridad.sp_crear_cuenta_paciente` (SP) | `p_dni VARCHAR(15), p_nombre_usuario VARCHAR(50), p_email VARCHAR(100), p_password_hash VARCHAR(255), p_origen VARCHAR(50)` | Cuenta opcional de una paciente (RF-15): se vincula con su DNI. |
| `seguridad.sp_login` (SP) | `p_usuario VARCHAR(50), p_password_hash VARCHAR(255), p_ip VARCHAR(45), p_origen VARCHAR(50)` | Ingreso al sistema. La contraseña llega ya hasheada (SHA-256 en hexadecimal). Tras 5 intentos fallidos en 15 minutos la cuenta se bloquea temporalmente; los intentos se cuentan desde el log (modelo, grupo 4, decisión 6). |

### Semana 4 (`backend/04_sp_semana4.sql`): seña, cancelación, cirugías, cupones, tarjetas, avisos, asistente

| SP / función | Parámetros | Qué hace |
|---|---|---|
| `agenda.sp_cancelar_turno` (SP) | `p_id_turno INT, p_id_usuario INT, p_origen VARCHAR(50)` | Cancela un turno pendiente o confirmado. Con más de 24 horas de anticipación la seña se reembolsa al 100%; con menos, queda retenida (RF-10). Si el turno tenía un cupón y se reembolsa, el cupón vuelve a quedar disponible. Devuelve: valor = monto reembolsado, dato = qué pasó con la seña. |
| `agenda.sp_marcar_turno` (SP) | `p_id_turno INT, p_estado VARCHAR(20), p_id_usuario INT, p_origen VARCHAR(50)` | Marca un turno confirmado como 'realizado' o 'ausente' una vez que empezó. La inasistencia retiene la seña. |
| `asistente.fn_filtrar_datos_personales` (función) | `p_texto LONGTEXT` | Saca emails y números largos (teléfonos, DNI, tarjetas) antes de guardar o de mandar el texto a la IA: al asistente no se le envían datos personales. |
| `asistente.sp_registrar_consulta` (SP) | `p_id_paciente INT, p_origen VARCHAR(50), p_pregunta LONGTEXT, p_respuesta LONGTEXT, p_derivada TINYINT, p_id_usuario INT` | Registra una pregunta al asistente y su respuesta. p_derivada = 1 cuando no supo responder y se derivó al WhatsApp del instituto. |
| `beneficios.fn_token_cupon` (función) | `p_secreto VARCHAR(255), p_tramo BIGINT` | Token rotativo del cupón: se renueva cada 5 minutos y no se guarda; sale de un hash (SHA-256) del secreto del cupón y del tramo de 5 minutos actual (RNF-14; no es un HMAC formal, se aclara en la defensa). |
| `beneficios.sp_aplicar_cupon_a_turno` (SP) | `p_id_turno INT, p_codigo VARCHAR(50), p_token VARCHAR(20), p_id_usuario INT, p_origen VARCHAR(50)` | Aplica un cupón a un turno pendiente escaneando su QR antes del pago (RF-22). |
| `beneficios.sp_emitir_cupones` (SP) | `p_origen VARCHAR(50)` | Emite los cupones que corresponden según las reglas activas, solo a pacientes con cuenta (RF-24). Lo corre el sistema periódicamente. Devuelve la cantidad emitida. frecuencia: visitas 'realizadas' dentro de la ventana >= umbral (y sin otro cupón de esa regla en la ventana) gasto acumulado: cada vez que el gasto total supera otro múltiplo del umbral promoción general: una sola vez por paciente |
| `beneficios.sp_generar_token_cupon` (SP) | `p_codigo VARCHAR(50), p_id_paciente INT` | Pide el token vigente de un cupón (lo muestra la app o el QR de la paciente). Devuelve: dato = token, valor = segundos que le quedan. |
| `beneficios.sp_validar_cupon` (SP) | `p_codigo VARCHAR(50), p_token VARCHAR(20), p_id_paciente INT, p_id_usuario INT, p_origen VARCHAR(50)` | Valida un cupón con su token (RF-22). Acepta el tramo actual y el anterior (margen por diferencia de relojes). Cada validación, aceptada o rechazada, queda en el log. Devuelve: id = cupón, valor = % de descuento. |
| `clinica.sp_reclamar_evaluacion` (SP) | `p_id_evaluacion INT, p_id_usuario INT, p_origen VARCHAR(50)` | La paciente reclama una evaluación vencida: el instituto retiene el 50% de la consulta y devuelve el resto. Solo se puede reclamar una vez. |
| `clinica.sp_resolver_evaluacion` (SP) | `p_id_evaluacion INT, p_resultado VARCHAR(50), p_observaciones VARCHAR(500), p_id_usuario INT, p_origen VARCHAR(50)` | El profesional carga el resultado de la consulta prequirúrgica. Si no es apta, el instituto retiene el 10% de la seña y devuelve el resto. Si es apta, la seña se devuelve cuando la paciente agenda la cirugía. |
| `clinica.sp_vencer_evaluaciones` (SP) | `p_origen VARCHAR(50)` | Evaluaciones aptas que vencieron (6 meses) sin que la paciente agende la cirugía: el instituto se queda con el dinero de la consulta. Es una tarea diaria del sistema (n8n). Devuelve: valor = cantidad de evaluaciones vencidas. |
| `notificaciones.sp_marcar_notificacion` (SP) | `p_id_notificacion INT, p_resultado VARCHAR(20), p_detalle VARCHAR(500)` | n8n informa cómo salió el envío. Un fallo se reintenta hasta 3 veces; recién al tercero queda 'fallida'. |
| `notificaciones.sp_notificaciones_pendientes` (SP) | `p_limite INT` | Avisos pendientes cuya hora ya llegó, con los datos del destinatario. |
| `pagos.fn_saldo_tarjeta` (función) | `p_id_tarjeta INT` | El saldo no se guarda: es el monto inicial menos la suma de los movimientos. |
| `pagos.sp_comprar_tarjeta` (SP) | `p_monto DECIMAL(12,2), p_medio_pago VARCHAR(50), p_comprador_nombre VARCHAR(100), p_comprador_telefono VARCHAR(30), p_id_usuario INT, p_origen VARCHAR(50)` | Vende una tarjeta de regalo (código largo y aleatorio, vigencia de 12 meses). Devuelve: id = tarjeta, valor = monto, dato = código de la tarjeta. |
| `pagos.sp_movimientos_tarjeta` (SP) | `p_codigo VARCHAR(50)` | Historial de una tarjeta de regalo: cada gasto (monto positivo) y cada devolución (negativo), con el turno y la paciente. Código inexistente, NULL o vacío: 0 filas. |
| `pagos.sp_registrar_sena` (SP) | `p_id_turno INT, p_medio_pago VARCHAR(50), p_codigo_tarjeta VARCHAR(50), p_id_usuario INT, p_origen VARCHAR(50)` | Registra la seña (pago simulado, sin pasarela) y confirma el turno. Devuelve: id = pago, valor = monto de la seña, dato = código de operación 'SIM-...'. Si se paga con tarjeta de regalo hay que pasar su código; el turno no puede tener cupón (un cupón y una tarjeta no van juntos). |
| `pagos.sp_saldo_tarjeta` (SP) | `p_codigo VARCHAR(50), p_id_usuario INT, p_origen VARCHAR(50)` | Saldo y vigencia de una tarjeta. Un código inexistente queda en el log (intentos fallidos, modelo grupo 3 decisión 9) y no devuelve filas. |

### Semana 5 (`backend/05_reportes_semana5.sql`): 8 reportes y auditoría

| SP / función | Parámetros | Qué hace |
|---|---|---|
| `agenda.sp_reporte_cancelaciones_inasistencias` (SP) | `p_desde DATE, p_hasta DATE, p_agrupar VARCHAR(10)` | Reporte 3: cancelaciones e inasistencias (los "turnos perdidos" de la MML). p_agrupar: 'mes' (por defecto) o 'semana'. Muestra por origen cuántos turnos se perdieron, la tasa de pérdida y la plata de señas retenida. |
| `agenda.sp_reporte_ocupacion_profesional` (SP) | `p_desde DATE, p_hasta DATE` | Reporte 6: ocupación por profesional = horas con turno / horas de disponibilidad. |
| `agenda.sp_reporte_turnos_por_periodo_profesional` (SP) | `p_desde DATE, p_hasta DATE, p_id_profesional INT` | Reporte 1: turnos por período (mes) y profesional. Cuántos turnos hubo, cómo terminaron, cuántas horas se agendaron y cuánto se facturó (a precio de lista) en los realizados. p_id_profesional NULL = todos. |
| `auditoria.sp_reporte_auditoria` (SP) | `p_desde DATE, p_hasta DATE, p_tipo_evento VARCHAR(50), p_id_usuario INT, p_id_paciente INT, p_exitoso TINYINT, p_origen VARCHAR(50)` | Reporte de auditoría (consigna 5d): quién hizo qué, cuándo y desde dónde. El rango de fechas es obligatorio (p_hasta incluye todo ese día). Los demás filtros son opcionales (NULL = sin filtrar): p_tipo_evento  nombre del tipo ('inicio_sesion', 'alta_turno', ...) p_id_usuario   quién hizo la acción p_id_paciente  paciente involucrada p_exitoso      1 = solo lo que salió bien, 0 = solo los fallos p_origen       'terminal', 'web', 'gestion' o 'sistema' |
| `beneficios.sp_reporte_cupones` (SP) | `p_desde DATE, p_hasta DATE` | Reporte 7: uso de cupones y reglas de beneficio, por regla. Cupones emitidos en el rango: cuántos se usaron, cuántos vencieron sin usar, cuántos siguen vigentes, tasa de uso y descuento total otorgado. |
| `clinica.sp_reporte_evaluaciones_cirugias` (SP) | `p_desde DATE, p_hasta DATE` | Reporte 4: evaluaciones previas y cirugías por resultado. Por cirugía y resultado: cuántas evaluaciones, cuántas terminaron en una cirugía agendada, cuántas vencieron sin agendar, en cuántos días se decidieron y cuánta plata de consultas retuvo el instituto. Se cuentan las consultas realizadas dentro del rango. |
| `clinica.sp_reporte_protocolos_mas_pedidos` (SP) | `p_desde DATE, p_hasta DATE, p_limite INT` | Reporte 5: protocolos más pedidos en un período (sin contar turnos cancelados). Ranking con RANK() y porcentaje sobre el total. p_limite NULL = 10. |
| `pagos.sp_reporte_ingresos_sena` (SP) | `p_desde DATE, p_hasta DATE` | Reporte 2: ingresos por seña, reembolsos y retenciones, por mes y medio de pago. Lo retenido es lo que el instituto se queda de las señas ya resueltas. |
| `pagos.sp_reporte_tarjetas_regalo` (SP) | `p_desde DATE, p_hasta DATE` | Reporte 8: saldo y uso de las tarjetas de regalo compradas en el rango. El código se muestra recortado: el código completo funciona como un billete. |

### Semana 6 (`backend/06_tuning_semana6.sql`): versiones `_tuneado`

| SP / función | Parámetros | Qué hace |
|---|---|---|
| `agenda.sp_reporte_turnos_por_periodo_profesional_tuneado` (SP) | `p_desde DATE, p_hasta DATE, p_id_profesional INT` | Reporte 1 tuneado. Devuelve exactamente lo mismo que el original. |
| `auditoria.sp_crear_indice_si_falta` (SP) | `p_schema VARCHAR(64), p_tabla VARCHAR(64), p_indice VARCHAR(64), p_columnas VARCHAR(300)` | Crea un índice solo si no existe (MySQL no tiene CREATE INDEX IF NOT EXISTS). Auxiliar del tuning: crea un índice solo si todavía no existe (MySQL no tiene CREATE INDEX IF NOT EXISTS). Se borra apenas termina de usarse. |
| `pagos.sp_reporte_ingresos_sena_tuneado` (SP) | `p_desde DATE, p_hasta DATE` | Reporte 2 tuneado. Devuelve exactamente lo mismo que el original. |

## Códigos de error

Son los números que devuelve la columna `codigo` cuando `estado = 'ERROR'`. Los 52xxx son reglas del negocio; el resto (por ejemplo `2002`, `1045`) son errores de MySQL que la app traduce en `BaseDatos::mensajeDeError`.

| Código | Mensaje |
|---|---|
| 52010 | Falta el usuario o la contraseña |
| 52011 | Usuario o contraseña incorrectos |
| 52012 | Cuenta bloqueada 15 minutos por demasiados intentos |
| 52013 | El usuario no existe |
| 52020 | No hay una paciente con ese DNI |
| 52021 | Esa paciente ya tiene cuenta |
| 52022 | El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo |
| 52023 | El email no es válido |
| 52024 | La contraseña debe llegar como hash SHA-256 |
| 52025 | Ese usuario o email ya está en uso |
| 52030 | El DNI debe tener 7 u 8 dígitos |
| 52031 | Nombre y apellido deben tener al menos 2 letras |
| 52032 | El teléfono debe tener de 10 a 13 dígitos |
| 52033 | La fecha de nacimiento no es válida |
| 52034 | El email no es válido |
| 52035 | Ya existe una paciente con ese DNI |
| 52036 | La paciente no existe |
| 52040 | Falta la matrícula |
| 52041 | Ya existe un profesional con esa matrícula |
| 52042 | El profesional no existe |
| 52043 | El estado activo debe ser 0 o 1 |
| 52044 | No se puede dar de baja: tiene turnos futuros sin cancelar |
| 52045 | El profesional no existe o está dado de baja |
| 52046 | Faltan la fecha o las horas |
| 52047 | La hora de fin debe ser posterior a la de inicio |
| 52048 | No se puede cargar disponibilidad en el pasado |
| 52049 | La franja se superpone con otra ya cargada |
| 52050 | La franja no existe |
| 52051 | La franja ya estaba dada de baja |
| 52052 | Hay turnos sin cancelar dentro de esa franja |
| 52060 | El protocolo no existe |
| 52061 | La categoría no existe |
| 52062 | El nombre debe tener al menos 3 caracteres |
| 52063 | El precio debe ser mayor a cero |
| 52064 | La duración debe estar entre 1 y 600 minutos |
| 52065 | Ya existe un protocolo con ese nombre |
| 52070 | Origen inválido (terminal, web, gestion o sistema) |
| 52071 | La paciente no existe |
| 52072 | El turno necesita al menos un protocolo |
| 52073 | El turno debe ser en el futuro |
| 52074 | El profesional no existe o está dado de baja |
| 52075 | Algún protocolo no existe o está dado de baja |
| 52076 | El profesional no realiza alguno de los protocolos pedidos |
| 52077 | Una cirugía se agenda sola, sin otros protocolos |
| 52078 | La consulta previa no puede incluir una cirugía |
| 52079 | La consulta previa debe ser para una cirugía existente |
| 52080 | El horario está fuera de la disponibilidad del profesional |
| 52081 | El profesional ya tiene un turno en ese horario |
| 52082 | La paciente ya tiene un turno en ese horario |
| 52083 | La cirugía necesita una consulta previa con resultado apto de menos de 6 meses |
| 52084 | El cupón no existe |
| 52085 | El cupón es de otra paciente |
| 52086 | El cupón ya fue usado |
| 52087 | El cupón está vencido |
| 52100 | El pago de seña no existe |
| 52101 | La seña ya fue resuelta (reembolsada o retenida) |
| 52102 | El monto a reembolsar no es válido |
| 52103 | Estado de pago inválido |
| 52110 | El turno no existe |
| 52111 | Solo se paga la seña de un turno pendiente |
| 52112 | El turno ya empezó o pasó |
| 52113 | El turno ya tiene un pago de seña |
| 52114 | Medio de pago inválido |
| 52115 | El turno no tiene una seña para cobrar |
| 52116 | Un cupón y una tarjeta de regalo no se pueden usar en el mismo turno |
| 52117 | La tarjeta de regalo no existe, está vencida o no tiene saldo suficiente |
| 52120 | El turno no existe |
| 52121 | Solo se cancela un turno pendiente o confirmado |
| 52122 | El turno ya empezó o pasó |
| 52125 | El estado debe ser realizado o ausente |
| 52126 | Solo se marca un turno confirmado |
| 52127 | El turno todavía no empezó |
| 52130 | La evaluación no existe |
| 52131 | La evaluación ya tiene resultado |
| 52132 | El resultado debe ser apto o no apto |
| 52133 | La consulta todavía no se realizó |
| 52134 | Solo se reclama una evaluación apta |
| 52135 | La evaluación ya fue reclamada |
| 52136 | La evaluación sigue vigente: todavía puede agendar la cirugía |
| 52137 | La evaluación ya se usó para una cirugía |
| 52140 | El cupón no existe |
| 52141 | El cupón es de otra paciente |
| 52142 | El cupón ya fue usado |
| 52143 | El cupón está vencido |
| 52144 | El token es inválido o ya venció |
| 52145 | El cupón se aplica antes de pagar la seña (turno pendiente) |
| 52146 | El turno ya tiene un cupón |
| 52150 | El monto de la tarjeta debe estar entre $20.000 y $5.000.000 |
| 52151 | Medio de pago inválido (una tarjeta de regalo no se paga con otra) |
| 52152 | Falta el nombre de quien compra |
| 52160 | La notificación no existe |
| 52161 | La notificación ya no está pendiente |
| 52162 | El resultado debe ser enviada o fallida |
| 52170 | La pregunta está vacía |
