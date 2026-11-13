/*
 =============================================================================
   DERMALIA - REPORTES Y AUDITORIA (SEMANA 5) - MySQL 8
   Se corre despues de 04_sp_semana4.sql:
       mysql -u root -p < backend/05_reportes_semana5.sql

   Consigna 5c: al menos 8 reportes de distinta indole, todos con funciones de
   agrupamiento, reuniones (INNER JOIN / LEFT JOIN) y gestion de fechas.
   Consigna 5d: un reporte de auditoria con parametros y siempre con rango de fechas.

   Estilo de los scripts de la catedra (TP9 y profundizacion 02): una pregunta de
   negocio por reporte, alias siempre con AS, una clausula por linea, columnas
   calculadas con alias y tablas derivadas (subconsultas en el FROM).

   Todos reciben un rango de fechas (p_desde y p_hasta, ambos inclusive).
   Con parametros NULL o con p_desde > p_hasta devuelven 0 filas, sin error.
   Los dos reportes con version _tuneado estan en 06_tuning_semana6.sql.
 =============================================================================
*/

DELIMITER //

-- =============================================================================
-- REPORTE 1: Turnos por periodo (mes) y profesional
-- Cuantos turnos hubo, como terminaron, cuantas horas se agendaron y cuanto se
-- facturo (a precio de lista) en los realizados. p_id_profesional NULL = todos.
-- Cada estado se cuenta con LEFT JOIN + COUNT(columna): COUNT(*) cuenta todos los
-- turnos y COUNT(tr.id_turno) solo los que encontraron su estado (los NULL no se cuentan).
-- Pipeline: FROM (INNER JOIN + LEFT JOIN) -> WHERE -> GROUP BY -> SELECT -> ORDER BY
-- =============================================================================
DROP PROCEDURE IF EXISTS agenda.sp_reporte_turnos_por_periodo_profesional//
CREATE PROCEDURE agenda.sp_reporte_turnos_por_periodo_profesional(
    IN p_desde DATE, IN p_hasta DATE, IN p_id_profesional INT)
BEGIN
    SELECT
        DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') AS periodo,
        pr.id_profesional AS id_profesional,
        pr.apellido AS profesional,
        pr.nombre AS profesional_nombre,
        COUNT(*) AS turnos,
        COUNT(tr.id_turno) AS realizados,
        COUNT(tc.id_turno) AS cancelados,
        COUNT(ta.id_turno) AS ausentes,
        COUNT(tv.id_turno) AS vigentes,
        ROUND(SUM(TIMESTAMPDIFF(MINUTE, t.fecha_hora_inicio, t.fecha_hora_fin)) / 60, 1) AS horas_agendadas,
        COALESCE(SUM(f.total), 0) AS facturado
    FROM agenda.Turno t
    INNER JOIN personas.Profesional pr ON t.id_profesional = pr.id_profesional
    LEFT JOIN agenda.Turno tr ON t.id_turno = tr.id_turno
         AND tr.id_estado_turno IN (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'realizado')
    LEFT JOIN agenda.Turno tc ON t.id_turno = tc.id_turno
         AND tc.id_estado_turno IN (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'cancelado')
    LEFT JOIN agenda.Turno ta ON t.id_turno = ta.id_turno
         AND ta.id_estado_turno IN (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'ausente')
    LEFT JOIN agenda.Turno tv ON t.id_turno = tv.id_turno
         AND tv.id_estado_turno IN (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre IN ('pendiente', 'confirmado'))
    LEFT JOIN (
        SELECT tp.id_turno AS id_turno, SUM(tp.precio_aplicado) AS total
        FROM agenda.TurnoProtocolo tp
        GROUP BY tp.id_turno
    ) AS f ON tr.id_turno = f.id_turno
    WHERE t.fecha_hora_inicio >= p_desde
      AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
      AND (p_id_profesional IS NULL OR t.id_profesional = p_id_profesional)
    GROUP BY DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m'), pr.id_profesional, pr.apellido, pr.nombre
    ORDER BY periodo, profesional, profesional_nombre;
