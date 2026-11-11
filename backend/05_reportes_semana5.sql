-- Dermalia: reportes y auditoría de la Semana 5 (MySQL 8).
-- Se corre después de 04_sp_semana4.sql:
--   mysql -u root -p < backend/05_reportes_semana5.sql
--
-- Consigna 5c: al menos 8 reportes de distinta índole, todos con funciones de
-- agrupamiento, reuniones (JOIN) y gestión de fechas. Consigna 5d: un reporte
-- de auditoría con parámetros y siempre con rango de fechas.
--
-- Todos reciben un rango de fechas (p_desde, p_hasta, ambos inclusive). Con
-- parámetros NULL o con p_desde > p_hasta devuelven 0 filas (sin error).
-- Los dos reportes con versión `_tuneado` están en 06_tuning_semana6.sql.

DELIMITER //

-- Reporte 1: turnos por período (mes) y profesional.
-- Cuántos turnos hubo, cómo terminaron, cuántas horas se agendaron y cuánto
-- se facturó (a precio de lista) en los realizados. p_id_profesional NULL = todos.
DROP PROCEDURE IF EXISTS agenda.sp_reporte_turnos_por_periodo_profesional//
CREATE PROCEDURE agenda.sp_reporte_turnos_por_periodo_profesional(
    IN p_desde DATE, IN p_hasta DATE, IN p_id_profesional INT)
BEGIN
    SELECT DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') AS periodo,
           pr.id_profesional,
           CONCAT(pr.apellido, ', ', pr.nombre) AS profesional,
           COUNT(*) AS turnos,
           SUM(e.nombre = 'realizado') AS realizados,
           SUM(e.nombre = 'cancelado') AS cancelados,
           SUM(e.nombre = 'ausente') AS ausentes,
           SUM(e.nombre IN ('pendiente', 'confirmado')) AS vigentes,
           ROUND(SUM(TIMESTAMPDIFF(MINUTE, t.fecha_hora_inicio, t.fecha_hora_fin)) / 60, 1) AS horas_agendadas,
           SUM(CASE WHEN e.nombre = 'realizado'
                    THEN (SELECT SUM(tp.precio_aplicado) FROM agenda.TurnoProtocolo tp WHERE tp.id_turno = t.id_turno)
                    ELSE 0 END) AS facturado
      FROM agenda.Turno t
      JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE DATE(t.fecha_hora_inicio) BETWEEN p_desde AND p_hasta
       AND (p_id_profesional IS NULL OR t.id_profesional = p_id_profesional)
     GROUP BY DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m'), pr.id_profesional, pr.apellido, pr.nombre
     ORDER BY periodo, profesional;
END//

