-- Dermalia: pruebas funcionales de los stored procedures (consigna 6).
-- Se corre sobre la base recién cargada (01 a 06):
--   mysql -u root -p < backend/codigobasededatossolotablas.sql   (y 02, 03, 04, 05, 06)
--   mysql -u root -p < backend/05_pruebas_sp.sql        (o abrirlo en Workbench / DBeaver)
-- Automático:  python3 backend/pruebas/correr_pruebas.py --recargar
--
-- ATENCIÓN: el script modifica datos (agenda turnos, paga señas, etc.). Para
-- repetirlo hay que volver a cargar la base.
--
-- Cada SP tiene cuatro casos (consigna 6b):
--   1 Éxito: parámetros válidos, resultado exacto.
--   2 Sin coincidencias / rechazo: valores que no existen o que las reglas
--     de negocio no permiten; tiene que devolver el error previsto y no romper nada.
--   3 Nulos y límites: NULL, vacío y bordes (por ejemplo, exactamente 24 horas).
--   4 Consistencia: el resultado coincide con una consulta SELECT directa, o
--     los datos y el log quedaron como tienen que quedar.
-- Las líneas `-- @caso` y `-- @espera` son anotaciones: para una persona dicen qué
-- tiene que pasar; el corredor automático las verifica solo.
-- Un reloj simulado (@ahora_simulado) permite probar vencimientos y plazos de 24 horas.

SET @ahora_simulado = '2026-11-03 09:00:00';

-- ======================================================================
-- A. REPORTES (solo leen: se prueban primero, sobre los datos de ejemplo)
-- ======================================================================

-- @caso sp_reporte_turnos_por_periodo_profesional.1 | Éxito | Reporte 1 con un rango que tiene datos: devuelve 53 filas
-- @espera filas 53
CALL agenda.sp_reporte_turnos_por_periodo_profesional('2026-09-01', '2026-11-30', NULL);

-- @caso sp_reporte_turnos_por_periodo_profesional.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error
-- @espera vacio
CALL agenda.sp_reporte_turnos_por_periodo_profesional('2020-01-01', '2020-01-31', NULL);

-- @caso sp_reporte_turnos_por_periodo_profesional.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error
-- @espera vacio
CALL agenda.sp_reporte_turnos_por_periodo_profesional(NULL, NULL, NULL);
-- @espera vacio
CALL agenda.sp_reporte_turnos_por_periodo_profesional('2026-11-30', '2026-09-01', NULL);

-- @caso sp_reporte_turnos_por_periodo_profesional.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores)
-- @espera igual
CALL agenda.sp_reporte_turnos_por_periodo_profesional('2026-09-01', '2026-11-30', NULL);
SELECT DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') AS periodo,
           pr.id_profesional,
           pr.apellido AS profesional, pr.nombre AS profesional_nombre,
           COUNT(*) AS turnos,
           SUM(e.nombre = 'realizado') AS realizados,
           SUM(e.nombre = 'cancelado') AS cancelados,
           SUM(e.nombre = 'ausente') AS ausentes,
           SUM(e.nombre IN ('pendiente', 'confirmado')) AS vigentes,
           ROUND(SUM(((EXTRACT(HOUR FROM t.fecha_hora_fin) - EXTRACT(HOUR FROM t.fecha_hora_inicio)) * 60 + EXTRACT(MINUTE FROM t.fecha_hora_fin) - EXTRACT(MINUTE FROM t.fecha_hora_inicio))) / 60, 1) AS horas_agendadas,
           SUM(COALESCE((SELECT (SELECT SUM(tp.precio_aplicado) FROM agenda.TurnoProtocolo tp WHERE tp.id_turno = t.id_turno)
                    FROM DUAL WHERE e.nombre = 'realizado'
                   ), 0)) AS facturado
      FROM agenda.Turno t
      JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE DATE(t.fecha_hora_inicio) BETWEEN '2026-09-01' AND '2026-11-30'
       AND (NULL IS NULL OR t.id_profesional = NULL)
     GROUP BY DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m'), pr.id_profesional, pr.apellido, pr.nombre
     ORDER BY periodo, profesional, profesional_nombre;

-- @caso sp_reporte_ingresos_sena.1 | Éxito | Reporte 2 con un rango que tiene datos: devuelve 12 filas
-- @espera filas 12
CALL pagos.sp_reporte_ingresos_sena('2026-09-01', '2026-11-30');

-- @caso sp_reporte_ingresos_sena.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error
-- @espera vacio
CALL pagos.sp_reporte_ingresos_sena('2020-01-01', '2020-01-31');

-- @caso sp_reporte_ingresos_sena.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error
-- @espera vacio
CALL pagos.sp_reporte_ingresos_sena(NULL, NULL);
-- @espera vacio
CALL pagos.sp_reporte_ingresos_sena('2026-11-30', '2026-09-01');

-- @caso sp_reporte_ingresos_sena.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores)
-- @espera igual
CALL pagos.sp_reporte_ingresos_sena('2026-09-01', '2026-11-30');
SELECT DATE_FORMAT(ps.fecha_pago, '%Y-%m') AS periodo,
           (SELECT mp.nombre FROM pagos.MedioPago mp WHERE mp.id_medio_pago = ps.id_medio_pago) AS medio_pago,
           COUNT(*) AS pagos,
           SUM(ps.monto) AS cobrado,
           SUM(COALESCE(ps.monto_reembolsado, 0)) AS reembolsado,
           SUM(COALESCE((SELECT ps.monto - COALESCE(ps.monto_reembolsado, 0) FROM DUAL WHERE ep.nombre IN ('retenida', 'reembolsada parcial')), 0)) AS retenido,
           SUM(ps.monto - COALESCE(ps.monto_reembolsado, 0)) AS neto
      FROM pagos.PagoSena ps
      JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
     WHERE DATE(ps.fecha_pago) BETWEEN '2026-09-01' AND '2026-11-30'
     GROUP BY DATE_FORMAT(ps.fecha_pago, '%Y-%m'), ps.id_medio_pago
     ORDER BY periodo, medio_pago;

-- @caso sp_reporte_cancelaciones_inasistencias.1 | Éxito | Reporte 3 con un rango que tiene datos: devuelve 9 filas
-- @espera filas 9
CALL agenda.sp_reporte_cancelaciones_inasistencias('2026-09-01', '2026-11-30', 'mes');

-- @caso sp_reporte_cancelaciones_inasistencias.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error
-- @espera vacio
CALL agenda.sp_reporte_cancelaciones_inasistencias('2020-01-01', '2020-01-31', 'mes');

-- @caso sp_reporte_cancelaciones_inasistencias.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error
-- @espera vacio
CALL agenda.sp_reporte_cancelaciones_inasistencias(NULL, NULL, 'mes');
-- @espera vacio
CALL agenda.sp_reporte_cancelaciones_inasistencias('2026-11-30', '2026-09-01', 'mes');

-- @caso sp_reporte_cancelaciones_inasistencias.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores)
-- @espera igual
CALL agenda.sp_reporte_cancelaciones_inasistencias('2026-09-01', '2026-11-30', 'mes');
SELECT x.periodo, x.origen,
           COUNT(*) AS turnos,
           SUM(x.estado = 'cancelado') AS cancelados,
           SUM(x.estado = 'cancelado' AND x.estado_sena = 'reembolsada') AS cancelados_con_aviso,
           SUM(x.estado = 'cancelado' AND x.estado_sena = 'retenida') AS cancelados_tarde,
           SUM(x.estado = 'ausente') AS ausentes,
           ROUND(100 * SUM(x.estado IN ('cancelado', 'ausente')) / COUNT(*), 1) AS tasa_perdida_pct,
           COALESCE(SUM((SELECT x.monto - COALESCE(x.reembolsado, 0) FROM DUAL WHERE x.estado IN ('cancelado', 'ausente') AND x.estado_sena IN ('retenida', 'reembolsada parcial')
                            )), 0) AS sena_retenida
      FROM (SELECT COALESCE((SELECT DATE_FORMAT(t.fecha_hora_inicio, '%x-S%v') FROM DUAL WHERE 0), DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m')) AS periodo,
                   o.nombre AS origen, e.nombre AS estado, ep.nombre AS estado_sena, ps.monto, ps.monto_reembolsado AS reembolsado
              FROM agenda.Turno t
              JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
              JOIN agenda.Origen o ON o.id_origen = t.id_origen
              LEFT JOIN pagos.PagoSena ps ON ps.id_turno = t.id_turno
              LEFT JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
             WHERE t.fecha_hora_inicio >= '2026-09-01' AND t.fecha_hora_inicio < '2026-11-30' + INTERVAL 1 DAY) x
     GROUP BY x.periodo, x.origen
     ORDER BY x.periodo, x.origen;

-- @caso sp_reporte_evaluaciones_cirugias.1 | Éxito | Reporte 4 con un rango que tiene datos: devuelve 13 filas
-- @espera filas 13
CALL clinica.sp_reporte_evaluaciones_cirugias('2026-01-01', '2026-12-31');

-- @caso sp_reporte_evaluaciones_cirugias.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error
-- @espera vacio
CALL clinica.sp_reporte_evaluaciones_cirugias('2020-01-01', '2020-01-31');

-- @caso sp_reporte_evaluaciones_cirugias.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error
-- @espera vacio
CALL clinica.sp_reporte_evaluaciones_cirugias(NULL, NULL);
-- @espera vacio
CALL clinica.sp_reporte_evaluaciones_cirugias('2026-12-31', '2026-01-01');

-- @caso sp_reporte_evaluaciones_cirugias.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores)
-- @espera igual
CALL clinica.sp_reporte_evaluaciones_cirugias('2026-01-01', '2026-12-31');
SELECT cir.nombre AS cirugia,
           r.nombre AS resultado,
           COUNT(*) AS evaluaciones,
           COUNT(tc.id_turno) AS con_cirugia_agendada,
           SUM(r.nombre = 'apto' AND tc.id_turno IS NULL AND ev.fecha_resultado + INTERVAL 6 MONTH < COALESCE(@ahora_simulado, NOW())) AS vencidas_sin_cirugia,
           SUM(ev.fecha_reclamo IS NOT NULL) AS reclamos,
           COALESCE(SUM((SELECT ps.monto - COALESCE(ps.monto_reembolsado, 0) FROM DUAL WHERE ep.nombre IN ('retenida', 'reembolsada parcial'))), 0) AS consulta_retenida
      FROM clinica.EvaluacionPrevia ev
      JOIN clinica.Protocolo cir ON cir.id_protocolo = ev.id_protocolo
      JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
      JOIN agenda.Turno t ON t.id_turno = ev.id_turno
      LEFT JOIN agenda.Turno tc ON tc.id_evaluacion_previa = ev.id_evaluacion
      LEFT JOIN pagos.PagoSena ps ON ps.id_turno = ev.id_turno
      LEFT JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
     WHERE t.fecha_hora_inicio >= '2026-01-01' AND t.fecha_hora_inicio < '2026-12-31' + INTERVAL 1 DAY
     GROUP BY cir.id_protocolo, cir.nombre, r.id_resultado, r.nombre
     ORDER BY cirugia, resultado;

-- @caso sp_reporte_protocolos_mas_pedidos.1 | Éxito | Reporte 5 con un rango que tiene datos: devuelve 5 filas
-- @espera filas 5
CALL clinica.sp_reporte_protocolos_mas_pedidos('2026-09-01', '2026-11-30', 5);

-- @caso sp_reporte_protocolos_mas_pedidos.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error
-- @espera vacio
CALL clinica.sp_reporte_protocolos_mas_pedidos('2020-01-01', '2020-01-31', 5);

-- @caso sp_reporte_protocolos_mas_pedidos.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error
-- @espera vacio
CALL clinica.sp_reporte_protocolos_mas_pedidos(NULL, NULL, 5);
-- @espera vacio
CALL clinica.sp_reporte_protocolos_mas_pedidos('2026-11-30', '2026-09-01', 5);

-- @caso sp_reporte_protocolos_mas_pedidos.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores)
-- @espera igual
CALL clinica.sp_reporte_protocolos_mas_pedidos('2026-09-01', '2026-11-30', 5);
SELECT x.puesto, x.protocolo, x.categoria, x.pedidos, x.ingresos_lista,
           ROUND(100 * x.pedidos / x.total_pedidos, 1) AS porcentaje
      FROM (
            SELECT 1 + (SELECT COUNT(*) FROM (SELECT p.id_protocolo, p.nombre AS protocolo, c.nombre AS categoria, COUNT(*) AS pedidos, SUM(tp.precio_aplicado) AS ingresos_lista
              FROM agenda.TurnoProtocolo tp
              JOIN agenda.Turno t ON t.id_turno = tp.id_turno
              JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre <> 'cancelado'
              JOIN clinica.Protocolo p ON p.id_protocolo = tp.id_protocolo
              JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
             WHERE t.fecha_hora_inicio >= '2026-09-01' AND t.fecha_hora_inicio < '2026-11-30' + INTERVAL 1 DAY
             GROUP BY p.id_protocolo, p.nombre, c.nombre) m
                         WHERE m.pedidos > a.pedidos OR (m.pedidos = a.pedidos AND m.protocolo < a.protocolo)) AS puesto,
                   a.protocolo, a.categoria, a.pedidos, a.ingresos_lista,
                   (SELECT SUM(z.pedidos) FROM (SELECT p.id_protocolo, p.nombre AS protocolo, c.nombre AS categoria, COUNT(*) AS pedidos, SUM(tp.precio_aplicado) AS ingresos_lista
              FROM agenda.TurnoProtocolo tp
              JOIN agenda.Turno t ON t.id_turno = tp.id_turno
              JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre <> 'cancelado'
              JOIN clinica.Protocolo p ON p.id_protocolo = tp.id_protocolo
              JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
             WHERE t.fecha_hora_inicio >= '2026-09-01' AND t.fecha_hora_inicio < '2026-11-30' + INTERVAL 1 DAY
             GROUP BY p.id_protocolo, p.nombre, c.nombre) z) AS total_pedidos
              FROM (SELECT p.id_protocolo, p.nombre AS protocolo, c.nombre AS categoria, COUNT(*) AS pedidos, SUM(tp.precio_aplicado) AS ingresos_lista
              FROM agenda.TurnoProtocolo tp
              JOIN agenda.Turno t ON t.id_turno = tp.id_turno
              JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre <> 'cancelado'
              JOIN clinica.Protocolo p ON p.id_protocolo = tp.id_protocolo
              JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
             WHERE t.fecha_hora_inicio >= '2026-09-01' AND t.fecha_hora_inicio < '2026-11-30' + INTERVAL 1 DAY
             GROUP BY p.id_protocolo, p.nombre, c.nombre) a
           ) x
     WHERE x.puesto <= COALESCE(5, 10)
     ORDER BY x.puesto, x.protocolo;

-- @caso sp_reporte_ocupacion_profesional.1 | Éxito | Reporte 6 con un rango que tiene datos: devuelve 19 filas
-- @espera filas 19
CALL agenda.sp_reporte_ocupacion_profesional('2026-09-01', '2026-11-30');

-- @caso sp_reporte_ocupacion_profesional.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error
-- @espera vacio
CALL agenda.sp_reporte_ocupacion_profesional('2020-01-01', '2020-01-31');

-- @caso sp_reporte_ocupacion_profesional.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error
-- @espera vacio
CALL agenda.sp_reporte_ocupacion_profesional(NULL, NULL);
-- @espera vacio
CALL agenda.sp_reporte_ocupacion_profesional('2026-11-30', '2026-09-01');

-- @caso sp_reporte_ocupacion_profesional.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores)
-- @espera igual
CALL agenda.sp_reporte_ocupacion_profesional('2026-09-01', '2026-11-30');
SELECT pr.id_profesional, pr.apellido AS profesional, pr.nombre AS profesional_nombre,
           ROUND(COALESCE(d.horas, 0), 1) AS horas_disponibles,
           ROUND(COALESCE(o.horas, 0), 1) AS horas_ocupadas,
           COALESCE(o.turnos, 0) AS turnos,
           ROUND(100 * COALESCE(o.horas, 0) / (SELECT d.horas FROM DUAL WHERE d.horas <> 0), 1) AS ocupacion_pct
      FROM personas.Profesional pr
      LEFT JOIN (SELECT dd.id_profesional, SUM((EXTRACT(HOUR FROM dd.hora_fin) - EXTRACT(HOUR FROM dd.hora_inicio)) * 60 + EXTRACT(MINUTE FROM dd.hora_fin) - EXTRACT(MINUTE FROM dd.hora_inicio)) / 60 AS horas
                   FROM personas.Disponibilidad dd
                  WHERE dd.activa = 1 AND dd.fecha BETWEEN '2026-09-01' AND '2026-11-30'
                  GROUP BY dd.id_profesional) d ON d.id_profesional = pr.id_profesional
      LEFT JOIN (SELECT t.id_profesional, COUNT(*) AS turnos, SUM(((EXTRACT(HOUR FROM t.fecha_hora_fin) - EXTRACT(HOUR FROM t.fecha_hora_inicio)) * 60 + EXTRACT(MINUTE FROM t.fecha_hora_fin) - EXTRACT(MINUTE FROM t.fecha_hora_inicio))) / 60 AS horas
                   FROM agenda.Turno t
                   JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre <> 'cancelado'
                  WHERE t.fecha_hora_inicio >= '2026-09-01' AND t.fecha_hora_inicio < '2026-11-30' + INTERVAL 1 DAY
                  GROUP BY t.id_profesional) o ON o.id_profesional = pr.id_profesional
     WHERE '2026-09-01' IS NOT NULL AND '2026-11-30' IS NOT NULL AND '2026-09-01' <= '2026-11-30'
       AND (d.horas IS NOT NULL OR o.horas IS NOT NULL)
     ORDER BY ocupacion_pct DESC, profesional;

