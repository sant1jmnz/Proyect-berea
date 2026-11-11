-- Dermalia: tuning de la Semana 6 (MySQL 8).
-- Se corre después de 05_reportes_semana5.sql:
--   mysql -u root -p < backend/06_tuning_semana6.sql
--
-- Consigna 5e: dos reportes que lo justifican, con una versión `_tuneado` del
-- stored procedure (mismo nombre + `_tuneado`, mismos parámetros, mismas filas):
--
--   Reporte 1  agenda.sp_reporte_turnos_por_periodo_profesional  -> ..._tuneado
--   Reporte 2  pagos.sp_reporte_ingresos_sena                    -> ..._tuneado
--
-- Técnica de la cátedra (PPT 004, "Caracol" contra "Cheetah"): el original junta
-- las tablas completas y filtra al final (Caracol). El tuneado aplica las reglas de
-- transformación del álgebra relacional (Cheetah A, con tablas temporales):
--   1. Selección conmutativa: el filtro por fechas (y por profesional) se aplica
--      sobre la tabla de origen, antes de cualquier reunión.
--   2. Proyección conmutativa: cada tabla aporta solo las columnas que se usan.
--   3. Reunión: recién entonces se juntan las tablas ya reducidas, de a una.
--   4. Agrupamiento al final.
-- Cada paso es una tabla temporal (N1, N2...), así se puede ver cuántas filas
-- llegan a cada reunión (backend/medir_tuning.sql las cuenta).
-- Cada tabla temporal se usa una sola vez por consulta: MySQL no deja usar dos
-- veces la misma tabla temporal en una misma sentencia.

DELIMITER //

-- Reporte 1 tuneado. Devuelve exactamente lo mismo que el original.
DROP PROCEDURE IF EXISTS agenda.sp_reporte_turnos_por_periodo_profesional_tuneado//
CREATE PROCEDURE agenda.sp_reporte_turnos_por_periodo_profesional_tuneado(
    IN p_desde DATE, IN p_hasta DATE, IN p_id_profesional INT)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n4;

    -- N1: Turno con la selección (fechas y profesional) y la proyección aplicadas
    CREATE TEMPORARY TABLE tmp_r1_n1 AS
    SELECT id_turno, id_profesional, id_estado_turno, fecha_hora_inicio, fecha_hora_fin
      FROM agenda.Turno
     WHERE DATE(fecha_hora_inicio) BETWEEN p_desde AND p_hasta
       AND (p_id_profesional IS NULL OR id_profesional = p_id_profesional);

    -- N2: EstadoTurno proyectado
    CREATE TEMPORARY TABLE tmp_r1_n2 AS
    SELECT id_estado_turno, nombre
      FROM agenda.EstadoTurno;

    -- N3: Profesional proyectado
    CREATE TEMPORARY TABLE tmp_r1_n3 AS
    SELECT id_profesional, apellido, nombre
      FROM personas.Profesional;

    -- N4: total de lista de cada turno de N1 (se junta TurnoProtocolo solo con esos turnos)
    CREATE TEMPORARY TABLE tmp_r1_n4 AS
    SELECT tp.id_turno, SUM(tp.precio_aplicado) AS total
      FROM agenda.TurnoProtocolo tp
      JOIN tmp_r1_n1 a ON a.id_turno = tp.id_turno
     GROUP BY tp.id_turno;

    -- Reunión final y agrupamiento
    SELECT DATE_FORMAT(a.fecha_hora_inicio, '%Y-%m') AS periodo,
           p.id_profesional,
           p.apellido AS profesional, p.nombre AS profesional_nombre,
           COUNT(*) AS turnos,
           SUM(e.nombre = 'realizado') AS realizados,
           SUM(e.nombre = 'cancelado') AS cancelados,
           SUM(e.nombre = 'ausente') AS ausentes,
           SUM(e.nombre IN ('pendiente', 'confirmado')) AS vigentes,
           ROUND(SUM(agenda.fn_minutos(a.fecha_hora_inicio, a.fecha_hora_fin)) / 60, 1) AS horas_agendadas,
           SUM(CASE WHEN e.nombre = 'realizado' THEN f.total ELSE 0 END) AS facturado
      FROM tmp_r1_n1 a
      JOIN tmp_r1_n3 p ON p.id_profesional = a.id_profesional
      JOIN tmp_r1_n2 e ON e.id_estado_turno = a.id_estado_turno
      LEFT JOIN tmp_r1_n4 f ON f.id_turno = a.id_turno
     GROUP BY DATE_FORMAT(a.fecha_hora_inicio, '%Y-%m'), p.id_profesional, p.apellido, p.nombre
     ORDER BY periodo, profesional, profesional_nombre;

    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n4;
END//

-- Reporte 2 tuneado. Devuelve exactamente lo mismo que el original.
DROP PROCEDURE IF EXISTS pagos.sp_reporte_ingresos_sena_tuneado//
CREATE PROCEDURE pagos.sp_reporte_ingresos_sena_tuneado(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n3;

    -- N1: PagoSena con la selección (fechas) y la proyección aplicadas
    CREATE TEMPORARY TABLE tmp_r2_n1 AS
    SELECT id_medio_pago, id_estado_pago, monto, monto_reembolsado, fecha_pago
      FROM pagos.PagoSena
     WHERE DATE(fecha_pago) BETWEEN p_desde AND p_hasta;

    -- N2: EstadoPago proyectado
    CREATE TEMPORARY TABLE tmp_r2_n2 AS
    SELECT id_estado_pago, nombre
      FROM pagos.EstadoPago;

    -- N3: MedioPago proyectado
    CREATE TEMPORARY TABLE tmp_r2_n3 AS
    SELECT id_medio_pago, nombre
      FROM pagos.MedioPago;

    -- Reunión final y agrupamiento
    SELECT DATE_FORMAT(a.fecha_pago, '%Y-%m') AS periodo,
           m.nombre AS medio_pago,
           COUNT(*) AS pagos,
           SUM(a.monto) AS cobrado,
           SUM(COALESCE(a.monto_reembolsado, 0)) AS reembolsado,
           SUM(CASE WHEN e.nombre IN ('retenida', 'reembolsada parcial') THEN a.monto - COALESCE(a.monto_reembolsado, 0) ELSE 0 END) AS retenido,
           SUM(a.monto - COALESCE(a.monto_reembolsado, 0)) AS neto
      FROM tmp_r2_n1 a
      JOIN tmp_r2_n2 e ON e.id_estado_pago = a.id_estado_pago
      JOIN tmp_r2_n3 m ON m.id_medio_pago = a.id_medio_pago
     GROUP BY DATE_FORMAT(a.fecha_pago, '%Y-%m'), a.id_medio_pago, m.nombre
     ORDER BY periodo, medio_pago;

    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n3;
END//

DELIMITER ;
