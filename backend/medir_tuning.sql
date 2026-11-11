-- Dermalia: medición del tuning (consigna 5e) con datos de volumen.
-- Se corre DESPUÉS de 06_tuning_semana6.sql, con la base cargada:
--   mysql -u root -p < backend/medir_tuning.sql
--
-- Con los 150 turnos de ejemplo la diferencia entre un SP y su versión _tuneado
-- no se nota (todo cabe en memoria y se lee en milisegundos). Para mostrarla,
-- este script:
--   1. quita los dos índices del tuning (queda el "antes");
--   2. carga 300.000 turnos y ~240.000 pagos de mentira;
--   3. mide con EXPLAIN ANALYZE el original y el tuneado, SIN índices;
--   4. crea los índices y vuelve a medir (queda el "después");
--   5. borra los datos de volumen (por id) y deja los índices creados.
-- (No se usa ROLLBACK: CREATE INDEX confirma la transacción por dentro, así que
-- los datos de mentira se borran a mano al final.)
-- Se mide la consulta que hay dentro de cada SP, con las fechas escritas a mano,
-- porque EXPLAIN ANALYZE no se puede ejecutar dentro de un SP.
-- En cada plan hay que mirar la línea de arriba: "actual time=A..B" (B = milisegundos
-- totales) y los "rows=" de la tabla leída: sin índice lee toda la tabla.

SET SESSION cte_max_recursion_depth = 400000;

DELIMITER //
-- Quita un índice si existe (MySQL no tiene DROP INDEX IF EXISTS).
DROP PROCEDURE IF EXISTS auditoria.sp_quitar_indice_si_existe//
CREATE PROCEDURE auditoria.sp_quitar_indice_si_existe(IN p_schema VARCHAR(64), IN p_tabla VARCHAR(64), IN p_indice VARCHAR(64))
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.statistics WHERE table_schema = p_schema AND table_name = p_tabla AND index_name = p_indice) THEN
        SET @sql_indice = CONCAT('DROP INDEX ', p_indice, ' ON ', p_schema, '.', p_tabla);
        PREPARE st FROM @sql_indice; EXECUTE st; DEALLOCATE PREPARE st;
    END IF;
END//
DELIMITER ;

CALL auditoria.sp_quitar_indice_si_existe('agenda', 'Turno', 'IX_Turno_inicio_profesional_estado');
CALL auditoria.sp_quitar_indice_si_existe('pagos', 'PagoSena', 'IX_PagoSena_fecha_medio_estado');

SELECT COALESCE(MAX(id_turno), 0) INTO @base FROM agenda.Turno;
SELECT COALESCE(MAX(id_pago), 0) INTO @base_pago FROM pagos.PagoSena;

-- 300.000 turnos, uno cada 7 minutos desde enero de 2024 (casi 4 años)
INSERT INTO agenda.Turno (id_paciente, id_profesional, id_estado_turno, id_origen, fecha_hora_inicio, fecha_hora_fin, fecha_creacion)
WITH RECURSIVE n AS (SELECT 1 AS k UNION ALL SELECT k + 1 FROM n WHERE k < 300000)
SELECT 1 + k MOD 60, 1 + k MOD 20, 1 + k MOD 5, 1 + k MOD 4,
       TIMESTAMP('2024-01-01') + INTERVAL (7 * k) MINUTE, TIMESTAMP('2024-01-01') + INTERVAL (7 * k + 30) MINUTE,
       TIMESTAMP('2024-01-01') + INTERVAL (7 * k) MINUTE - INTERVAL 5 DAY
  FROM n;
INSERT INTO agenda.TurnoProtocolo (id_turno, id_protocolo, precio_aplicado)
SELECT id_turno, 1 + id_turno MOD 24, 90000 FROM agenda.Turno WHERE id_turno > @base;
INSERT INTO pagos.PagoSena (id_turno, id_estado_pago, id_medio_pago, monto, fecha_pago, codigo_operacion, monto_reembolsado)
SELECT id_turno, 1 + id_turno MOD 5, 1 + id_turno MOD 4, 27000, fecha_hora_inicio - INTERVAL 3 DAY, CONCAT('SIMV-', id_turno), 0
  FROM agenda.Turno WHERE id_turno > @base AND id_turno MOD 5 <> 1;
ANALYZE TABLE agenda.Turno, agenda.TurnoProtocolo, pagos.PagoSena;
SELECT (SELECT COUNT(*) FROM agenda.Turno) AS turnos, (SELECT COUNT(*) FROM pagos.PagoSena) AS pagos;