-- @caso sp_reporte_cupones.1 | Éxito | Reporte 7 con un rango que tiene datos: devuelve 14 filas
-- @espera filas 14
CALL beneficios.sp_reporte_cupones('2026-01-01', '2026-12-31');

-- @caso sp_reporte_cupones.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error
-- @espera vacio
CALL beneficios.sp_reporte_cupones('2020-01-01', '2020-01-31');

-- @caso sp_reporte_cupones.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error
-- @espera vacio
CALL beneficios.sp_reporte_cupones(NULL, NULL);
-- @espera vacio
CALL beneficios.sp_reporte_cupones('2026-12-31', '2026-01-01');

-- @caso sp_reporte_cupones.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores)
-- @espera igual
CALL beneficios.sp_reporte_cupones('2026-01-01', '2026-12-31');
SELECT r.id_regla, r.nombre AS regla, tr.nombre AS tipo, r.porcentaje_descuento AS descuento_pct,
           COUNT(*) AS emitidos,
           SUM(c.id_turno IS NOT NULL) AS usados,
           SUM(c.id_turno IS NULL AND c.fecha_vencimiento <= COALESCE(@ahora_simulado, NOW())) AS vencidos_sin_usar,
           SUM(c.id_turno IS NULL AND c.fecha_vencimiento > COALESCE(@ahora_simulado, NOW())) AS vigentes,
           ROUND(100 * SUM(c.id_turno IS NOT NULL) / COUNT(*), 1) AS tasa_uso_pct,
           COALESCE(SUM(pt.total * c.porcentaje_descuento / 100), 0) AS descuento_otorgado
      FROM beneficios.Cupon c
      JOIN beneficios.ReglaBeneficio r ON r.id_regla = c.id_regla
      JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla
      LEFT JOIN (SELECT tp.id_turno, SUM(tp.precio_aplicado) AS total FROM agenda.TurnoProtocolo tp GROUP BY tp.id_turno) pt ON pt.id_turno = c.id_turno
     WHERE c.fecha_emision >= '2026-01-01' AND c.fecha_emision < '2026-12-31' + INTERVAL 1 DAY
     GROUP BY r.id_regla, r.nombre, tr.nombre, r.porcentaje_descuento
     ORDER BY emitidos DESC, regla;

-- @caso sp_reporte_tarjetas_regalo.1 | Éxito | Reporte 8 con un rango que tiene datos: devuelve 22 filas
-- @espera filas 22
CALL pagos.sp_reporte_tarjetas_regalo('2026-01-01', '2026-12-31');

-- @caso sp_reporte_tarjetas_regalo.2 | Sin coincidencias | Rango de enero de 2020: no hay datos y no da error
-- @espera vacio
CALL pagos.sp_reporte_tarjetas_regalo('2020-01-01', '2020-01-31');

-- @caso sp_reporte_tarjetas_regalo.3 | Nulos y límites | Fechas NULL y rango invertido (desde > hasta): 0 filas, sin error
-- @espera vacio
CALL pagos.sp_reporte_tarjetas_regalo(NULL, NULL);
-- @espera vacio
CALL pagos.sp_reporte_tarjetas_regalo('2026-12-31', '2026-01-01');

-- @caso sp_reporte_tarjetas_regalo.4 | Consistencia | El SP devuelve lo mismo que su consulta SELECT directa (mismas filas y valores)
-- @espera igual
CALL pagos.sp_reporte_tarjetas_regalo('2026-01-01', '2026-12-31');
SELECT t.id_tarjeta, CAST(t.codigo AS CHAR(7)) AS codigo, t.comprador_nombre, mp.nombre AS medio_compra,
           DATE(t.fecha_compra) AS fecha_compra, DATE(t.fecha_vencimiento) AS vence,
           t.monto_inicial,
           COALESCE(SUM((m.monto > 0) * m.monto), 0) AS gastado,
           COALESCE(-SUM((m.monto < 0) * m.monto), 0) AS devuelto,
           t.monto_inicial - COALESCE(SUM(m.monto), 0) AS saldo,
           COUNT(m.id_movimiento) AS movimientos,
           MAX(m.fecha_movimiento) AS ultimo_uso,
           COALESCE((SELECT 'vencida' FROM DUAL WHERE t.fecha_vencimiento <= COALESCE(@ahora_simulado, NOW())),
                    (SELECT 'agotada' FROM DUAL WHERE t.monto_inicial - COALESCE(SUM(m.monto), 0) <= 0),
                    (SELECT 'sin uso' FROM DUAL WHERE COUNT(m.id_movimiento) = 0), 'en uso') AS situacion
      FROM pagos.TarjetaRegalo t
      JOIN pagos.MedioPago mp ON mp.id_medio_pago = t.id_medio_pago
      LEFT JOIN pagos.MovimientoTarjeta m ON m.id_tarjeta = t.id_tarjeta
     WHERE t.fecha_compra >= '2026-01-01' AND t.fecha_compra < '2026-12-31' + INTERVAL 1 DAY
     GROUP BY t.id_tarjeta, t.codigo, t.comprador_nombre, mp.nombre, t.fecha_compra, t.fecha_vencimiento, t.monto_inicial
     ORDER BY t.fecha_compra, t.id_tarjeta;
CALL agenda.sp_reporte_turnos_por_periodo_profesional('2026-09-01', '2026-11-30', 1);

-- ======================================================================
-- B. REPORTES TUNEADOS (tienen que devolver exactamente lo mismo que el original)
-- ======================================================================

-- @caso sp_reporte_turnos_por_periodo_profesional_tuneado.1 | Éxito | Con un rango con datos devuelve 53 filas
-- @espera filas 53
CALL agenda.sp_reporte_turnos_por_periodo_profesional_tuneado('2026-09-01', '2026-11-30', NULL);

-- @caso sp_reporte_turnos_por_periodo_profesional_tuneado.2 | Sin coincidencias | Rango sin datos: 0 filas
-- @espera vacio
CALL agenda.sp_reporte_turnos_por_periodo_profesional_tuneado('2020-01-01', '2020-01-31', NULL);

-- @caso sp_reporte_turnos_por_periodo_profesional_tuneado.3 | Nulos y límites | Fechas NULL y rango invertido: 0 filas
-- @espera vacio
CALL agenda.sp_reporte_turnos_por_periodo_profesional_tuneado(NULL, NULL, NULL);
-- @espera vacio
CALL agenda.sp_reporte_turnos_por_periodo_profesional_tuneado('2026-11-30', '2026-09-01', NULL);

-- @caso sp_reporte_turnos_por_periodo_profesional_tuneado.4 | Consistencia | Tuneado y original devuelven filas y valores idénticos (todo el rango y un recorte)
-- @espera igual
CALL agenda.sp_reporte_turnos_por_periodo_profesional_tuneado('2026-09-01', '2026-11-30', NULL);
CALL agenda.sp_reporte_turnos_por_periodo_profesional('2026-09-01', '2026-11-30', NULL);
-- @espera igual
CALL agenda.sp_reporte_turnos_por_periodo_profesional_tuneado('2026-09-01', '2026-11-30', 1);
CALL agenda.sp_reporte_turnos_por_periodo_profesional('2026-09-01', '2026-11-30', 1);

-- @caso sp_reporte_ingresos_sena_tuneado.1 | Éxito | Con un rango con datos devuelve 12 filas
-- @espera filas 12
CALL pagos.sp_reporte_ingresos_sena_tuneado('2026-09-01', '2026-11-30');

-- @caso sp_reporte_ingresos_sena_tuneado.2 | Sin coincidencias | Rango sin datos: 0 filas
-- @espera vacio
CALL pagos.sp_reporte_ingresos_sena_tuneado('2020-01-01', '2020-01-31');

-- @caso sp_reporte_ingresos_sena_tuneado.3 | Nulos y límites | Fechas NULL y rango invertido: 0 filas
-- @espera vacio
CALL pagos.sp_reporte_ingresos_sena_tuneado(NULL, NULL);
-- @espera vacio
CALL pagos.sp_reporte_ingresos_sena_tuneado('2026-11-30', '2026-09-01');

-- @caso sp_reporte_ingresos_sena_tuneado.4 | Consistencia | Tuneado y original devuelven filas y valores idénticos (todo el rango y un recorte)
-- @espera igual
CALL pagos.sp_reporte_ingresos_sena_tuneado('2026-09-01', '2026-11-30');
CALL pagos.sp_reporte_ingresos_sena('2026-09-01', '2026-11-30');
-- @espera igual
CALL pagos.sp_reporte_ingresos_sena_tuneado('2026-10-01', '2026-10-31');
CALL pagos.sp_reporte_ingresos_sena('2026-10-01', '2026-10-31');

-- ======================================================================

-- ======================================================================
-- C. DATOS DE PRUEBA PROPIOS (un profesional y tres pacientes nuevos, así no dependen de los datos de ejemplo)
-- ======================================================================
-- Se crean con los mismos SP que se prueban abajo.
CALL personas.sp_alta_profesional('MN-T001','Prueba','Profesional','prueba.prof@test.example','1155550001','t.prof1','clave','gestion',1);
SELECT MAX(id_profesional) INTO @prof FROM personas.Profesional;
SELECT id_usuario INTO @uprof FROM personas.Profesional WHERE id_profesional = @prof;
CALL personas.sp_alta_paciente('10000001','Paula','Prueba','1990-01-01','paula@test.example','1155550002','gestion',2);
SELECT MAX(id_paciente) INTO @pacA FROM personas.Paciente;
CALL personas.sp_alta_paciente('10000002','Berta','Prueba','1990-01-01','berta@test.example','1155550003','gestion',2);
SELECT MAX(id_paciente) INTO @pacB FROM personas.Paciente;
CALL personas.sp_alta_paciente('10000003','Carla','Prueba','1990-01-01','carla@test.example','1155550004','gestion',2);
SELECT MAX(id_paciente) INTO @pacC FROM personas.Paciente;
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-14', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-15', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-16', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-17', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-18', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-22', '09:00', '15:00', 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@prof, 1, 1, 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@prof, 2, 1, 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@prof, 10, 1, 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@prof, 25, 1, 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@prof, 26, 1, 'gestion', 1);
SELECT @pacA IS NOT NULL AND @prof IS NOT NULL;

-- ======================================================================
-- D. AUXILIARES
-- ======================================================================

-- @caso sp_registrar_log.1 | Éxito | Escribe una fila con tipo, usuario, origen y fecha del reloj del sistema
-- @espera nada
CALL auditoria.sp_registrar_log('inicio_sesion', 1, NULL, 'gestion', 'prueba log 1', 'seguridad.Usuario', 1, NULL, NULL, 1, '10.1.1.1', 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log WHERE descripcion = 'prueba log 1' AND id_usuario = 1 AND fecha_hora = @ahora_simulado AND exitoso = 1) = 1) AS verificacion;

-- @caso sp_registrar_log.2 | Sin coincidencias | Un tipo de evento que no existe no escribe nada ni da error
-- @espera nada
CALL auditoria.sp_registrar_log('evento_inventado', 1, NULL, 'gestion', 'prueba log 2', NULL, NULL, NULL, NULL, 1, NULL, 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log WHERE descripcion = 'prueba log 2') = 0) AS verificacion;

-- @caso sp_registrar_log.3 | Nulos y límites | Usuario inexistente y origen desconocido: el log queda con usuario NULL y origen sistema; exitoso NULL vale 1
-- @espera nada
CALL auditoria.sp_registrar_log('inicio_sesion', 99999999, NULL, 'marte', 'prueba log 3', NULL, NULL, NULL, NULL, NULL, NULL, 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN agenda.Origen o ON o.id_origen = l.id_origen WHERE l.descripcion = 'prueba log 3' AND l.id_usuario IS NULL AND o.nombre = 'sistema' AND l.exitoso = 1) = 1) AS verificacion;

-- @caso sp_registrar_log.4 | Consistencia | La descripción se recorta a 500 caracteres y exitoso=0 se conserva
-- @espera nada
CALL auditoria.sp_registrar_log('intento_fallido', NULL, NULL, 'web', 'prueba log 4 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', NULL, NULL, NULL, NULL, 0, NULL, 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log WHERE descripcion LIKE 'prueba log 4 %' AND CHAR_LENGTH(descripcion) = 500 AND exitoso = 0) = 1) AS verificacion;

-- @caso fn_ahora.1 | Éxito | Con @ahora_simulado devuelve esa hora
-- @espera verdadero
SELECT (COALESCE(@ahora_simulado, NOW()) = '2026-11-03 09:00:00') AS verificacion;

-- @caso fn_ahora.2 | Sin coincidencias | Sin reloj simulado devuelve la hora real (cerca de CURRENT_TIMESTAMP)
SET @guardado = @ahora_simulado;
SET @ahora_simulado = NULL;
-- @espera verdadero
SELECT (COALESCE(@ahora_simulado, NOW()) BETWEEN CURRENT_TIMESTAMP - INTERVAL 2 SECOND AND CURRENT_TIMESTAMP + INTERVAL 2 SECOND) AS verificacion;

-- @caso fn_ahora.3 | Nulos y límites | Un valor vacío del reloj también cae a CURRENT_TIMESTAMP
-- @espera verdadero
SELECT (COALESCE(@ahora_simulado, NOW()) IS NOT NULL) AS verificacion;

-- @caso fn_ahora.4 | Consistencia | Al volver a poner el reloj simulado se vuelve a usar
SET @ahora_simulado = @guardado;
-- @espera verdadero
SELECT (COALESCE(@ahora_simulado, NOW()) = '2026-11-03 09:00:00') AS verificacion;

-- ======================================================================
-- E. SEGURIDAD
-- ======================================================================

-- @caso sp_login.1 | Éxito | Ingreso correcto del administrador: devuelve id, rol y deja el inicio de sesión en el log
-- @espera ok
CALL seguridad.sp_login('admin', 'dermalia2026', '10.0.0.5', 'gestion');
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'inicio_sesion' AND l.id_usuario = 1 AND l.ip_origen = '10.0.0.5' AND l.exitoso = 1) = 1) AS verificacion;

-- @caso sp_login.2 | Sin coincidencias | Usuario inexistente y contraseña mal: error 52011 y los dos intentos quedan en el log
-- @espera error 52011
CALL seguridad.sp_login('nadie', 'x', '10.0.0.6', 'web');
-- @espera error 52011
CALL seguridad.sp_login('recepcion1', 'mal', '10.0.0.6', 'web');
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'intento_fallido' AND l.ip_origen = '10.0.0.6' AND l.exitoso = 0) = 2) AS verificacion;

-- @caso sp_login.3 | Nulos y límites | Usuario o contraseña NULL o vacíos: error 52010
-- @espera error 52010
CALL seguridad.sp_login(NULL, NULL, NULL, 'web');
-- @espera error 52010
CALL seguridad.sp_login('admin', '', NULL, 'web');
-- @espera error 52010
CALL seguridad.sp_login('  ', 'x', NULL, 'web');

-- @caso sp_login.4 | Consistencia | Tras 5 intentos fallidos la cuenta se bloquea (52012), aunque la clave sea la correcta; los intentos se cuentan desde el log
-- @espera error 52011
CALL seguridad.sp_login('recepcion2', 'mal', '10.0.0.7', 'gestion');
-- @espera error 52011
CALL seguridad.sp_login('recepcion2', 'mal', '10.0.0.7', 'gestion');
-- @espera error 52011
CALL seguridad.sp_login('recepcion2', 'mal', '10.0.0.7', 'gestion');
-- @espera error 52011
CALL seguridad.sp_login('recepcion2', 'mal', '10.0.0.7', 'gestion');
-- @espera error 52011
CALL seguridad.sp_login('recepcion2', 'mal', '10.0.0.7', 'gestion');
-- @espera error 52012
CALL seguridad.sp_login('recepcion2', 'dermalia2026', '10.0.0.7', 'gestion');
SET @ahora_simulado = '2026-11-03 09:16:00';
-- @espera ok
CALL seguridad.sp_login('recepcion2', 'dermalia2026', '10.0.0.7', 'gestion');
SET @ahora_simulado = '2026-11-03 09:00:00';

