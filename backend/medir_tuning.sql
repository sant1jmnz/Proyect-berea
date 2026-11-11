-- Dermalia: medición del tuning (consigna 5e) con datos de volumen.
-- Se corre DESPUÉS de 06_tuning_semana6.sql, con la base cargada:
--   mysql -u root -p < backend/medir_tuning.sql
--
-- Con los 150 turnos de ejemplo no se nota la diferencia entre un SP y su versión
-- _tuneado. Como en los scripts de la cátedra (Caracol contra Cheetah), se mide
-- CUÁNTAS FILAS llegan a cada paso, no los milisegundos. Este script:
--   1. carga 300.000 turnos y ~240.000 pagos de mentira (con la tabla de números);
--   2. cuenta las filas de cada paso del original (junta todo y filtra al final)
--      y del tuneado (filtra y proyecta antes de juntar);
--   3. corre los dos reportes de cada par para comparar el resultado;
--   4. borra los datos de volumen.

SELECT COALESCE(MAX(id_turno), 0) INTO @base FROM agenda.Turno;
SELECT COALESCE(MAX(id_pago), 0) INTO @base_pago FROM pagos.PagoSena;

-- 300.000 turnos, uno cada 7 minutos desde enero de 2024 (casi 4 años)
INSERT INTO agenda.Turno (id_paciente, id_profesional, id_estado_turno, id_origen, fecha_hora_inicio, fecha_hora_fin, fecha_creacion)
SELECT 1 + (x.k - 60 * (x.k DIV 60)), 1 + (x.k - 20 * (x.k DIV 20)), 1 + (x.k - 5 * (x.k DIV 5)), 1 + (x.k - 4 * (x.k DIV 4)),
       CAST('2024-01-01' AS DATETIME) + INTERVAL (7 * x.k) MINUTE,
       CAST('2024-01-01' AS DATETIME) + INTERVAL (7 * x.k + 30) MINUTE,
       CAST('2024-01-01' AS DATETIME) + INTERVAL (7 * x.k) MINUTE - INTERVAL 5 DAY
  FROM (SELECT a.n + 48 * b.n + 2304 * c.n + 110592 * d.n AS k
          FROM agenda.Numero a, agenda.Numero b, agenda.Numero c, agenda.Numero d
         WHERE d.n < 3) x
 WHERE x.k BETWEEN 1 AND 300000;
INSERT INTO agenda.TurnoProtocolo (id_turno, id_protocolo, precio_aplicado)
SELECT id_turno, 1 + (id_turno - 24 * (id_turno DIV 24)), 90000 FROM agenda.Turno WHERE id_turno > @base;
INSERT INTO pagos.PagoSena (id_turno, id_estado_pago, id_medio_pago, monto, fecha_pago, codigo_operacion, monto_reembolsado)
SELECT id_turno, 1 + (id_turno - 5 * (id_turno DIV 5)), 1 + (id_turno - 4 * (id_turno DIV 4)), 27000, fecha_hora_inicio - INTERVAL 3 DAY, id_turno + 100000000, 0
  FROM agenda.Turno WHERE id_turno > @base AND (id_turno - 5 * (id_turno DIV 5)) <> 1;

-- ===================== REPORTE 1: turnos por período y profesional (marzo de 2025) =====================
SELECT '--- REPORTE 1: filas de cada paso ---' AS medicion;
SELECT COUNT(*) AS filas_turno_completo FROM agenda.Turno;
SELECT COUNT(*) AS filas_turno_completo_x_protocolos FROM agenda.Turno t JOIN agenda.TurnoProtocolo tp ON tp.id_turno = t.id_turno;
-- Original (Caracol): junta Turno con Profesional y EstadoTurno sin filtrar, y recién después filtra.
-- Tuneado (Cheetah A): N1 = Turno ya filtrado por fechas, que es lo único que se junta después.
SELECT COUNT(*) AS filas_N1_turno_filtrado FROM agenda.Turno WHERE DATE(fecha_hora_inicio) BETWEEN '2025-03-01' AND '2025-03-31';
SELECT COUNT(*) AS filas_N4_protocolos_de_N1
  FROM agenda.TurnoProtocolo tp
  JOIN (SELECT id_turno FROM agenda.Turno WHERE DATE(fecha_hora_inicio) BETWEEN '2025-03-01' AND '2025-03-31') a ON a.id_turno = tp.id_turno;

SELECT '--- REPORTE 1 ORIGINAL ---' AS medicion;
CALL agenda.sp_reporte_turnos_por_periodo_profesional('2025-03-01', '2025-03-31', NULL);
SELECT '--- REPORTE 1 TUNEADO (tiene que dar lo mismo) ---' AS medicion;
CALL agenda.sp_reporte_turnos_por_periodo_profesional_tuneado('2025-03-01', '2025-03-31', NULL);

-- ===================== REPORTE 2: ingresos por seña (marzo de 2025) =====================
SELECT '--- REPORTE 2: filas de cada paso ---' AS medicion;
SELECT COUNT(*) AS filas_pagosena_completo FROM pagos.PagoSena;
SELECT COUNT(*) AS filas_N1_pagosena_filtrado FROM pagos.PagoSena WHERE DATE(fecha_pago) BETWEEN '2025-03-01' AND '2025-03-31';

SELECT '--- REPORTE 2 ORIGINAL ---' AS medicion;
CALL pagos.sp_reporte_ingresos_sena('2025-03-01', '2025-03-31');
SELECT '--- REPORTE 2 TUNEADO (tiene que dar lo mismo) ---' AS medicion;
CALL pagos.sp_reporte_ingresos_sena_tuneado('2025-03-01', '2025-03-31');

-- ===================== Limpieza =====================
DELETE FROM pagos.PagoSena WHERE id_turno > @base;
DELETE FROM agenda.TurnoProtocolo WHERE id_turno > @base;
DELETE FROM agenda.Turno WHERE id_turno > @base;
SELECT COUNT(*) AS turnos_despues_de_limpiar FROM agenda.Turno;