-- ===================== ANTES: sin índices =====================
SELECT '--- REPORTE 1 ORIGINAL, sin índice ---' AS medicion;
EXPLAIN ANALYZE
SELECT DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') AS periodo, pr.id_profesional, CONCAT(pr.apellido, ', ', pr.nombre) AS profesional,
       COUNT(*) AS turnos, SUM(e.nombre = 'realizado') AS realizados, SUM(e.nombre = 'cancelado') AS cancelados,
       SUM(e.nombre = 'ausente') AS ausentes, SUM(e.nombre IN ('pendiente', 'confirmado')) AS vigentes,
       ROUND(SUM(TIMESTAMPDIFF(MINUTE, t.fecha_hora_inicio, t.fecha_hora_fin)) / 60, 1) AS horas_agendadas,
       SUM(CASE WHEN e.nombre = 'realizado' THEN (SELECT SUM(tp.precio_aplicado) FROM agenda.TurnoProtocolo tp WHERE tp.id_turno = t.id_turno) ELSE 0 END) AS facturado
  FROM agenda.Turno t
  JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
  JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
 WHERE DATE(t.fecha_hora_inicio) BETWEEN '2025-03-01' AND '2025-03-31'
 GROUP BY DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m'), pr.id_profesional, pr.apellido, pr.nombre
 ORDER BY periodo, profesional;

SELECT '--- REPORTE 1 TUNEADO, sin índice (solo reescritura) ---' AS medicion;
EXPLAIN ANALYZE
SELECT DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') AS periodo, pr.id_profesional, CONCAT(pr.apellido, ', ', pr.nombre) AS profesional,
       COUNT(*) AS turnos, SUM(t.id_estado_turno = 3) AS realizados, SUM(t.id_estado_turno = 4) AS cancelados,
       SUM(t.id_estado_turno = 5) AS ausentes, SUM(t.id_estado_turno IN (1, 2)) AS vigentes,
       ROUND(SUM(TIMESTAMPDIFF(MINUTE, t.fecha_hora_inicio, t.fecha_hora_fin)) / 60, 1) AS horas_agendadas,
       COALESCE(SUM(f.total), 0) AS facturado
  FROM agenda.Turno t
  JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
  LEFT JOIN (SELECT tp.id_turno, SUM(tp.precio_aplicado) AS total FROM agenda.TurnoProtocolo tp
               JOIN agenda.Turno t2 ON t2.id_turno = tp.id_turno
              WHERE t2.fecha_hora_inicio >= '2025-03-01' AND t2.fecha_hora_inicio < '2025-03-31' + INTERVAL 1 DAY AND t2.id_estado_turno = 3
              GROUP BY tp.id_turno) f ON f.id_turno = t.id_turno
 WHERE t.fecha_hora_inicio >= '2025-03-01' AND t.fecha_hora_inicio < '2025-03-31' + INTERVAL 1 DAY
 GROUP BY DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m'), pr.id_profesional, pr.apellido, pr.nombre
 ORDER BY periodo, profesional;

SELECT '--- REPORTE 2 ORIGINAL, sin índice ---' AS medicion;
EXPLAIN ANALYZE
SELECT DATE_FORMAT(ps.fecha_pago, '%Y-%m') AS periodo,
       (SELECT mp.nombre FROM pagos.MedioPago mp WHERE mp.id_medio_pago = ps.id_medio_pago) AS medio_pago,
       COUNT(*) AS pagos, SUM(ps.monto) AS cobrado, SUM(COALESCE(ps.monto_reembolsado, 0)) AS reembolsado,
       SUM(CASE WHEN ep.nombre IN ('retenida', 'reembolsada parcial') THEN ps.monto - COALESCE(ps.monto_reembolsado, 0) ELSE 0 END) AS retenido,
       SUM(ps.monto - COALESCE(ps.monto_reembolsado, 0)) AS neto
  FROM pagos.PagoSena ps
  JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
 WHERE DATE(ps.fecha_pago) BETWEEN '2025-03-01' AND '2025-03-31'
 GROUP BY DATE_FORMAT(ps.fecha_pago, '%Y-%m'), ps.id_medio_pago
 ORDER BY periodo, medio_pago;

SELECT '--- REPORTE 2 TUNEADO, sin índice (solo reescritura) ---' AS medicion;
EXPLAIN ANALYZE
SELECT DATE_FORMAT(ps.fecha_pago, '%Y-%m') AS periodo, mp.nombre AS medio_pago,
       COUNT(*) AS pagos, SUM(ps.monto) AS cobrado, SUM(COALESCE(ps.monto_reembolsado, 0)) AS reembolsado,
       SUM(CASE WHEN ps.id_estado_pago IN (5, 4) THEN ps.monto - COALESCE(ps.monto_reembolsado, 0) ELSE 0 END) AS retenido,
       SUM(ps.monto - COALESCE(ps.monto_reembolsado, 0)) AS neto
  FROM pagos.PagoSena ps
  JOIN pagos.MedioPago mp ON mp.id_medio_pago = ps.id_medio_pago
 WHERE ps.fecha_pago >= '2025-03-01' AND ps.fecha_pago < '2025-03-31' + INTERVAL 1 DAY
 GROUP BY DATE_FORMAT(ps.fecha_pago, '%Y-%m'), ps.id_medio_pago, mp.nombre
 ORDER BY periodo, medio_pago;