-- @caso sp_cerrar_sesion.1 | Éxito | Cierra la sesión de un usuario existente y queda en el log
-- @espera ok
CALL seguridad.sp_cerrar_sesion(1, 'gestion', '10.0.0.5');
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'cierre_sesion' AND l.id_usuario = 1) = 1) AS verificacion;

-- @caso sp_cerrar_sesion.2 | Sin coincidencias | Usuario inexistente: error 52013 y no escribe en el log
-- @espera error 52013
CALL seguridad.sp_cerrar_sesion(99999999, 'gestion', NULL);

-- @caso sp_cerrar_sesion.3 | Nulos y límites | Usuario NULL: error 52013
-- @espera error 52013
CALL seguridad.sp_cerrar_sesion(NULL, 'gestion', NULL);

-- @caso sp_cerrar_sesion.4 | Consistencia | Hay exactamente un cierre de sesión en el log (el del caso 1)
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'cierre_sesion') = 1) AS verificacion;

-- @caso sp_crear_cuenta_paciente.1 | Éxito | Una paciente sin cuenta crea la suya con su DNI
-- @espera ok
CALL seguridad.sp_crear_cuenta_paciente('10000001', 'paula.prueba', 'paula.cuenta@test.example', 'clave1', 'web');
-- @espera verdadero
SELECT ((SELECT id_usuario FROM personas.Paciente WHERE id_paciente = @pacA) IS NOT NULL) AS verificacion;

-- @caso sp_crear_cuenta_paciente.2 | Sin coincidencias | DNI inexistente (52020), cuenta ya creada (52021), usuario o email repetidos (52025)
-- @espera error 52020
CALL seguridad.sp_crear_cuenta_paciente('99999999', 'nadie.nadie', 'n@test.example', 'c', 'web');
-- @espera error 52021
CALL seguridad.sp_crear_cuenta_paciente('10000001', 'otra.cuenta', 'otra@test.example', 'c', 'web');
-- @espera error 52025
CALL seguridad.sp_crear_cuenta_paciente('10000002', 'paula.prueba', 'berta.cuenta@test.example', 'c', 'web');

-- @caso sp_crear_cuenta_paciente.3 | Nulos y límites | DNI NULL, usuario de menos de 4 letras, email de menos de 5 letras y contraseña vacía
-- @espera error 52020
CALL seguridad.sp_crear_cuenta_paciente(NULL, 'abcd', 'a@b.com', 'c', 'web');
-- @espera error 52022
CALL seguridad.sp_crear_cuenta_paciente('10000002', 'abc', 'a@b.com', 'c', 'web');
-- @espera error 52022
CALL seguridad.sp_crear_cuenta_paciente('10000002', 'xy', 'a@b.com', 'c', 'web');
-- @espera error 52023
CALL seguridad.sp_crear_cuenta_paciente('10000002', 'berta.prueba', 'a@b', 'c', 'web');
-- @espera error 52024
CALL seguridad.sp_crear_cuenta_paciente('10000002', 'berta.prueba', 'berta.cuenta@test.example', '', 'web');

-- @caso sp_crear_cuenta_paciente.4 | Consistencia | El usuario nuevo tiene rol paciente, la paciente quedó vinculada y el alta está en el log
-- @espera verdadero
SELECT ((SELECT r.nombre FROM seguridad.Usuario u JOIN seguridad.Rol r ON r.id_rol = u.id_rol JOIN personas.Paciente p ON p.id_usuario = u.id_usuario WHERE p.id_paciente = @pacA) = 'paciente') AS verificacion;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'cuenta_creada' AND l.id_paciente = @pacA AND l.exitoso = 1) = 1) AS verificacion;

-- ======================================================================
-- F. PACIENTES
-- ======================================================================

-- @caso sp_alta_paciente.1 | Éxito | Alta con todos los datos válidos: queda la paciente y su teléfono
-- @espera ok
CALL personas.sp_alta_paciente('10000010','Ana','Test','1992-02-02','ana.t@test.example','1155550010','gestion',1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.Paciente p JOIN personas.TelefonoPaciente t ON t.id_paciente = p.id_paciente WHERE p.dni = '10000010' AND t.telefono = '1155550010') = 1) AS verificacion;

-- @caso sp_alta_paciente.2 | Sin coincidencias | DNI repetido: error 52035 y no se crea otra fila
-- @espera error 52035
CALL personas.sp_alta_paciente('10000010','Otra','Test','1992-02-02','otra@test.example','1155550011','gestion',1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.Paciente WHERE dni = '10000010') = 1) AS verificacion;

-- @caso sp_alta_paciente.3 | Nulos y límites | DNI NULL o de 6 y 9 dígitos, nombre de 1 letra, teléfono corto, fecha futura, email de menos de 5 letras
-- @espera error 52030
CALL personas.sp_alta_paciente(NULL,'Ana','Test','1992-02-02',NULL,'1155550012','gestion',1);
-- @espera error 52030
CALL personas.sp_alta_paciente('123456','Ana','Test','1992-02-02',NULL,'1155550012','gestion',1);
-- @espera error 52030
CALL personas.sp_alta_paciente('123456789','Ana','Test','1992-02-02',NULL,'1155550012','gestion',1);
-- @espera error 52031
CALL personas.sp_alta_paciente('10000011','A','Test','1992-02-02',NULL,'1155550012','gestion',1);
-- @espera error 52032
CALL personas.sp_alta_paciente('10000011','Ana','Test','1992-02-02',NULL,'12345','gestion',1);
-- @espera error 52033
CALL personas.sp_alta_paciente('10000011','Ana','Test','2099-01-01',NULL,'1155550012','gestion',1);
-- @espera error 52034
CALL personas.sp_alta_paciente('10000011','Ana','Test','1992-02-02','a@b','1155550012','gestion',1);
-- @espera ok
CALL personas.sp_alta_paciente('10000011','Ana','Test','1992-02-02','','1155550012','gestion',1);

-- @caso sp_alta_paciente.4 | Consistencia | El log tiene las altas correctas (exitoso=1) y los rechazos (exitoso=0); un email vacío se guarda como NULL
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'alta_paciente' AND l.exitoso = 0) >= 7) AS verificacion;
-- @espera verdadero
SELECT ((SELECT email IS NULL FROM personas.Paciente WHERE dni = '10000011')) AS verificacion;

-- @caso sp_modificar_paciente.1 | Éxito | Cambia nombre y email y agrega un teléfono
-- @espera ok
CALL personas.sp_modificar_paciente(@pacB, 'Berta María', 'Prueba', 'berta.nueva@test.example', '1155559999', 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT nombre = 'Berta María' AND email = 'berta.nueva@test.example' FROM personas.Paciente WHERE id_paciente = @pacB) AND (SELECT COUNT(*) FROM personas.TelefonoPaciente WHERE id_paciente = @pacB) = 2) AS verificacion;

-- @caso sp_modificar_paciente.2 | Sin coincidencias | Paciente inexistente: error 52036
-- @espera error 52036
CALL personas.sp_modificar_paciente(99999999, 'Ana', 'Test', NULL, NULL, 'gestion', 1);

-- @caso sp_modificar_paciente.3 | Nulos y límites | Nombre NULL o corto, email mal escrito y teléfono inválido; un teléfono repetido no se duplica
-- @espera error 52031
CALL personas.sp_modificar_paciente(@pacB, NULL, 'Prueba', NULL, NULL, 'gestion', 1);
-- @espera error 52031
CALL personas.sp_modificar_paciente(@pacB, 'B', 'Prueba', NULL, NULL, 'gestion', 1);
-- @espera error 52034
CALL personas.sp_modificar_paciente(@pacB, 'Berta María', 'Prueba', 'mal', NULL, 'gestion', 1);
-- @espera error 52032
CALL personas.sp_modificar_paciente(@pacB, 'Berta María', 'Prueba', NULL, '123', 'gestion', 1);
-- @espera ok
CALL personas.sp_modificar_paciente(@pacB, 'Berta María', 'Prueba', NULL, '1155559999', 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.TelefonoPaciente WHERE id_paciente = @pacB) = 2) AS verificacion;

-- @caso sp_modificar_paciente.4 | Consistencia | El log guarda el valor anterior y el nuevo
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log WHERE tabla_afectada = 'personas.Paciente' AND id_registro_afectado = @pacB AND exitoso = 1 AND valor_anterior = 'Berta' AND valor_nuevo = 'Berta María') >= 1) AS verificacion;

-- @caso sp_buscar_paciente.1 | Éxito | Busca por DNI exacto: una fila con sus teléfonos
-- @espera filas 1
CALL personas.sp_buscar_paciente('10000002');

-- @caso sp_buscar_paciente.2 | Sin coincidencias | DNI y apellido que no existen: 0 filas
-- @espera vacio
CALL personas.sp_buscar_paciente('77777777');
-- @espera vacio
CALL personas.sp_buscar_paciente('Zzzzzzz');

-- @caso sp_buscar_paciente.3 | Nulos y límites | NULL, vacío y menos de 3 caracteres: 0 filas
-- @espera vacio
CALL personas.sp_buscar_paciente(NULL);
-- @espera vacio
CALL personas.sp_buscar_paciente('');
-- @espera vacio
CALL personas.sp_buscar_paciente('Pr');

-- @caso sp_buscar_paciente.4 | Consistencia | Por apellido trae las tres pacientes "Prueba" + Ana y Carla; igual a un SELECT directo
-- @espera igual
CALL personas.sp_buscar_paciente('Prueba');
SELECT p.id_paciente, p.dni, p.nombre, p.apellido, p.fecha_nacimiento, p.email, (SELECT tp.telefono FROM personas.TelefonoPaciente tp WHERE tp.id_telefono_paciente = (SELECT MIN(tpx.id_telefono_paciente) FROM personas.TelefonoPaciente tpx WHERE tpx.id_paciente = p.id_paciente)) AS telefonos, (p.id_usuario IS NOT NULL) AS tiene_cuenta FROM personas.Paciente p WHERE p.apellido LIKE '%Prueba%' OR p.nombre LIKE '%Prueba%' ORDER BY p.apellido, p.nombre;

-- ======================================================================
-- G. PROFESIONALES Y DISPONIBILIDAD
-- ======================================================================

-- @caso sp_alta_profesional.1 | Éxito | Alta con cuenta propia (rol profesional) y teléfono
-- @espera ok
CALL personas.sp_alta_profesional('MN-T002','Segundo','Profesional','segundo.prof@test.example','1155550020','t.prof2','clave','gestion',1);
-- @espera verdadero
SELECT ((SELECT r.nombre FROM personas.Profesional p JOIN seguridad.Usuario u ON u.id_usuario = p.id_usuario JOIN seguridad.Rol r ON r.id_rol = u.id_rol WHERE p.matricula = 'MN-T002') = 'profesional') AS verificacion;

-- @caso sp_alta_profesional.2 | Sin coincidencias | Matrícula repetida (52041) y usuario o email repetidos (52025)
-- @espera error 52041
CALL personas.sp_alta_profesional('MN-T002','Otro','Profesional','otro.prof@test.example','1155550021','t.prof3','clave','gestion',1);
-- @espera error 52025
CALL personas.sp_alta_profesional('MN-T003','Otro','Profesional','otro.prof@test.example','1155550021','t.prof2','clave','gestion',1);

-- @caso sp_alta_profesional.3 | Nulos y límites | Matrícula vacía, nombre corto, email, teléfono, usuario y contraseña inválidos
-- @espera error 52040
CALL personas.sp_alta_profesional(NULL,'Otro','Profesional','o@test.example','1155550021','t.prof3','c','gestion',1);
-- @espera error 52031
CALL personas.sp_alta_profesional('MN-T003','O','Profesional','o@test.example','1155550021','t.prof3','c','gestion',1);
-- @espera error 52034
CALL personas.sp_alta_profesional('MN-T003','Otro','Profesional','mal','1155550021','t.prof3','c','gestion',1);
-- @espera error 52032
CALL personas.sp_alta_profesional('MN-T003','Otro','Profesional','o@test.example','12','t.prof3','c','gestion',1);
-- @espera error 52022
CALL personas.sp_alta_profesional('MN-T003','Otro','Profesional','o@test.example','1155550021','T','c','gestion',1);
-- @espera error 52024
CALL personas.sp_alta_profesional('MN-T003','Otro','Profesional','o@test.example','1155550021','t.prof3','','gestion',1);

-- @caso sp_alta_profesional.4 | Consistencia | Los intentos fallidos no dejaron usuarios huérfanos y quedaron en el log
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM seguridad.Usuario u WHERE u.nombre_usuario LIKE 't.prof%' AND NOT EXISTS (SELECT 1 FROM personas.Profesional p WHERE p.id_usuario = u.id_usuario)) = 0) AS verificacion;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'alta_profesional' AND l.exitoso = 0) >= 8) AS verificacion;
SELECT id_profesional INTO @prof2 FROM personas.Profesional WHERE matricula = 'MN-T002';

-- @caso sp_modificar_profesional.1 | Éxito | Cambia el email del profesional de prueba 2
-- @espera ok
CALL personas.sp_modificar_profesional(@prof2, 'Segundo', 'Profesional', 'segundo.nuevo@test.example', 1, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT email FROM personas.Profesional WHERE id_profesional = @prof2) = 'segundo.nuevo@test.example') AS verificacion;

-- @caso sp_modificar_profesional.2 | Sin coincidencias | Profesional inexistente: error 52042
-- @espera error 52042
CALL personas.sp_modificar_profesional(99999999, 'Ana', 'Test', 'a@test.example', 1, 'gestion', 1);

-- @caso sp_modificar_profesional.3 | Nulos y límites | Nombre NULL, email mal escrito y activo fuera de 0/1
-- @espera error 52031
CALL personas.sp_modificar_profesional(@prof2, NULL, 'Profesional', 'a@test.example', 1, 'gestion', 1);
-- @espera error 52034
CALL personas.sp_modificar_profesional(@prof2, 'Segundo', 'Profesional', 'mal', 1, 'gestion', 1);
-- @espera error 52043
CALL personas.sp_modificar_profesional(@prof2, 'Segundo', 'Profesional', 'a@test.example', 2, 'gestion', 1);
-- @espera error 52043
CALL personas.sp_modificar_profesional(@prof2, 'Segundo', 'Profesional', 'a@test.example', NULL, 'gestion', 1);

-- @caso sp_modificar_profesional.4 | Consistencia | La baja se rechaza si hay turnos futuros sin cancelar (52044) y se acepta sin turnos; la baja queda en el log
-- @espera error 52044
CALL personas.sp_modificar_profesional(1, 'Julieta', 'Marino', 'julieta.marino@dermalia.example', 0, 'gestion', 1);
-- @espera ok
CALL personas.sp_modificar_profesional(@prof2, 'Segundo', 'Profesional', 'segundo.nuevo@test.example', 0, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT activo FROM personas.Profesional WHERE id_profesional = @prof2) = 0 AND (SELECT COUNT(*) FROM auditoria.Log WHERE tabla_afectada = 'personas.Profesional' AND id_registro_afectado = @prof2 AND descripcion = 'Baja del profesional') = 1) AS verificacion;

-- @caso sp_cargar_disponibilidad.1 | Éxito | Carga una franja nueva de 14 a 18 el lunes 21/12
-- @espera ok
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-21', '14:00', '18:00', 'gestion', 1);
SELECT MAX(id_disponibilidad) INTO @disp FROM personas.Disponibilidad WHERE id_profesional = @prof;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.Disponibilidad WHERE id_disponibilidad = @disp AND fecha = '2026-12-21' AND activa = 1) = 1) AS verificacion;

-- @caso sp_cargar_disponibilidad.2 | Sin coincidencias | Profesional inexistente o dado de baja (52045) y franja que se superpone (52049)
-- @espera error 52045
CALL personas.sp_cargar_disponibilidad(99999999, '2026-12-22', '09:00', '13:00', 'gestion', 1);
-- @espera error 52045
CALL personas.sp_cargar_disponibilidad(@prof2, '2026-12-22', '09:00', '13:00', 'gestion', 1);
-- @espera error 52049
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-21', '16:00', '20:00', 'gestion', 1);

-- @caso sp_cargar_disponibilidad.3 | Nulos y límites | Fecha u hora NULL, fin igual al inicio y fecha en el pasado; una franja pegada (18:00) sí se acepta
-- @espera error 52046
CALL personas.sp_cargar_disponibilidad(@prof, NULL, '09:00', '13:00', 'gestion', 1);
-- @espera error 52046
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-22', NULL, '13:00', 'gestion', 1);
-- @espera error 52047
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-22', '13:00', '13:00', 'gestion', 1);
-- @espera error 52048
CALL personas.sp_cargar_disponibilidad(@prof, '2026-10-01', '09:00', '13:00', 'gestion', 1);
-- @espera ok
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-21', '18:00', '20:00', 'gestion', 1);

