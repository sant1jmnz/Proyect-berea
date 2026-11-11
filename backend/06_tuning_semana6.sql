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
-- Por qué estos dos: son los que recorren las tablas que más crecen (Turno y
-- PagoSena), siempre filtrando por un rango de fechas, y los originales tienen
-- los tres problemas clásicos:
--   1. DATE(columna) BETWEEN ...  tapa el índice: la base tiene que leer TODA la
--      tabla y calcular DATE() fila por fila. Se reemplaza por un rango
--      (columna >= desde AND columna < hasta + 1 día), que sí usa el índice.
--   2. Una subconsulta correlacionada por cada fila (el nombre del medio de
--      pago, el total de cada turno). Se reemplaza por un JOIN o por una
--      agregación hecha una sola vez.
--   3. Joins a tablas maestras solo para comparar un nombre ('realizado'). Se
--      busca el id una vez al principio y se compara el número.
-- Y se agregan índices que cubren el filtro y las columnas del reporte.
-- La medición con datos de volumen y el plan de ejecución están en
-- backend/medir_tuning.sql y en docs/11-pruebas-bbdd.md.

DELIMITER //

-- Crea un índice solo si no existe (MySQL no tiene CREATE INDEX IF NOT EXISTS).
-- Auxiliar del tuning: crea un índice solo si todavía no existe (MySQL no
-- tiene CREATE INDEX IF NOT EXISTS). Se borra apenas termina de usarse.
DROP PROCEDURE IF EXISTS auditoria.sp_crear_indice_si_falta//
CREATE PROCEDURE auditoria.sp_crear_indice_si_falta(IN p_schema VARCHAR(64), IN p_tabla VARCHAR(64), IN p_indice VARCHAR(64), IN p_columnas VARCHAR(300))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.statistics
                    WHERE table_schema = p_schema AND table_name = p_tabla AND index_name = p_indice) THEN
        SET @sql_indice = CONCAT('CREATE INDEX ', p_indice, ' ON ', p_schema, '.', p_tabla, ' (', p_columnas, ')');
        PREPARE st FROM @sql_indice;
        EXECUTE st;
        DEALLOCATE PREPARE st;
    END IF;
END//

-- Índice del reporte 1 y también del 3, 5 y 6: por fecha de inicio, con las
-- columnas que el reporte lee, así no hace falta ir a buscar la fila entera.
CALL auditoria.sp_crear_indice_si_falta('agenda', 'Turno', 'IX_Turno_inicio_profesional_estado', 'fecha_hora_inicio, id_profesional, id_estado_turno, fecha_hora_fin')//
-- Índice del reporte 2: por fecha de pago, con medio, estado y montos.
CALL auditoria.sp_crear_indice_si_falta('pagos', 'PagoSena', 'IX_PagoSena_fecha_medio_estado', 'fecha_pago, id_medio_pago, id_estado_pago, monto, monto_reembolsado')//
DROP PROCEDURE IF EXISTS auditoria.sp_crear_indice_si_falta//

-- Reporte 1 tuneado. Devuelve exactamente lo mismo que el original.
DROP PROCEDURE IF EXISTS agenda.sp_reporte_turnos_por_periodo_profesional_tuneado//
CREATE PROCEDURE agenda.sp_reporte_turnos_por_periodo_profesional_tuneado(
    IN p_desde DATE, IN p_hasta DATE, IN p_id_profesional INT)
BEGIN
    DECLARE v_realizado INT;
    DECLARE v_cancelado INT;
    DECLARE v_ausente INT;
    DECLARE v_pendiente INT;
    DECLARE v_confirmado INT;
    SELECT MAX(CASE WHEN nombre = 'realizado' THEN id_estado_turno END), MAX(CASE WHEN nombre = 'cancelado' THEN id_estado_turno END),
           MAX(CASE WHEN nombre = 'ausente' THEN id_estado_turno END), MAX(CASE WHEN nombre = 'pendiente' THEN id_estado_turno END),
           MAX(CASE WHEN nombre = 'confirmado' THEN id_estado_turno END)
      INTO v_realizado, v_cancelado, v_ausente, v_pendiente, v_confirmado
      FROM agenda.EstadoTurno;

    SELECT DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') AS periodo,
           pr.id_profesional,
           CONCAT(pr.apellido, ', ', pr.nombre) AS profesional,
           COUNT(*) AS turnos,
           SUM(t.id_estado_turno = v_realizado) AS realizados,
           SUM(t.id_estado_turno = v_cancelado) AS cancelados,
           SUM(t.id_estado_turno = v_ausente) AS ausentes,
           SUM(t.id_estado_turno IN (v_pendiente, v_confirmado)) AS vigentes,
           ROUND(SUM(TIMESTAMPDIFF(MINUTE, t.fecha_hora_inicio, t.fecha_hora_fin)) / 60, 1) AS horas_agendadas,
           COALESCE(SUM(f.total), 0) AS facturado
      FROM agenda.Turno t
      JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
      LEFT JOIN (SELECT tp.id_turno, SUM(tp.precio_aplicado) AS total
                   FROM agenda.TurnoProtocolo tp
                   JOIN agenda.Turno t2 ON t2.id_turno = tp.id_turno
                  WHERE t2.fecha_hora_inicio >= p_desde AND t2.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
                    AND t2.id_estado_turno = v_realizado
                  GROUP BY tp.id_turno) f ON f.id_turno = t.id_turno
     WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
       AND (p_id_profesional IS NULL OR t.id_profesional = p_id_profesional)
     GROUP BY DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m'), pr.id_profesional, pr.apellido, pr.nombre
     ORDER BY periodo, profesional;
END//

-- Reporte 2 tuneado. Devuelve exactamente lo mismo que el original.
DROP PROCEDURE IF EXISTS pagos.sp_reporte_ingresos_sena_tuneado//
CREATE PROCEDURE pagos.sp_reporte_ingresos_sena_tuneado(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    DECLARE v_retenida INT;
    DECLARE v_parcial INT;
    SELECT MAX(CASE WHEN nombre = 'retenida' THEN id_estado_pago END), MAX(CASE WHEN nombre = 'reembolsada parcial' THEN id_estado_pago END)
      INTO v_retenida, v_parcial
      FROM pagos.EstadoPago;

    SELECT DATE_FORMAT(ps.fecha_pago, '%Y-%m') AS periodo,
           mp.nombre AS medio_pago,
           COUNT(*) AS pagos,
           SUM(ps.monto) AS cobrado,
           SUM(COALESCE(ps.monto_reembolsado, 0)) AS reembolsado,
           SUM(CASE WHEN ps.id_estado_pago IN (v_retenida, v_parcial) THEN ps.monto - COALESCE(ps.monto_reembolsado, 0) ELSE 0 END) AS retenido,
           SUM(ps.monto - COALESCE(ps.monto_reembolsado, 0)) AS neto
      FROM pagos.PagoSena ps
      JOIN pagos.MedioPago mp ON mp.id_medio_pago = ps.id_medio_pago
     WHERE ps.fecha_pago >= p_desde AND ps.fecha_pago < p_hasta + INTERVAL 1 DAY
     GROUP BY DATE_FORMAT(ps.fecha_pago, '%Y-%m'), ps.id_medio_pago, mp.nombre
     ORDER BY periodo, medio_pago;
END//

DELIMITER ;
