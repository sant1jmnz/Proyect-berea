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

-- =============================================================================
-- REPORTE 1 TUNEADO: Turnos por periodo (mes) y profesional
-- Devuelve exactamente lo mismo que el original. Cada paso es una tabla temporal:
--   N1 Turno filtrado (seleccion) y proyectado; N2, N3 EstadoTurno y Profesional proyectados;
--   N4 total de lista de cada turno de N1; N5 reunion de N1, N2 y N3;
--   G0 a G4 un agrupamiento por periodo y profesional: todos, realizados, cancelados,
--   ausentes y vigentes; el final une los grupos con LEFT JOIN.
-- =============================================================================
DROP PROCEDURE IF EXISTS agenda.sp_reporte_turnos_por_periodo_profesional_tuneado//
CREATE PROCEDURE agenda.sp_reporte_turnos_por_periodo_profesional_tuneado(
    IN p_desde DATE, IN p_hasta DATE, IN p_id_profesional INT)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n4;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n5;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g0;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g4;

    -- N1: Turno con la seleccion (fechas y profesional) y la proyeccion aplicadas
    CREATE TEMPORARY TABLE tmp_r1_n1 AS
    SELECT id_turno, id_profesional, id_estado_turno, fecha_hora_inicio, fecha_hora_fin
    FROM agenda.Turno
    WHERE fecha_hora_inicio >= p_desde
      AND fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
      AND (p_id_profesional IS NULL OR id_profesional = p_id_profesional);

    -- N2: EstadoTurno proyectado
    CREATE TEMPORARY TABLE tmp_r1_n2 AS
    SELECT id_estado_turno, nombre
    FROM agenda.EstadoTurno;

    -- N3: Profesional proyectado
    CREATE TEMPORARY TABLE tmp_r1_n3 AS
    SELECT id_profesional, apellido, nombre
    FROM personas.Profesional;

    -- N4: total de lista de cada turno de N1 (TurnoProtocolo se junta solo con esos turnos)
    CREATE TEMPORARY TABLE tmp_r1_n4 AS
    SELECT tp.id_turno AS id_turno, SUM(tp.precio_aplicado) AS total
    FROM agenda.TurnoProtocolo tp
    INNER JOIN tmp_r1_n1 a ON tp.id_turno = a.id_turno
    GROUP BY tp.id_turno;

    -- N5: reunion de los turnos filtrados con su estado y su profesional
    CREATE TEMPORARY TABLE tmp_r1_n5 AS
    SELECT
        DATE_FORMAT(a.fecha_hora_inicio, '%Y-%m') AS periodo,
        p.id_profesional AS id_profesional,
        p.apellido AS profesional,
        p.nombre AS profesional_nombre,
        a.id_turno AS id_turno,
        e.nombre AS estado,
        TIMESTAMPDIFF(MINUTE, a.fecha_hora_inicio, a.fecha_hora_fin) AS minutos
    FROM tmp_r1_n1 a
    INNER JOIN tmp_r1_n3 p ON a.id_profesional = p.id_profesional
    INNER JOIN tmp_r1_n2 e ON a.id_estado_turno = e.id_estado_turno;

    -- G0: todos los turnos por periodo y profesional
    CREATE TEMPORARY TABLE tmp_r1_g0 AS
    SELECT periodo, id_profesional, profesional, profesional_nombre,
           COUNT(*) AS turnos, ROUND(SUM(minutos) / 60, 1) AS horas_agendadas
    FROM tmp_r1_n5
    GROUP BY periodo, id_profesional, profesional, profesional_nombre;

    -- G1: realizados (con lo facturado a precio de lista)
    CREATE TEMPORARY TABLE tmp_r1_g1 AS
    SELECT n.periodo AS periodo, n.id_profesional AS id_profesional,
           COUNT(*) AS cantidad, SUM(f.total) AS facturado
    FROM tmp_r1_n5 n
    LEFT JOIN tmp_r1_n4 f ON n.id_turno = f.id_turno
    WHERE n.estado = 'realizado'
    GROUP BY n.periodo, n.id_profesional;

    -- G2: cancelados
    CREATE TEMPORARY TABLE tmp_r1_g2 AS
    SELECT periodo, id_profesional, COUNT(*) AS cantidad
    FROM tmp_r1_n5
    WHERE estado = 'cancelado'
    GROUP BY periodo, id_profesional;

    -- G3: ausentes
    CREATE TEMPORARY TABLE tmp_r1_g3 AS
    SELECT periodo, id_profesional, COUNT(*) AS cantidad
    FROM tmp_r1_n5
    WHERE estado = 'ausente'
    GROUP BY periodo, id_profesional;

    -- G4: vigentes (pendientes y confirmados)
    CREATE TEMPORARY TABLE tmp_r1_g4 AS
    SELECT periodo, id_profesional, COUNT(*) AS cantidad
    FROM tmp_r1_n5
    WHERE estado IN ('pendiente', 'confirmado')
    GROUP BY periodo, id_profesional;

    -- Reunion final
    SELECT
        g0.periodo AS periodo,
        g0.id_profesional AS id_profesional,
        g0.profesional AS profesional,
        g0.profesional_nombre AS profesional_nombre,
        g0.turnos AS turnos,
        COALESCE(g1.cantidad, 0) AS realizados,
        COALESCE(g2.cantidad, 0) AS cancelados,
        COALESCE(g3.cantidad, 0) AS ausentes,
        COALESCE(g4.cantidad, 0) AS vigentes,
        g0.horas_agendadas AS horas_agendadas,
        COALESCE(g1.facturado, 0) AS facturado
    FROM tmp_r1_g0 g0
    LEFT JOIN tmp_r1_g1 g1 ON g0.periodo = g1.periodo AND g0.id_profesional = g1.id_profesional
    LEFT JOIN tmp_r1_g2 g2 ON g0.periodo = g2.periodo AND g0.id_profesional = g2.id_profesional
    LEFT JOIN tmp_r1_g3 g3 ON g0.periodo = g3.periodo AND g0.id_profesional = g3.id_profesional
    LEFT JOIN tmp_r1_g4 g4 ON g0.periodo = g4.periodo AND g0.id_profesional = g4.id_profesional
    ORDER BY periodo, profesional, profesional_nombre;

    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n4;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n5;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g0;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_g4;