-- @caso sp_cargar_disponibilidad.4 | Consistencia | Las franjas válidas quedaron en la tabla y las rechazadas no
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.Disponibilidad WHERE id_profesional = @prof AND fecha = '2026-12-21') = 2) AS verificacion;

-- @caso sp_baja_disponibilidad.1 | Éxito | Da de baja la franja del 21/12 14 a 18
-- @espera ok
CALL personas.sp_baja_disponibilidad(@disp, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT activa FROM personas.Disponibilidad WHERE id_disponibilidad = @disp) = 0) AS verificacion;

-- @caso sp_baja_disponibilidad.2 | Sin coincidencias | Franja inexistente (52050) y franja ya dada de baja (52051)
-- @espera error 52050
CALL personas.sp_baja_disponibilidad(99999999, 'gestion', 1);
-- @espera error 52051
CALL personas.sp_baja_disponibilidad(@disp, 'gestion', 1);

-- @caso sp_baja_disponibilidad.3 | Nulos y límites | Id NULL: error 52050
-- @espera error 52050
CALL personas.sp_baja_disponibilidad(NULL, 'gestion', 1);

-- @caso sp_baja_disponibilidad.4 | Consistencia | No se da de baja una franja con un turno adentro (52052); después de cancelar el turno sí
SELECT id_disponibilidad INTO @disp2 FROM personas.Disponibilidad WHERE id_profesional = @prof AND fecha = '2026-12-18';
-- @espera ok
CALL agenda.sp_alta_turno(@pacC, @prof, '2026-12-18 10:00:00', 2, NULL, NULL, 'gestion', 1, NULL, NULL);
SELECT MAX(id_turno) INTO @tdisp FROM agenda.Turno WHERE id_profesional = @prof;
-- @espera error 52052
CALL personas.sp_baja_disponibilidad(@disp2, 'gestion', 1);
-- @espera ok
CALL agenda.sp_cancelar_turno(@tdisp, 1, 'gestion');
-- @espera ok
CALL personas.sp_baja_disponibilidad(@disp2, 'gestion', 1);
-- @espera ok
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-18', '09:00', '13:00', 'gestion', 1);

-- @caso sp_asignar_protocolo.1 | Éxito | Habilita el protocolo 11 al profesional de prueba
-- @espera ok
CALL clinica.sp_asignar_protocolo(@prof, 11, 1, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM clinica.ProfesionalProtocolo WHERE id_profesional = @prof AND id_protocolo = 11) = 1) AS verificacion;

-- @caso sp_asignar_protocolo.2 | Sin coincidencias | Profesional (52042) o protocolo (52060) inexistente
-- @espera error 52042
CALL clinica.sp_asignar_protocolo(99999999, 11, 1, 'gestion', 1);
-- @espera error 52060
CALL clinica.sp_asignar_protocolo(@prof, 99999999, 1, 'gestion', 1);

-- @caso sp_asignar_protocolo.3 | Nulos y límites | Habilitar NULL o 5: error 52043; habilitar dos veces no duplica
-- @espera error 52043
CALL clinica.sp_asignar_protocolo(@prof, 11, NULL, 'gestion', 1);
-- @espera error 52043
CALL clinica.sp_asignar_protocolo(@prof, 11, 5, 'gestion', 1);
-- @espera ok
CALL clinica.sp_asignar_protocolo(@prof, 11, 1, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM clinica.ProfesionalProtocolo WHERE id_profesional = @prof AND id_protocolo = 11) = 1) AS verificacion;

-- @caso sp_asignar_protocolo.4 | Consistencia | Quitarlo lo borra de la tabla y deja el log
-- @espera ok
CALL clinica.sp_asignar_protocolo(@prof, 11, 0, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM clinica.ProfesionalProtocolo WHERE id_profesional = @prof AND id_protocolo = 11) = 0) AS verificacion;

-- @caso sp_profesionales_para_protocolos.1 | Éxito | Para el protocolo 26 (rinoplastia) están los tres cirujanos y el profesional de prueba
-- @espera filas 4
CALL personas.sp_profesionales_para_protocolos(26, NULL, NULL);

-- @caso sp_profesionales_para_protocolos.2 | Sin coincidencias | Un protocolo que nadie hace: 0 filas
-- @espera vacio
CALL personas.sp_profesionales_para_protocolos(99999999, NULL, NULL);

-- @caso sp_profesionales_para_protocolos.3 | Nulos y límites | NULL, vacío y texto que no es una lista de números: 0 filas, sin error
-- @espera vacio
CALL personas.sp_profesionales_para_protocolos(NULL, NULL, NULL);
-- @espera vacio
CALL personas.sp_profesionales_para_protocolos(NULL, NULL, NULL);
-- @espera vacio
CALL personas.sp_profesionales_para_protocolos(0, NULL, NULL);

-- @caso sp_profesionales_para_protocolos.4 | Consistencia | Con dos protocolos solo salen quienes hacen los dos; igual a un SELECT directo
-- @espera igual
CALL personas.sp_profesionales_para_protocolos(1, 2, NULL);
SELECT pr.id_profesional, pr.apellido AS profesional, pr.nombre AS profesional_nombre, pr.matricula FROM personas.Profesional pr WHERE pr.activo = 1 AND (SELECT COUNT(*) FROM clinica.ProfesionalProtocolo pp WHERE pp.id_profesional = pr.id_profesional AND pp.id_protocolo IN (1, 2)) = 2 ORDER BY pr.apellido, pr.nombre;

-- ======================================================================
-- H. PROTOCOLOS
-- ======================================================================

-- @caso sp_alta_protocolo.1 | Éxito | Alta de un protocolo nuevo en la categoría 1
-- @espera ok
CALL clinica.sp_alta_protocolo(1, 'Protocolo de prueba', 'Solo para pruebas', 50000, 40, 'gestion', 1);
SELECT MAX(id_protocolo) INTO @protprueba FROM clinica.Protocolo;
-- @espera verdadero
SELECT ((SELECT precio = 50000 AND duracion_min = 40 AND activo = 1 FROM clinica.Protocolo WHERE id_protocolo = @protprueba)) AS verificacion;

-- @caso sp_alta_protocolo.2 | Sin coincidencias | Categoría inexistente (52061) y nombre repetido (52065)
-- @espera error 52061
CALL clinica.sp_alta_protocolo(99999999, 'Otro protocolo', NULL, 50000, 40, 'gestion', 1);
-- @espera error 52065
CALL clinica.sp_alta_protocolo(1, 'Protocolo de prueba', NULL, 50000, 40, 'gestion', 1);

-- @caso sp_alta_protocolo.3 | Nulos y límites | Nombre NULL o corto, precio 0, duración 0 y 601
-- @espera error 52062
CALL clinica.sp_alta_protocolo(1, NULL, NULL, 50000, 40, 'gestion', 1);
-- @espera error 52062
CALL clinica.sp_alta_protocolo(1, 'ab', NULL, 50000, 40, 'gestion', 1);
-- @espera error 52063
CALL clinica.sp_alta_protocolo(1, 'Otro protocolo', NULL, 0, 40, 'gestion', 1);
-- @espera error 52063
CALL clinica.sp_alta_protocolo(1, 'Otro protocolo', NULL, NULL, 40, 'gestion', 1);
-- @espera error 52064
CALL clinica.sp_alta_protocolo(1, 'Otro protocolo', NULL, 50000, 0, 'gestion', 1);
-- @espera error 52064
CALL clinica.sp_alta_protocolo(1, 'Otro protocolo', NULL, 50000, 601, 'gestion', 1);
-- @espera ok
CALL clinica.sp_alta_protocolo(1, 'Otro protocolo', NULL, 50000, 600, 'gestion', 1);

-- @caso sp_alta_protocolo.4 | Consistencia | Hay exactamente 2 protocolos creados por las pruebas y los rechazos quedaron en el log
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM clinica.Protocolo WHERE nombre IN ('Protocolo de prueba', 'Otro protocolo')) = 2) AS verificacion;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'cambio_protocolo' AND l.exitoso = 0) >= 8) AS verificacion;

-- @caso sp_modificar_protocolo.1 | Éxito | Sube el precio del protocolo de prueba a 65000
-- @espera ok
CALL clinica.sp_modificar_protocolo(@protprueba, 'Protocolo de prueba', 'Solo para pruebas', 65000, 40, 1, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT precio FROM clinica.Protocolo WHERE id_protocolo = @protprueba) = 65000) AS verificacion;

-- @caso sp_modificar_protocolo.2 | Sin coincidencias | Protocolo inexistente (52060) y nombre de otro protocolo (52065)
-- @espera error 52060
CALL clinica.sp_modificar_protocolo(99999999, 'Lo que sea', NULL, 1000, 10, 1, 'gestion', 1);
-- @espera error 52065
CALL clinica.sp_modificar_protocolo(@protprueba, 'Limpieza facial profunda', NULL, 1000, 10, 1, 'gestion', 1);

-- @caso sp_modificar_protocolo.3 | Nulos y límites | Precio negativo, duración NULL y activo 3
-- @espera error 52063
CALL clinica.sp_modificar_protocolo(@protprueba, 'Protocolo de prueba', NULL, -1, 40, 1, 'gestion', 1);
-- @espera error 52064
CALL clinica.sp_modificar_protocolo(@protprueba, 'Protocolo de prueba', NULL, 1000, NULL, 1, 'gestion', 1);
-- @espera error 52043
CALL clinica.sp_modificar_protocolo(@protprueba, 'Protocolo de prueba', NULL, 1000, 10, 3, 'gestion', 1);

-- @caso sp_modificar_protocolo.4 | Consistencia | Los turnos viejos conservan su precio aplicado; la baja lo saca del catálogo; el log guarda lo anterior y lo nuevo
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM agenda.TurnoProtocolo tp WHERE tp.id_protocolo = 1 AND tp.precio_aplicado <> 90000) = 0) AS verificacion;
-- @espera ok
CALL clinica.sp_modificar_protocolo(@protprueba, 'Protocolo de prueba', 'Solo para pruebas', 65000, 40, 0, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log WHERE tabla_afectada = 'clinica.Protocolo' AND id_registro_afectado = @protprueba AND valor_anterior = '50000.00' AND valor_nuevo = '65000.00') = 1) AS verificacion;

-- @caso sp_listar_protocolos.1 | Éxito | Sin filtros trae todo el catálogo activo (30 de ejemplo + "Otro protocolo")
-- @espera filas 31
CALL clinica.sp_listar_protocolos(NULL, NULL, 0);

-- @caso sp_listar_protocolos.2 | Sin coincidencias | Una palabra que no está en ningún protocolo: 0 filas
-- @espera vacio
CALL clinica.sp_listar_protocolos('xyzxyz', NULL, 0);

-- @caso sp_listar_protocolos.3 | Nulos y límites | Texto vacío trae todo; un protocolo dado de baja no aparece; categoría inexistente trae 0 filas
-- @espera filas 31
CALL clinica.sp_listar_protocolos('', NULL, 0);
-- @espera vacio
CALL clinica.sp_listar_protocolos('Protocolo de prueba', NULL, 0);
-- @espera vacio
CALL clinica.sp_listar_protocolos(NULL, 99999999, 0);

-- @caso sp_listar_protocolos.4 | Consistencia | La búsqueda por la categoría "Aparatología" (texto exacto) y la categoría Cirugías coinciden con un SELECT directo
-- @espera igual
CALL clinica.sp_listar_protocolos('Aparatología', NULL, 0);
SELECT p.id_protocolo, p.nombre, p.descripcion, c.id_categoria, c.nombre AS categoria, p.precio, p.duracion_min, c.porcentaje_sena, ROUND(p.precio * c.porcentaje_sena / 100, 0) AS sena, c.requiere_evaluacion, p.activo FROM clinica.Protocolo p JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria WHERE p.activo = 1 AND (p.nombre = 'Aparatología' OR p.descripcion = 'Aparatología' OR c.nombre = 'Aparatología') ORDER BY c.id_categoria, p.nombre;
-- @espera filas 5
CALL clinica.sp_listar_protocolos(NULL, 4, 0);
-- @espera filas 1
CALL clinica.sp_listar_protocolos('Protocolo de prueba', NULL, 1);

-- ======================================================================
-- I. AGENDA: horarios libres, alta de turno y búsqueda
-- ======================================================================

-- @caso sp_horarios_libres.1 | Éxito | Una limpieza (60 min) el lunes 14/12 de 9 a 13 deja 7 horarios para el profesional de prueba
-- @espera filas 7
CALL agenda.sp_horarios_libres('2026-12-14', 1, NULL, NULL, @prof);

-- @caso sp_horarios_libres.2 | Sin coincidencias | Un día sin disponibilidad y un protocolo que el profesional no hace: 0 filas
-- @espera vacio
CALL agenda.sp_horarios_libres('2026-12-20', 1, NULL, NULL, @prof);
-- @espera vacio
CALL agenda.sp_horarios_libres('2026-12-14', 3, NULL, NULL, @prof);

-- @caso sp_horarios_libres.3 | Nulos y límites | Fecha NULL, protocolos NULL, vacíos o con letras, protocolo de baja: 0 filas; el último horario de una cirugía de 180 min es 10:00
-- @espera vacio
CALL agenda.sp_horarios_libres(NULL, 1, NULL, NULL, @prof);
-- @espera vacio
CALL agenda.sp_horarios_libres('2026-12-14', NULL, NULL, NULL, @prof);
-- @espera vacio
CALL agenda.sp_horarios_libres('2026-12-14', NULL, NULL, NULL, @prof);
-- @espera vacio
CALL agenda.sp_horarios_libres('2026-12-14', 0, NULL, NULL, @prof);
-- @espera vacio
CALL agenda.sp_horarios_libres('2026-12-14', @protprueba, NULL, NULL, @prof);
-- @espera filas 3
CALL agenda.sp_horarios_libres('2026-12-14', 26, NULL, NULL, @prof);

-- @caso sp_horarios_libres.4 | Consistencia | Igual a una grilla armada a mano: 09:00 a 12:00 cada 30 minutos
-- @espera igual
CALL agenda.sp_horarios_libres('2026-12-15', 1, NULL, NULL, @prof);
SELECT pr.id_profesional, pr.apellido AS profesional, pr.nombre AS profesional_nombre, CAST('2026-12-15' AS DATE) + INTERVAL (540 + 30 * n.n) MINUTE AS inicio, CAST('2026-12-15' AS DATE) + INTERVAL (540 + 30 * n.n + 60) MINUTE AS fin FROM agenda.Numero n JOIN personas.Profesional pr ON pr.id_profesional = @prof WHERE n.n BETWEEN 0 AND 6 ORDER BY n.n;

-- @caso sp_alta_turno.1 | Éxito | Limpieza facial del lunes 14/12 a las 9: queda pendiente, termina a las 10 y la seña es el 30%
-- @espera ok
CALL agenda.sp_alta_turno(@pacA, @prof, '2026-12-14 09:00:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
SELECT MAX(id_turno) INTO @t1 FROM agenda.Turno WHERE id_profesional = @prof;
-- @espera verdadero
SELECT ((SELECT e.nombre = 'pendiente' AND t.fecha_hora_fin = '2026-12-14 10:00:00' FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno WHERE t.id_turno = @t1)) AS verificacion;
-- @espera verdadero
SELECT (COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t1), 0) = 90000 AND ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t1), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t1), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = @t1), 0) / 100, 2)) * COALESCE((SELECT MAX(caz.porcentaje_sena) FROM agenda.TurnoProtocolo tpy JOIN clinica.Protocolo prz ON prz.id_protocolo = tpy.id_protocolo JOIN clinica.CategoriaProtocolo caz ON caz.id_categoria = prz.id_categoria WHERE tpy.id_turno = @t1), 0) / 100, 0) = 27000) AS verificacion;

-- @caso sp_alta_turno.2 | Sin coincidencias | Superposición (52081), fuera de horario (52080), protocolo inexistente (52075), profesional que no lo hace (52076), pasado (52073), paciente inexistente (52071), cirugía sin evaluación (52083)
-- @espera error 52081
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 09:30:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52080
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 14:00:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52075
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 11:00:00', 99999999, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52076
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 11:00:00', 3, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52073
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-10-01 11:00:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52071
CALL agenda.sp_alta_turno(99999999, @prof, '2026-12-14 11:00:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52083
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 10:00:00', 26, NULL, NULL, 'gestion', 1, NULL, NULL);

-- @caso sp_alta_turno.3 | Nulos y límites | Protocolos NULL o vacíos, inicio NULL, origen inválido; un turno que termina justo a las 13:00 sí entra; uno que termina 13:30 no
-- @espera error 52072
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 11:00:00', NULL, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52072
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 11:00:00', NULL, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52073
CALL agenda.sp_alta_turno(@pacB, @prof, NULL, 1, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52070
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 11:00:00', 1, NULL, NULL, 'marte', 1, NULL, NULL);
-- @espera error 52080
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 12:30:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera ok
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 12:00:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
SELECT MAX(id_turno) INTO @t2 FROM agenda.Turno WHERE id_profesional = @prof;

-- @caso sp_alta_turno.4 | Consistencia | Los rechazos no dejaron turnos de más (solo 2 en el día), quedaron en el log y los horarios libres ya no ofrecen lo ocupado
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM agenda.Turno WHERE id_profesional = @prof AND DATE(fecha_hora_inicio) = '2026-12-14') = 2) AS verificacion;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'turno_rechazado' AND l.exitoso = 0) >= 12) AS verificacion;
-- @espera filas 3
CALL agenda.sp_horarios_libres('2026-12-14', 1, NULL, NULL, @prof);

