# Documentación de pruebas de la base de datos (consigna punto 6)

Pruebas funcionales de los **stored procedures** de Dermalia, con el formato que
pide la consigna (`docs/consigna-bbdd.md`, punto 6b) y la plantilla de la cátedra
(`docs/catedra/semana-3-casos-de-prueba-funcional.md`).

**Resultado: 222 casos, 222 aprobados, 0 con fallas** (MySQL 8.0.46, base
recién cargada con `backend/01` a `06`).

## Cómo se corren

El script es `backend/05_pruebas_sp.sql`. Dos formas:

1. **A mano (Workbench / DBeaver / consola):** cargar la base (`codigobasededatossolotablas.sql`,
   `02` a `06`) y ejecutar `05_pruebas_sp.sql`. Cada caso empieza con un comentario
   `-- @caso ...` y las líneas `-- @espera ...` dicen qué tiene que pasar; se compara con lo
   que muestra el cliente.
2. **Automática:** `pip install pymysql` y
   ```bash
   python3 backend/pruebas/correr_pruebas.py --recargar
   ```
   El corredor lee las anotaciones, ejecuta todo y verifica solo (`--markdown salida.md` genera la
   tabla de abajo). Variables: `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`.

> El script **modifica datos** (agenda turnos, paga señas, vende tarjetas). Para repetirlo hay
> que volver a cargar la base; el corredor lo hace con `--recargar`. Un **reloj simulado**
> (`@ahora_simulado`) permite probar el plazo de 24 horas y el vencimiento de 6 meses sin esperar.

## Los cuatro casos de cada SP

La consigna define cuatro casos pensados para SP que consultan. Para los que **escriben** se
adaptaron conservando la idea:

| # | Consigna (consulta) | Adaptación para SP que escriben |
|---|---|---|
| 1 | Éxito: parámetros válidos, conjunto exacto | Éxito: la operación se hace y los datos quedan bien |
| 2 | Sin coincidencias: valores que no existen, sin errores de ejecución | Rechazo: valores inexistentes o que las reglas no permiten; devuelve el error previsto y no rompe nada |
| 3 | Nulos y límites: `NULL` o vacío, sin datos erróneos | Igual: `NULL`, vacíos y bordes (por ejemplo, exactamente 24 horas) |
| 4 | Equivalencia con un `SELECT` directo, idéntico en filas y valores | Igual para consultas y reportes; para escrituras, los datos y el log quedan como corresponde |

Para los reportes, el caso 4 compara el SP con su consulta `SELECT` directa; para los
`_tuneado`, con el SP original (mismas filas y valores). Algunos SP tienen casos extra (por ejemplo
`sp_alta_turno` 5 a 9: varios protocolos, cirugías y consulta previa).

## Resultados medidos del tuning (consigna 5e)

Dos reportes con versión `_tuneado` (`backend/06_tuning_semana6.sql`), medidos con
`backend/medir_tuning.sql` sobre **300.000 turnos y 240.000 pagos** (un mes de datos, 2025-03):

| Reporte | Original, sin índice | Solo reescritura (sin índice) | Reescritura + índice |
|---|---|---|---|
| 1. Turnos por período y profesional | 700 ms | 239 ms | **35 ms** |
| 2. Ingresos por seña | 594 ms | 98 ms | **15 ms** |

- El **índice solo no alcanza**: con el índice creado, el reporte 1 original tardó lo mismo
  (≈ 690 ms), porque `DATE(columna) BETWEEN ...` impide usarlo. Hace falta reescribir la consulta.
- Mejora total: reporte 1 unas **20 veces**, reporte 2 unas **40 veces**.
- Cambios: (1) `DATE(col) BETWEEN` → rango `col >= desde AND col < hasta + 1 día`; (2) subconsulta
  correlacionada por fila → `JOIN`/agregación hecha una vez; (3) comparar `id_estado` en lugar de
  hacer `JOIN` a la tabla maestra por el nombre; (4) índices que cubren el filtro y las columnas
  (`IX_Turno_inicio_profesional_estado`, `IX_PagoSena_fecha_medio_estado`).
- Tiempos de `EXPLAIN ANALYZE` (milisegundos totales) en una PC de laboratorio virtual: sirven por
  la **proporción**, no por el valor absoluto.

## Datos de ejemplo (consigna punto 4)