-- ===================== DESPUÉS: con los índices del tuning =====================
CREATE INDEX IX_Turno_inicio_profesional_estado ON agenda.Turno (fecha_hora_inicio, id_profesional, id_estado_turno, fecha_hora_fin);
CREATE INDEX IX_PagoSena_fecha_medio_estado ON pagos.PagoSena (fecha_pago, id_medio_pago, id_estado_pago, monto, monto_reembolsado);
ANALYZE TABLE agenda.Turno, pagos.PagoSena;

SELECT '--- REPORTE 1 ORIGINAL, con índice (el índice no ayuda: DATE() lo tapa) ---' AS medicion;
EXPLAIN ANALYZE
SELECT DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') AS periodo, pr.id_profesional, COUNT(*) AS turnos,
       SUM(CASE WHEN e.nombre = 'realizado' THEN (SELECT SUM(tp.precio_aplicado) FROM agenda.TurnoProtocolo tp WHERE tp.id_turno = t.id_turno) ELSE 0 END) AS facturado
  FROM agenda.Turno t
  JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
  JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
 WHERE DATE(t.fecha_hora_inicio) BETWEEN '2025-03-01' AND '2025-03-31'
 GROUP BY DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m'), pr.id_profesional;

SELECT '--- REPORTE 1 TUNEADO, con índice ---' AS medicion;
EXPLAIN ANALYZE
SELECT DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') AS periodo, pr.id_profesional, CONCAT(pr.apellido, ', ', pr.nombre) AS profesional,
       COUNT(*) AS turnos, SUM(t.id_estado_turno = 3) AS realizados, SUM(t.id_estado_turno = 4) AS cancelados,
       SUM(t.id_estado_turno = 5) AS ausentes, SUM(t.id_estado_turno IN (1, 2)) AS vigentes,
       ROUND(SUM(TIMESTAMPDIFF(MINUTE, t.fecha_hora_inicio, t.fecha_hora_fin)) / 60, 1) AS horas_agendadas,
       COALESCE(SUM(f.total), 0) AS facturado
  FROM agenda.Turno t
  JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
  LEFT JOIN (SELECT tp.id_turno, SUM(tp.precio_aplicado) AS total FROM agenda.TurnoProtocolo tp
               JOIN agenda.Turno t2 ON t2.id_turno = tp.id_turno
              WHERE t2.fecha_hora_inicio >= '2025-03-01' AND t2.fecha_hora_inicio < '2025-03-31' + INTERVAL 1 DAY AND t2.id_estado_turno = 3
              GROUP BY tp.id_turno) f ON f.id_turno = t.id_turno
 WHERE t.fecha_hora_inicio >= '2025-03-01' AND t.fecha_hora_inicio < '2025-03-31' + INTERVAL 1 DAY
 GROUP BY DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m'), pr.id_profesional, pr.apellido, pr.nombre
 ORDER BY periodo, profesional;

SELECT '--- REPORTE 2 TUNEADO, con índice ---' AS medicion;
EXPLAIN ANALYZE
SELECT DATE_FORMAT(ps.fecha_pago, '%Y-%m') AS periodo, mp.nombre AS medio_pago,
       COUNT(*) AS pagos, SUM(ps.monto) AS cobrado, SUM(COALESCE(ps.monto_reembolsado, 0)) AS reembolsado,
       SUM(CASE WHEN ps.id_estado_pago IN (5, 4) THEN ps.monto - COALESCE(ps.monto_reembolsado, 0) ELSE 0 END) AS retenido,
       SUM(ps.monto - COALESCE(ps.monto_reembolsado, 0)) AS neto
  FROM pagos.PagoSena ps
  JOIN pagos.MedioPago mp ON mp.id_medio_pago = ps.id_medio_pago
 WHERE ps.fecha_pago >= '2025-03-01' AND ps.fecha_pago < '2025-03-31' + INTERVAL 1 DAY
 GROUP BY DATE_FORMAT(ps.fecha_pago, '%Y-%m'), ps.id_medio_pago, mp.nombre
 ORDER BY periodo, medio_pago;

-- ===================== Limpieza =====================
DELETE FROM pagos.PagoSena WHERE id_turno > @base;
DELETE FROM agenda.TurnoProtocolo WHERE id_turno > @base;
DELETE FROM agenda.Turno WHERE id_turno > @base;
-- el contador de ids vuelve a donde estaba
SET @sql_ai = CONCAT('ALTER TABLE agenda.Turno AUTO_INCREMENT = ', @base + 1);
PREPARE st FROM @sql_ai; EXECUTE st; DEALLOCATE PREPARE st;
SET @sql_ai = CONCAT('ALTER TABLE pagos.PagoSena AUTO_INCREMENT = ', @base_pago + 1);
PREPARE st FROM @sql_ai; EXECUTE st; DEALLOCATE PREPARE st;
DROP PROCEDURE IF EXISTS auditoria.sp_quitar_indice_si_existe;
SELECT COUNT(*) AS turnos_despues_de_limpiar FROM agenda.Turno;