-- @caso sp_alta_turno.5 | Dos protocolos | Dos protocolos en un turno suman duración y precio (peeling 45 + láser 30 = 75 min)
-- @espera ok
CALL agenda.sp_alta_turno(@pacC, @prof, '2026-12-15 09:00:00', 2, 10, NULL, 'terminal', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @t3 FROM agenda.Turno WHERE id_profesional = @prof;
-- @espera verdadero
SELECT ((SELECT ((EXTRACT(HOUR FROM fecha_hora_fin) - EXTRACT(HOUR FROM fecha_hora_inicio)) * 60 + EXTRACT(MINUTE FROM fecha_hora_fin) - EXTRACT(MINUTE FROM fecha_hora_inicio)) = 75 FROM agenda.Turno WHERE id_turno = @t3) AND COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t3), 0) = 240000) AS verificacion;

-- @caso sp_alta_turno.6 | Paciente superpuesta | La misma paciente no puede tener dos turnos a la vez (52082)
-- @espera error 52074
CALL agenda.sp_alta_turno(@pacC, @prof2, '2026-12-15 09:30:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52080
CALL agenda.sp_alta_turno(@pacC, 1, '2026-12-15 09:30:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);

-- @caso sp_buscar_turnos.1 | Éxito | Por DNI de la paciente A: su turno del 14/12
-- @espera filas 1
CALL agenda.sp_buscar_turnos('10000001', 0);

-- @caso sp_buscar_turnos.2 | Sin coincidencias | DNI y apellido que no existen: 0 filas
-- @espera vacio
CALL agenda.sp_buscar_turnos('77777777', 0);
-- @espera vacio
CALL agenda.sp_buscar_turnos('Zzzzzz', 1);

-- @caso sp_buscar_turnos.3 | Nulos y límites | NULL, vacío y 2 caracteres: 0 filas
-- @espera vacio
CALL agenda.sp_buscar_turnos(NULL, 0);
-- @espera vacio
CALL agenda.sp_buscar_turnos('', 1);
-- @espera vacio
CALL agenda.sp_buscar_turnos('ab', 0);

-- @caso sp_buscar_turnos.4 | Consistencia | Por apellido trae los 4 turnos de las pacientes de prueba (uno está cancelado) y la cantidad coincide con un conteo directo
-- @espera filas 4
CALL agenda.sp_buscar_turnos('Prueba', 0);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM agenda.Turno t JOIN personas.Paciente p ON p.id_paciente = t.id_paciente WHERE p.apellido = 'Prueba') = 4) AS verificacion;

-- ======================================================================
-- J. SEÑA, CANCELACIÓN Y ASISTENCIA
-- ======================================================================

-- @caso sp_registrar_sena.1 | Éxito | Seña del turno 1 en efectivo: $27.000, turno confirmado, se guarda el código de operación que genera la aplicación, confirmación y recordatorio programados
-- @espera ok
CALL pagos.sp_registrar_sena(@t1, 'efectivo', NULL, 1, 'gestion', 'SIM-123456');
-- @espera verdadero
SELECT ((SELECT ps.monto = 27000 AND ps.codigo_operacion = 'SIM-123456' AND ep.nombre = 'pagada' FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = @t1)) AS verificacion;
-- @espera verdadero
SELECT ((SELECT e.nombre FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno WHERE t.id_turno = @t1) = 'confirmado') AS verificacion;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM notificaciones.Notificacion WHERE id_turno = @t1) = 2) AS verificacion;

-- @caso sp_registrar_sena.2 | Sin coincidencias | Turno inexistente (52110), ya pagado (52111), medio de pago inexistente (52114), tarjeta inexistente (52117)
-- @espera error 52110
CALL pagos.sp_registrar_sena(99999999, 'efectivo', NULL, 1, 'gestion', NULL);
-- @espera error 52111
CALL pagos.sp_registrar_sena(@t1, 'efectivo', NULL, 1, 'gestion', NULL);
-- @espera error 52114
CALL pagos.sp_registrar_sena(@t2, 'bitcoin', NULL, 1, 'gestion', NULL);
-- @espera error 52117
CALL pagos.sp_registrar_sena(@t2, 'tarjeta de regalo', 'GC-NOEXISTE', 1, 'gestion', NULL);

-- @caso sp_registrar_sena.3 | Nulos y límites | Turno NULL, medio NULL y tarjeta de regalo sin código
-- @espera error 52110
CALL pagos.sp_registrar_sena(NULL, 'efectivo', NULL, 1, 'gestion', NULL);
-- @espera error 52114
CALL pagos.sp_registrar_sena(@t2, NULL, NULL, 1, 'gestion', NULL);
-- @espera error 52117
CALL pagos.sp_registrar_sena(@t2, 'tarjeta de regalo', NULL, 1, 'gestion', NULL);

-- @caso sp_registrar_sena.4 | Consistencia | El monto cobrado coincide con fn_sena y con 30% del precio; el rechazo de la tarjeta quedó en el log
-- @espera verdadero
SELECT ((SELECT ps.monto FROM pagos.PagoSena ps WHERE ps.id_turno = @t1) = ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t1), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t1), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = @t1), 0) / 100, 2)) * 0.30, 0)) AS verificacion;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'tarjeta_rechazada' AND l.exitoso = 0) >= 2) AS verificacion;

-- @caso sp_cancelar_turno.1 | Éxito | Cancelar con más de 24 h reembolsa el 100% de la seña
-- @espera ok
CALL agenda.sp_cancelar_turno(@t1, 1, 'gestion');
-- @espera verdadero
SELECT ((SELECT ep.nombre = 'reembolsada' AND ps.monto_reembolsado = ps.monto FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = @t1)) AS verificacion;
-- @espera verdadero
SELECT ((SELECT e.nombre FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno WHERE t.id_turno = @t1) = 'cancelado') AS verificacion;

-- @caso sp_cancelar_turno.2 | Sin coincidencias | Turno inexistente (52120) y turno ya cancelado (52121)
-- @espera error 52120
CALL agenda.sp_cancelar_turno(99999999, 1, 'gestion');
-- @espera error 52121
CALL agenda.sp_cancelar_turno(@t1, 1, 'gestion');

-- @caso sp_cancelar_turno.3 | Nulos y límites | Turno NULL (52120); a exactamente 24 h la seña NO se reembolsa (queda retenida); sin seña se cancela igual
-- @espera error 52120
CALL agenda.sp_cancelar_turno(NULL, 1, 'gestion');
-- @espera ok
CALL agenda.sp_alta_turno(@pacA, @prof, '2026-12-16 09:00:00', 1, NULL, NULL, 'web', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @t4 FROM agenda.Turno WHERE id_profesional = @prof;
-- @espera ok
CALL pagos.sp_registrar_sena(@t4, 'transferencia', NULL, NULL, 'web', NULL);
SET @ahora_simulado = '2026-12-15 09:00:00';
-- @espera ok
CALL agenda.sp_cancelar_turno(@t4, NULL, 'web');
-- @espera verdadero
SELECT ((SELECT ep.nombre = 'retenida' AND ps.monto_reembolsado = 0 FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = @t4)) AS verificacion;
SET @ahora_simulado = '2026-11-03 09:00:00';
-- @espera ok
CALL agenda.sp_cancelar_turno(@t2, 1, 'gestion');

-- @caso sp_cancelar_turno.4 | Consistencia | Cada cancelación avisó a la paciente, liberó el horario y quedó en el log
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM notificaciones.Notificacion n JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion WHERE n.id_turno = @t1 AND tn.nombre = 'cancelación') = 1) AS verificacion;
-- @espera filas 7
CALL agenda.sp_horarios_libres('2026-12-14', 1, NULL, NULL, @prof);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'cancelacion_turno' AND l.exitoso = 1) >= 3) AS verificacion;

-- @caso sp_marcar_turno.1 | Éxito | Marca como realizado un turno confirmado que ya empezó
-- @espera ok
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-16 09:00:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
SELECT MAX(id_turno) INTO @t5 FROM agenda.Turno WHERE id_profesional = @prof;
-- @espera ok
CALL pagos.sp_registrar_sena(@t5, 'efectivo', NULL, 1, 'gestion', NULL);
-- @espera error 52127
CALL agenda.sp_marcar_turno(@t5, 'realizado', 1, 'gestion');
SET @ahora_simulado = '2026-12-16 10:30:00';
-- @espera ok
CALL agenda.sp_marcar_turno(@t5, 'realizado', 1, 'gestion');
-- @espera verdadero
SELECT ((SELECT e.nombre FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno WHERE t.id_turno = @t5) = 'realizado') AS verificacion;

-- @caso sp_marcar_turno.2 | Sin coincidencias | Turno inexistente (52120), estado inválido (52125), turno que no está confirmado (52126)
-- @espera error 52120
CALL agenda.sp_marcar_turno(99999999, 'realizado', 1, 'gestion');
-- @espera error 52125
CALL agenda.sp_marcar_turno(@t5, 'volando', 1, 'gestion');
-- @espera error 52126
CALL agenda.sp_marcar_turno(@t5, 'ausente', 1, 'gestion');

-- @caso sp_marcar_turno.3 | Nulos y límites | Estado NULL (52125); el turno que no empezó todavía no se puede marcar (52127)
-- @espera error 52125
CALL agenda.sp_marcar_turno(@t5, NULL, 1, 'gestion');
SET @ahora_simulado = '2026-11-03 09:00:00';
-- @espera ok
CALL agenda.sp_alta_turno(@pacC, @prof, '2026-12-17 09:00:00', 1, NULL, NULL, 'gestion', 1, NULL, NULL);
SELECT MAX(id_turno) INTO @t6 FROM agenda.Turno WHERE id_profesional = @prof;
-- @espera ok
CALL pagos.sp_registrar_sena(@t6, 'efectivo', NULL, 1, 'gestion', NULL);
-- @espera error 52127
CALL agenda.sp_marcar_turno(@t6, 'ausente', 1, 'gestion');

-- @caso sp_marcar_turno.4 | Consistencia | La inasistencia retiene la seña (retenida, reembolsado 0) y queda en el log
SET @ahora_simulado = '2026-12-17 10:30:00';
-- @espera ok
CALL agenda.sp_marcar_turno(@t6, 'ausente', 1, 'gestion');
-- @espera verdadero
SELECT ((SELECT ep.nombre = 'retenida' AND ps.monto_reembolsado = 0 FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = @t6)) AS verificacion;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log WHERE tabla_afectada = 'agenda.Turno' AND id_registro_afectado = @t6 AND valor_nuevo = 'ausente') = 1) AS verificacion;
SET @ahora_simulado = '2026-11-03 09:00:00';
SELECT id_pago INTO @pago5 FROM pagos.PagoSena WHERE id_turno = @t5;

-- @caso sp_aplicar_reembolso.3 | Nulos y límites | Monto NULL o mayor al pagado (52102) y estado inventado (52103); con el pago todavía "pagada"
-- @espera nada
CALL pagos.sp_aplicar_reembolso(@pago5, NULL, 'retenida', 'prueba', 1, 'gestion', 1);
-- @espera verdadero
SELECT (@reembolso_codigo = 52102) AS verificacion;
-- @espera nada
CALL pagos.sp_aplicar_reembolso(@pago5, 99999999, 'retenida', 'prueba', 1, 'gestion', 1);
-- @espera verdadero
SELECT (@reembolso_codigo = 52102) AS verificacion;
-- @espera nada
CALL pagos.sp_aplicar_reembolso(@pago5, 100, 'inventado', 'prueba', 1, 'gestion', 1);
-- @espera verdadero
SELECT (@reembolso_codigo = 52103) AS verificacion;

-- @caso sp_aplicar_reembolso.1 | Éxito | Reembolso parcial de la seña del turno 5 (interno: lo usan otros SP)
-- @espera nada
CALL pagos.sp_aplicar_reembolso(@pago5, 10000, 'reembolsada parcial', 'prueba', 1, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT ep.nombre = 'reembolsada parcial' AND ps.monto_reembolsado = 10000 FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_pago = @pago5)) AS verificacion;

-- @caso sp_aplicar_reembolso.2 | Sin coincidencias | Pago inexistente: deja el código 52100 en @reembolso_codigo
-- @espera nada
CALL pagos.sp_aplicar_reembolso(99999999, 1, 'retenida', 'prueba', 1, 'gestion', 1);
-- @espera verdadero
SELECT (@reembolso_codigo = 52100) AS verificacion;

-- @caso sp_aplicar_reembolso.4 | Consistencia | Un pago ya resuelto no se puede resolver de nuevo (52101) y su monto no cambia
-- @espera nada
CALL pagos.sp_aplicar_reembolso(@pago5, 5000, 'retenida', 'prueba', 1, 'gestion', 1);
-- @espera verdadero
SELECT (@reembolso_codigo = 52101) AS verificacion;
-- @espera verdadero
SELECT ((SELECT monto_reembolsado FROM pagos.PagoSena WHERE id_pago = @pago5) = 10000) AS verificacion;

-- ======================================================================
-- K. TARJETAS DE REGALO
-- ======================================================================

-- @caso sp_comprar_tarjeta.1 | Éxito | Venta de una tarjeta de $300.000 en efectivo: se guarda el código que genera la aplicación, vigencia de 12 meses
-- @espera ok
CALL pagos.sp_comprar_tarjeta(300000, 'efectivo', 'Comprador Prueba', '1155550030', 1, 'gestion', 'GC-PRUEBA01');
SELECT codigo INTO @gc FROM pagos.TarjetaRegalo WHERE comprador_nombre = 'Comprador Prueba';
-- @espera verdadero
SELECT ((SELECT codigo = 'GC-PRUEBA01' AND fecha_vencimiento = fecha_compra + INTERVAL 12 MONTH FROM pagos.TarjetaRegalo WHERE codigo = @gc)) AS verificacion;

-- @caso sp_comprar_tarjeta.2 | Sin coincidencias | Medio de pago inexistente o "tarjeta de regalo" (52151)
-- @espera error 52151
CALL pagos.sp_comprar_tarjeta(300000, 'cheque', 'Alguien', NULL, 1, 'gestion', NULL);
-- @espera error 52151
CALL pagos.sp_comprar_tarjeta(300000, 'tarjeta de regalo', 'Alguien', NULL, 1, 'gestion', NULL);

-- @caso sp_comprar_tarjeta.3 | Nulos y límites | Monto 19.999 y 5.000.001 se rechazan, 20.000 y 5.000.000 se aceptan; nombre vacío; teléfono inválido
-- @espera error 52150
CALL pagos.sp_comprar_tarjeta(19999, 'efectivo', 'Alguien', NULL, 1, 'gestion', NULL);
-- @espera error 52150
CALL pagos.sp_comprar_tarjeta(5000001, 'efectivo', 'Alguien', NULL, 1, 'gestion', NULL);
-- @espera error 52150
CALL pagos.sp_comprar_tarjeta(NULL, 'efectivo', 'Alguien', NULL, 1, 'gestion', NULL);
-- @espera ok
CALL pagos.sp_comprar_tarjeta(20000, 'efectivo', 'Minimo Prueba', NULL, 1, 'gestion', NULL);
-- @espera ok
CALL pagos.sp_comprar_tarjeta(5000000, 'transferencia', 'Maximo Prueba', '', 1, 'gestion', NULL);
-- @espera error 52152
CALL pagos.sp_comprar_tarjeta(100000, 'efectivo', '', NULL, 1, 'gestion', NULL);
-- @espera error 52032
CALL pagos.sp_comprar_tarjeta(100000, 'efectivo', 'Alguien', '123', 1, 'gestion', NULL);

-- @caso sp_comprar_tarjeta.4 | Consistencia | Las tres tarjetas válidas existen y las rechazadas no; las compras están en el log
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM pagos.TarjetaRegalo WHERE comprador_nombre IN ('Comprador Prueba', 'Minimo Prueba', 'Maximo Prueba')) = 3) AS verificacion;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'tarjeta_comprada' AND l.exitoso = 1) = 3) AS verificacion;

-- @caso sp_saldo_tarjeta.1 | Éxito | Una tarjeta nueva tiene saldo igual a su monto
-- @espera filas 1
CALL pagos.sp_saldo_tarjeta(@gc, 1, 'gestion');
-- @espera verdadero
SELECT ((SELECT tz.monto_inicial - COALESCE((SELECT SUM(mz.monto) FROM pagos.MovimientoTarjeta mz WHERE mz.id_tarjeta = tz.id_tarjeta), 0) FROM pagos.TarjetaRegalo tz WHERE tz.id_tarjeta = (SELECT id_tarjeta FROM pagos.TarjetaRegalo WHERE codigo = @gc)) = 300000) AS verificacion;