| Tabla | Filas |
|---|---|
| Turno (tabla principal) | 150 (más la actividad de `07_actividad_con_sps.sql`) |
| Paciente / Teléfonos | 60 / 72 |
| Profesional | 20 |
| Disponibilidad | 1.085 |
| Protocolo / Profesional–Protocolo | 30 / 115 |
| Protocolos de cada turno | 172 |
| Evaluación previa | 24 |
| Pago de seña | 145 |
| Tarjeta de regalo / Movimientos | 22 / 27 |
| Regla de beneficio / Cupón | 22 / 26 |
| Notificación | 166 |
| Consulta al asistente | 42 |
| Usuario | 45 |
| **Log** | **0 en `02_datos.sql`**: lo llenan los stored procedures (`07_actividad_con_sps.sql`) |

Los **catálogos cerrados** (rol, estado de turno, estado de pago, medio de pago, origen, canal, tipos de
regla y de notificación, resultado de evaluación) tienen los valores que define el negocio
(entre 3 y 5), no 20: no tendría sentido inventar estados. Conviene confirmar este criterio con el
docente.

## Detalle de los 222 casos

| Caso | Tipo | Descripción | Resultado |
|---|---|---|---|
| sp_reporte_turnos_por_periodo_profesional.1 | Éxito | Reporte 1 con un rango que tiene datos: devuelve 53 filas | OK |
| sp_reporte_turnos_por_periodo_profesional.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error | OK |
| sp_reporte_turnos_por_periodo_profesional.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error | OK |
| sp_reporte_turnos_por_periodo_profesional.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores) | OK |
| sp_reporte_ingresos_sena.1 | Éxito | Reporte 2 con un rango que tiene datos: devuelve 12 filas | OK |
| sp_reporte_ingresos_sena.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error | OK |
| sp_reporte_ingresos_sena.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error | OK |
| sp_reporte_ingresos_sena.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores) | OK |
| sp_reporte_cancelaciones_inasistencias.1 | Éxito | Reporte 3 con un rango que tiene datos: devuelve 9 filas | OK |
| sp_reporte_cancelaciones_inasistencias.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error | OK |
| sp_reporte_cancelaciones_inasistencias.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error | OK |
| sp_reporte_cancelaciones_inasistencias.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores) | OK |
| sp_reporte_evaluaciones_cirugias.1 | Éxito | Reporte 4 con un rango que tiene datos: devuelve 13 filas | OK |
| sp_reporte_evaluaciones_cirugias.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error | OK |
| sp_reporte_evaluaciones_cirugias.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error | OK |
| sp_reporte_evaluaciones_cirugias.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores) | OK |
| sp_reporte_protocolos_mas_pedidos.1 | Éxito | Reporte 5 con un rango que tiene datos: devuelve 5 filas | OK |
| sp_reporte_protocolos_mas_pedidos.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error | OK |
| sp_reporte_protocolos_mas_pedidos.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error | OK |
| sp_reporte_protocolos_mas_pedidos.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores) | OK |
| sp_reporte_ocupacion_profesional.1 | Éxito | Reporte 6 con un rango que tiene datos: devuelve 19 filas | OK |
| sp_reporte_ocupacion_profesional.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error | OK |
| sp_reporte_ocupacion_profesional.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error | OK |
| sp_reporte_ocupacion_profesional.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores) | OK |
| sp_reporte_cupones.1 | Éxito | Reporte 7 con un rango que tiene datos: devuelve 14 filas | OK |
| sp_reporte_cupones.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error | OK |
| sp_reporte_cupones.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error | OK |
| sp_reporte_cupones.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores) | OK |
| sp_reporte_tarjetas_regalo.1 | Éxito | Reporte 8 con un rango que tiene datos: devuelve 22 filas | OK |
| sp_reporte_tarjetas_regalo.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error | OK |
| sp_reporte_tarjetas_regalo.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error | OK |
| sp_reporte_tarjetas_regalo.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores) | OK |
| sp_reporte_turnos_por_periodo_profesional_tuneado.1 | Éxito | Con un rango con datos devuelve 53 filas | OK |
| sp_reporte_turnos_por_periodo_profesional_tuneado.2 | Sin coincidencias | Rango sin datos: 0 filas | OK |
| sp_reporte_turnos_por_periodo_profesional_tuneado.3 | Nulos y límites | Fechas NULL y rango invertido: 0 filas | OK |
| sp_reporte_turnos_por_periodo_profesional_tuneado.4 | Consistencia | Tuneado y original devuelven filas y valores idénticos (todo el rango y un recorte) | OK |
| sp_reporte_ingresos_sena_tuneado.1 | Éxito | Con un rango con datos devuelve 12 filas | OK |
| sp_reporte_ingresos_sena_tuneado.2 | Sin coincidencias | Rango sin datos: 0 filas | OK |
| sp_reporte_ingresos_sena_tuneado.3 | Nulos y límites | Fechas NULL y rango invertido: 0 filas | OK |
| sp_reporte_ingresos_sena_tuneado.4 | Consistencia | Tuneado y original devuelven filas y valores idénticos (todo el rango y un recorte) | OK |
| sp_registrar_log.1 | Éxito | Escribe una fila con tipo, usuario, origen y fecha del reloj del sistema | OK |
| sp_registrar_log.2 | Sin coincidencias | Un tipo de evento que no existe no escribe nada ni da error | OK |
| sp_registrar_log.3 | Nulos y límites | Usuario inexistente y origen desconocido: el log queda con usuario NULL y origen sistema; exitoso NULL vale 1 | OK |
| sp_registrar_log.4 | Consistencia | La descripción se recorta a 500 caracteres y exitoso=0 se conserva | OK |
| fn_ahora.1 | Éxito | Con @ahora_simulado devuelve esa hora | OK |
| fn_ahora.2 | Sin coincidencias | Sin reloj simulado devuelve la hora real (cerca de NOW()) | OK |
| fn_ahora.3 | Nulos y límites | Un valor vacío del reloj también cae a NOW() | OK |
| fn_ahora.4 | Consistencia | Al volver a poner el reloj simulado se vuelve a usar | OK |
| sp_login.1 | Éxito | Ingreso correcto del administrador: devuelve id, rol y deja el inicio de sesión en el log | OK |
| sp_login.2 | Sin coincidencias | Usuario inexistente y contraseña mal: error 52011 y los dos intentos quedan en el log | OK |
| sp_login.3 | Nulos y límites | Usuario o contraseña NULL o vacíos: error 52010 | OK |
| sp_login.4 | Consistencia | Tras 5 intentos fallidos la cuenta se bloquea (52012), aunque la clave sea la correcta; los intentos se cuentan desde el log | OK |
| sp_cerrar_sesion.1 | Éxito | Cierra la sesión de un usuario existente y queda en el log | OK |
| sp_cerrar_sesion.2 | Sin coincidencias | Usuario inexistente: error 52013 y no escribe en el log | OK |
| sp_cerrar_sesion.3 | Nulos y límites | Usuario NULL: error 52013 | OK |
| sp_cerrar_sesion.4 | Consistencia | Hay exactamente un cierre de sesión en el log (el del caso 1) | OK |
| sp_crear_cuenta_paciente.1 | Éxito | Una paciente sin cuenta crea la suya con su DNI | OK |
| sp_crear_cuenta_paciente.2 | Sin coincidencias | DNI inexistente (52020), cuenta ya creada (52021), usuario o email repetidos (52025) | OK |
| sp_crear_cuenta_paciente.3 | Nulos y límites | DNI NULL, usuario corto o con mayúsculas, email mal escrito y contraseña que no es un hash | OK |
| sp_crear_cuenta_paciente.4 | Consistencia | El usuario nuevo tiene rol paciente, la paciente quedó vinculada y el alta está en el log | OK |
| sp_alta_paciente.1 | Éxito | Alta con todos los datos válidos: queda la paciente y su teléfono | OK |
| sp_alta_paciente.2 | Sin coincidencias | DNI repetido: error 52035 y no se crea otra fila | OK |
| sp_alta_paciente.3 | Nulos y límites | DNI NULL o de 6 y 9 dígitos, nombre de 1 letra, teléfono corto, fecha futura, email mal escrito | OK |
| sp_alta_paciente.4 | Consistencia | El log tiene las altas correctas (exitoso=1) y los rechazos (exitoso=0); un email vacío se guarda como NULL | OK |
| sp_modificar_paciente.1 | Éxito | Cambia nombre y email y agrega un teléfono | OK |
| sp_modificar_paciente.2 | Sin coincidencias | Paciente inexistente: error 52036 | OK |
| sp_modificar_paciente.3 | Nulos y límites | Nombre NULL o corto, email mal escrito y teléfono inválido; un teléfono repetido no se duplica | OK |
| sp_modificar_paciente.4 | Consistencia | El log guarda el valor anterior y el nuevo | OK |
| sp_buscar_paciente.1 | Éxito | Busca por DNI exacto: una fila con sus teléfonos | OK |
| sp_buscar_paciente.2 | Sin coincidencias | DNI y apellido que no existen: 0 filas | OK |
| sp_buscar_paciente.3 | Nulos y límites | NULL, vacío y menos de 3 caracteres: 0 filas | OK |
| sp_buscar_paciente.4 | Consistencia | Por apellido trae las tres pacientes "Prueba" + Ana y Carla; igual a un SELECT directo | OK |
| sp_alta_profesional.1 | Éxito | Alta con cuenta propia (rol profesional) y teléfono | OK |
| sp_alta_profesional.2 | Sin coincidencias | Matrícula repetida (52041) y usuario o email repetidos (52025) | OK |
| sp_alta_profesional.3 | Nulos y límites | Matrícula vacía, nombre corto, email, teléfono, usuario y contraseña inválidos | OK |
| sp_alta_profesional.4 | Consistencia | Los intentos fallidos no dejaron usuarios huérfanos y quedaron en el log | OK |
| sp_modificar_profesional.1 | Éxito | Cambia el email del profesional de prueba 2 | OK |
| sp_modificar_profesional.2 | Sin coincidencias | Profesional inexistente: error 52042 | OK |
| sp_modificar_profesional.3 | Nulos y límites | Nombre NULL, email mal escrito y activo fuera de 0/1 | OK |
| sp_modificar_profesional.4 | Consistencia | La baja se rechaza si hay turnos futuros sin cancelar (52044) y se acepta sin turnos; la baja queda en el log | OK |
| sp_cargar_disponibilidad.1 | Éxito | Carga una franja nueva de 14 a 18 el lunes 21/12 | OK |
| sp_cargar_disponibilidad.2 | Sin coincidencias | Profesional inexistente o dado de baja (52045) y franja que se superpone (52049) | OK |
| sp_cargar_disponibilidad.3 | Nulos y límites | Fecha u hora NULL, fin igual al inicio y fecha en el pasado; una franja pegada (18:00) sí se acepta | OK |
| sp_cargar_disponibilidad.4 | Consistencia | Las franjas válidas quedaron en la tabla y las rechazadas no | OK |
| sp_baja_disponibilidad.1 | Éxito | Da de baja la franja del 21/12 14 a 18 | OK |
| sp_baja_disponibilidad.2 | Sin coincidencias | Franja inexistente (52050) y franja ya dada de baja (52051) | OK |
| sp_baja_disponibilidad.3 | Nulos y límites | Id NULL: error 52050 | OK |
| sp_baja_disponibilidad.4 | Consistencia | No se da de baja una franja con un turno adentro (52052); después de cancelar el turno sí | OK |
| sp_asignar_protocolo.1 | Éxito | Habilita el protocolo 11 al profesional de prueba | OK |
| sp_asignar_protocolo.2 | Sin coincidencias | Profesional (52042) o protocolo (52060) inexistente | OK |
| sp_asignar_protocolo.3 | Nulos y límites | Habilitar NULL o 5: error 52043; habilitar dos veces no duplica | OK |
| sp_asignar_protocolo.4 | Consistencia | Quitarlo lo borra de la tabla y deja el log | OK |
| sp_profesionales_para_protocolos.1 | Éxito | Para el protocolo 26 (rinoplastia) están los tres cirujanos y el profesional de prueba | OK |
| sp_profesionales_para_protocolos.2 | Sin coincidencias | Un protocolo que nadie hace: 0 filas | OK |
| sp_profesionales_para_protocolos.3 | Nulos y límites | NULL, vacío y texto que no es una lista de números: 0 filas, sin error | OK |
| sp_profesionales_para_protocolos.4 | Consistencia | Con dos protocolos solo salen quienes hacen los dos; igual a un SELECT directo | OK |
| sp_alta_protocolo.1 | Éxito | Alta de un protocolo nuevo en la categoría 1 | OK |
| sp_alta_protocolo.2 | Sin coincidencias | Categoría inexistente (52061) y nombre repetido (52065) | OK |
| sp_alta_protocolo.3 | Nulos y límites | Nombre NULL o corto, precio 0, duración 0 y 601 | OK |
| sp_alta_protocolo.4 | Consistencia | Hay exactamente 2 protocolos creados por las pruebas y los rechazos quedaron en el log | OK |
| sp_modificar_protocolo.1 | Éxito | Sube el precio del protocolo de prueba a 65000 | OK |
| sp_modificar_protocolo.2 | Sin coincidencias | Protocolo inexistente (52060) y nombre de otro protocolo (52065) | OK |
| sp_modificar_protocolo.3 | Nulos y límites | Precio negativo, duración NULL y activo 3 | OK |
| sp_modificar_protocolo.4 | Consistencia | Los turnos viejos conservan su precio aplicado; la baja lo saca del catálogo; el log guarda lo anterior y lo nuevo | OK |
| sp_listar_protocolos.1 | Éxito | Sin filtros trae todo el catálogo activo (30 de ejemplo + "Otro protocolo") | OK |
| sp_listar_protocolos.2 | Sin coincidencias | Una palabra que no está en ningún protocolo: 0 filas | OK |
| sp_listar_protocolos.3 | Nulos y límites | Texto vacío trae todo; un protocolo dado de baja no aparece; categoría inexistente trae 0 filas | OK |
| sp_listar_protocolos.4 | Consistencia | La búsqueda "láser" y la categoría Cirugías coinciden con un SELECT directo | OK |
| sp_horarios_libres.1 | Éxito | Una limpieza (60 min) el lunes 14/12 de 9 a 13 deja 7 horarios para el profesional de prueba | OK |
| sp_horarios_libres.2 | Sin coincidencias | Un día sin disponibilidad y un protocolo que el profesional no hace: 0 filas | OK |
| sp_horarios_libres.3 | Nulos y límites | Fecha NULL, protocolos NULL, vacíos o con letras, protocolo de baja: 0 filas; el último horario de una cirugía de 180 min es 10:00 | OK |
| sp_horarios_libres.4 | Consistencia | Igual a una grilla armada a mano: 09:00 a 12:00 cada 30 minutos | OK |
| sp_alta_turno.1 | Éxito | Limpieza facial del lunes 14/12 a las 9: queda pendiente, termina a las 10 y la seña es el 30% | OK |
| sp_alta_turno.2 | Sin coincidencias | Superposición (52081), fuera de horario (52080), protocolo inexistente (52075), profesional que no lo hace (52076), pasado (52073), paciente inexistente (52071), cirugía sin evaluación (52083) | OK |
| sp_alta_turno.3 | Nulos y límites | Protocolos NULL o vacíos, inicio NULL, origen inválido; un turno que termina justo a las 13:00 sí entra; uno que termina 13:30 no | OK |
| sp_alta_turno.4 | Consistencia | Los rechazos no dejaron turnos de más (solo 2 en el día), quedaron en el log y los horarios libres ya no ofrecen lo ocupado | OK |
| sp_alta_turno.5 | Dos protocolos | Dos protocolos en un turno suman duración y precio (peeling 45 + láser 30 = 75 min) | OK |
| sp_alta_turno.6 | Paciente superpuesta | La misma paciente no puede tener dos turnos a la vez (52082) | OK |
| sp_buscar_turnos.1 | Éxito | Por DNI de la paciente A: su turno del 14/12 | OK |
| sp_buscar_turnos.2 | Sin coincidencias | DNI y apellido que no existen: 0 filas | OK |
| sp_buscar_turnos.3 | Nulos y límites | NULL, vacío y 2 caracteres: 0 filas | OK |
| sp_buscar_turnos.4 | Consistencia | Por apellido trae los 4 turnos de las pacientes de prueba (uno está cancelado) y la cantidad coincide con un conteo directo | OK |
| sp_registrar_sena.1 | Éxito | Seña del turno 1 en efectivo: $27.000, turno confirmado, código de operación, confirmación y recordatorio programados | OK |
| sp_registrar_sena.2 | Sin coincidencias | Turno inexistente (52110), ya pagado (52111), medio de pago inexistente (52114), tarjeta inexistente (52117) | OK |
| sp_registrar_sena.3 | Nulos y límites | Turno NULL, medio NULL y tarjeta de regalo sin código | OK |
| sp_registrar_sena.4 | Consistencia | El monto cobrado coincide con fn_sena y con 30% del precio; el rechazo de la tarjeta quedó en el log | OK |
| sp_cancelar_turno.1 | Éxito | Cancelar con más de 24 h reembolsa el 100% de la seña | OK |
| sp_cancelar_turno.2 | Sin coincidencias | Turno inexistente (52120) y turno ya cancelado (52121) | OK |
| sp_cancelar_turno.3 | Nulos y límites | Turno NULL (52120); a exactamente 24 h la seña NO se reembolsa (queda retenida); sin seña se cancela igual | OK |
| sp_cancelar_turno.4 | Consistencia | Cada cancelación avisó a la paciente, liberó el horario y quedó en el log | OK |
| sp_marcar_turno.1 | Éxito | Marca como realizado un turno confirmado que ya empezó | OK |
| sp_marcar_turno.2 | Sin coincidencias | Turno inexistente (52120), estado inválido (52125), turno que no está confirmado (52126) | OK |
| sp_marcar_turno.3 | Nulos y límites | Estado NULL (52125); el turno que no empezó todavía no se puede marcar (52127) | OK |
| sp_marcar_turno.4 | Consistencia | La inasistencia retiene la seña (retenida, reembolsado 0) y queda en el log | OK |
| sp_aplicar_reembolso.3 | Nulos y límites | Monto NULL o mayor al pagado (52102) y estado inventado (52103); con el pago todavía "pagada" | OK |
| sp_aplicar_reembolso.1 | Éxito | Reembolso parcial de la seña del turno 5 (interno: lo usan otros SP) | OK |
| sp_aplicar_reembolso.2 | Sin coincidencias | Pago inexistente: excepción 52100 | OK |
| sp_aplicar_reembolso.4 | Consistencia | Un pago ya resuelto no se puede resolver de nuevo (52101) y su monto no cambia | OK |
| sp_comprar_tarjeta.1 | Éxito | Venta de una tarjeta de $300.000 en efectivo: código numérico de 7 cifras, vigencia de 12 meses | OK |
| sp_comprar_tarjeta.2 | Sin coincidencias | Medio de pago inexistente o "tarjeta de regalo" (52151) | OK |
| sp_comprar_tarjeta.3 | Nulos y límites | Monto 19.999 y 5.000.001 se rechazan, 20.000 y 5.000.000 se aceptan; nombre vacío; teléfono inválido | OK |
| sp_comprar_tarjeta.4 | Consistencia | Las tres tarjetas válidas existen y las rechazadas no; las compras están en el log | OK |
| sp_saldo_tarjeta.1 | Éxito | Una tarjeta nueva tiene saldo igual a su monto | OK |
| sp_saldo_tarjeta.2 | Sin coincidencias | Código inexistente: 0 filas y el intento queda en el log | OK |
| sp_saldo_tarjeta.3 | Nulos y límites | NULL y vacío: 0 filas y no ensucian el log | OK |
| sp_saldo_tarjeta.4 | Consistencia | Igual a un SELECT directo | OK |
| sp_registrar_sena.5 | Pago con tarjeta de regalo | Paga la seña con la tarjeta, baja el saldo, y una tarjeta sin saldo suficiente se rechaza (52117) | OK |
| sp_movimientos_tarjeta.1 | Éxito | La tarjeta usada tiene 1 movimiento (el gasto de la seña) | OK |
| sp_movimientos_tarjeta.2 | Sin coincidencias | Código inexistente y tarjeta sin uso: 0 filas | OK |
| sp_movimientos_tarjeta.3 | Nulos y límites | NULL y vacío: 0 filas | OK |
| sp_movimientos_tarjeta.4 | Consistencia | Cancelando el turno con más de 24 h el saldo vuelve a 300.000 con un movimiento negativo; la suma de movimientos = monto - saldo | OK |
| sp_emitir_cupones.1 | Éxito | Emite cupones a las pacientes con cuenta según las reglas activas; la paciente A (con cuenta) recibe los de promoción general | OK |
| sp_emitir_cupones.2 | Sin coincidencias | Una segunda corrida inmediata no emite nada nuevo (0 cupones) | OK |
| sp_emitir_cupones.3 | Nulos y límites | Sin origen (NULL) corre igual; la paciente B, que no tiene cuenta, nunca recibe cupones | OK |
| sp_emitir_cupones.4 | Consistencia | Todo cupón vence en emisión + vigencia de su regla y copia el porcentaje de la regla | OK |
| sp_generar_token_cupon.1 | Éxito | Devuelve un token numérico (hasta 7 cifras) que dura 300 segundos desde el inicio del tramo | OK |
| sp_generar_token_cupon.2 | Sin coincidencias | Cupón inexistente (52140), de otra paciente (52141), ya usado (52142), vencido (52143) | OK |
| sp_generar_token_cupon.3 | Nulos y límites | Código NULL: error 52140; sin paciente se genera igual; a mitad del tramo quedan 150 segundos | OK |
| sp_generar_token_cupon.4 | Consistencia | El token cambia en el tramo siguiente y es el mismo dentro del tramo | OK |
| sp_validar_cupon.1 | Éxito | Cupón de la paciente A con su token vigente: válido, devuelve el porcentaje | OK |
| sp_validar_cupon.2 | Sin coincidencias | Cupón inexistente (52140), de otra paciente (52141), usado (52142), vencido (52143), token incorrecto (52144) | OK |
| sp_validar_cupon.3 | Nulos y límites | Código NULL (52140) y token NULL (52144); sin paciente se valida igual | OK |
| sp_validar_cupon.4 | Consistencia | El token del tramo anterior se acepta; a los 10 minutos ya no; todo queda en el log | OK |
| sp_aplicar_cupon_a_turno.1 | Éxito | Aplica el cupón escaneado a un turno pendiente: baja el precio y la seña | OK |
| sp_aplicar_cupon_a_turno.2 | Sin coincidencias | Turno inexistente (52120), ya tiene cupón (52146), cupón de otra paciente (52141), ya usado (52142), token incorrecto (52144) | OK |
| sp_aplicar_cupon_a_turno.3 | Nulos y límites | Turno NULL (52120); turno ya pagado (52145); un cupón y una tarjeta de regalo no se mezclan (52116) | OK |
| sp_aplicar_cupon_a_turno.4 | Consistencia | Con cupón la seña es el 30% del precio con descuento; cancelando con más de 24 h el cupón queda libre otra vez | OK |
| sp_resolver_evaluacion.1 | Éxito | Después de la consulta, el profesional carga "apto" | OK |
| sp_resolver_evaluacion.2 | Sin coincidencias | Evaluación inexistente (52130) y ya resuelta (52131) | OK |
| sp_resolver_evaluacion.3 | Nulos y límites | Resultado NULL o inventado (52132); evaluación NULL (52130) | OK |
| sp_resolver_evaluacion.4 | Consistencia | "No apto": se retiene el 10% de la seña (24.000 → devuelve 21.600, retiene 2.400) y queda en el log | OK |
| sp_alta_turno.7 | Cirugía con evaluación apta | La paciente B agenda la rinoplastia: se acepta (apta y de menos de 6 meses), seña del 40% y se le devuelve la seña de la consulta | OK |
| sp_alta_turno.8 | Cirugía con evaluación no apta o ya usada | La C (no apta) no puede (52083) y la B tampoco puede usar la misma evaluación dos veces | OK |
| sp_alta_turno.9 | Reglas de las cirugías | Una cirugía no se mezcla con otro protocolo (52077) y la consulta previa no puede incluir una cirugía (52078) ni apuntar a un protocolo común (52079) | OK |
| sp_reclamar_evaluacion.1 | Éxito | Evaluación apta vencida (más de 6 meses) sin cirugía: la paciente reclama y se le devuelve el 50% | OK |
| sp_reclamar_evaluacion.2 | Sin coincidencias | Evaluación inexistente (52130), ya reclamada (52135), no apta (52134) | OK |
| sp_reclamar_evaluacion.3 | Nulos y límites | Evaluación NULL (52130); una evaluación apta todavía vigente no se reclama (52136); una usada para cirugía tampoco | OK |
| sp_reclamar_evaluacion.4 | Consistencia | El reclamo dejó la fecha, el pago cambió una sola vez y está en el log | OK |
| sp_vencer_evaluaciones.1 | Éxito | Siete meses después, las evaluaciones aptas sin cirugía vencen: el instituto se queda con la consulta | OK |
| sp_vencer_evaluaciones.2 | Sin coincidencias | Una segunda corrida no encuentra nada que vencer | OK |
| sp_vencer_evaluaciones.3 | Nulos y límites | Sin origen (NULL) corre sin error; la evaluación usada para cirugía de la paciente B no se toca | OK |
| sp_vencer_evaluaciones.4 | Consistencia | Ninguna seña de evaluación vencida quedó "pagada": todas pasaron a retenida | OK |
| sp_notificaciones_pendientes.1 | Éxito | Con p_limite 5 trae 5 avisos pendientes cuya hora ya llegó | OK |
| sp_notificaciones_pendientes.2 | Sin coincidencias | En una fecha anterior a todos los avisos no hay nada pendiente | OK |
| sp_notificaciones_pendientes.3 | Nulos y límites | Límite NULL, 0 o 501 se reemplaza por 50 | OK |
| sp_notificaciones_pendientes.4 | Consistencia | Con límite 500 la cantidad es igual al conteo directo de avisos pendientes ya vencidos | OK |
| sp_marcar_notificacion.1 | Éxito | n8n informa que el aviso se envió: queda enviada con fecha de envío | OK |
| sp_marcar_notificacion.2 | Sin coincidencias | Aviso inexistente (52160) y aviso que ya no está pendiente (52161) | OK |
| sp_marcar_notificacion.3 | Nulos y límites | Id NULL (52160), resultado NULL o inventado (52162) | OK |
| sp_marcar_notificacion.4 | Consistencia | Un fallo se reintenta: sigue pendiente en los intentos 1 y 2 y pasa a fallida en el 3 | OK |
| sp_registrar_consulta.1 | Éxito | Registra una pregunta y su respuesta | OK |
| sp_registrar_consulta.2 | Sin coincidencias | Origen inválido (52070), pregunta vacía (52170) y paciente inexistente (52071) | OK |
| sp_registrar_consulta.3 | Nulos y límites | Pregunta NULL (52170); sin paciente (invitada) y sin respuesta se registra; derivada NULL vale 0 | OK |
| sp_registrar_consulta.4 | Consistencia | La pregunta se guarda tal cual (ya no se filtran datos personales) y la derivación queda registrada | OK |
| sp_turnos_del_periodo.1 | Éxito | Los turnos de todo noviembre (hay muchos: la agenda del mes) | OK |
| sp_turnos_del_periodo.2 | Sin coincidencias | Un rango de 2020: 0 filas | OK |
| sp_turnos_del_periodo.3 | Nulos y límites | Fechas NULL o rango invertido: 0 filas | OK |
| sp_turnos_del_periodo.4 | Consistencia | Igual a su SELECT directo (mismas filas y valores) | OK |
| sp_listar_pacientes.1 | Éxito | Trae todas las pacientes (63 con las de prueba: 60 de ejemplo + A, B, C + 2 altas de prueba) | OK |
| sp_listar_pacientes.2 | Sin coincidencias | No tiene parámetros: una paciente dada de alta aparece sola (la lista crece en 1) | OK |
| sp_listar_pacientes.3 | Nulos y límites | La paciente sin cuenta y sin email aparece igual, con tiene_cuenta = 0 | OK |
| sp_listar_pacientes.4 | Consistencia | El orden es por apellido y nombre y no se pierde ninguna fila | OK |
| sp_listar_profesionales.1 | Éxito | Trae a los profesionales activos e inactivos | OK |
| sp_listar_profesionales.2 | Sin coincidencias | Un profesional dado de baja sigue en la lista, con activo = 0 | OK |
| sp_listar_profesionales.3 | Nulos y límites | Sin parámetros: no puede fallar | OK |
| sp_listar_profesionales.4 | Consistencia | Cantidad igual al conteo directo | OK |
| sp_listar_profesional_protocolo.1 | Éxito | Un par por cada protocolo que hace cada profesional | OK |
| sp_listar_profesional_protocolo.2 | Sin coincidencias | Un protocolo quitado deja de aparecer | OK |
| sp_listar_profesional_protocolo.3 | Nulos y límites | Sin parámetros: no puede fallar | OK |
| sp_listar_profesional_protocolo.4 | Consistencia | Cada par existe en las dos tablas | OK |
| sp_listar_disponibilidad.1 | Éxito | Las franjas activas desde el 14/12 incluyen las del profesional de prueba | OK |
| sp_listar_disponibilidad.2 | Sin coincidencias | Desde una fecha lejana no hay franjas | OK |
| sp_listar_disponibilidad.3 | Nulos y límites | Fecha NULL: 0 filas | OK |
| sp_listar_disponibilidad.4 | Consistencia | Una franja dada de baja no aparece | OK |
| sp_listar_notificaciones.1 | Éxito | Los avisos de noviembre | OK |
| sp_listar_notificaciones.2 | Sin coincidencias | Un rango sin avisos: 0 filas | OK |
| sp_listar_notificaciones.3 | Nulos y límites | Fechas NULL o invertidas: 0 filas | OK |
| sp_listar_notificaciones.4 | Consistencia | Cada aviso trae su turno cuando lo tiene | OK |
| sp_reporte_auditoria.1 | Éxito | Los inicios de sesión del día (2 reales y 2 que escribió la prueba del log) | OK |
| sp_reporte_auditoria.2 | Sin coincidencias | Un rango en el pasado y un usuario inexistente: 0 filas | OK |
| sp_reporte_auditoria.3 | Nulos y límites | Fechas NULL o rango invertido: 0 filas; el último día se incluye completo | OK |
| sp_reporte_auditoria.4 | Consistencia | Los filtros coinciden con un SELECT directo: solo fallos del tipo "intento_fallido" desde la web | OK |

## Pruebas de las aplicaciones contra la base

Además de los casos de SQL, las aplicaciones se prueban contra el MySQL real (se saltean si no hay base):

| Prueba | Qué recorre |
|---|---|
| `frontend/pruebas/prueba_base.cpp` | La capa `Repositorio`: catálogo, ingreso, paciente nueva, horario libre, turno, seña, búsqueda y cancelación con reembolso |
| `frontend/pruebas/prueba_gestion_base.cpp` | La ventana de Gestión conectada: lee los datos, carga un turno con seña (dialogos incluidos), lo busca y lo cancela; la pantalla Reportes; y la sincronización de la contingencia |
| `frontend/pruebas/prueba_cliente_base.cpp` | La terminal: elegir protocolo, profesional y horario de la base, reservar con seña simulada |
| `web/api/servidor.test.js` | La API del sitio: catálogo, horarios, reserva (con y sin fecha de nacimiento), superposición rechazada, búsqueda y cancelación |
| Recorrido en navegador (Playwright) | Reservar en el sitio, verlo en "Mi turno" y cancelarlo: la base queda con el turno cancelado y la seña reembolsada |

Se corren con `DERMALIA_DB_USER=root ctest --test-dir build` y `DERMALIA_DB_USER=root npm run test:api`.