END//

-- =============================================================================
-- REPORTE 2 TUNEADO: Ingresos por sena, reembolsos y retenciones
-- Devuelve exactamente lo mismo que el original.
--   N1 PagoSena filtrado por fechas; N2 EstadoPago; N3 MedioPago;
--   N4 reunion de N1, N2 y N3; G0 todos los pagos por periodo y medio;
--   G1 solo lo retenido; el final une G0 con G1.
-- =============================================================================
DROP PROCEDURE IF EXISTS pagos.sp_reporte_ingresos_sena_tuneado//
CREATE PROCEDURE pagos.sp_reporte_ingresos_sena_tuneado(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n4;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_g0;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_g1;

    -- N1: PagoSena con la seleccion (fechas) y la proyeccion aplicadas
    CREATE TEMPORARY TABLE tmp_r2_n1 AS
    SELECT id_medio_pago, id_estado_pago, monto, monto_reembolsado, fecha_pago
    FROM pagos.PagoSena
    WHERE fecha_pago >= p_desde
      AND fecha_pago < p_hasta + INTERVAL 1 DAY;

    -- N2: EstadoPago proyectado
    CREATE TEMPORARY TABLE tmp_r2_n2 AS
    SELECT id_estado_pago, nombre
    FROM pagos.EstadoPago;

    -- N3: MedioPago proyectado
    CREATE TEMPORARY TABLE tmp_r2_n3 AS
    SELECT id_medio_pago, nombre
    FROM pagos.MedioPago;

    -- N4: reunion de los pagos filtrados con su estado y su medio de pago
    CREATE TEMPORARY TABLE tmp_r2_n4 AS
    SELECT
        DATE_FORMAT(a.fecha_pago, '%Y-%m') AS periodo,
        a.id_medio_pago AS id_medio_pago,
        m.nombre AS medio_pago,
        e.nombre AS estado,
        a.monto AS monto,
        IFNULL(a.monto_reembolsado, 0) AS reembolsado
    FROM tmp_r2_n1 a
    INNER JOIN tmp_r2_n2 e ON a.id_estado_pago = e.id_estado_pago
    INNER JOIN tmp_r2_n3 m ON a.id_medio_pago = m.id_medio_pago;

    -- G0: todos los pagos por periodo y medio de pago
    CREATE TEMPORARY TABLE tmp_r2_g0 AS
    SELECT periodo, id_medio_pago, medio_pago,
           COUNT(*) AS pagos, SUM(monto) AS cobrado, SUM(reembolsado) AS reembolsado,
           SUM(monto - reembolsado) AS neto
    FROM tmp_r2_n4
    GROUP BY periodo, id_medio_pago, medio_pago;

    -- G1: lo retenido (pagos 'retenida' o 'reembolsada parcial')
    CREATE TEMPORARY TABLE tmp_r2_g1 AS
    SELECT periodo, id_medio_pago, SUM(monto - reembolsado) AS retenido
    FROM tmp_r2_n4
    WHERE estado IN ('retenida', 'reembolsada parcial')
    GROUP BY periodo, id_medio_pago;

    -- Reunion final
    SELECT
        g0.periodo AS periodo,
        g0.medio_pago AS medio_pago,
        g0.pagos AS pagos,
        g0.cobrado AS cobrado,
        g0.reembolsado AS reembolsado,
        COALESCE(g1.retenido, 0) AS retenido,
        g0.neto AS neto
    FROM tmp_r2_g0 g0
    LEFT JOIN tmp_r2_g1 g1 ON g0.periodo = g1.periodo AND g0.id_medio_pago = g1.id_medio_pago
    ORDER BY periodo, medio_pago;

    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n4;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_g0;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_g1;
END//

DELIMITER ;