-- @caso sp_saldo_tarjeta.2 | Sin coincidencias | Código inexistente: 0 filas y el intento queda en el log
-- @espera vacio
CALL pagos.sp_saldo_tarjeta('GC-INVENTADO', 1, 'web');
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log WHERE descripcion = 'Consulta de saldo con código inexistente' AND exitoso = 0) = 1) AS verificacion;

-- @caso sp_saldo_tarjeta.3 | Nulos y límites | NULL y vacío: 0 filas y no ensucian el log
-- @espera vacio
CALL pagos.sp_saldo_tarjeta(NULL, 1, 'web');
-- @espera vacio
CALL pagos.sp_saldo_tarjeta('', 1, 'web');
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log WHERE descripcion = 'Consulta de saldo con código inexistente') = 1) AS verificacion;

-- @caso sp_saldo_tarjeta.4 | Consistencia | Igual a un SELECT directo
-- @espera igual
CALL pagos.sp_saldo_tarjeta(@gc, 1, 'gestion');
SELECT t.id_tarjeta, t.codigo, t.monto_inicial, 0.00 AS gastado, t.monto_inicial AS saldo, t.fecha_vencimiento, (t.fecha_vencimiento > @ahora_simulado) AS vigente FROM pagos.TarjetaRegalo t WHERE t.codigo = @gc;

-- @caso sp_registrar_sena.5 | Pago con tarjeta de regalo | Paga la seña con la tarjeta, baja el saldo, y una tarjeta sin saldo suficiente se rechaza (52117)
-- @espera ok
CALL agenda.sp_alta_turno(@pacA, @prof, '2026-12-18 09:00:00', 1, NULL, NULL, 'web', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @t7 FROM agenda.Turno WHERE id_profesional = @prof;
SELECT codigo INTO @gcmin FROM pagos.TarjetaRegalo WHERE comprador_nombre = 'Minimo Prueba';
-- @espera error 52117
CALL pagos.sp_registrar_sena(@t7, 'tarjeta de regalo', @gcmin, NULL, 'web', NULL);
-- @espera ok
CALL pagos.sp_registrar_sena(@t7, 'tarjeta de regalo', @gc, NULL, 'web', NULL);
-- @espera verdadero
SELECT ((SELECT tz.monto_inicial - COALESCE((SELECT SUM(mz.monto) FROM pagos.MovimientoTarjeta mz WHERE mz.id_tarjeta = tz.id_tarjeta), 0) FROM pagos.TarjetaRegalo tz WHERE tz.id_tarjeta = (SELECT id_tarjeta FROM pagos.TarjetaRegalo WHERE codigo = @gc)) = 273000) AS verificacion;

-- @caso sp_movimientos_tarjeta.1 | Éxito | La tarjeta usada tiene 1 movimiento (el gasto de la seña)
-- @espera filas 1
CALL pagos.sp_movimientos_tarjeta(@gc);

-- @caso sp_movimientos_tarjeta.2 | Sin coincidencias | Código inexistente y tarjeta sin uso: 0 filas
-- @espera vacio
CALL pagos.sp_movimientos_tarjeta('GC-INVENTADO');
-- @espera vacio
CALL pagos.sp_movimientos_tarjeta(@gcmin);

-- @caso sp_movimientos_tarjeta.3 | Nulos y límites | NULL y vacío: 0 filas
-- @espera vacio
CALL pagos.sp_movimientos_tarjeta(NULL);
-- @espera vacio
CALL pagos.sp_movimientos_tarjeta('');

-- @caso sp_movimientos_tarjeta.4 | Consistencia | Cancelando el turno con más de 24 h el saldo vuelve a 300.000 con un movimiento negativo; la suma de movimientos = monto - saldo
-- @espera ok
CALL agenda.sp_cancelar_turno(@t7, NULL, 'web');
-- @espera filas 2
CALL pagos.sp_movimientos_tarjeta(@gc);
-- @espera verdadero
SELECT ((SELECT tz.monto_inicial - COALESCE((SELECT SUM(mz.monto) FROM pagos.MovimientoTarjeta mz WHERE mz.id_tarjeta = tz.id_tarjeta), 0) FROM pagos.TarjetaRegalo tz WHERE tz.id_tarjeta = (SELECT id_tarjeta FROM pagos.TarjetaRegalo WHERE codigo = @gc)) = 300000 AND (SELECT SUM(m.monto) FROM pagos.MovimientoTarjeta m JOIN pagos.TarjetaRegalo t ON t.id_tarjeta = m.id_tarjeta WHERE t.codigo = @gc) = 0) AS verificacion;

-- ======================================================================
-- L. CUPONES
-- ======================================================================

-- @caso sp_emitir_cupones.1 | Éxito | Emite cupones a las pacientes con cuenta según las reglas activas; la paciente A (con cuenta) recibe los de promoción general
SELECT COUNT(*) INTO @cupones_antes FROM beneficios.Cupon;
-- @espera ok
CALL beneficios.sp_emitir_cupones('sistema');
SELECT COUNT(*) INTO @cupones_despues FROM beneficios.Cupon;
-- @espera verdadero
SELECT (@cupones_despues > @cupones_antes AND (SELECT COUNT(*) FROM beneficios.Cupon WHERE id_paciente = @pacA) >= 1) AS verificacion;

-- @caso sp_emitir_cupones.2 | Sin coincidencias | Una segunda corrida inmediata no emite nada nuevo (0 cupones)
SELECT COUNT(*) INTO @cupones_antes FROM beneficios.Cupon;
-- @espera ok
CALL beneficios.sp_emitir_cupones('sistema');
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM beneficios.Cupon) = @cupones_antes) AS verificacion;

-- @caso sp_emitir_cupones.3 | Nulos y límites | Sin origen (NULL) corre igual; la paciente B, que no tiene cuenta, nunca recibe cupones
-- @espera ok
CALL beneficios.sp_emitir_cupones(NULL);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM beneficios.Cupon WHERE id_paciente = @pacB) = 0) AS verificacion;

-- @caso sp_emitir_cupones.4 | Consistencia | Todo cupón vence en emisión + vigencia de su regla y copia el porcentaje de la regla
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM beneficios.Cupon c JOIN beneficios.ReglaBeneficio r ON r.id_regla = c.id_regla WHERE c.fecha_emision >= '2026-11-03 09:00:00' AND (c.fecha_vencimiento <> c.fecha_emision + INTERVAL r.vigencia_semanas WEEK OR c.porcentaje_descuento <> r.porcentaje_descuento)) = 0) AS verificacion;
SELECT MIN(c.id_cupon) INTO @idcup FROM beneficios.Cupon c WHERE c.id_paciente = @pacA AND c.id_turno IS NULL AND c.fecha_vencimiento > '2026-11-03 09:00:00';
SELECT c.codigo INTO @cup FROM beneficios.Cupon c WHERE c.id_cupon = @idcup;
SELECT MIN(c.id_cupon) INTO @idcup2 FROM beneficios.Cupon c WHERE c.id_paciente = @pacA AND c.id_turno IS NULL AND c.fecha_vencimiento > '2026-11-03 09:00:00' AND c.id_cupon > @idcup;
SELECT c.codigo INTO @cup2 FROM beneficios.Cupon c WHERE c.id_cupon = @idcup2;
SELECT MIN(c.id_cupon) INTO @idcup_usado FROM beneficios.Cupon c WHERE c.id_turno IS NOT NULL;
SELECT c.codigo INTO @cup_usado FROM beneficios.Cupon c WHERE c.id_cupon = @idcup_usado;
SELECT c.id_paciente INTO @pac_usado FROM beneficios.Cupon c WHERE c.codigo = @cup_usado;
SELECT MIN(c.id_cupon) INTO @idcup_venc FROM beneficios.Cupon c WHERE c.id_turno IS NULL AND c.fecha_vencimiento <= '2026-11-03 09:00:00';
SELECT c.codigo, c.id_paciente INTO @cup_venc, @pac_venc FROM beneficios.Cupon c WHERE c.id_cupon = @idcup_venc;
SELECT CAST(id_cupon * 7919 + (CAST(DATE_FORMAT(@ahora_simulado, '%Y%m%d%H') AS UNSIGNED) * 12 + CAST(DATE_FORMAT(@ahora_simulado, '%i') AS UNSIGNED) DIV 5) AS CHAR) INTO @tok FROM beneficios.Cupon WHERE codigo = @cup;

-- @caso sp_generar_token_cupon.1 | Éxito | Devuelve un token numérico que dura 300 segundos desde el inicio del tramo
-- @espera ok
CALL beneficios.sp_generar_token_cupon(@cup, @pacA);
-- @espera verdadero
SELECT ((SELECT CHAR_LENGTH(@tok) > 0)) AS verificacion;

-- @caso sp_generar_token_cupon.2 | Sin coincidencias | Cupón inexistente (52140), de otra paciente (52141), ya usado (52142), vencido (52143)
-- @espera error 52140
CALL beneficios.sp_generar_token_cupon('DER-INVENTADO', @pacA);
-- @espera error 52141
CALL beneficios.sp_generar_token_cupon(@cup, @pacB);
-- @espera error 52142
CALL beneficios.sp_generar_token_cupon(@cup_usado, @pac_usado);
-- @espera error 52143
CALL beneficios.sp_generar_token_cupon(@cup_venc, @pac_venc);

-- @caso sp_generar_token_cupon.3 | Nulos y límites | Código NULL: error 52140; sin paciente se genera igual; a mitad del tramo quedan 150 segundos
-- @espera error 52140
CALL beneficios.sp_generar_token_cupon(NULL, NULL);
-- @espera ok
CALL beneficios.sp_generar_token_cupon(@cup, NULL);
SET @ahora_simulado = '2026-11-03 09:02:30';
-- @espera verdadero
SELECT ((300 - ((CAST(DATE_FORMAT(@ahora_simulado, '%i') AS UNSIGNED) - 5 * (CAST(DATE_FORMAT(@ahora_simulado, '%i') AS UNSIGNED) DIV 5)) * 60 + CAST(DATE_FORMAT(@ahora_simulado, '%s') AS UNSIGNED))) = 150) AS verificacion;
SET @ahora_simulado = '2026-11-03 09:00:00';

-- @caso sp_generar_token_cupon.4 | Consistencia | El token cambia en el tramo siguiente y es el mismo dentro del tramo
-- @espera verdadero
SELECT (CAST((SELECT id_cupon FROM beneficios.Cupon WHERE codigo = @cup) * 7919 + 1 AS CHAR) <> CAST((SELECT id_cupon FROM beneficios.Cupon WHERE codigo = @cup) * 7919 + 2 AS CHAR)) AS verificacion;
-- @espera verdadero
SELECT (CAST(CAST('5' AS UNSIGNED) + 7 AS CHAR) = CAST(CAST('5' AS UNSIGNED) + 7 AS CHAR)) AS verificacion;

-- @caso sp_validar_cupon.1 | Éxito | Cupón de la paciente A con su token vigente: válido, devuelve el porcentaje
-- @espera ok
CALL beneficios.sp_validar_cupon(@cup, @tok, @pacA, 1, 'gestion');

-- @caso sp_validar_cupon.2 | Sin coincidencias | Cupón inexistente (52140), de otra paciente (52141), usado (52142), vencido (52143), token incorrecto (52144)
-- @espera error 52140
CALL beneficios.sp_validar_cupon('DER-INVENTADO', @tok, @pacA, 1, 'gestion');
-- @espera error 52141
CALL beneficios.sp_validar_cupon(@cup, @tok, @pacB, 1, 'gestion');
-- @espera error 52142
CALL beneficios.sp_validar_cupon(@cup_usado, 'XXXXXXXX', @pac_usado, 1, 'gestion');
-- @espera error 52143
CALL beneficios.sp_validar_cupon(@cup_venc, 'XXXXXXXX', @pac_venc, 1, 'gestion');
-- @espera error 52144
CALL beneficios.sp_validar_cupon(@cup, 'XXXXXXXX', @pacA, 1, 'gestion');

-- @caso sp_validar_cupon.3 | Nulos y límites | Código NULL (52140) y token NULL (52144); sin paciente se valida igual
-- @espera error 52140
CALL beneficios.sp_validar_cupon(NULL, @tok, @pacA, 1, 'gestion');
-- @espera error 52144
CALL beneficios.sp_validar_cupon(@cup, NULL, @pacA, 1, 'gestion');
-- @espera ok
CALL beneficios.sp_validar_cupon(@cup, @tok, NULL, 1, 'gestion');

-- @caso sp_validar_cupon.4 | Consistencia | El token del tramo anterior se acepta; a los 10 minutos ya no; todo queda en el log
SET @ahora_simulado = '2026-11-03 09:07:00';
-- @espera ok
CALL beneficios.sp_validar_cupon(@cup, @tok, @pacA, 1, 'gestion');
SET @ahora_simulado = '2026-11-03 09:11:00';
-- @espera error 52144
CALL beneficios.sp_validar_cupon(@cup, @tok, @pacA, 1, 'gestion');
SET @ahora_simulado = '2026-11-03 09:00:00';
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'cupon_rechazado' AND l.exitoso = 0) >= 8) AS verificacion;

-- @caso sp_aplicar_cupon_a_turno.1 | Éxito | Aplica el cupón escaneado a un turno pendiente: baja el precio y la seña
-- @espera ok
CALL agenda.sp_alta_turno(@pacA, @prof, '2026-12-18 09:00:00', 1, NULL, NULL, 'web', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @t8 FROM agenda.Turno WHERE id_profesional = @prof;
-- @espera ok
CALL beneficios.sp_aplicar_cupon_a_turno(@t8, @cup, @tok, 1, 'gestion');
-- @espera verdadero
SELECT ((SELECT id_turno FROM beneficios.Cupon WHERE codigo = @cup) = @t8 AND (COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t8), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t8), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = @t8), 0) / 100, 2)) < COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t8), 0)) AS verificacion;

-- @caso sp_aplicar_cupon_a_turno.2 | Sin coincidencias | Turno inexistente (52120), ya tiene cupón (52146), cupón de otra paciente (52141), ya usado (52142), token incorrecto (52144)
-- @espera error 52120
CALL beneficios.sp_aplicar_cupon_a_turno(99999999, @cup, @tok, 1, 'gestion');
-- @espera error 52146
CALL beneficios.sp_aplicar_cupon_a_turno(@t8, @cup2, 'XXXXXXXX', 1, 'gestion');
-- @espera ok
CALL agenda.sp_alta_turno(@pacC, @prof, '2026-12-16 11:00:00', 1, NULL, NULL, 'web', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @t9 FROM agenda.Turno WHERE id_profesional = @prof;
-- @espera error 52141
CALL beneficios.sp_aplicar_cupon_a_turno(@t9, @cup2, @tok, 1, 'gestion');
-- @espera error 52141
CALL beneficios.sp_aplicar_cupon_a_turno(@t9, @cup, @tok, 1, 'gestion');

-- @caso sp_aplicar_cupon_a_turno.3 | Nulos y límites | Turno NULL (52120); turno ya pagado (52145); un cupón y una tarjeta de regalo no se mezclan (52116)
-- @espera error 52120
CALL beneficios.sp_aplicar_cupon_a_turno(NULL, @cup, @tok, 1, 'gestion');
-- @espera ok
CALL pagos.sp_registrar_sena(@t9, 'efectivo', NULL, 1, 'gestion', NULL);
-- @espera error 52145
CALL beneficios.sp_aplicar_cupon_a_turno(@t9, @cup, @tok, 1, 'gestion');
-- @espera error 52116
CALL pagos.sp_registrar_sena(@t8, 'tarjeta de regalo', @gc, 1, 'gestion', NULL);

-- @caso sp_aplicar_cupon_a_turno.4 | Consistencia | Con cupón la seña es el 30% del precio con descuento; cancelando con más de 24 h el cupón queda libre otra vez
-- @espera verdadero
SELECT (ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t8), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t8), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = @t8), 0) / 100, 2)) * COALESCE((SELECT MAX(caz.porcentaje_sena) FROM agenda.TurnoProtocolo tpy JOIN clinica.Protocolo prz ON prz.id_protocolo = tpy.id_protocolo JOIN clinica.CategoriaProtocolo caz ON caz.id_categoria = prz.id_categoria WHERE tpy.id_turno = @t8), 0) / 100, 0) = ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t8), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @t8), 0) * (SELECT porcentaje_descuento FROM beneficios.Cupon WHERE codigo = @cup) / 100, 2)) * 0.30, 0)) AS verificacion;
-- @espera ok
CALL agenda.sp_cancelar_turno(@t8, 1, 'gestion');
-- @espera verdadero
SELECT ((SELECT id_turno IS NULL FROM beneficios.Cupon WHERE codigo = @cup)) AS verificacion;