END//

-- =============================================================================
-- REPORTE 2: Ingresos por sena, reembolsos y retenciones, por mes y medio de pago
-- Lo retenido es lo que el instituto se queda de las senas ya resueltas: se suma
-- solo en los pagos que encuentran su estado 'retenida' o 'reembolsada parcial'.
-- Pipeline: FROM (INNER JOIN + LEFT JOIN) -> WHERE -> GROUP BY -> SELECT -> ORDER BY
-- =============================================================================
DROP PROCEDURE IF EXISTS pagos.sp_reporte_ingresos_sena//
CREATE PROCEDURE pagos.sp_reporte_ingresos_sena(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT
        DATE_FORMAT(ps.fecha_pago, '%Y-%m') AS periodo,
        mp.nombre AS medio_pago,
        COUNT(*) AS pagos,
        SUM(ps.monto) AS cobrado,
        SUM(IFNULL(ps.monto_reembolsado, 0)) AS reembolsado,
        COALESCE(SUM(pr.monto - IFNULL(pr.monto_reembolsado, 0)), 0) AS retenido,
        SUM(ps.monto - IFNULL(ps.monto_reembolsado, 0)) AS neto
    FROM pagos.PagoSena ps
    INNER JOIN pagos.MedioPago mp ON ps.id_medio_pago = mp.id_medio_pago
    LEFT JOIN pagos.PagoSena pr ON ps.id_pago = pr.id_pago
         AND pr.id_estado_pago IN (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre IN ('retenida', 'reembolsada parcial'))
    WHERE ps.fecha_pago >= p_desde
      AND ps.fecha_pago < p_hasta + INTERVAL 1 DAY
    GROUP BY DATE_FORMAT(ps.fecha_pago, '%Y-%m'), ps.id_medio_pago, mp.nombre
    ORDER BY periodo, medio_pago;
END//

-- =============================================================================
-- REPORTE 3: Cancelaciones e inasistencias (los "turnos perdidos" de la MML)
-- p_agrupar: 'mes' (por defecto) o 'semana'. Por origen: cuantos turnos se
-- perdieron, la tasa de perdida y la plata de senas retenida.
-- El formato del periodo sale de una tabla derivada de dos filas (semana / mes) y el
-- WHERE se queda con la fila que corresponde al parametro. Los estados se cuentan con
-- LEFT JOIN + COUNT(columna), como en el reporte 1.
-- Pipeline: FROM (INNER JOIN + LEFT JOIN) -> WHERE -> GROUP BY -> SELECT -> ORDER BY
-- =============================================================================
DROP PROCEDURE IF EXISTS agenda.sp_reporte_cancelaciones_inasistencias//
CREATE PROCEDURE agenda.sp_reporte_cancelaciones_inasistencias(
    IN p_desde DATE, IN p_hasta DATE, IN p_agrupar VARCHAR(10))
BEGIN
    SELECT
        DATE_FORMAT(t.fecha_hora_inicio, fm.formato) AS periodo,
        o.nombre AS origen,
        COUNT(*) AS turnos,
        COUNT(tc.id_turno) AS cancelados,
        COUNT(pa.id_pago) AS cancelados_con_aviso,
        COUNT(pt.id_pago) AS cancelados_tarde,
        COUNT(ta.id_turno) AS ausentes,
        ROUND(100 * (COUNT(tc.id_turno) + COUNT(ta.id_turno)) / COUNT(*), 1) AS tasa_perdida_pct,
        COALESCE(SUM(pr.monto - IFNULL(pr.monto_reembolsado, 0)), 0) AS sena_retenida
    FROM agenda.Turno t
    INNER JOIN (
        SELECT 1 AS es_semana, '%x-S%v' AS formato
        UNION ALL
        SELECT 0 AS es_semana, '%Y-%m' AS formato
    ) AS fm ON fm.es_semana = IFNULL(p_agrupar = 'semana', 0)
    INNER JOIN agenda.Origen o ON t.id_origen = o.id_origen
    LEFT JOIN agenda.Turno tc ON t.id_turno = tc.id_turno
         AND tc.id_estado_turno IN (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'cancelado')
    LEFT JOIN agenda.Turno ta ON t.id_turno = ta.id_turno
         AND ta.id_estado_turno IN (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'ausente')
    LEFT JOIN pagos.PagoSena pa ON tc.id_turno = pa.id_turno
         AND pa.id_estado_pago IN (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre = 'reembolsada')
    LEFT JOIN pagos.PagoSena pt ON tc.id_turno = pt.id_turno
         AND pt.id_estado_pago IN (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre = 'retenida')
    LEFT JOIN pagos.PagoSena pr ON t.id_turno = pr.id_turno
         AND (tc.id_turno IS NOT NULL OR ta.id_turno IS NOT NULL)
         AND pr.id_estado_pago IN (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre IN ('retenida', 'reembolsada parcial'))
    WHERE t.fecha_hora_inicio >= p_desde
      AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
    GROUP BY DATE_FORMAT(t.fecha_hora_inicio, fm.formato), o.nombre
    ORDER BY periodo, origen;
END//

-- =============================================================================
-- REPORTE 4: Evaluaciones previas y cirugias por resultado
-- Por cirugia y resultado: cuantas evaluaciones, cuantas terminaron en una
-- cirugia agendada, cuantas vencieron sin agendar, cuantos reclamos y cuanta plata
-- de consultas retuvo el instituto. Se cuentan las consultas del rango.
-- COUNT(columna) no cuenta los NULL: COUNT(tc.id_turno) = evaluaciones con cirugia
-- agendada y COUNT(ev.fecha_reclamo) = evaluaciones con reclamo.
-- Pipeline: FROM (INNER JOIN + LEFT JOIN) -> WHERE -> GROUP BY -> SELECT -> ORDER BY
-- =============================================================================
DROP PROCEDURE IF EXISTS clinica.sp_reporte_evaluaciones_cirugias//
CREATE PROCEDURE clinica.sp_reporte_evaluaciones_cirugias(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT
        cir.nombre AS cirugia,
        r.nombre AS resultado,
        COUNT(*) AS evaluaciones,
        COUNT(tc.id_turno) AS con_cirugia_agendada,
        COUNT(rv.id_resultado) AS vencidas_sin_cirugia,
        COUNT(ev.fecha_reclamo) AS reclamos,
        COALESCE(SUM(pr.monto - IFNULL(pr.monto_reembolsado, 0)), 0) AS consulta_retenida
    FROM clinica.EvaluacionPrevia ev
    INNER JOIN clinica.Protocolo cir ON ev.id_protocolo = cir.id_protocolo
    INNER JOIN clinica.ResultadoEvaluacion r ON ev.id_resultado = r.id_resultado
    INNER JOIN agenda.Turno t ON ev.id_turno = t.id_turno
    LEFT JOIN agenda.Turno tc ON ev.id_evaluacion = tc.id_evaluacion_previa
    LEFT JOIN clinica.ResultadoEvaluacion rv ON ev.id_resultado = rv.id_resultado
         AND rv.nombre = 'apto'
         AND tc.id_turno IS NULL
         AND ev.fecha_resultado + INTERVAL 6 MONTH < IFNULL(@ahora_simulado, NOW())
    LEFT JOIN pagos.PagoSena pr ON ev.id_turno = pr.id_turno
         AND pr.id_estado_pago IN (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre IN ('retenida', 'reembolsada parcial'))
    WHERE t.fecha_hora_inicio >= p_desde
      AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
    GROUP BY cir.id_protocolo, cir.nombre, r.id_resultado, r.nombre
    ORDER BY cirugia, resultado;
END//

-- =============================================================================
-- REPORTE 5: Protocolos mas pedidos en un periodo (sin contar turnos cancelados)
-- Puesto en el ranking = 1 + cuantos protocolos tienen mas pedidos (o los mismos
-- y un nombre anterior en el alfabeto); porcentaje sobre el total de pedidos.
-- p_limite NULL = 10.
-- Se arma con tablas temporales (Cheetah A del material): primero se filtra y se
-- agrupa (N1) y despues se compara N1 contra una copia de si misma (N2), porque
-- MySQL no deja usar dos veces la misma tabla temporal en una sentencia.
-- =============================================================================
DROP PROCEDURE IF EXISTS clinica.sp_reporte_protocolos_mas_pedidos//
CREATE PROCEDURE clinica.sp_reporte_protocolos_mas_pedidos(
    IN p_desde DATE, IN p_hasta DATE, IN p_limite INT)
BEGIN
    DECLARE v_total_pedidos INT DEFAULT 0;

    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n2;

    -- N1: pedidos e ingresos de lista por protocolo
    CREATE TEMPORARY TABLE tmp_pedidos_n1 AS
    SELECT
        p.id_protocolo AS id_protocolo,
        p.nombre AS protocolo,
        c.nombre AS categoria,
        COUNT(*) AS pedidos,
        SUM(tp.precio_aplicado) AS ingresos_lista
    FROM agenda.TurnoProtocolo tp
    INNER JOIN agenda.Turno t ON tp.id_turno = t.id_turno
    INNER JOIN agenda.EstadoTurno e ON t.id_estado_turno = e.id_estado_turno
    INNER JOIN clinica.Protocolo p ON tp.id_protocolo = p.id_protocolo
    INNER JOIN clinica.CategoriaProtocolo c ON p.id_categoria = c.id_categoria
    WHERE e.nombre <> 'cancelado'
      AND t.fecha_hora_inicio >= p_desde
      AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
    GROUP BY p.id_protocolo, p.nombre, c.nombre;

    -- N2: copia de N1 con solo las columnas del ranking
    CREATE TEMPORARY TABLE tmp_pedidos_n2 AS
    SELECT id_protocolo, protocolo, pedidos
    FROM tmp_pedidos_n1;

    SELECT IFNULL(SUM(pedidos), 0) INTO v_total_pedidos
    FROM tmp_pedidos_n2;

    SELECT
        x.puesto AS puesto,
        x.protocolo AS protocolo,
        x.categoria AS categoria,
        x.pedidos AS pedidos,
        x.ingresos_lista AS ingresos_lista,
        ROUND(100 * x.pedidos / v_total_pedidos, 1) AS porcentaje
    FROM (
        SELECT
            1 + COUNT(m.id_protocolo) AS puesto,
            a.protocolo AS protocolo,
            a.categoria AS categoria,
            a.pedidos AS pedidos,
            a.ingresos_lista AS ingresos_lista
        FROM tmp_pedidos_n1 a
        LEFT JOIN tmp_pedidos_n2 m
               ON m.pedidos > a.pedidos
               OR (m.pedidos = a.pedidos AND m.protocolo < a.protocolo)
        GROUP BY a.id_protocolo, a.protocolo, a.categoria, a.pedidos, a.ingresos_lista
    ) AS x
    WHERE x.puesto <= IFNULL(p_limite, 10)
    ORDER BY x.puesto, x.protocolo;

    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n2;
END//

-- =============================================================================
-- REPORTE 6: Ocupacion por profesional = horas con turno / horas de disponibilidad
-- Si el profesional no tiene horas de disponibilidad, la division por cero da NULL y no se informa el porcentaje.
-- Pipeline: FROM (Profesional + 2 tablas derivadas con LEFT JOIN) -> WHERE -> SELECT -> ORDER BY
-- =============================================================================
DROP PROCEDURE IF EXISTS agenda.sp_reporte_ocupacion_profesional//
CREATE PROCEDURE agenda.sp_reporte_ocupacion_profesional(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT
        pr.id_profesional AS id_profesional,
        pr.apellido AS profesional,
        pr.nombre AS profesional_nombre,
        ROUND(IFNULL(d.horas, 0), 1) AS horas_disponibles,
        ROUND(IFNULL(o.horas, 0), 1) AS horas_ocupadas,
        IFNULL(o.turnos, 0) AS turnos,
        ROUND(100 * IFNULL(o.horas, 0) / d.horas, 1) AS ocupacion_pct
    FROM personas.Profesional pr
    LEFT JOIN (
        SELECT
            dd.id_profesional AS id_profesional,
            SUM(TIMESTAMPDIFF(MINUTE, dd.hora_inicio, dd.hora_fin)) / 60 AS horas
        FROM personas.Disponibilidad dd
        WHERE dd.activa = 1
          AND dd.fecha BETWEEN p_desde AND p_hasta
        GROUP BY dd.id_profesional
    ) AS d ON pr.id_profesional = d.id_profesional
    LEFT JOIN (
        SELECT
            t.id_profesional AS id_profesional,
            COUNT(*) AS turnos,
            SUM(TIMESTAMPDIFF(MINUTE, t.fecha_hora_inicio, t.fecha_hora_fin)) / 60 AS horas
        FROM agenda.Turno t
        INNER JOIN agenda.EstadoTurno e ON t.id_estado_turno = e.id_estado_turno
        WHERE e.nombre <> 'cancelado'
          AND t.fecha_hora_inicio >= p_desde
          AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
        GROUP BY t.id_profesional
    ) AS o ON pr.id_profesional = o.id_profesional
    WHERE p_desde IS NOT NULL
      AND p_hasta IS NOT NULL
      AND p_desde <= p_hasta
      AND (d.horas IS NOT NULL OR o.horas IS NOT NULL)
    ORDER BY ocupacion_pct DESC, profesional;
END//

-- =============================================================================
-- REPORTE 7: Uso de cupones y reglas de beneficio, por regla
-- Cupones emitidos en el rango: cuantos se usaron, cuantos vencieron sin usar,
-- cuantos siguen vigentes, tasa de uso y descuento total otorgado.
-- COUNT(c.id_turno) cuenta los cupones usados (los sin usar tienen id_turno NULL).
-- Pipeline: FROM (INNER JOIN + LEFT JOIN) -> WHERE -> GROUP BY -> SELECT -> ORDER BY
-- =============================================================================
DROP PROCEDURE IF EXISTS beneficios.sp_reporte_cupones//
CREATE PROCEDURE beneficios.sp_reporte_cupones(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT
        r.id_regla AS id_regla,
        r.nombre AS regla,
        tr.nombre AS tipo,
        r.porcentaje_descuento AS descuento_pct,
        COUNT(*) AS emitidos,
        COUNT(c.id_turno) AS usados,
        COUNT(cv.id_cupon) AS vencidos_sin_usar,
        COUNT(cg.id_cupon) AS vigentes,
        ROUND(100 * COUNT(c.id_turno) / COUNT(*), 1) AS tasa_uso_pct,
        IFNULL(SUM(pt.total * c.porcentaje_descuento / 100), 0) AS descuento_otorgado
    FROM beneficios.Cupon c
    INNER JOIN beneficios.ReglaBeneficio r ON c.id_regla = r.id_regla
    INNER JOIN beneficios.TipoRegla tr ON r.id_tipo_regla = tr.id_tipo_regla
    LEFT JOIN beneficios.Cupon cv ON c.id_cupon = cv.id_cupon
         AND cv.id_turno IS NULL
         AND cv.fecha_vencimiento <= IFNULL(@ahora_simulado, NOW())
    LEFT JOIN beneficios.Cupon cg ON c.id_cupon = cg.id_cupon
         AND cg.id_turno IS NULL
         AND cg.fecha_vencimiento > IFNULL(@ahora_simulado, NOW())
    LEFT JOIN (
        SELECT tp.id_turno AS id_turno, SUM(tp.precio_aplicado) AS total
        FROM agenda.TurnoProtocolo tp
        GROUP BY tp.id_turno
    ) AS pt ON c.id_turno = pt.id_turno
    WHERE c.fecha_emision >= p_desde
      AND c.fecha_emision < p_hasta + INTERVAL 1 DAY
    GROUP BY r.id_regla, r.nombre, tr.nombre, r.porcentaje_descuento
    ORDER BY emitidos DESC, regla;
END//

-- =============================================================================
-- REPORTE 8: Saldo y uso de las tarjetas de regalo compradas en el rango
-- El codigo se muestra recortado: el codigo completo funciona como un billete.
-- La situacion sale de cuatro consultas con condiciones que no se pisan (vencida,
-- agotada, sin uso, en uso) unidas con UNION ALL.
-- Pipeline: FROM (tabla derivada con INNER JOIN + LEFT JOIN) -> UNION ALL -> ORDER BY
-- =============================================================================
DROP PROCEDURE IF EXISTS pagos.sp_reporte_tarjetas_regalo//
CREATE PROCEDURE pagos.sp_reporte_tarjetas_regalo(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT u.id_tarjeta, u.codigo, u.comprador_nombre, u.medio_compra, u.fecha_compra, u.vence,
           u.monto_inicial, u.gastado, u.devuelto, u.saldo, u.movimientos, u.ultimo_uso, u.situacion
    FROM (
        SELECT g.*, 'vencida' AS situacion
        FROM (
            SELECT
                t.id_tarjeta AS id_tarjeta,
                CAST(t.codigo AS CHAR(7)) AS codigo,
                t.comprador_nombre AS comprador_nombre,
                mp.nombre AS medio_compra,
                DATE(t.fecha_compra) AS fecha_compra,
                DATE(t.fecha_vencimiento) AS vence,
                t.monto_inicial AS monto_inicial,
                COALESCE(SUM(mg.monto), 0) AS gastado,
                COALESCE(-SUM(md.monto), 0) AS devuelto,
                t.monto_inicial - IFNULL(SUM(m.monto), 0) AS saldo,
                COUNT(m.id_movimiento) AS movimientos,
                MAX(m.fecha_movimiento) AS ultimo_uso,
                t.fecha_vencimiento AS fecha_vencimiento
            FROM pagos.TarjetaRegalo t
            INNER JOIN pagos.MedioPago mp ON t.id_medio_pago = mp.id_medio_pago
            LEFT JOIN pagos.MovimientoTarjeta m ON t.id_tarjeta = m.id_tarjeta
            LEFT JOIN pagos.MovimientoTarjeta mg ON m.id_movimiento = mg.id_movimiento AND mg.monto > 0
            LEFT JOIN pagos.MovimientoTarjeta md ON m.id_movimiento = md.id_movimiento AND md.monto < 0
            WHERE t.fecha_compra >= p_desde
              AND t.fecha_compra < p_hasta + INTERVAL 1 DAY
            GROUP BY t.id_tarjeta, t.codigo, t.comprador_nombre, mp.nombre, t.fecha_compra, t.fecha_vencimiento, t.monto_inicial
        ) AS g
        WHERE g.fecha_vencimiento <= IFNULL(@ahora_simulado, NOW())
        UNION ALL
        SELECT g.*, 'agotada' AS situacion
        FROM (
            SELECT
                t.id_tarjeta AS id_tarjeta,
                CAST(t.codigo AS CHAR(7)) AS codigo,
                t.comprador_nombre AS comprador_nombre,
                mp.nombre AS medio_compra,
                DATE(t.fecha_compra) AS fecha_compra,
                DATE(t.fecha_vencimiento) AS vence,
                t.monto_inicial AS monto_inicial,
                COALESCE(SUM(mg.monto), 0) AS gastado,
                COALESCE(-SUM(md.monto), 0) AS devuelto,
                t.monto_inicial - IFNULL(SUM(m.monto), 0) AS saldo,
                COUNT(m.id_movimiento) AS movimientos,
                MAX(m.fecha_movimiento) AS ultimo_uso,
                t.fecha_vencimiento AS fecha_vencimiento
            FROM pagos.TarjetaRegalo t
            INNER JOIN pagos.MedioPago mp ON t.id_medio_pago = mp.id_medio_pago
            LEFT JOIN pagos.MovimientoTarjeta m ON t.id_tarjeta = m.id_tarjeta
            LEFT JOIN pagos.MovimientoTarjeta mg ON m.id_movimiento = mg.id_movimiento AND mg.monto > 0
            LEFT JOIN pagos.MovimientoTarjeta md ON m.id_movimiento = md.id_movimiento AND md.monto < 0
            WHERE t.fecha_compra >= p_desde
              AND t.fecha_compra < p_hasta + INTERVAL 1 DAY
            GROUP BY t.id_tarjeta, t.codigo, t.comprador_nombre, mp.nombre, t.fecha_compra, t.fecha_vencimiento, t.monto_inicial
        ) AS g
        WHERE g.fecha_vencimiento > IFNULL(@ahora_simulado, NOW())
          AND g.saldo <= 0
        UNION ALL
        SELECT g.*, 'sin uso' AS situacion
        FROM (
            SELECT
                t.id_tarjeta AS id_tarjeta,
                CAST(t.codigo AS CHAR(7)) AS codigo,
                t.comprador_nombre AS comprador_nombre,
                mp.nombre AS medio_compra,
                DATE(t.fecha_compra) AS fecha_compra,
                DATE(t.fecha_vencimiento) AS vence,
                t.monto_inicial AS monto_inicial,
                COALESCE(SUM(mg.monto), 0) AS gastado,
                COALESCE(-SUM(md.monto), 0) AS devuelto,
                t.monto_inicial - IFNULL(SUM(m.monto), 0) AS saldo,
                COUNT(m.id_movimiento) AS movimientos,
                MAX(m.fecha_movimiento) AS ultimo_uso,
                t.fecha_vencimiento AS fecha_vencimiento
            FROM pagos.TarjetaRegalo t
            INNER JOIN pagos.MedioPago mp ON t.id_medio_pago = mp.id_medio_pago
            LEFT JOIN pagos.MovimientoTarjeta m ON t.id_tarjeta = m.id_tarjeta
            LEFT JOIN pagos.MovimientoTarjeta mg ON m.id_movimiento = mg.id_movimiento AND mg.monto > 0
            LEFT JOIN pagos.MovimientoTarjeta md ON m.id_movimiento = md.id_movimiento AND md.monto < 0
            WHERE t.fecha_compra >= p_desde
              AND t.fecha_compra < p_hasta + INTERVAL 1 DAY
            GROUP BY t.id_tarjeta, t.codigo, t.comprador_nombre, mp.nombre, t.fecha_compra, t.fecha_vencimiento, t.monto_inicial
        ) AS g
        WHERE g.fecha_vencimiento > IFNULL(@ahora_simulado, NOW())
          AND g.saldo > 0
          AND g.movimientos = 0
        UNION ALL
        SELECT g.*, 'en uso' AS situacion
        FROM (
            SELECT
                t.id_tarjeta AS id_tarjeta,
                CAST(t.codigo AS CHAR(7)) AS codigo,
                t.comprador_nombre AS comprador_nombre,
                mp.nombre AS medio_compra,
                DATE(t.fecha_compra) AS fecha_compra,
                DATE(t.fecha_vencimiento) AS vence,
                t.monto_inicial AS monto_inicial,
                COALESCE(SUM(mg.monto), 0) AS gastado,
                COALESCE(-SUM(md.monto), 0) AS devuelto,
                t.monto_inicial - IFNULL(SUM(m.monto), 0) AS saldo,
                COUNT(m.id_movimiento) AS movimientos,
                MAX(m.fecha_movimiento) AS ultimo_uso,
                t.fecha_vencimiento AS fecha_vencimiento
            FROM pagos.TarjetaRegalo t
            INNER JOIN pagos.MedioPago mp ON t.id_medio_pago = mp.id_medio_pago
            LEFT JOIN pagos.MovimientoTarjeta m ON t.id_tarjeta = m.id_tarjeta
            LEFT JOIN pagos.MovimientoTarjeta mg ON m.id_movimiento = mg.id_movimiento AND mg.monto > 0
            LEFT JOIN pagos.MovimientoTarjeta md ON m.id_movimiento = md.id_movimiento AND md.monto < 0
            WHERE t.fecha_compra >= p_desde
              AND t.fecha_compra < p_hasta + INTERVAL 1 DAY
            GROUP BY t.id_tarjeta, t.codigo, t.comprador_nombre, mp.nombre, t.fecha_compra, t.fecha_vencimiento, t.monto_inicial
        ) AS g
        WHERE g.fecha_vencimiento > IFNULL(@ahora_simulado, NOW())
          AND g.saldo > 0
          AND g.movimientos > 0
    ) AS u
    ORDER BY u.fecha_compra, u.id_tarjeta;
END//

-- =============================================================================
-- REPORTE DE AUDITORIA (consigna 5d): quien hizo que, cuando y desde donde
-- El rango de fechas es obligatorio (p_hasta incluye todo ese dia). Los demas
-- filtros son opcionales (NULL = sin filtrar):
--   p_tipo_evento  nombre del tipo ('inicio_sesion', 'alta_turno', ...)
--   p_id_usuario   quien hizo la accion
--   p_id_paciente  paciente involucrada
--   p_exitoso      1 = solo lo que salio bien, 0 = solo los fallos
--   p_origen       'terminal', 'web', 'gestion' o 'sistema'
-- Pipeline: FROM (INNER JOIN + LEFT JOIN) -> WHERE -> SELECT -> ORDER BY
-- =============================================================================
DROP PROCEDURE IF EXISTS auditoria.sp_reporte_auditoria//
CREATE PROCEDURE auditoria.sp_reporte_auditoria(
    IN p_desde DATE, IN p_hasta DATE, IN p_tipo_evento VARCHAR(50), IN p_id_usuario INT,
    IN p_id_paciente INT, IN p_exitoso SMALLINT, IN p_origen VARCHAR(50))
BEGIN
    SELECT
        l.id_log AS id_log,
        l.fecha_hora AS fecha_hora,
        te.nombre AS evento,
        IFNULL(u.nombre_usuario, '(sin usuario)') AS usuario,
        r.nombre AS rol,
        p.apellido AS paciente,
        p.nombre AS paciente_nombre,
        o.nombre AS origen,
        l.exitoso AS exitoso,
        l.descripcion AS descripcion,
        l.tabla_afectada AS tabla_afectada,
        l.id_registro_afectado AS id_registro_afectado,
        l.valor_anterior AS valor_anterior,
        l.valor_nuevo AS valor_nuevo,
        l.ip_origen AS ip_origen
    FROM auditoria.Log l
    INNER JOIN auditoria.TipoEvento te ON l.id_tipo_evento = te.id_tipo_evento
    INNER JOIN agenda.Origen o ON l.id_origen = o.id_origen
    LEFT JOIN seguridad.Usuario u ON l.id_usuario = u.id_usuario
    LEFT JOIN seguridad.Rol r ON u.id_rol = r.id_rol
    LEFT JOIN personas.Paciente p ON l.id_paciente = p.id_paciente
    WHERE l.fecha_hora >= p_desde
      AND l.fecha_hora < p_hasta + INTERVAL 1 DAY
      AND (p_tipo_evento IS NULL OR te.nombre = p_tipo_evento)
      AND (p_id_usuario IS NULL OR l.id_usuario = p_id_usuario)
      AND (p_id_paciente IS NULL OR l.id_paciente = p_id_paciente)
      AND (p_exitoso IS NULL OR l.exitoso = p_exitoso)
      AND (p_origen IS NULL OR o.nombre = p_origen)
    ORDER BY l.fecha_hora, l.id_log;
END//

DELIMITER ;