-- Reporte 2: ingresos por seña, reembolsos y retenciones, por mes y medio de pago.
-- Lo retenido es lo que el instituto se queda de las señas ya resueltas.
DROP PROCEDURE IF EXISTS pagos.sp_reporte_ingresos_sena//
CREATE PROCEDURE pagos.sp_reporte_ingresos_sena(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT DATE_FORMAT(ps.fecha_pago, '%Y-%m') AS periodo,
           (SELECT mp.nombre FROM pagos.MedioPago mp WHERE mp.id_medio_pago = ps.id_medio_pago) AS medio_pago,
           COUNT(*) AS pagos,
           SUM(ps.monto) AS cobrado,
           SUM(COALESCE(ps.monto_reembolsado, 0)) AS reembolsado,
           SUM(CASE WHEN ep.nombre IN ('retenida', 'reembolsada parcial') THEN ps.monto - COALESCE(ps.monto_reembolsado, 0) ELSE 0 END) AS retenido,
           SUM(ps.monto - COALESCE(ps.monto_reembolsado, 0)) AS neto
      FROM pagos.PagoSena ps
      JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
     WHERE DATE(ps.fecha_pago) BETWEEN p_desde AND p_hasta
     GROUP BY DATE_FORMAT(ps.fecha_pago, '%Y-%m'), ps.id_medio_pago
     ORDER BY periodo, medio_pago;
END//

-- Reporte 3: cancelaciones e inasistencias (los "turnos perdidos" de la MML).
-- p_agrupar: 'mes' (por defecto) o 'semana'. Muestra por origen cuántos turnos
-- se perdieron, la tasa de pérdida y la plata de señas retenida.
DROP PROCEDURE IF EXISTS agenda.sp_reporte_cancelaciones_inasistencias//
CREATE PROCEDURE agenda.sp_reporte_cancelaciones_inasistencias(IN p_desde DATE, IN p_hasta DATE, IN p_agrupar VARCHAR(10))
BEGIN
    DECLARE v_semana TINYINT DEFAULT (p_agrupar = 'semana');
    SELECT x.periodo, x.origen,
           COUNT(*) AS turnos,
           SUM(x.estado = 'cancelado') AS cancelados,
           SUM(x.estado = 'cancelado' AND x.estado_sena = 'reembolsada') AS cancelados_con_aviso,
           SUM(x.estado = 'cancelado' AND x.estado_sena = 'retenida') AS cancelados_tarde,
           SUM(x.estado = 'ausente') AS ausentes,
           ROUND(100 * SUM(x.estado IN ('cancelado', 'ausente')) / COUNT(*), 1) AS tasa_perdida_pct,
           COALESCE(SUM(CASE WHEN x.estado IN ('cancelado', 'ausente') AND x.estado_sena IN ('retenida', 'reembolsada parcial')
                             THEN x.monto - COALESCE(x.reembolsado, 0) END), 0) AS sena_retenida
      FROM (SELECT IF(v_semana, DATE_FORMAT(t.fecha_hora_inicio, '%x-S%v'), DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m')) AS periodo,
                   o.nombre AS origen, e.nombre AS estado, ep.nombre AS estado_sena, ps.monto, ps.monto_reembolsado AS reembolsado
              FROM agenda.Turno t
              JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
              JOIN agenda.Origen o ON o.id_origen = t.id_origen
              LEFT JOIN pagos.PagoSena ps ON ps.id_turno = t.id_turno
              LEFT JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
             WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY) x
     GROUP BY x.periodo, x.origen
     ORDER BY x.periodo, x.origen;
END//

-- Reporte 4: evaluaciones previas y cirugías por resultado.
-- Por cirugía y resultado: cuántas evaluaciones, cuántas terminaron en una
-- cirugía agendada, cuántas vencieron sin agendar, en cuántos días se
-- decidieron y cuánta plata de consultas retuvo el instituto.
-- Se cuentan las consultas realizadas dentro del rango.
DROP PROCEDURE IF EXISTS clinica.sp_reporte_evaluaciones_cirugias//
CREATE PROCEDURE clinica.sp_reporte_evaluaciones_cirugias(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT cir.nombre AS cirugia,
           r.nombre AS resultado,
           COUNT(*) AS evaluaciones,
           COUNT(tc.id_turno) AS con_cirugia_agendada,
           SUM(r.nombre = 'apto' AND tc.id_turno IS NULL AND ev.fecha_resultado + INTERVAL 6 MONTH < auditoria.fn_ahora()) AS vencidas_sin_cirugia,
           ROUND(AVG(TIMESTAMPDIFF(DAY, ev.fecha_resultado, tc.fecha_creacion)), 1) AS dias_promedio_hasta_agendar,
           SUM(ev.fecha_reclamo IS NOT NULL) AS reclamos,
           COALESCE(SUM(CASE WHEN ep.nombre IN ('retenida', 'reembolsada parcial') THEN ps.monto - COALESCE(ps.monto_reembolsado, 0) END), 0) AS consulta_retenida
      FROM clinica.EvaluacionPrevia ev
      JOIN clinica.Protocolo cir ON cir.id_protocolo = ev.id_protocolo
      JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
      JOIN agenda.Turno t ON t.id_turno = ev.id_turno
      LEFT JOIN agenda.Turno tc ON tc.id_evaluacion_previa = ev.id_evaluacion
      LEFT JOIN pagos.PagoSena ps ON ps.id_turno = ev.id_turno
      LEFT JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
     WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
     GROUP BY cir.id_protocolo, cir.nombre, r.id_resultado, r.nombre
     ORDER BY cirugia, resultado;
END//

-- Reporte 5: protocolos más pedidos en un período (sin contar turnos cancelados).
-- Puesto en el ranking = 1 + cuántos protocolos tienen más pedidos (o los mismos y
-- un nombre anterior en el alfabeto); porcentaje sobre el total de pedidos.
-- p_limite NULL = 10. Se arma con tablas temporales, como el Cheetah A del material:
-- primero se filtra y se agrupa, después se compara. n2 es una copia de n1 porque
-- MySQL no deja usar dos veces la misma tabla temporal en una consulta.
DROP PROCEDURE IF EXISTS clinica.sp_reporte_protocolos_mas_pedidos//
CREATE PROCEDURE clinica.sp_reporte_protocolos_mas_pedidos(IN p_desde DATE, IN p_hasta DATE, IN p_limite INT)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n2;

    CREATE TEMPORARY TABLE tmp_pedidos_n1 AS
    SELECT p.id_protocolo, p.nombre AS protocolo, c.nombre AS categoria,
           COUNT(*) AS pedidos, SUM(tp.precio_aplicado) AS ingresos_lista
      FROM agenda.TurnoProtocolo tp
      JOIN agenda.Turno t ON t.id_turno = tp.id_turno
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre <> 'cancelado'
      JOIN clinica.Protocolo p ON p.id_protocolo = tp.id_protocolo
      JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
     WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
     GROUP BY p.id_protocolo, p.nombre, c.nombre;

    CREATE TEMPORARY TABLE tmp_pedidos_n2 AS
    SELECT id_protocolo, protocolo, pedidos
      FROM tmp_pedidos_n1;

    SELECT x.puesto, x.protocolo, x.categoria, x.pedidos, x.ingresos_lista,
           ROUND(100 * x.pedidos / x.total_pedidos, 1) AS porcentaje
      FROM (
            SELECT 1 + COUNT(m.id_protocolo) AS puesto,
                   a.protocolo, a.categoria, a.pedidos, a.ingresos_lista,
                   (SELECT SUM(pedidos) FROM tmp_pedidos_n2) AS total_pedidos
              FROM tmp_pedidos_n1 a
              LEFT JOIN tmp_pedidos_n2 m
                     ON m.pedidos > a.pedidos
                     OR (m.pedidos = a.pedidos AND m.protocolo < a.protocolo)
             GROUP BY a.id_protocolo, a.protocolo, a.categoria, a.pedidos, a.ingresos_lista
           ) x
     WHERE x.puesto <= COALESCE(p_limite, 10)
     ORDER BY x.puesto, x.protocolo;

    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n2;
END//

-- Reporte 6: ocupación por profesional = horas con turno / horas de disponibilidad.
DROP PROCEDURE IF EXISTS agenda.sp_reporte_ocupacion_profesional//
CREATE PROCEDURE agenda.sp_reporte_ocupacion_profesional(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT pr.id_profesional, CONCAT(pr.apellido, ', ', pr.nombre) AS profesional,
           ROUND(COALESCE(d.horas, 0), 1) AS horas_disponibles,
           ROUND(COALESCE(o.horas, 0), 1) AS horas_ocupadas,
           COALESCE(o.turnos, 0) AS turnos,
           ROUND(100 * COALESCE(o.horas, 0) / NULLIF(d.horas, 0), 1) AS ocupacion_pct
      FROM personas.Profesional pr
      LEFT JOIN (SELECT dd.id_profesional, SUM(TIME_TO_SEC(TIMEDIFF(dd.hora_fin, dd.hora_inicio))) / 3600 AS horas
                   FROM personas.Disponibilidad dd
                  WHERE dd.activa = 1 AND dd.fecha BETWEEN p_desde AND p_hasta
                  GROUP BY dd.id_profesional) d ON d.id_profesional = pr.id_profesional
      LEFT JOIN (SELECT t.id_profesional, COUNT(*) AS turnos, SUM(TIMESTAMPDIFF(MINUTE, t.fecha_hora_inicio, t.fecha_hora_fin)) / 60 AS horas
                   FROM agenda.Turno t
                   JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre <> 'cancelado'
                  WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
                  GROUP BY t.id_profesional) o ON o.id_profesional = pr.id_profesional
     WHERE p_desde IS NOT NULL AND p_hasta IS NOT NULL AND p_desde <= p_hasta
       AND (d.horas IS NOT NULL OR o.horas IS NOT NULL)
     ORDER BY ocupacion_pct DESC, profesional;
END//

-- Reporte 7: uso de cupones y reglas de beneficio, por regla.
-- Cupones emitidos en el rango: cuántos se usaron, cuántos vencieron sin usar,
-- cuántos siguen vigentes, tasa de uso y descuento total otorgado.
DROP PROCEDURE IF EXISTS beneficios.sp_reporte_cupones//
CREATE PROCEDURE beneficios.sp_reporte_cupones(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT r.id_regla, r.nombre AS regla, tr.nombre AS tipo, r.porcentaje_descuento AS descuento_pct,
           COUNT(*) AS emitidos,
           SUM(c.id_turno IS NOT NULL) AS usados,
           SUM(c.id_turno IS NULL AND c.fecha_vencimiento <= auditoria.fn_ahora()) AS vencidos_sin_usar,
           SUM(c.id_turno IS NULL AND c.fecha_vencimiento > auditoria.fn_ahora()) AS vigentes,
           ROUND(100 * SUM(c.id_turno IS NOT NULL) / COUNT(*), 1) AS tasa_uso_pct,
           COALESCE(SUM(pt.total * c.porcentaje_descuento / 100), 0) AS descuento_otorgado
      FROM beneficios.Cupon c
      JOIN beneficios.ReglaBeneficio r ON r.id_regla = c.id_regla
      JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla
      LEFT JOIN (SELECT tp.id_turno, SUM(tp.precio_aplicado) AS total FROM agenda.TurnoProtocolo tp GROUP BY tp.id_turno) pt ON pt.id_turno = c.id_turno
     WHERE c.fecha_emision >= p_desde AND c.fecha_emision < p_hasta + INTERVAL 1 DAY
     GROUP BY r.id_regla, r.nombre, tr.nombre, r.porcentaje_descuento
     ORDER BY emitidos DESC, regla;
END//

-- Reporte 8: saldo y uso de las tarjetas de regalo compradas en el rango.
-- El código se muestra recortado: el código completo funciona como un billete.
DROP PROCEDURE IF EXISTS pagos.sp_reporte_tarjetas_regalo//
CREATE PROCEDURE pagos.sp_reporte_tarjetas_regalo(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT t.id_tarjeta, CONCAT(LEFT(t.codigo, 7), '…') AS codigo, t.comprador_nombre, mp.nombre AS medio_compra,
           DATE(t.fecha_compra) AS fecha_compra, DATE(t.fecha_vencimiento) AS vence,
           t.monto_inicial,
           COALESCE(SUM(CASE WHEN m.monto > 0 THEN m.monto END), 0) AS gastado,
           COALESCE(-SUM(CASE WHEN m.monto < 0 THEN m.monto END), 0) AS devuelto,
           t.monto_inicial - COALESCE(SUM(m.monto), 0) AS saldo,
           COUNT(m.id_movimiento) AS movimientos,
           MAX(m.fecha_movimiento) AS ultimo_uso,
           CASE WHEN t.fecha_vencimiento <= auditoria.fn_ahora() THEN 'vencida'
                WHEN t.monto_inicial - COALESCE(SUM(m.monto), 0) <= 0 THEN 'agotada'
                WHEN COUNT(m.id_movimiento) = 0 THEN 'sin uso'
                ELSE 'en uso' END AS situacion
      FROM pagos.TarjetaRegalo t
      JOIN pagos.MedioPago mp ON mp.id_medio_pago = t.id_medio_pago
      LEFT JOIN pagos.MovimientoTarjeta m ON m.id_tarjeta = t.id_tarjeta
     WHERE t.fecha_compra >= p_desde AND t.fecha_compra < p_hasta + INTERVAL 1 DAY
     GROUP BY t.id_tarjeta, t.codigo, t.comprador_nombre, mp.nombre, t.fecha_compra, t.fecha_vencimiento, t.monto_inicial
     ORDER BY t.fecha_compra, t.id_tarjeta;
END//

-- Reporte de auditoría (consigna 5d): quién hizo qué, cuándo y desde dónde.
-- El rango de fechas es obligatorio (p_hasta incluye todo ese día). Los demás
-- filtros son opcionales (NULL = sin filtrar):
--   p_tipo_evento  nombre del tipo ('inicio_sesion', 'alta_turno', ...)
--   p_id_usuario   quién hizo la acción
--   p_id_paciente  paciente involucrada
--   p_exitoso      1 = solo lo que salió bien, 0 = solo los fallos
--   p_origen       'terminal', 'web', 'gestion' o 'sistema'
DROP PROCEDURE IF EXISTS auditoria.sp_reporte_auditoria//
CREATE PROCEDURE auditoria.sp_reporte_auditoria(
    IN p_desde DATE, IN p_hasta DATE, IN p_tipo_evento VARCHAR(50), IN p_id_usuario INT,
    IN p_id_paciente INT, IN p_exitoso TINYINT, IN p_origen VARCHAR(50))
BEGIN
    SELECT l.id_log, l.fecha_hora, te.nombre AS evento, COALESCE(u.nombre_usuario, '(sin usuario)') AS usuario,
           r.nombre AS rol, CONCAT(p.apellido, ', ', p.nombre) AS paciente, o.nombre AS origen,
           l.exitoso, l.descripcion, l.tabla_afectada, l.id_registro_afectado, l.valor_anterior, l.valor_nuevo, l.ip_origen
      FROM auditoria.Log l
      JOIN auditoria.TipoEvento te ON te.id_tipo_evento = l.id_tipo_evento
      JOIN agenda.Origen o ON o.id_origen = l.id_origen
      LEFT JOIN seguridad.Usuario u ON u.id_usuario = l.id_usuario
      LEFT JOIN seguridad.Rol r ON r.id_rol = u.id_rol
      LEFT JOIN personas.Paciente p ON p.id_paciente = l.id_paciente
     WHERE l.fecha_hora >= p_desde AND l.fecha_hora < p_hasta + INTERVAL 1 DAY
       AND (p_tipo_evento IS NULL OR te.nombre = p_tipo_evento)
       AND (p_id_usuario IS NULL OR l.id_usuario = p_id_usuario)
       AND (p_id_paciente IS NULL OR l.id_paciente = p_id_paciente)
       AND (p_exitoso IS NULL OR l.exitoso = p_exitoso)
       AND (p_origen IS NULL OR o.nombre = p_origen)
     ORDER BY l.fecha_hora, l.id_log;
END//

DELIMITER ;