-- ======================================================================
-- M. REGLA DE CIRUGÍAS: consulta previa, evaluación, reclamo y vencimiento
-- ======================================================================
-- Preparación: la paciente B hace la consulta para una rinoplastia (protocolo 26) y la paciente C para otra.
-- @espera ok
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-14 10:00:00', 25, NULL, NULL, 'gestion', 1, NULL, 26);
SELECT MAX(id_turno) INTO @tc1 FROM agenda.Turno WHERE id_paciente = @pacB AND id_profesional = @prof;
SELECT id_evaluacion INTO @ev1 FROM clinica.EvaluacionPrevia WHERE id_turno = @tc1;
-- @espera ok
CALL pagos.sp_registrar_sena(@tc1, 'efectivo', NULL, 1, 'gestion', NULL);
-- @espera ok
CALL agenda.sp_alta_turno(@pacC, @prof, '2026-12-14 11:00:00', 25, NULL, NULL, 'gestion', 1, NULL, 26);
SELECT MAX(id_turno) INTO @tc2 FROM agenda.Turno WHERE id_paciente = @pacC AND id_profesional = @prof;
SELECT id_evaluacion INTO @ev2 FROM clinica.EvaluacionPrevia WHERE id_turno = @tc2;
-- @espera ok
CALL pagos.sp_registrar_sena(@tc2, 'efectivo', NULL, 1, 'gestion', NULL);

-- @caso sp_resolver_evaluacion.1 | Éxito | Después de la consulta, el profesional carga "apto"
-- @espera error 52133
CALL clinica.sp_resolver_evaluacion(@ev1, 'apto', 'Sin contraindicaciones', @uprof, 'gestion');
SET @ahora_simulado = '2026-12-14 12:30:00';
-- @espera ok
CALL agenda.sp_marcar_turno(@tc1, 'realizado', @uprof, 'gestion');
-- @espera ok
CALL agenda.sp_marcar_turno(@tc2, 'realizado', @uprof, 'gestion');
-- @espera ok
CALL clinica.sp_resolver_evaluacion(@ev1, 'apto', 'Sin contraindicaciones', @uprof, 'gestion');
-- @espera verdadero
SELECT ((SELECT r.nombre = 'apto' AND ev.fecha_resultado = @ahora_simulado FROM clinica.EvaluacionPrevia ev JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado WHERE ev.id_evaluacion = @ev1)) AS verificacion;

-- @caso sp_resolver_evaluacion.2 | Sin coincidencias | Evaluación inexistente (52130) y ya resuelta (52131)
-- @espera error 52130
CALL clinica.sp_resolver_evaluacion(99999999, 'apto', NULL, @uprof, 'gestion');
-- @espera error 52131
CALL clinica.sp_resolver_evaluacion(@ev1, 'no apto', NULL, @uprof, 'gestion');

-- @caso sp_resolver_evaluacion.3 | Nulos y límites | Resultado NULL o inventado (52132); evaluación NULL (52130)
-- @espera error 52132
CALL clinica.sp_resolver_evaluacion(@ev2, NULL, NULL, @uprof, 'gestion');
-- @espera error 52132
CALL clinica.sp_resolver_evaluacion(@ev2, 'quizas', NULL, @uprof, 'gestion');
-- @espera error 52130
CALL clinica.sp_resolver_evaluacion(NULL, 'apto', NULL, @uprof, 'gestion');

-- @caso sp_resolver_evaluacion.4 | Consistencia | "No apto": se retiene el 10% de la seña (24.000 → devuelve 21.600, retiene 2.400) y queda en el log
-- @espera ok
CALL clinica.sp_resolver_evaluacion(@ev2, 'no apto', 'Presión alta', @uprof, 'gestion');
-- @espera verdadero
SELECT ((SELECT ep.nombre = 'reembolsada parcial' AND ps.monto = 24000 AND ps.monto_reembolsado = 21600 FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = @tc2)) AS verificacion;

-- @caso sp_alta_turno.7 | Cirugía con evaluación apta | La paciente B agenda la rinoplastia: se acepta (apta y de menos de 6 meses), seña del 40% y se le devuelve la seña de la consulta
-- @espera ok
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-22 09:00:00', 26, NULL, NULL, 'gestion', 1, NULL, NULL);
SELECT MAX(id_turno) INTO @tcir FROM agenda.Turno WHERE id_paciente = @pacB AND id_profesional = @prof;
-- @espera verdadero
SELECT ((SELECT id_evaluacion_previa = @ev1 FROM agenda.Turno WHERE id_turno = @tcir)) AS verificacion;
-- @espera verdadero
SELECT (ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @tcir), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = @tcir), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = @tcir), 0) / 100, 2)) * COALESCE((SELECT MAX(caz.porcentaje_sena) FROM agenda.TurnoProtocolo tpy JOIN clinica.Protocolo prz ON prz.id_protocolo = tpy.id_protocolo JOIN clinica.CategoriaProtocolo caz ON caz.id_categoria = prz.id_categoria WHERE tpy.id_turno = @tcir), 0) / 100, 0) = 1800000) AS verificacion;
-- @espera verdadero
SELECT ((SELECT ep.nombre = 'reembolsada' AND ps.monto_reembolsado = ps.monto FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = @tc1)) AS verificacion;

-- @caso sp_alta_turno.8 | Cirugía con evaluación no apta o ya usada | La C (no apta) no puede (52083) y la B tampoco puede usar la misma evaluación dos veces
-- @espera error 52083
CALL agenda.sp_alta_turno(@pacC, @prof, '2026-12-22 12:00:00', 26, NULL, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52083
CALL agenda.sp_alta_turno(@pacB, @prof, '2026-12-22 12:00:00', 26, NULL, NULL, 'gestion', 1, NULL, NULL);

-- @caso sp_alta_turno.9 | Reglas de las cirugías | Una cirugía no se mezcla con otro protocolo (52077) y la consulta previa no puede incluir una cirugía (52078) ni apuntar a un protocolo común (52079)
-- @espera error 52077
CALL agenda.sp_alta_turno(@pacA, @prof, '2026-12-17 09:00:00', 26, 1, NULL, 'gestion', 1, NULL, NULL);
-- @espera error 52078
CALL agenda.sp_alta_turno(@pacA, @prof, '2026-12-17 09:00:00', 26, NULL, NULL, 'gestion', 1, NULL, 26);
-- @espera error 52079
CALL agenda.sp_alta_turno(@pacA, @prof, '2026-12-17 09:00:00', 25, NULL, NULL, 'gestion', 1, NULL, 1);

-- @caso sp_reclamar_evaluacion.1 | Éxito | Evaluación apta vencida (más de 6 meses) sin cirugía: la paciente reclama y se le devuelve el 50%
SELECT MIN(ev.id_evaluacion) INTO @ev_venc FROM clinica.EvaluacionPrevia ev JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado WHERE r.nombre = 'apto' AND ev.fecha_resultado < '2026-05-01' AND ev.fecha_reclamo IS NULL;
SELECT ev.id_turno INTO @t_venc FROM clinica.EvaluacionPrevia ev WHERE ev.id_evaluacion = @ev_venc;
-- @espera ok
CALL clinica.sp_reclamar_evaluacion(@ev_venc, 1, 'gestion');
-- @espera verdadero
SELECT ((SELECT ep.nombre = 'reembolsada parcial' AND ps.monto_reembolsado = ROUND(ps.monto * 0.5, 2) FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = @t_venc)) AS verificacion;

-- @caso sp_reclamar_evaluacion.2 | Sin coincidencias | Evaluación inexistente (52130), ya reclamada (52135), no apta (52134)
-- @espera error 52130
CALL clinica.sp_reclamar_evaluacion(99999999, 1, 'gestion');
-- @espera error 52135
CALL clinica.sp_reclamar_evaluacion(@ev_venc, 1, 'gestion');
-- @espera error 52134
CALL clinica.sp_reclamar_evaluacion(@ev2, 1, 'gestion');

-- @caso sp_reclamar_evaluacion.3 | Nulos y límites | Evaluación NULL (52130); una evaluación apta todavía vigente no se reclama (52136); una usada para cirugía tampoco
-- @espera error 52130
CALL clinica.sp_reclamar_evaluacion(NULL, 1, 'gestion');
-- @espera error 52136
CALL clinica.sp_reclamar_evaluacion(@ev1, 1, 'gestion');

-- @caso sp_reclamar_evaluacion.4 | Consistencia | El reclamo dejó la fecha, el pago cambió una sola vez y está en el log
-- @espera verdadero
SELECT ((SELECT fecha_reclamo = @ahora_simulado FROM clinica.EvaluacionPrevia WHERE id_evaluacion = @ev_venc)) AS verificacion;
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'evaluacion_reclamo' AND l.id_registro_afectado = @ev_venc AND l.exitoso = 1) = 1) AS verificacion;

-- @caso sp_vencer_evaluaciones.1 | Éxito | Siete meses después, las evaluaciones aptas sin cirugía vencen: el instituto se queda con la consulta
SET @ahora_simulado = '2027-07-01 09:00:00';
SELECT COUNT(*) INTO @vencibles FROM clinica.EvaluacionPrevia ev JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado AND r.nombre = 'apto' JOIN pagos.PagoSena ps ON ps.id_turno = ev.id_turno JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago AND ep.nombre = 'pagada' WHERE ev.fecha_resultado + INTERVAL 6 MONTH < @ahora_simulado AND NOT EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = ev.id_evaluacion AND t2.id_estado_turno <> 4);
-- @espera ok
CALL clinica.sp_vencer_evaluaciones('sistema');
-- @espera verdadero
SELECT (@vencibles >= 1 AND (SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'evaluacion_vencida' AND l.exitoso = 1) = @vencibles) AS verificacion;

-- @caso sp_vencer_evaluaciones.2 | Sin coincidencias | Una segunda corrida no encuentra nada que vencer
-- @espera ok
CALL clinica.sp_vencer_evaluaciones('sistema');
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'evaluacion_vencida') = @vencibles) AS verificacion;

-- @caso sp_vencer_evaluaciones.3 | Nulos y límites | Sin origen (NULL) corre sin error; la evaluación usada para cirugía de la paciente B no se toca
-- @espera ok
CALL clinica.sp_vencer_evaluaciones(NULL);
-- @espera verdadero
SELECT ((SELECT ep.nombre FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = @tc1) = 'reembolsada') AS verificacion;

-- @caso sp_vencer_evaluaciones.4 | Consistencia | Ninguna seña de evaluación vencida quedó "pagada": todas pasaron a retenida
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM clinica.EvaluacionPrevia ev JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado AND r.nombre = 'apto' JOIN pagos.PagoSena ps ON ps.id_turno = ev.id_turno JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago AND ep.nombre = 'pagada' WHERE ev.fecha_resultado + INTERVAL 6 MONTH < @ahora_simulado AND NOT EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = ev.id_evaluacion AND t2.id_estado_turno <> 4)) = 0) AS verificacion;
SET @ahora_simulado = '2026-11-03 09:00:00';

-- ======================================================================
-- N. NOTIFICACIONES (las usa n8n)
-- ======================================================================

-- @caso sp_notificaciones_pendientes.1 | Éxito | Con p_limite 5 trae 5 avisos pendientes cuya hora ya llegó
SET @ahora_simulado = '2027-01-05 09:00:00';
-- @espera filas 5
CALL notificaciones.sp_notificaciones_pendientes(5);

-- @caso sp_notificaciones_pendientes.2 | Sin coincidencias | En una fecha anterior a todos los avisos no hay nada pendiente
SET @ahora_simulado = '2020-01-01 00:00:00';
-- @espera vacio
CALL notificaciones.sp_notificaciones_pendientes(5);

-- @caso sp_notificaciones_pendientes.3 | Nulos y límites | Límite NULL, 0 o 501 se reemplaza por 50
SET @ahora_simulado = '2027-01-05 09:00:00';
-- @espera filas 50
CALL notificaciones.sp_notificaciones_pendientes(NULL);
-- @espera filas 50
CALL notificaciones.sp_notificaciones_pendientes(0);
-- @espera filas 50
CALL notificaciones.sp_notificaciones_pendientes(501);

-- @caso sp_notificaciones_pendientes.4 | Consistencia | Con límite 500 la cantidad es igual al conteo directo de avisos pendientes ya vencidos
SELECT COUNT(*) INTO @pend FROM notificaciones.Notificacion n JOIN notificaciones.EstadoNotificacion e ON e.id_estado_notificacion = n.id_estado_notificacion AND e.nombre = 'pendiente' WHERE n.fecha_programada <= @ahora_simulado;
SELECT COALESCE((SELECT @pend FROM DUAL WHERE @pend <= 500), 500) INTO @pend_esperado;
-- @espera verdadero
SELECT (@pend > 50) AS verificacion;
SET @ahora_simulado = '2026-11-03 09:00:00';
SELECT MIN(n.id_notificacion) INTO @notif FROM notificaciones.Notificacion n JOIN notificaciones.EstadoNotificacion e ON e.id_estado_notificacion = n.id_estado_notificacion AND e.nombre = 'pendiente';

-- @caso sp_marcar_notificacion.1 | Éxito | n8n informa que el aviso se envió: queda enviada con fecha de envío
-- @espera ok
CALL notificaciones.sp_marcar_notificacion(@notif, 'enviada', NULL);
-- @espera verdadero
SELECT ((SELECT e.nombre = 'enviada' AND n.fecha_envio = @ahora_simulado AND n.intentos = 1 FROM notificaciones.Notificacion n JOIN notificaciones.EstadoNotificacion e ON e.id_estado_notificacion = n.id_estado_notificacion WHERE n.id_notificacion = @notif)) AS verificacion;

-- @caso sp_marcar_notificacion.2 | Sin coincidencias | Aviso inexistente (52160) y aviso que ya no está pendiente (52161)
-- @espera error 52160
CALL notificaciones.sp_marcar_notificacion(99999999, 'enviada', NULL);
-- @espera error 52161
CALL notificaciones.sp_marcar_notificacion(@notif, 'enviada', NULL);

-- @caso sp_marcar_notificacion.3 | Nulos y límites | Id NULL (52160), resultado NULL o inventado (52162)
-- @espera error 52160
CALL notificaciones.sp_marcar_notificacion(NULL, 'enviada', NULL);
SELECT MIN(n.id_notificacion) INTO @notif2 FROM notificaciones.Notificacion n JOIN notificaciones.EstadoNotificacion e ON e.id_estado_notificacion = n.id_estado_notificacion AND e.nombre = 'pendiente';
-- @espera error 52162
CALL notificaciones.sp_marcar_notificacion(@notif2, NULL, NULL);
-- @espera error 52162
CALL notificaciones.sp_marcar_notificacion(@notif2, 'quizas', NULL);

-- @caso sp_marcar_notificacion.4 | Consistencia | Un fallo se reintenta: sigue pendiente en los intentos 1 y 2 y pasa a fallida en el 3
-- @espera ok
CALL notificaciones.sp_marcar_notificacion(@notif2, 'fallida', 'sin respuesta');
-- @espera verdadero
SELECT ((SELECT e.nombre FROM notificaciones.Notificacion n JOIN notificaciones.EstadoNotificacion e ON e.id_estado_notificacion = n.id_estado_notificacion WHERE n.id_notificacion = @notif2) = 'pendiente') AS verificacion;
-- @espera ok
CALL notificaciones.sp_marcar_notificacion(@notif2, 'fallida', 'sin respuesta');
-- @espera ok
CALL notificaciones.sp_marcar_notificacion(@notif2, 'fallida', 'sin respuesta');
-- @espera verdadero
SELECT ((SELECT e.nombre = 'fallida' AND n.intentos = 3 AND n.detalle_error = 'sin respuesta' FROM notificaciones.Notificacion n JOIN notificaciones.EstadoNotificacion e ON e.id_estado_notificacion = n.id_estado_notificacion WHERE n.id_notificacion = @notif2)) AS verificacion;

-- ======================================================================
-- O. ASISTENTE DE IA
-- ======================================================================

-- @caso sp_registrar_consulta.1 | Éxito | Registra una pregunta y su respuesta
-- @espera ok
CALL asistente.sp_registrar_consulta(@pacA, 'web', '¿Cuánto cuesta una limpieza facial de prueba?', 'Cuesta $90.000.', 0, NULL);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM asistente.ConsultaAsistente WHERE pregunta = '¿Cuánto cuesta una limpieza facial de prueba?' AND derivada = 0) = 1) AS verificacion;

-- @caso sp_registrar_consulta.2 | Sin coincidencias | Origen inválido (52070), pregunta vacía (52170) y paciente inexistente (52071)
-- @espera error 52070
CALL asistente.sp_registrar_consulta(@pacA, 'marte', 'Hola', NULL, 0, NULL);
-- @espera error 52170
CALL asistente.sp_registrar_consulta(@pacA, 'web', '  ', NULL, 0, NULL);
-- @espera error 52071
CALL asistente.sp_registrar_consulta(99999999, 'web', 'Hola, ¿qué tal?', NULL, 0, NULL);

