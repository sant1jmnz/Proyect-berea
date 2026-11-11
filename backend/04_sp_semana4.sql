-- Dermalia: stored procedures de la Semana 4 (MySQL 8).
-- Se corre después de 03_sp_semana3.sql:
--   mysql -u root -p < backend/04_sp_semana4.sql
--
-- Contenido: seña, cancelación y reembolso, asistencia, regla de cirugías
-- (evaluación previa, reclamo y vencimiento), cupones con token rotativo,
-- tarjetas de regalo, notificaciones (para n8n) y consultas al asistente.
-- Misma convención que la Semana 3: 6 columnas de respuesta
-- (estado, codigo, mensaje, id, valor, dato) y error con EXIT HANDLER.

DELIMITER //

-- =====================================================================
--  SEÑA, CANCELACIÓN Y ASISTENCIA (RF-08, RF-09, RF-10)
-- =====================================================================

-- Registra la seña (pago simulado, sin pasarela) y confirma el turno. Devuelve:
-- id = pago, valor = monto de la seña, dato = código de operación 'SIM-...'.
-- Si se paga con tarjeta de regalo hay que pasar su código; el turno no puede
-- tener cupón (un cupón y una tarjeta no van juntos).
DROP PROCEDURE IF EXISTS pagos.sp_registrar_sena//
CREATE PROCEDURE pagos.sp_registrar_sena(
    IN p_id_turno INT, IN p_medio_pago VARCHAR(50), IN p_codigo_tarjeta VARCHAR(50),
    IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_tipo_log VARCHAR(50) DEFAULT 'pago_registrado';  -- tipo de evento si el pago se rechaza
    DECLARE v_desc_log VARCHAR(500) DEFAULT NULL;              -- motivo del rechazo (si no, el mensaje de error)
    DECLARE v_estado VARCHAR(50);
    DECLARE v_paciente INT;
    DECLARE v_inicio DATETIME;
    DECLARE v_medio INT DEFAULT NULL;
    DECLARE v_monto DECIMAL(12,2);
    DECLARE v_tarjeta INT DEFAULT NULL;
    DECLARE v_venc DATETIME;
    DECLARE v_pago INT;
    DECLARE v_codigo VARCHAR(100);
    DECLARE v_canal INT;
    DECLARE v_programada DATETIME;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, CONCAT('Error ', v_errno, ': ', v_msg)),
                                        'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT e.nombre, t.id_paciente, t.fecha_hora_inicio INTO v_estado, v_paciente, v_inicio
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno FOR UPDATE;
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52110, MESSAGE_TEXT = 'El turno no existe';
    END IF;
    IF v_estado <> 'pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52111, MESSAGE_TEXT = 'Solo se paga la seña de un turno pendiente';
    END IF;
    IF v_inicio <= auditoria.fn_ahora() THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52112, MESSAGE_TEXT = 'El turno ya empezó o pasó';
    END IF;
    IF EXISTS (SELECT 1 FROM pagos.PagoSena WHERE id_turno = p_id_turno) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52113, MESSAGE_TEXT = 'El turno ya tiene un pago de seña';
    END IF;
    SELECT id_medio_pago INTO v_medio FROM pagos.MedioPago WHERE nombre = p_medio_pago;
    IF v_medio IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52114, MESSAGE_TEXT = 'Medio de pago inválido';
    END IF;
    SET v_monto = agenda.fn_sena(p_id_turno);
    IF v_monto <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52115, MESSAGE_TEXT = 'El turno no tiene una seña para cobrar';
    END IF;

    IF p_medio_pago = 'tarjeta de regalo' THEN
        IF EXISTS (SELECT 1 FROM beneficios.Cupon WHERE id_turno = p_id_turno) THEN
            SET v_tipo_log = 'tarjeta_rechazada', v_desc_log = 'Un turno con cupón no puede pagarse con tarjeta de regalo';
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52116, MESSAGE_TEXT = 'Un cupón y una tarjeta de regalo no se pueden usar en el mismo turno';
        END IF;
        SELECT id_tarjeta, fecha_vencimiento INTO v_tarjeta, v_venc
          FROM pagos.TarjetaRegalo WHERE codigo = p_codigo_tarjeta FOR UPDATE;
        IF v_tarjeta IS NULL OR v_venc <= auditoria.fn_ahora() OR pagos.fn_saldo_tarjeta(v_tarjeta) < v_monto THEN
            SET v_tipo_log = 'tarjeta_rechazada',
                v_desc_log = IF(v_tarjeta IS NULL, 'Código de tarjeta inexistente', IF(v_venc <= auditoria.fn_ahora(), 'Tarjeta vencida', 'Saldo insuficiente'));
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52117, MESSAGE_TEXT = 'La tarjeta de regalo no existe, está vencida o no tiene saldo suficiente';
        END IF;
    END IF;

    SET v_codigo = CONCAT('SIM-', DATE_FORMAT(auditoria.fn_ahora(), '%Y%m%d'), '-', LPAD(p_id_turno, 5, '0'));
    INSERT INTO pagos.PagoSena (id_turno, id_estado_pago, id_medio_pago, monto, fecha_pago, codigo_operacion)
    VALUES (p_id_turno, (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre = 'pagada'), v_medio, v_monto,
            auditoria.fn_ahora(), v_codigo);
    SET v_pago = LAST_INSERT_ID();
    UPDATE agenda.Turno SET id_estado_turno = (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'confirmado')
     WHERE id_turno = p_id_turno;
    IF v_tarjeta IS NOT NULL THEN
        INSERT INTO pagos.MovimientoTarjeta (id_tarjeta, id_turno, monto, fecha_movimiento)
        VALUES (v_tarjeta, p_id_turno, v_monto, auditoria.fn_ahora());
        CALL auditoria.sp_registrar_log('tarjeta_usada', p_id_usuario, v_paciente, p_origen,
            CONCAT('Gasto de $', v_monto, ' en el turno ', p_id_turno), 'pagos.MovimientoTarjeta', v_tarjeta, NULL,
            CONCAT('saldo=', pagos.fn_saldo_tarjeta(v_tarjeta)), 1, NULL);
    END IF;

    -- Avisos: confirmación ahora y recordatorio 24 horas antes (Telegram si la paciente lo vinculó).
    SELECT IF(telegram_chat_id IS NOT NULL, (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'Telegram'),
              (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido'))
      INTO v_canal FROM personas.Paciente WHERE id_paciente = v_paciente;
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada)
    VALUES (v_canal, (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
            (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'confirmación'), v_paciente, p_id_turno,
            CONCAT('Tu turno quedó confirmado: ', DATE_FORMAT(v_inicio, '%d/%m'), ' a las ', DATE_FORMAT(v_inicio, '%H:%i'), '.'),
            auditoria.fn_ahora());
    SET v_programada = CASE WHEN v_inicio - INTERVAL 24 HOUR > auditoria.fn_ahora() THEN v_inicio - INTERVAL 24 HOUR ELSE auditoria.fn_ahora() END;
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada)
    VALUES (v_canal, (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
            (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'recordatorio de turno'), v_paciente, p_id_turno,
            CONCAT('Recordatorio: tu turno es el ', DATE_FORMAT(v_inicio, '%d/%m'), ' a las ', DATE_FORMAT(v_inicio, '%H:%i'), '.'),
            v_programada);

    CALL auditoria.sp_registrar_log('pago_registrado', p_id_usuario, v_paciente, p_origen,
        CONCAT('Seña de $', v_monto, ' del turno ', p_id_turno, ' (', p_medio_pago, ')'), 'pagos.PagoSena', v_pago, NULL,
        CONCAT('monto=', v_monto, ';codigo=', v_codigo), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Seña registrada, turno confirmado' AS mensaje, v_pago AS id, v_monto AS valor, v_codigo AS dato;
END//

-- Cancela un turno pendiente o confirmado. Con más de 24 horas de anticipación
-- la seña se reembolsa al 100%; con menos, queda retenida (RF-10). Si el turno
-- tenía un cupón y se reembolsa, el cupón vuelve a quedar disponible.
-- Devuelve: valor = monto reembolsado, dato = qué pasó con la seña.
DROP PROCEDURE IF EXISTS agenda.sp_cancelar_turno//
CREATE PROCEDURE agenda.sp_cancelar_turno(IN p_id_turno INT, IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_estado VARCHAR(50);
    DECLARE v_paciente INT;
    DECLARE v_inicio DATETIME;
    DECLARE v_pago INT DEFAULT NULL;
    DECLARE v_monto DECIMAL(12,2) DEFAULT 0;
    DECLARE v_estado_pago VARCHAR(50);
    DECLARE v_total SMALLINT;
    DECLARE v_reembolsado DECIMAL(12,2) DEFAULT 0;
    DECLARE v_resultado VARCHAR(50) DEFAULT 'sin seña';
    DECLARE v_canal INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cancelacion_turno', p_id_usuario, v_paciente, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT e.nombre, t.id_paciente, t.fecha_hora_inicio INTO v_estado, v_paciente, v_inicio
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno FOR UPDATE;
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52120, MESSAGE_TEXT = 'El turno no existe';
    END IF;
    IF v_estado NOT IN ('pendiente', 'confirmado') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52121, MESSAGE_TEXT = 'Solo se cancela un turno pendiente o confirmado';
    END IF;
    IF v_inicio <= auditoria.fn_ahora() THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52122, MESSAGE_TEXT = 'El turno ya empezó o pasó';
    END IF;

    SET v_total = (TIMESTAMPDIFF(MINUTE, auditoria.fn_ahora(), v_inicio) > 24 * 60);

    SELECT ps.id_pago, ps.monto, ep.nombre INTO v_pago, v_monto, v_estado_pago
      FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
     WHERE ps.id_turno = p_id_turno;
    IF v_pago IS NOT NULL AND v_estado_pago = 'pagada' THEN
        IF v_total = 1 THEN
            SET v_reembolsado = v_monto, v_resultado = 'reembolsada';
            CALL pagos.sp_aplicar_reembolso(v_pago, v_monto, 'reembolsada', 'Cancelación con más de 24 h', p_id_usuario, p_origen);
        ELSE
            SET v_reembolsado = 0, v_resultado = 'retenida';
            CALL pagos.sp_aplicar_reembolso(v_pago, 0, 'retenida', 'Cancelación con menos de 24 h', p_id_usuario, p_origen);
        END IF;
    END IF;

    UPDATE agenda.Turno SET id_estado_turno = (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'cancelado')
     WHERE id_turno = p_id_turno;
    -- La consulta previa cancelada deja de esperar un resultado.
    DELETE FROM clinica.EvaluacionPrevia
     WHERE id_turno = p_id_turno AND id_resultado = (SELECT id_resultado FROM clinica.ResultadoEvaluacion WHERE nombre = 'pendiente');
    IF v_total = 1 THEN
        UPDATE beneficios.Cupon SET id_turno = NULL WHERE id_turno = p_id_turno AND fecha_vencimiento > auditoria.fn_ahora();
    END IF;

    UPDATE notificaciones.Notificacion SET id_estado_notificacion = (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'cancelada')
     WHERE id_turno = p_id_turno AND id_estado_notificacion = (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente');
    SELECT IF(telegram_chat_id IS NOT NULL, (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'Telegram'),
              (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido'))
      INTO v_canal FROM personas.Paciente WHERE id_paciente = v_paciente;
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada)
    VALUES (v_canal, (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
            (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'cancelación'), v_paciente, p_id_turno,
            CONCAT('Tu turno del ', DATE_FORMAT(v_inicio, '%d/%m'), ' a las ', DATE_FORMAT(v_inicio, '%H:%i'), ' fue cancelado.'),
            auditoria.fn_ahora());

    CALL auditoria.sp_registrar_log('cancelacion_turno', p_id_usuario, v_paciente, p_origen,
        CONCAT('Turno ', p_id_turno, ' cancelado con ', TIMESTAMPDIFF(HOUR, auditoria.fn_ahora(), v_inicio), ' h de anticipación; seña: ', v_resultado),
        'agenda.Turno', p_id_turno, v_estado, 'cancelado', 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Turno cancelado' AS mensaje, p_id_turno AS id, v_reembolsado AS valor, v_resultado AS dato;
END//

-- Marca un turno confirmado como 'realizado' o 'ausente' una vez que empezó.
-- La inasistencia retiene la seña.
DROP PROCEDURE IF EXISTS agenda.sp_marcar_turno//
CREATE PROCEDURE agenda.sp_marcar_turno(IN p_id_turno INT, IN p_estado VARCHAR(20), IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_estado VARCHAR(50);
    DECLARE v_paciente INT;
    DECLARE v_inicio DATETIME;
    DECLARE v_pago INT DEFAULT NULL;
    DECLARE v_estado_pago VARCHAR(50);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_estado_turno', p_id_usuario, v_paciente, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_estado IS NULL OR p_estado NOT IN ('realizado', 'ausente') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52125, MESSAGE_TEXT = 'El estado debe ser realizado o ausente';
    END IF;
    START TRANSACTION;
    SELECT e.nombre, t.id_paciente, t.fecha_hora_inicio INTO v_estado, v_paciente, v_inicio
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno FOR UPDATE;
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52120, MESSAGE_TEXT = 'El turno no existe';
    END IF;
    IF v_estado <> 'confirmado' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52126, MESSAGE_TEXT = 'Solo se marca un turno confirmado';
    END IF;
    IF v_inicio > auditoria.fn_ahora() THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52127, MESSAGE_TEXT = 'El turno todavía no empezó';
    END IF;

    UPDATE agenda.Turno SET id_estado_turno = (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = p_estado) WHERE id_turno = p_id_turno;
    IF p_estado = 'ausente' THEN
        SELECT ps.id_pago, ep.nombre INTO v_pago, v_estado_pago
          FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = p_id_turno;
        IF v_pago IS NOT NULL AND v_estado_pago = 'pagada' THEN
            CALL pagos.sp_aplicar_reembolso(v_pago, 0, 'retenida', 'Inasistencia', p_id_usuario, p_origen);
        END IF;
    END IF;
    CALL auditoria.sp_registrar_log('cambio_estado_turno', p_id_usuario, v_paciente, p_origen,
        CONCAT('Turno ', p_id_turno, ' marcado como ', p_estado), 'agenda.Turno', p_id_turno, v_estado, p_estado, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, CONCAT('Turno marcado como ', p_estado) AS mensaje, p_id_turno AS id, NULL AS valor, NULL AS dato;
END//


-- =====================================================================
--  REGLA DE CIRUGÍAS (RF-25): evaluación previa, reclamo y vencimiento
-- =====================================================================

-- El profesional carga el resultado de la consulta prequirúrgica. Si no es
-- apta, el instituto retiene el 10% de la seña y devuelve el resto. Si es
-- apta, la seña se devuelve cuando la paciente agenda la cirugía.
DROP PROCEDURE IF EXISTS clinica.sp_resolver_evaluacion//
CREATE PROCEDURE clinica.sp_resolver_evaluacion(
    IN p_id_evaluacion INT, IN p_resultado VARCHAR(50), IN p_observaciones VARCHAR(500),
    IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_res_actual VARCHAR(50);
    DECLARE v_turno INT;
    DECLARE v_estado_turno VARCHAR(50);
    DECLARE v_paciente INT;
    DECLARE v_pago INT DEFAULT NULL;
    DECLARE v_monto DECIMAL(12,2);
    DECLARE v_estado_pago VARCHAR(50);
    DECLARE v_devuelto DECIMAL(12,2) DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_resuelta', p_id_usuario, v_paciente, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT r.nombre, ev.id_turno, e.nombre, t.id_paciente INTO v_res_actual, v_turno, v_estado_turno, v_paciente
      FROM clinica.EvaluacionPrevia ev
      JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
      JOIN agenda.Turno t ON t.id_turno = ev.id_turno
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE ev.id_evaluacion = p_id_evaluacion FOR UPDATE;
    IF v_res_actual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52130, MESSAGE_TEXT = 'La evaluación no existe';
    END IF;
    IF v_res_actual <> 'pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52131, MESSAGE_TEXT = 'La evaluación ya tiene resultado';
    END IF;
    IF p_resultado IS NULL OR p_resultado NOT IN ('apto', 'no apto') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52132, MESSAGE_TEXT = 'El resultado debe ser apto o no apto';
    END IF;
    IF v_estado_turno <> 'realizado' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52133, MESSAGE_TEXT = 'La consulta todavía no se realizó';
    END IF;

    UPDATE clinica.EvaluacionPrevia
       SET id_resultado = (SELECT id_resultado FROM clinica.ResultadoEvaluacion WHERE nombre = p_resultado),
           observaciones = p_observaciones, fecha_resultado = auditoria.fn_ahora()
     WHERE id_evaluacion = p_id_evaluacion;
    IF p_resultado = 'no apto' THEN
        SELECT ps.id_pago, ps.monto, ep.nombre INTO v_pago, v_monto, v_estado_pago
          FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = v_turno;
        IF v_pago IS NOT NULL AND v_estado_pago = 'pagada' THEN
            SET v_devuelto = ROUND(v_monto * 0.9, 2);
            CALL pagos.sp_aplicar_reembolso(v_pago, v_devuelto, 'reembolsada parcial', 'Evaluación no apta: se retiene el 10%', p_id_usuario, p_origen);
        END IF;
    END IF;
    CALL auditoria.sp_registrar_log('evaluacion_resuelta', p_id_usuario, v_paciente, p_origen,
        CONCAT('Evaluación ', p_id_evaluacion, ': ', p_resultado), 'clinica.EvaluacionPrevia', p_id_evaluacion, 'pendiente', p_resultado, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, CONCAT('Evaluación resuelta: ', p_resultado) AS mensaje, p_id_evaluacion AS id, v_devuelto AS valor, p_resultado AS dato;
END//

-- Evaluaciones aptas que vencieron (6 meses) sin que la paciente agende la
-- cirugía: el instituto se queda con el dinero de la consulta. Es una tarea
-- diaria del sistema (n8n). Devuelve: valor = cantidad de evaluaciones vencidas.
DROP PROCEDURE IF EXISTS clinica.sp_vencer_evaluaciones//
CREATE PROCEDURE clinica.sp_vencer_evaluaciones(IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_fin SMALLINT DEFAULT 0;
    DECLARE v_eval INT;
    DECLARE v_pago INT;
    DECLARE v_cuenta INT DEFAULT 0;
    DECLARE v_cancelado INT;
    DECLARE cur CURSOR FOR
        SELECT ev.id_evaluacion, ps.id_pago
          FROM clinica.EvaluacionPrevia ev
          JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado AND r.nombre = 'apto'
          JOIN pagos.PagoSena ps ON ps.id_turno = ev.id_turno
          JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago AND ep.nombre = 'pagada'
         WHERE ev.fecha_resultado + INTERVAL 6 MONTH < auditoria.fn_ahora()
           AND NOT EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = ev.id_evaluacion AND t2.id_estado_turno <> v_cancelado);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_vencida', NULL, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'clinica.EvaluacionPrevia', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';
    START TRANSACTION;
    OPEN cur;
    leer: LOOP
        FETCH cur INTO v_eval, v_pago;
        IF v_fin = 1 THEN LEAVE leer; END IF;
        CALL pagos.sp_aplicar_reembolso(v_pago, 0, 'retenida', 'Evaluación apta vencida sin agendar la cirugía', NULL, p_origen);
        CALL auditoria.sp_registrar_log('evaluacion_vencida', NULL, NULL, p_origen,
            CONCAT('La evaluación ', v_eval, ' venció a los 6 meses'), 'clinica.EvaluacionPrevia', v_eval, NULL, NULL, 1, NULL);
        SET v_cuenta = v_cuenta + 1;
    END LOOP;
    CLOSE cur;
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, CONCAT(v_cuenta, ' evaluaciones vencidas') AS mensaje, NULL AS id, v_cuenta AS valor, NULL AS dato;
END//

-- La paciente reclama una evaluación vencida: el instituto retiene el 50% de
-- la consulta y devuelve el resto. Solo se puede reclamar una vez.
DROP PROCEDURE IF EXISTS clinica.sp_reclamar_evaluacion//
CREATE PROCEDURE clinica.sp_reclamar_evaluacion(IN p_id_evaluacion INT, IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_res VARCHAR(50);
    DECLARE v_turno INT;
    DECLARE v_fecha_res DATETIME;
    DECLARE v_reclamo DATETIME;
    DECLARE v_paciente INT;
    DECLARE v_pago INT DEFAULT NULL;
    DECLARE v_monto DECIMAL(12,2);
    DECLARE v_estado_pago VARCHAR(50);
    DECLARE v_devuelto DECIMAL(12,2) DEFAULT 0;
    DECLARE v_cancelado INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';
    SELECT r.nombre, ev.id_turno, ev.fecha_resultado, ev.fecha_reclamo, t.id_paciente
      INTO v_res, v_turno, v_fecha_res, v_reclamo, v_paciente
      FROM clinica.EvaluacionPrevia ev
      JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
      JOIN agenda.Turno t ON t.id_turno = ev.id_turno
     WHERE ev.id_evaluacion = p_id_evaluacion FOR UPDATE;
    IF v_res IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52130, MESSAGE_TEXT = 'La evaluación no existe';
    END IF;
    IF v_res <> 'apto' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52134, MESSAGE_TEXT = 'Solo se reclama una evaluación apta';
    END IF;
    IF v_reclamo IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52135, MESSAGE_TEXT = 'La evaluación ya fue reclamada';
    END IF;
    IF v_fecha_res + INTERVAL 6 MONTH >= auditoria.fn_ahora() THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52136, MESSAGE_TEXT = 'La evaluación sigue vigente: todavía puede agendar la cirugía';
    END IF;
    IF EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = p_id_evaluacion AND t2.id_estado_turno <> v_cancelado) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52137, MESSAGE_TEXT = 'La evaluación ya se usó para una cirugía';
    END IF;

    UPDATE clinica.EvaluacionPrevia SET fecha_reclamo = auditoria.fn_ahora() WHERE id_evaluacion = p_id_evaluacion;
    SELECT ps.id_pago, ps.monto, ep.nombre INTO v_pago, v_monto, v_estado_pago
      FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = v_turno;
    IF v_pago IS NOT NULL AND v_estado_pago IN ('pagada', 'retenida') THEN
        SET v_devuelto = ROUND(v_monto * 0.5, 2);
        CALL pagos.sp_aplicar_reembolso(v_pago, v_devuelto, 'reembolsada parcial', 'Reclamo de evaluación vencida: se retiene el 50%', p_id_usuario, p_origen);
    END IF;
    CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen,
        CONCAT('Reclamo de la evaluación ', p_id_evaluacion, ': se devuelven $', v_devuelto), 'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Reclamo registrado' AS mensaje, p_id_evaluacion AS id, v_devuelto AS valor, NULL AS dato;
END//


-- =====================================================================
--  CUPONES (RF-17, RF-22, RF-24, RNF-14)
-- =====================================================================

-- Emite los cupones que corresponden según las reglas activas, solo a pacientes
-- con cuenta (RF-24). Lo corre el sistema periódicamente. Devuelve la cantidad emitida.
--   frecuencia: visitas 'realizadas' dentro de la ventana >= umbral (y sin otro cupón de esa regla en la ventana)
--   gasto acumulado: cada vez que el gasto total supera otro múltiplo del umbral
--   promoción general: una sola vez por paciente
DROP PROCEDURE IF EXISTS beneficios.sp_emitir_cupones//
CREATE PROCEDURE beneficios.sp_emitir_cupones(IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_max_antes INT DEFAULT 0;
    DECLARE v_fin SMALLINT DEFAULT 0;
    DECLARE v_id INT;
    DECLARE v_pac INT;
    DECLARE v_pct DECIMAL(5,2);
    DECLARE v_codigo VARCHAR(50);
    DECLARE v_cuenta INT DEFAULT 0;
    DECLARE v_canal INT;
    DECLARE cur CURSOR FOR
        SELECT c.id_cupon, c.id_paciente, c.porcentaje_descuento, c.codigo FROM beneficios.Cupon c WHERE c.id_cupon > v_max_antes ORDER BY c.id_cupon;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_emitido', NULL, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'beneficios.Cupon', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT COALESCE(MAX(id_cupon), 0) INTO v_max_antes FROM beneficios.Cupon;
    START TRANSACTION;
    INSERT INTO beneficios.Cupon (id_regla, id_paciente, codigo, secreto, porcentaje_descuento, fecha_emision, fecha_vencimiento)
    WITH RECURSIVE nums AS (SELECT 1 AS n UNION ALL SELECT n + 1 FROM nums WHERE n < 30)
    SELECT cand.id_regla, cand.id_paciente,
           CONCAT('DER-', UPPER(SUBSTRING(REPLACE(UUID(), '-', '') FROM 1 FOR 8))),
           UUID(),
           cand.pct, auditoria.fn_ahora(), auditoria.fn_ahora() + INTERVAL cand.vig WEEK
      FROM (
            -- frecuencia de visitas
            SELECT r.id_regla, p.id_paciente, r.porcentaje_descuento AS pct, r.vigencia_semanas AS vig
              FROM beneficios.ReglaBeneficio r
              JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla AND tr.nombre = 'frecuencia de visitas'
              JOIN personas.Paciente p ON p.id_usuario IS NOT NULL
             WHERE r.activa = 1
               AND (SELECT COUNT(*) FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre = 'realizado'
                     WHERE t.id_paciente = p.id_paciente
                       AND t.fecha_hora_inicio BETWEEN auditoria.fn_ahora() - INTERVAL r.ventana_dias DAY AND auditoria.fn_ahora()) >= r.umbral
               AND NOT EXISTS (SELECT 1 FROM beneficios.Cupon c WHERE c.id_regla = r.id_regla AND c.id_paciente = p.id_paciente
                                  AND c.fecha_emision >= auditoria.fn_ahora() - INTERVAL r.ventana_dias DAY)
            UNION ALL
            -- gasto acumulado
            SELECT r.id_regla, g.id_paciente, r.porcentaje_descuento, r.vigencia_semanas
              FROM nums
              JOIN beneficios.ReglaBeneficio r ON TRUE
              JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla AND tr.nombre = 'gasto acumulado'
              JOIN (SELECT t.id_paciente, SUM(agenda.fn_precio_final(t.id_turno)) AS gasto
                      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre = 'realizado'
                     GROUP BY t.id_paciente) g ON TRUE
              JOIN personas.Paciente p ON p.id_paciente = g.id_paciente AND p.id_usuario IS NOT NULL
             WHERE r.activa = 1
               -- un cupón por cada múltiplo del umbral que la paciente ya superó y todavía no tiene
               AND nums.n > (SELECT COUNT(*) FROM beneficios.Cupon c WHERE c.id_regla = r.id_regla AND c.id_paciente = p.id_paciente)
               AND nums.n <= FLOOR(g.gasto / r.umbral)
            UNION ALL
            -- promoción general: una vez por paciente con cuenta
            SELECT r.id_regla, p.id_paciente, r.porcentaje_descuento, r.vigencia_semanas
              FROM beneficios.ReglaBeneficio r
              JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla AND tr.nombre = 'promoción general'
              JOIN personas.Paciente p ON p.id_usuario IS NOT NULL
             WHERE r.activa = 1
               AND NOT EXISTS (SELECT 1 FROM beneficios.Cupon c WHERE c.id_regla = r.id_regla AND c.id_paciente = p.id_paciente)
           ) cand;

    SELECT id_canal INTO v_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido';
    OPEN cur;
    leer: LOOP
        FETCH cur INTO v_id, v_pac, v_pct, v_codigo;
        IF v_fin = 1 THEN LEAVE leer; END IF;
        INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, mensaje, fecha_programada)
        SELECT COALESCE((SELECT cn.id_canal FROM notificaciones.CanalNotificacion cn WHERE cn.nombre = 'Telegram' AND p.telegram_chat_id IS NOT NULL), v_canal),
               (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
               (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'cupón nuevo'),
               v_pac, CONCAT('Tenés un cupón nuevo del ', ROUND(v_pct, 0), '%: ', v_codigo, '.'), auditoria.fn_ahora()
          FROM personas.Paciente p WHERE p.id_paciente = v_pac;
        CALL auditoria.sp_registrar_log('cupon_emitido', NULL, v_pac, p_origen,
            CONCAT('Cupón ', v_codigo, ' del ', v_pct, '%'), 'beneficios.Cupon', v_id, NULL, NULL, 1, NULL);
        SET v_cuenta = v_cuenta + 1;
    END LOOP;
    CLOSE cur;
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, CONCAT(v_cuenta, ' cupones emitidos') AS mensaje, NULL AS id, v_cuenta AS valor, NULL AS dato;
END//

-- Token rotativo del cupón: se renueva cada 5 minutos y no se guarda; sale de
-- una cuenta simple (CRC32) con el secreto del cupón y el tramo de 5 minutos actual
-- (RNF-14; no es encriptación ni un HMAC, se aclara en la defensa).
DROP FUNCTION IF EXISTS beneficios.fn_token_cupon//
CREATE FUNCTION beneficios.fn_token_cupon(p_secreto VARCHAR(255), p_tramo BIGINT) RETURNS VARCHAR(8)
    DETERMINISTIC NO SQL
BEGIN
    RETURN UPPER(LPAD(CONV(CRC32(CONCAT(p_secreto, ':', p_tramo)), 10, 16), 8, '0'));
END//

-- Pide el token vigente de un cupón (lo muestra la app o el QR de la paciente).
-- Devuelve: dato = token, valor = segundos que le quedan.
DROP PROCEDURE IF EXISTS beneficios.sp_generar_token_cupon//
CREATE PROCEDURE beneficios.sp_generar_token_cupon(IN p_codigo VARCHAR(50), IN p_id_paciente INT)
BEGIN
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_secreto VARCHAR(255);
    DECLARE v_pac INT;
    DECLARE v_turno INT;
    DECLARE v_venc DATETIME;
    DECLARE v_seg BIGINT DEFAULT TIMESTAMPDIFF(SECOND, '1970-01-01 00:00:00', auditoria.fn_ahora());

    SELECT id_cupon, secreto, id_paciente, id_turno, fecha_vencimiento INTO v_id, v_secreto, v_pac, v_turno, v_venc
      FROM beneficios.Cupon WHERE codigo = p_codigo;
    IF v_id IS NULL THEN
        SELECT 'ERROR' AS estado, 52140 AS codigo, 'El cupón no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    ELSEIF p_id_paciente IS NOT NULL AND v_pac <> p_id_paciente THEN
        SELECT 'ERROR' AS estado, 52141 AS codigo, 'El cupón es de otra paciente' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    ELSEIF v_turno IS NOT NULL THEN
        SELECT 'ERROR' AS estado, 52142 AS codigo, 'El cupón ya fue usado' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
    ELSEIF v_venc <= auditoria.fn_ahora() THEN
        SELECT 'ERROR' AS estado, 52143 AS codigo, 'El cupón está vencido' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
    ELSE
        SELECT 'OK' AS estado, 0 AS codigo, 'Token vigente por menos de 5 minutos' AS mensaje, v_id AS id,
               300 - (v_seg MOD 300) AS valor, beneficios.fn_token_cupon(v_secreto, v_seg DIV 300) AS dato;
    END IF;
END//

-- Valida un cupón con su token (RF-22). Acepta el tramo actual y el anterior
-- (margen por diferencia de relojes). Cada validación, aceptada o rechazada,
-- queda en el log. Devuelve: id = cupón, valor = % de descuento.
DROP PROCEDURE IF EXISTS beneficios.sp_validar_cupon//
CREATE PROCEDURE beneficios.sp_validar_cupon(
    IN p_codigo VARCHAR(50), IN p_token VARCHAR(20), IN p_id_paciente INT, IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_secreto VARCHAR(255);
    DECLARE v_pac INT;
    DECLARE v_turno INT;
    DECLARE v_venc DATETIME;
    DECLARE v_pct DECIMAL(5,2);
    DECLARE v_tramo BIGINT DEFAULT TIMESTAMPDIFF(SECOND, '1970-01-01 00:00:00', auditoria.fn_ahora()) DIV 300;
    DECLARE v_motivo VARCHAR(100) DEFAULT NULL;
    DECLARE v_cod INT DEFAULT 0;

    SELECT id_cupon, secreto, id_paciente, id_turno, fecha_vencimiento, porcentaje_descuento
      INTO v_id, v_secreto, v_pac, v_turno, v_venc, v_pct
      FROM beneficios.Cupon WHERE codigo = p_codigo;

    IF v_id IS NULL THEN SET v_motivo = 'El cupón no existe', v_cod = 52140;
    ELSEIF p_id_paciente IS NOT NULL AND v_pac <> p_id_paciente THEN SET v_motivo = 'El cupón es de otra paciente', v_cod = 52141;
    ELSEIF v_turno IS NOT NULL THEN SET v_motivo = 'El cupón ya fue usado', v_cod = 52142;
    ELSEIF v_venc <= auditoria.fn_ahora() THEN SET v_motivo = 'El cupón está vencido', v_cod = 52143;
    ELSEIF p_token IS NULL OR UPPER(p_token) NOT IN (beneficios.fn_token_cupon(v_secreto, v_tramo), beneficios.fn_token_cupon(v_secreto, v_tramo - 1)) THEN
        SET v_motivo = 'El token es inválido o ya venció', v_cod = 52144;
    END IF;

    IF v_motivo IS NOT NULL THEN
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_pac, p_origen, v_motivo, 'beneficios.Cupon', v_id, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_cod AS codigo, v_motivo AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
    ELSE
        CALL auditoria.sp_registrar_log('cupon_validado', p_id_usuario, v_pac, p_origen, 'Cupón validado con su token', 'beneficios.Cupon', v_id, NULL, NULL, 1, NULL);
        SELECT 'OK' AS estado, 0 AS codigo, 'Cupón válido' AS mensaje, v_id AS id, v_pct AS valor, NULL AS dato;
    END IF;
END//

-- Aplica un cupón a un turno pendiente escaneando su QR antes del pago (RF-22).
DROP PROCEDURE IF EXISTS beneficios.sp_aplicar_cupon_a_turno//
CREATE PROCEDURE beneficios.sp_aplicar_cupon_a_turno(
    IN p_id_turno INT, IN p_codigo VARCHAR(50), IN p_token VARCHAR(20), IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_paciente INT;
    DECLARE v_estado VARCHAR(50);
    DECLARE v_cupon INT DEFAULT NULL;
    DECLARE v_secreto VARCHAR(255);
    DECLARE v_pac_cupon INT;
    DECLARE v_turno_cupon INT;
    DECLARE v_venc DATETIME;
    DECLARE v_tramo BIGINT DEFAULT TIMESTAMPDIFF(SECOND, '1970-01-01 00:00:00', auditoria.fn_ahora()) DIV 300;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT e.nombre, t.id_paciente INTO v_estado, v_paciente
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno FOR UPDATE;
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52120, MESSAGE_TEXT = 'El turno no existe';
    END IF;
    IF v_estado <> 'pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52145, MESSAGE_TEXT = 'El cupón se aplica antes de pagar la seña (turno pendiente)';
    END IF;
    IF EXISTS (SELECT 1 FROM beneficios.Cupon WHERE id_turno = p_id_turno) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52146, MESSAGE_TEXT = 'El turno ya tiene un cupón';
    END IF;
    SELECT id_cupon, secreto, id_paciente, id_turno, fecha_vencimiento INTO v_cupon, v_secreto, v_pac_cupon, v_turno_cupon, v_venc
      FROM beneficios.Cupon WHERE codigo = p_codigo FOR UPDATE;
    IF v_cupon IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52140, MESSAGE_TEXT = 'El cupón no existe';
    END IF;
    IF v_pac_cupon <> v_paciente THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52141, MESSAGE_TEXT = 'El cupón es de otra paciente';
    END IF;
    IF v_turno_cupon IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52142, MESSAGE_TEXT = 'El cupón ya fue usado';
    END IF;
    IF v_venc <= auditoria.fn_ahora() THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52143, MESSAGE_TEXT = 'El cupón está vencido';
    END IF;
    IF p_token IS NULL OR UPPER(p_token) NOT IN (beneficios.fn_token_cupon(v_secreto, v_tramo), beneficios.fn_token_cupon(v_secreto, v_tramo - 1)) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52144, MESSAGE_TEXT = 'El token es inválido o ya venció';
    END IF;

    START TRANSACTION;
    UPDATE beneficios.Cupon SET id_turno = p_id_turno WHERE id_cupon = v_cupon;
    CALL auditoria.sp_registrar_log('cupon_validado', p_id_usuario, v_paciente, p_origen,
        CONCAT('Cupón ', p_codigo, ' aplicado al turno ', p_id_turno, ' con QR'), 'beneficios.Cupon', v_cupon, NULL, NULL, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Cupón aplicado' AS mensaje, v_cupon AS id,
           agenda.fn_sena(p_id_turno) AS valor, CAST(agenda.fn_precio_final(p_id_turno) AS CHAR) AS dato;
END//


-- =====================================================================
--  TARJETAS DE REGALO (RF-23)
-- =====================================================================

-- El saldo no se guarda: es el monto inicial menos la suma de los movimientos.
DROP FUNCTION IF EXISTS pagos.fn_saldo_tarjeta//
CREATE FUNCTION pagos.fn_saldo_tarjeta(p_id_tarjeta INT) RETURNS DECIMAL(12,2)
    NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT t.monto_inicial - COALESCE((SELECT SUM(m.monto) FROM pagos.MovimientoTarjeta m WHERE m.id_tarjeta = t.id_tarjeta), 0)
              FROM pagos.TarjetaRegalo t WHERE t.id_tarjeta = p_id_tarjeta);
END//

-- Vende una tarjeta de regalo (código largo y aleatorio, vigencia de 12 meses).
-- Devuelve: id = tarjeta, valor = monto, dato = código de la tarjeta.
DROP PROCEDURE IF EXISTS pagos.sp_comprar_tarjeta//
CREATE PROCEDURE pagos.sp_comprar_tarjeta(
    IN p_monto DECIMAL(12,2), IN p_medio_pago VARCHAR(50), IN p_comprador_nombre VARCHAR(100),
    IN p_comprador_telefono VARCHAR(30), IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_medio INT DEFAULT NULL;
    DECLARE v_codigo VARCHAR(50);
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_monto IS NULL OR p_monto < 20000 OR p_monto > 5000000 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52150, MESSAGE_TEXT = 'El monto de la tarjeta debe estar entre $20.000 y $5.000.000';
    END IF;
    SELECT id_medio_pago INTO v_medio FROM pagos.MedioPago WHERE nombre = p_medio_pago;
    IF v_medio IS NULL OR p_medio_pago = 'tarjeta de regalo' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52151, MESSAGE_TEXT = 'Medio de pago inválido (una tarjeta de regalo no se paga con otra)';
    END IF;
    IF p_comprador_nombre IS NULL OR CHAR_LENGTH(TRIM(p_comprador_nombre)) < 2 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52152, MESSAGE_TEXT = 'Falta el nombre de quien compra';
    END IF;
    IF p_comprador_telefono IS NOT NULL AND p_comprador_telefono <> '' AND p_comprador_telefono NOT REGEXP '^[+]?[0-9]{10,13}$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52032, MESSAGE_TEXT = 'El teléfono debe tener de 10 a 13 dígitos';
    END IF;

    START TRANSACTION;
    SET v_codigo = CONCAT('GC-', UPPER(SUBSTRING(REPLACE(UUID(), '-', '') FROM 1 FOR 24)));
    INSERT INTO pagos.TarjetaRegalo (id_medio_pago, codigo, monto_inicial, fecha_compra, fecha_vencimiento, comprador_nombre, comprador_telefono)
    VALUES (v_medio, v_codigo, p_monto, auditoria.fn_ahora(), auditoria.fn_ahora() + INTERVAL 12 MONTH, TRIM(p_comprador_nombre), NULLIF(p_comprador_telefono, ''));
    SET v_id = LAST_INSERT_ID();
    CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen,
        CONCAT('Tarjeta de regalo de $', p_monto, ' comprada por ', TRIM(p_comprador_nombre)), 'pagos.TarjetaRegalo', v_id, NULL, CONCAT('monto=', p_monto), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Tarjeta emitida' AS mensaje, v_id AS id, p_monto AS valor, v_codigo AS dato;
END//

-- Saldo y vigencia de una tarjeta. Un código inexistente queda en el log
-- (intentos fallidos, modelo grupo 3 decisión 9) y no devuelve filas.
DROP PROCEDURE IF EXISTS pagos.sp_saldo_tarjeta//
CREATE PROCEDURE pagos.sp_saldo_tarjeta(IN p_codigo VARCHAR(50), IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_id INT DEFAULT NULL;
    SELECT id_tarjeta INTO v_id FROM pagos.TarjetaRegalo WHERE codigo = p_codigo;
    IF v_id IS NULL AND p_codigo IS NOT NULL AND p_codigo <> '' THEN
        CALL auditoria.sp_registrar_log('tarjeta_rechazada', p_id_usuario, NULL, p_origen, 'Consulta de saldo con código inexistente',
                                        'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL);
    END IF;
    SELECT t.id_tarjeta, t.codigo, t.monto_inicial,
           t.monto_inicial - pagos.fn_saldo_tarjeta(t.id_tarjeta) AS gastado,
           pagos.fn_saldo_tarjeta(t.id_tarjeta) AS saldo,
           t.fecha_vencimiento, (t.fecha_vencimiento > auditoria.fn_ahora()) AS vigente
      FROM pagos.TarjetaRegalo t WHERE t.id_tarjeta = v_id;
END//

-- Historial de una tarjeta de regalo: cada gasto (monto positivo) y cada
-- devolución (negativo), con el turno y la paciente. Código inexistente,
-- NULL o vacío: 0 filas.
DROP PROCEDURE IF EXISTS pagos.sp_movimientos_tarjeta//
CREATE PROCEDURE pagos.sp_movimientos_tarjeta(IN p_codigo VARCHAR(50))
BEGIN
    SELECT m.id_movimiento, m.fecha_movimiento, m.monto, IF(m.monto > 0, 'gasto', 'devolución') AS tipo,
           m.id_turno, CONCAT(p.apellido, ', ', p.nombre) AS paciente
      FROM pagos.MovimientoTarjeta m
      JOIN pagos.TarjetaRegalo t ON t.id_tarjeta = m.id_tarjeta
      JOIN agenda.Turno tu ON tu.id_turno = m.id_turno
      JOIN personas.Paciente p ON p.id_paciente = tu.id_paciente
     WHERE t.codigo = p_codigo
     ORDER BY m.fecha_movimiento, m.id_movimiento;
END//


-- =====================================================================
--  NOTIFICACIONES (las lee y actualiza n8n)
-- =====================================================================

-- Avisos pendientes cuya hora ya llegó, con los datos del destinatario.
DROP PROCEDURE IF EXISTS notificaciones.sp_notificaciones_pendientes//
CREATE PROCEDURE notificaciones.sp_notificaciones_pendientes(IN p_limite INT)
BEGIN
    -- Sin límite (o fuera de 1 a 500) trae de a 50.
    DECLARE v_limite INT DEFAULT IF(p_limite BETWEEN 1 AND 500, p_limite, 50);
    SELECT n.id_notificacion, c.nombre AS canal, tn.nombre AS tipo, n.mensaje, n.fecha_programada, n.intentos, n.id_turno,
           COALESCE(CONCAT(p.apellido, ', ', p.nombre), CONCAT(pr.apellido, ', ', pr.nombre)) AS destinatario,
           p.telegram_chat_id,
           COALESCE((SELECT tp.telefono FROM personas.TelefonoPaciente tp WHERE tp.id_paciente = p.id_paciente ORDER BY tp.id_telefono_paciente LIMIT 1),
                    (SELECT tf.telefono FROM personas.TelefonoProfesional tf WHERE tf.id_profesional = pr.id_profesional ORDER BY tf.id_telefono_profesional LIMIT 1)) AS telefono,
           COALESCE(p.email, pr.email) AS email
      FROM notificaciones.Notificacion n
      JOIN notificaciones.EstadoNotificacion en ON en.id_estado_notificacion = n.id_estado_notificacion AND en.nombre = 'pendiente'
      JOIN notificaciones.CanalNotificacion c ON c.id_canal = n.id_canal
      JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion
      LEFT JOIN personas.Paciente p ON p.id_paciente = n.id_paciente
      LEFT JOIN personas.Profesional pr ON pr.id_profesional = n.id_profesional
     WHERE n.fecha_programada <= auditoria.fn_ahora()
     ORDER BY n.fecha_programada, n.id_notificacion
     LIMIT v_limite;
END//

-- n8n informa cómo salió el envío. Un fallo se reintenta hasta 3 veces; recién
-- al tercero queda 'fallida'.
DROP PROCEDURE IF EXISTS notificaciones.sp_marcar_notificacion//
CREATE PROCEDURE notificaciones.sp_marcar_notificacion(IN p_id_notificacion INT, IN p_resultado VARCHAR(20), IN p_detalle VARCHAR(500))
BEGIN
    DECLARE v_estado VARCHAR(50);
    DECLARE v_intentos INT;
    DECLARE v_paciente INT;
    DECLARE v_nuevo VARCHAR(50);

    SELECT en.nombre, n.intentos, n.id_paciente INTO v_estado, v_intentos, v_paciente
      FROM notificaciones.Notificacion n JOIN notificaciones.EstadoNotificacion en ON en.id_estado_notificacion = n.id_estado_notificacion
     WHERE n.id_notificacion = p_id_notificacion;
    IF v_estado IS NULL THEN
        SELECT 'ERROR' AS estado, 52160 AS codigo, 'La notificación no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    ELSEIF v_estado <> 'pendiente' THEN
        SELECT 'ERROR' AS estado, 52161 AS codigo, 'La notificación ya no está pendiente' AS mensaje, p_id_notificacion AS id, NULL AS valor, NULL AS dato;
    ELSEIF p_resultado NOT IN ('enviada', 'fallida') OR p_resultado IS NULL THEN
        SELECT 'ERROR' AS estado, 52162 AS codigo, 'El resultado debe ser enviada o fallida' AS mensaje, p_id_notificacion AS id, NULL AS valor, NULL AS dato;
    ELSE
        SET v_nuevo = IF(p_resultado = 'enviada', 'enviada', IF(v_intentos + 1 >= 3, 'fallida', 'pendiente'));
        UPDATE notificaciones.Notificacion
           SET id_estado_notificacion = (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = v_nuevo),
               intentos = intentos + 1,
               fecha_envio = IF(p_resultado = 'enviada', auditoria.fn_ahora(), fecha_envio),
               detalle_error = IF(p_resultado = 'fallida', SUBSTRING(p_detalle FROM 1 FOR 500), NULL)
         WHERE id_notificacion = p_id_notificacion;
        CALL auditoria.sp_registrar_log('notificacion_enviada', NULL, v_paciente, 'sistema',
            CONCAT('Notificación ', p_id_notificacion, ': ', p_resultado, ' (intento ', v_intentos + 1, ')'),
            'notificaciones.Notificacion', p_id_notificacion, v_estado, v_nuevo, IF(p_resultado = 'enviada', 1, 0), NULL);
        SELECT 'OK' AS estado, 0 AS codigo, CONCAT('Notificación ', v_nuevo) AS mensaje, p_id_notificacion AS id, v_intentos + 1 AS valor, v_nuevo AS dato;
    END IF;
END//


-- =====================================================================
--  ASISTENTE DE IA (RF-07, RF-14, RNF-06, RNF-10)
-- =====================================================================

-- Saca emails y números largos (teléfonos, DNI, tarjetas) antes de guardar o
-- de mandar el texto a la IA: al asistente no se le envían datos personales.
DROP FUNCTION IF EXISTS asistente.fn_filtrar_datos_personales//
CREATE FUNCTION asistente.fn_filtrar_datos_personales(p_texto TEXT) RETURNS TEXT
    DETERMINISTIC NO SQL
BEGIN
    RETURN REGEXP_REPLACE(REGEXP_REPLACE(p_texto, '[^@ ]+@[^@ ]+[.][^@ ]+', '[email]'),
                          '[+]?[0-9]([ .-]?[0-9]){6,}', '[número]');
END//

-- Registra una pregunta al asistente y su respuesta. p_derivada = 1 cuando no
-- supo responder y se derivó al WhatsApp del instituto.
DROP PROCEDURE IF EXISTS asistente.sp_registrar_consulta//
CREATE PROCEDURE asistente.sp_registrar_consulta(
    IN p_id_paciente INT, IN p_origen VARCHAR(50), IN p_pregunta TEXT, IN p_respuesta TEXT,
    IN p_derivada SMALLINT, IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_origen INT DEFAULT NULL;
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'asistente.ConsultaAsistente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT id_origen INTO v_origen FROM agenda.Origen WHERE nombre = p_origen;
    IF v_origen IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52070, MESSAGE_TEXT = 'Origen inválido (terminal, web, gestion o sistema)';
    END IF;
    IF p_pregunta IS NULL OR CHAR_LENGTH(TRIM(p_pregunta)) < 3 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52170, MESSAGE_TEXT = 'La pregunta está vacía';
    END IF;
    IF p_id_paciente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM personas.Paciente WHERE id_paciente = p_id_paciente) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52071, MESSAGE_TEXT = 'La paciente no existe';
    END IF;

    START TRANSACTION;
    INSERT INTO asistente.ConsultaAsistente (id_paciente, id_origen, pregunta, fecha_hora, derivada, respuesta)
    VALUES (p_id_paciente, v_origen, asistente.fn_filtrar_datos_personales(TRIM(p_pregunta)), auditoria.fn_ahora(),
            COALESCE(p_derivada, 0), asistente.fn_filtrar_datos_personales(p_respuesta));
    SET v_id = LAST_INSERT_ID();
    CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen,
        IF(COALESCE(p_derivada, 0) = 1, 'Consulta derivada al WhatsApp del instituto', 'Consulta respondida por el asistente'),
        'asistente.ConsultaAsistente', v_id, NULL, NULL, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Consulta registrada' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
END//

DELIMITER ;