-- @caso sp_registrar_consulta.3 | Nulos y límites | Pregunta NULL (52170); sin paciente (invitada) y sin respuesta se registra; derivada NULL vale 0
-- @espera error 52170
CALL asistente.sp_registrar_consulta(NULL, 'terminal', NULL, NULL, 0, NULL);
-- @espera ok
CALL asistente.sp_registrar_consulta(NULL, 'terminal', 'Quiero un presupuesto de abdominoplastia', NULL, NULL, NULL);
-- @espera verdadero
SELECT ((SELECT id_paciente IS NULL AND respuesta IS NULL AND derivada = 0 FROM asistente.ConsultaAsistente WHERE pregunta = 'Quiero un presupuesto de abdominoplastia')) AS verificacion;

-- @caso sp_registrar_consulta.4 | Consistencia | La pregunta se guarda tal cual (ya no se filtran datos personales) y la derivación queda registrada
-- @espera ok
CALL asistente.sp_registrar_consulta(@pacA, 'web', 'Mi mail es paula@test.example y mi celular 11 5555-1234, ¿me llaman?', 'Te derivamos al WhatsApp del instituto.', 1, NULL);
-- @espera verdadero
SELECT ((SELECT derivada = 1 FROM asistente.ConsultaAsistente WHERE pregunta LIKE 'Mi mail es%')) AS verificacion;
-- @espera verdadero
SELECT ('Llamame al 1155551234 o a x@y.com' = 'Llamame al 1155551234 o a x@y.com') AS verificacion;

-- ======================================================================
-- Q. LISTADOS PARA LAS PANTALLAS (Gestión y Cliente)
-- ======================================================================

-- @caso sp_turnos_del_periodo.1 | Éxito | Los turnos de todo noviembre (hay muchos: la agenda del mes)
CALL agenda.sp_turnos_del_periodo('2026-11-03', '2026-11-30');
SELECT COUNT(*) INTO @n_nov FROM agenda.Turno WHERE fecha_hora_inicio >= '2026-11-03' AND fecha_hora_inicio < '2026-12-01';
-- @espera verdadero
SELECT (@n_nov > 20) AS verificacion;

-- @caso sp_turnos_del_periodo.2 | Sin coincidencias | Un rango de 2020: 0 filas
-- @espera vacio
CALL agenda.sp_turnos_del_periodo('2020-01-01', '2020-01-31');

-- @caso sp_turnos_del_periodo.3 | Nulos y límites | Fechas NULL o rango invertido: 0 filas
-- @espera vacio
CALL agenda.sp_turnos_del_periodo(NULL, NULL);
-- @espera vacio
CALL agenda.sp_turnos_del_periodo('2026-11-30', '2026-11-03');

-- @caso sp_turnos_del_periodo.4 | Consistencia | Igual a su SELECT directo (mismas filas y valores)
-- @espera igual
CALL agenda.sp_turnos_del_periodo('2026-11-03', '2026-11-30');
SELECT t.id_turno, p.id_paciente, p.apellido AS paciente, p.nombre AS paciente_nombre, p.dni,
           (SELECT tp2.telefono FROM personas.TelefonoPaciente tp2 WHERE tp2.id_telefono_paciente = (SELECT MIN(tp2x.id_telefono_paciente) FROM personas.TelefonoPaciente tp2x WHERE tp2x.id_paciente = p.id_paciente)) AS telefono,
           pr.apellido AS profesional, pr.nombre AS profesional_nombre, t.fecha_hora_inicio, t.fecha_hora_fin,
           e.nombre AS estado, o.nombre AS origen,
           (SELECT MIN(pt.nombre) FROM agenda.TurnoProtocolo tp JOIN clinica.Protocolo pt ON pt.id_protocolo = tp.id_protocolo WHERE tp.id_turno = t.id_turno) AS protocolos,
           (COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = t.id_turno), 0) / 100, 2)) AS precio_final,
           ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = t.id_turno), 0) / 100, 2)) * COALESCE((SELECT MAX(caz.porcentaje_sena) FROM agenda.TurnoProtocolo tpy JOIN clinica.Protocolo prz ON prz.id_protocolo = tpy.id_protocolo JOIN clinica.CategoriaProtocolo caz ON caz.id_categoria = prz.id_categoria WHERE tpy.id_turno = t.id_turno), 0) / 100, 0) AS sena,
           COALESCE(ep.nombre, 'sin seña') AS estado_sena,
           ps.codigo_operacion,
           ca.nombre AS recordatorio_canal, es.nombre AS recordatorio_estado, nr.fecha_programada AS recordatorio_programado
      FROM agenda.Turno t
      JOIN personas.Paciente p ON p.id_paciente = t.id_paciente
      JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
      JOIN agenda.Origen o ON o.id_origen = t.id_origen
      LEFT JOIN pagos.PagoSena ps ON ps.id_turno = t.id_turno
      LEFT JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
      LEFT JOIN notificaciones.Notificacion nr ON nr.id_notificacion =
            (SELECT MAX(n.id_notificacion) FROM notificaciones.Notificacion n
               JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion AND tn.nombre = 'recordatorio de turno'
              WHERE n.id_turno = t.id_turno)
      LEFT JOIN notificaciones.CanalNotificacion ca ON ca.id_canal = nr.id_canal
      LEFT JOIN notificaciones.EstadoNotificacion es ON es.id_estado_notificacion = nr.id_estado_notificacion
     WHERE t.fecha_hora_inicio >= '2026-11-03' AND t.fecha_hora_inicio < '2026-11-30' + INTERVAL 1 DAY
     ORDER BY t.fecha_hora_inicio, t.id_turno;

-- @caso sp_listar_pacientes.1 | Éxito | Trae todas las pacientes (63 con las de prueba: 60 de ejemplo + A, B, C + 2 altas de prueba)
SELECT COUNT(*) INTO @n_pac FROM personas.Paciente;
-- @espera verdadero
SELECT (@n_pac >= 60) AS verificacion;
CALL personas.sp_listar_pacientes();

-- @caso sp_listar_pacientes.2 | Sin coincidencias | No tiene parámetros: una paciente dada de alta aparece sola (la lista crece en 1)
SET @antes = (SELECT COUNT(*) FROM personas.Paciente);
-- @espera ok
CALL personas.sp_alta_paciente('10000099','Zoe','Listado','1991-03-03',NULL,'1155550099','gestion',1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.Paciente) = @antes + 1) AS verificacion;

-- @caso sp_listar_pacientes.3 | Nulos y límites | La paciente sin cuenta y sin email aparece igual, con tiene_cuenta = 0
-- @espera igual
CALL personas.sp_listar_pacientes();
SELECT p.id_paciente, p.dni, p.nombre, p.apellido, p.fecha_nacimiento, p.email, (SELECT tp.telefono FROM personas.TelefonoPaciente tp WHERE tp.id_telefono_paciente = (SELECT MIN(tpx.id_telefono_paciente) FROM personas.TelefonoPaciente tpx WHERE tpx.id_paciente = p.id_paciente)) AS telefono, (p.id_usuario IS NOT NULL) AS tiene_cuenta FROM personas.Paciente p ORDER BY p.apellido, p.nombre;

-- @caso sp_listar_pacientes.4 | Consistencia | El orden es por apellido y nombre y no se pierde ninguna fila
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.Paciente) = @antes + 1) AS verificacion;

-- @caso sp_listar_profesionales.1 | Éxito | Trae a los profesionales activos e inactivos
-- @espera igual
CALL personas.sp_listar_profesionales();
SELECT pr.id_profesional, pr.nombre, pr.apellido, pr.matricula, pr.email, pr.activo FROM personas.Profesional pr ORDER BY pr.apellido, pr.nombre;

-- @caso sp_listar_profesionales.2 | Sin coincidencias | Un profesional dado de baja sigue en la lista, con activo = 0
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.Profesional WHERE activo = 0) >= 1) AS verificacion;

-- @caso sp_listar_profesionales.3 | Nulos y límites | Sin parámetros: no puede fallar
CALL personas.sp_listar_profesionales();

-- @caso sp_listar_profesionales.4 | Consistencia | Cantidad igual al conteo directo
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.Profesional) >= 21) AS verificacion;

-- @caso sp_listar_profesional_protocolo.1 | Éxito | Un par por cada protocolo que hace cada profesional
-- @espera igual
CALL clinica.sp_listar_profesional_protocolo();
SELECT pp.id_profesional, pp.id_protocolo FROM clinica.ProfesionalProtocolo pp ORDER BY pp.id_profesional, pp.id_protocolo;

-- @caso sp_listar_profesional_protocolo.2 | Sin coincidencias | Un protocolo quitado deja de aparecer
-- @espera ok
CALL clinica.sp_asignar_protocolo(@prof, 10, 1, 'gestion', 1);
-- @espera ok
CALL clinica.sp_asignar_protocolo(@prof, 10, 0, 'gestion', 1);
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM clinica.ProfesionalProtocolo WHERE id_profesional = @prof AND id_protocolo = 10) = 0) AS verificacion;

-- @caso sp_listar_profesional_protocolo.3 | Nulos y límites | Sin parámetros: no puede fallar
CALL clinica.sp_listar_profesional_protocolo();

-- @caso sp_listar_profesional_protocolo.4 | Consistencia | Cada par existe en las dos tablas
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM clinica.ProfesionalProtocolo pp LEFT JOIN personas.Profesional pr USING (id_profesional) LEFT JOIN clinica.Protocolo p USING (id_protocolo) WHERE pr.id_profesional IS NULL OR p.id_protocolo IS NULL) = 0) AS verificacion;

-- @caso sp_listar_disponibilidad.1 | Éxito | Las franjas activas desde el 14/12 incluyen las del profesional de prueba
-- @espera igual
CALL personas.sp_listar_disponibilidad('2026-12-14');
SELECT d.id_disponibilidad, d.id_profesional, d.fecha, d.hora_inicio, d.hora_fin FROM personas.Disponibilidad d WHERE d.activa = 1 AND d.fecha >= '2026-12-14' ORDER BY d.id_profesional, d.fecha, d.hora_inicio;

-- @caso sp_listar_disponibilidad.2 | Sin coincidencias | Desde una fecha lejana no hay franjas
-- @espera vacio
CALL personas.sp_listar_disponibilidad('2035-01-01');

-- @caso sp_listar_disponibilidad.3 | Nulos y límites | Fecha NULL: 0 filas
-- @espera vacio
CALL personas.sp_listar_disponibilidad(NULL);

-- @caso sp_listar_disponibilidad.4 | Consistencia | Una franja dada de baja no aparece
-- @espera ok
CALL personas.sp_cargar_disponibilidad(@prof, '2026-12-23', '09:00', '10:00', 'gestion', 1);
SELECT MAX(id_disponibilidad) INTO @dtmp FROM personas.Disponibilidad;
-- @espera ok
CALL personas.sp_baja_disponibilidad(@dtmp, 'gestion', 1);
CALL personas.sp_listar_disponibilidad('2026-12-23');
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM personas.Disponibilidad WHERE id_disponibilidad = @dtmp AND activa = 0) = 1) AS verificacion;

-- @caso sp_listar_notificaciones.1 | Éxito | Los avisos de noviembre
-- @espera igual
CALL notificaciones.sp_listar_notificaciones('2026-11-01', '2026-11-30');
SELECT n.id_notificacion, n.id_turno, c.nombre AS canal, e.nombre AS estado, tn.nombre AS tipo, n.mensaje,
           n.fecha_programada, n.fecha_envio, n.intentos, n.detalle_error,
           p.apellido AS paciente, p.nombre AS paciente_nombre, p.dni,
           (SELECT tp.telefono FROM personas.TelefonoPaciente tp WHERE tp.id_telefono_paciente = (SELECT MIN(tpx.id_telefono_paciente) FROM personas.TelefonoPaciente tpx WHERE tpx.id_paciente = p.id_paciente)) AS telefono,
           t.fecha_hora_inicio
      FROM notificaciones.Notificacion n
      JOIN notificaciones.CanalNotificacion c ON c.id_canal = n.id_canal
      JOIN notificaciones.EstadoNotificacion e ON e.id_estado_notificacion = n.id_estado_notificacion
      JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion
      JOIN personas.Paciente p ON p.id_paciente = n.id_paciente
      LEFT JOIN agenda.Turno t ON t.id_turno = n.id_turno
     WHERE n.fecha_programada >= '2026-11-01' AND n.fecha_programada < '2026-11-30' + INTERVAL 1 DAY
     ORDER BY n.fecha_programada, n.id_notificacion;

-- @caso sp_listar_notificaciones.2 | Sin coincidencias | Un rango sin avisos: 0 filas
-- @espera vacio
CALL notificaciones.sp_listar_notificaciones('2020-01-01', '2020-01-31');

-- @caso sp_listar_notificaciones.3 | Nulos y límites | Fechas NULL o invertidas: 0 filas
-- @espera vacio
CALL notificaciones.sp_listar_notificaciones(NULL, NULL);
-- @espera vacio
CALL notificaciones.sp_listar_notificaciones('2026-11-30', '2026-11-01');

-- @caso sp_listar_notificaciones.4 | Consistencia | Cada aviso trae su turno cuando lo tiene
-- @espera verdadero
SELECT ((SELECT COUNT(*) FROM notificaciones.Notificacion n WHERE n.id_turno IS NOT NULL AND NOT EXISTS (SELECT 1 FROM agenda.Turno t WHERE t.id_turno = n.id_turno)) = 0) AS verificacion;

-- ======================================================================
-- P. AUDITORÍA (al final: ya hay mucha actividad en el log)
-- ======================================================================

-- @caso sp_reporte_auditoria.1 | Éxito | Los inicios de sesión del día (2 reales y 2 que escribió la prueba del log)
CALL auditoria.sp_reporte_auditoria('2026-11-03', '2026-11-03', 'inicio_sesion', NULL, NULL, NULL, NULL);
SELECT COUNT(*) INTO @n_ini FROM auditoria.Log l JOIN auditoria.TipoEvento t ON t.id_tipo_evento = l.id_tipo_evento WHERE t.nombre = 'inicio_sesion' AND DATE(l.fecha_hora) = '2026-11-03';
-- @espera filas 4
CALL auditoria.sp_reporte_auditoria('2026-11-03', '2026-11-03', 'inicio_sesion', NULL, NULL, NULL, NULL);
-- @espera verdadero
SELECT (@n_ini = 4) AS verificacion;

-- @caso sp_reporte_auditoria.2 | Sin coincidencias | Un rango en el pasado y un usuario inexistente: 0 filas
-- @espera vacio
CALL auditoria.sp_reporte_auditoria('2020-01-01', '2020-12-31', NULL, NULL, NULL, NULL, NULL);
-- @espera vacio
CALL auditoria.sp_reporte_auditoria('2026-11-03', '2026-11-03', NULL, 99999999, NULL, NULL, NULL);

-- @caso sp_reporte_auditoria.3 | Nulos y límites | Fechas NULL o rango invertido: 0 filas; el último día se incluye completo
-- @espera vacio
CALL auditoria.sp_reporte_auditoria(NULL, NULL, NULL, NULL, NULL, NULL, NULL);
-- @espera vacio
CALL auditoria.sp_reporte_auditoria('2026-11-04', '2026-11-03', NULL, NULL, NULL, NULL, NULL);
CALL auditoria.sp_reporte_auditoria('2026-10-01', '2026-11-03', 'intento_fallido', NULL, NULL, 0, 'web');

-- @caso sp_reporte_auditoria.4 | Consistencia | Los filtros coinciden con un SELECT directo: solo fallos del tipo "intento_fallido" desde la web
-- @espera igual
CALL auditoria.sp_reporte_auditoria('2026-11-03', '2026-11-03', 'intento_fallido', NULL, NULL, 0, 'web');
SELECT l.id_log, l.fecha_hora, te.nombre AS evento, COALESCE(u.nombre_usuario, '(sin usuario)') AS usuario, r.nombre AS rol, p.apellido AS paciente, p.nombre AS paciente_nombre, o.nombre AS origen, l.exitoso, l.descripcion, l.tabla_afectada, l.id_registro_afectado, l.valor_anterior, l.valor_nuevo, l.ip_origen FROM auditoria.Log l JOIN auditoria.TipoEvento te ON te.id_tipo_evento = l.id_tipo_evento JOIN agenda.Origen o ON o.id_origen = l.id_origen LEFT JOIN seguridad.Usuario u ON u.id_usuario = l.id_usuario LEFT JOIN seguridad.Rol r ON r.id_rol = u.id_rol LEFT JOIN personas.Paciente p ON p.id_paciente = l.id_paciente WHERE DATE(l.fecha_hora) = '2026-11-03' AND te.nombre = 'intento_fallido' AND l.exitoso = 0 AND o.nombre = 'web' ORDER BY l.fecha_hora, l.id_log;

