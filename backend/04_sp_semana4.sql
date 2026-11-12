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
    IN p_id_usuario INT, IN p_origen VARCHAR(50), IN p_codigo_operacion VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
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
    DECLARE v_saldo DECIMAL(12,2);
    DECLARE v_pago INT;
    DECLARE v_codigo_op VARCHAR(100);
    DECLARE v_canal INT;
    DECLARE v_programada DATETIME;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, v_msg),
                                        'pagos.PagoSena', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT e.nombre, t.id_paciente, t.fecha_hora_inicio INTO v_estado, v_paciente, v_inicio
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_estado IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52110 FROM DUAL WHERE v_estado IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Solo se paga la seña de un turno pendiente' FROM DUAL WHERE v_codigo IS NULL AND (v_estado <> 'pendiente')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52111 FROM DUAL WHERE v_estado <> 'pendiente'));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno ya empezó o pasó' FROM DUAL WHERE v_codigo IS NULL AND (v_inicio <= COALESCE(@ahora_simulado, NOW()))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52112 FROM DUAL WHERE v_inicio <= COALESCE(@ahora_simulado, NOW())));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno ya tiene un pago de seña' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM pagos.PagoSena WHERE id_turno = p_id_turno))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52113 FROM DUAL WHERE EXISTS (SELECT 1 FROM pagos.PagoSena WHERE id_turno = p_id_turno)));
    SELECT id_medio_pago INTO v_medio FROM pagos.MedioPago WHERE nombre = p_medio_pago;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Medio de pago inválido' FROM DUAL WHERE v_codigo IS NULL AND (v_medio IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52114 FROM DUAL WHERE v_medio IS NULL));
    -- Seña = precio final (lista menos el cupón) por el mayor porcentaje de seña de sus protocolos.
    SET v_monto = ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = p_id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = p_id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = p_id_turno), 0) / 100, 2)) * COALESCE((SELECT MAX(caz.porcentaje_sena) FROM agenda.TurnoProtocolo tpy JOIN clinica.Protocolo prz ON prz.id_protocolo = tpy.id_protocolo JOIN clinica.CategoriaProtocolo caz ON caz.id_categoria = prz.id_categoria WHERE tpy.id_turno = p_id_turno), 0) / 100, 0);
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno no tiene una seña para cobrar' FROM DUAL WHERE v_codigo IS NULL AND (v_monto <= 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52115 FROM DUAL WHERE v_monto <= 0));

    -- Pago con tarjeta de regalo: no se combina con un cupón, y la tarjeta tiene que existir,
    -- estar vigente y tener saldo. Si es otro medio de pago, v_tarjeta queda NULL.
    SELECT id_tarjeta, fecha_vencimiento INTO v_tarjeta, v_venc
      FROM pagos.TarjetaRegalo WHERE codigo = p_codigo_tarjeta AND p_medio_pago = 'tarjeta de regalo';
    SET v_saldo = (SELECT tz.monto_inicial - COALESCE((SELECT SUM(mz.monto) FROM pagos.MovimientoTarjeta mz WHERE mz.id_tarjeta = tz.id_tarjeta), 0)
                     FROM pagos.TarjetaRegalo tz WHERE tz.id_tarjeta = v_tarjeta);
    SET v_desc_log = COALESCE(v_desc_log, (SELECT 'Un turno con cupón no puede pagarse con tarjeta de regalo' FROM DUAL
                                           WHERE v_codigo IS NULL AND p_medio_pago = 'tarjeta de regalo' AND EXISTS (SELECT 1 FROM beneficios.Cupon WHERE id_turno = p_id_turno)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Un cupón y una tarjeta de regalo no se pueden usar en el mismo turno' FROM DUAL
                                         WHERE v_codigo IS NULL AND p_medio_pago = 'tarjeta de regalo' AND EXISTS (SELECT 1 FROM beneficios.Cupon WHERE id_turno = p_id_turno)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52116 FROM DUAL WHERE p_medio_pago = 'tarjeta de regalo' AND EXISTS (SELECT 1 FROM beneficios.Cupon WHERE id_turno = p_id_turno)));
    SET v_desc_log = COALESCE(v_desc_log,
        (SELECT 'Código de tarjeta inexistente' FROM DUAL WHERE v_codigo IS NULL AND p_medio_pago = 'tarjeta de regalo' AND v_tarjeta IS NULL),
        (SELECT 'Tarjeta vencida' FROM DUAL WHERE v_codigo IS NULL AND p_medio_pago = 'tarjeta de regalo' AND v_venc <= COALESCE(@ahora_simulado, NOW())),
        (SELECT 'Saldo insuficiente' FROM DUAL WHERE v_codigo IS NULL AND p_medio_pago = 'tarjeta de regalo' AND v_saldo < v_monto));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La tarjeta de regalo no existe, está vencida o no tiene saldo suficiente' FROM DUAL
                                         WHERE v_codigo IS NULL AND p_medio_pago = 'tarjeta de regalo'
                                           AND (v_tarjeta IS NULL OR v_venc <= COALESCE(@ahora_simulado, NOW()) OR v_saldo < v_monto)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52117 FROM DUAL WHERE p_medio_pago = 'tarjeta de regalo'
                                         AND (v_tarjeta IS NULL OR v_venc <= COALESCE(@ahora_simulado, NOW()) OR v_saldo < v_monto)));
    SET v_tipo_log = COALESCE((SELECT 'tarjeta_rechazada' FROM DUAL WHERE v_codigo IN (52116, 52117)), v_tipo_log);

    -- El código lo genera la aplicación (escritorio o web) y llega en p_codigo_operacion. Si no llega,
    -- se arma con la fecha (AAAAMMDD) y el número de turno, todo junto como número.
    SET v_codigo_op = COALESCE((SELECT p_codigo_operacion FROM DUAL WHERE p_codigo_operacion <> ''),
                               CAST(CAST(DATE_FORMAT(COALESCE(@ahora_simulado, NOW()), '%Y%m%d') AS UNSIGNED) * 100000 + p_id_turno AS CHAR));
    INSERT INTO pagos.PagoSena (id_turno, id_estado_pago, id_medio_pago, monto, fecha_pago, codigo_operacion)
    SELECT p_id_turno, (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre = 'pagada'), v_medio, v_monto,
           COALESCE(@ahora_simulado, NOW()), v_codigo_op
      FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_pago) INTO v_pago FROM pagos.PagoSena WHERE codigo_operacion = v_codigo_op AND v_codigo IS NULL;
    UPDATE agenda.Turno SET id_estado_turno = (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'confirmado')
     WHERE id_turno = p_id_turno AND v_codigo IS NULL;
    INSERT INTO pagos.MovimientoTarjeta (id_tarjeta, id_turno, monto, fecha_movimiento)
    SELECT v_tarjeta, p_id_turno, v_monto, COALESCE(@ahora_simulado, NOW())
      FROM DUAL WHERE v_codigo IS NULL AND v_tarjeta IS NOT NULL;
    CALL auditoria.sp_registrar_log('tarjeta_usada', p_id_usuario, v_paciente, p_origen,
        CONCAT('Gasto de $', v_monto, ' en el turno ', p_id_turno), 'pagos.MovimientoTarjeta', v_tarjeta, NULL,
        CONCAT('saldo=', v_saldo - v_monto), 1, NULL, v_codigo IS NULL AND v_tarjeta IS NOT NULL);

    -- Avisos: confirmación ahora y recordatorio 24 horas antes (Telegram si la paciente lo vinculó).
    SELECT COALESCE((SELECT (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'Telegram') FROM DUAL WHERE telegram_chat_id IS NOT NULL), (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido'))
      INTO v_canal FROM personas.Paciente WHERE id_paciente = v_paciente;
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada)
    SELECT v_canal, (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
           (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'confirmación'), v_paciente, p_id_turno,
           CONCAT('Tu turno quedó confirmado: ', DATE_FORMAT(v_inicio, '%d/%m'), ' a las ', DATE_FORMAT(v_inicio, '%H:%i'), '.'),
           COALESCE(@ahora_simulado, NOW())
      FROM DUAL WHERE v_codigo IS NULL;
    SET v_programada = COALESCE((SELECT v_inicio - INTERVAL 24 HOUR FROM DUAL WHERE v_inicio - INTERVAL 24 HOUR > COALESCE(@ahora_simulado, NOW())), COALESCE(@ahora_simulado, NOW()));
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada)
    SELECT v_canal, (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
           (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'recordatorio de turno'), v_paciente, p_id_turno,
           CONCAT('Recordatorio: tu turno es el ', DATE_FORMAT(v_inicio, '%d/%m'), ' a las ', DATE_FORMAT(v_inicio, '%H:%i'), '.'),
           v_programada
      FROM DUAL WHERE v_codigo IS NULL;

    CALL auditoria.sp_registrar_log('pago_registrado', p_id_usuario, v_paciente, p_origen,
        CONCAT('Seña de $', v_monto, ' del turno ', p_id_turno, ' (', p_medio_pago, ')'), 'pagos.PagoSena', v_pago, NULL,
        CONCAT('monto=', v_monto, ';codigo=', v_codigo_op), 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, v_mensaje),
                                    'pagos.PagoSena', NULL, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Seña registrada, turno confirmado' AS mensaje, v_pago AS id, v_monto AS valor, v_codigo_op AS dato
      FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Cancela un turno pendiente o confirmado. Con más de 24 horas de anticipación
-- la seña se reembolsa al 100%; con menos, queda retenida (RF-10). Si el turno
-- tenía un cupón y se reembolsa, el cupón vuelve a quedar disponible.
-- Devuelve: valor = monto reembolsado, dato = qué pasó con la seña.
DROP PROCEDURE IF EXISTS agenda.sp_cancelar_turno//
CREATE PROCEDURE agenda.sp_cancelar_turno(IN p_id_turno INT, IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
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
        CALL auditoria.sp_registrar_log('cancelacion_turno', p_id_usuario, v_paciente, p_origen, v_msg,
                                        'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT e.nombre, t.id_paciente, t.fecha_hora_inicio INTO v_estado, v_paciente, v_inicio
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_estado IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52120 FROM DUAL WHERE v_estado IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Solo se cancela un turno pendiente o confirmado' FROM DUAL WHERE v_codigo IS NULL AND (v_estado NOT IN ('pendiente', 'confirmado'))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52121 FROM DUAL WHERE v_estado NOT IN ('pendiente', 'confirmado')));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno ya empezó o pasó' FROM DUAL WHERE v_codigo IS NULL AND (v_inicio <= COALESCE(@ahora_simulado, NOW()))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52122 FROM DUAL WHERE v_inicio <= COALESCE(@ahora_simulado, NOW())));

    SET v_total = (v_inicio > COALESCE(@ahora_simulado, NOW()) + INTERVAL 24 HOUR);

    SELECT ps.id_pago, ps.monto, ep.nombre INTO v_pago, v_monto, v_estado_pago
      FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
     WHERE ps.id_turno = p_id_turno;
    -- Con más de 24 h la seña se devuelve; con menos, se retiene. Cada llamada se ejecuta solo si corresponde.
    SET v_resultado = COALESCE((SELECT 'reembolsada' FROM DUAL WHERE v_pago IS NOT NULL AND v_estado_pago = 'pagada' AND v_total = 1),
                               (SELECT 'retenida' FROM DUAL WHERE v_pago IS NOT NULL AND v_estado_pago = 'pagada' AND v_total = 0),
                               v_resultado);
    SET v_reembolsado = COALESCE((SELECT v_monto FROM DUAL WHERE v_resultado = 'reembolsada'), 0);
    CALL pagos.sp_aplicar_reembolso(v_pago, v_monto, 'reembolsada', 'Cancelación con más de 24 h', p_id_usuario, p_origen,
                                    v_codigo IS NULL AND v_resultado = 'reembolsada');
    CALL pagos.sp_aplicar_reembolso(v_pago, 0, 'retenida', 'Cancelación con menos de 24 h', p_id_usuario, p_origen,
                                    v_codigo IS NULL AND v_resultado = 'retenida');

    UPDATE agenda.Turno SET id_estado_turno = (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'cancelado')
     WHERE id_turno = p_id_turno AND v_codigo IS NULL;
    -- La consulta previa cancelada deja de esperar un resultado.
    DELETE FROM clinica.EvaluacionPrevia
     WHERE id_turno = p_id_turno AND id_resultado = (SELECT id_resultado FROM clinica.ResultadoEvaluacion WHERE nombre = 'pendiente');
    -- Con más de 24 h, el cupón vigente vuelve a estar disponible.
    UPDATE beneficios.Cupon SET id_turno = NULL WHERE id_turno = p_id_turno AND fecha_vencimiento > COALESCE(@ahora_simulado, NOW()) AND v_total = 1;

    UPDATE notificaciones.Notificacion SET id_estado_notificacion = (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'cancelada')
     WHERE id_turno = p_id_turno AND id_estado_notificacion = (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente') AND v_codigo IS NULL;
    SELECT COALESCE((SELECT (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'Telegram') FROM DUAL WHERE telegram_chat_id IS NOT NULL), (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido'))
      INTO v_canal FROM personas.Paciente WHERE id_paciente = v_paciente;
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada)
    SELECT v_canal, (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
            (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'cancelación'), v_paciente, p_id_turno,
            CONCAT('Tu turno del ', DATE_FORMAT(v_inicio, '%d/%m'), ' a las ', DATE_FORMAT(v_inicio, '%H:%i'), ' fue cancelado.'),
            COALESCE(@ahora_simulado, NOW()) FROM DUAL WHERE v_codigo IS NULL;

    CALL auditoria.sp_registrar_log('cancelacion_turno', p_id_usuario, v_paciente, p_origen,
        CONCAT('Turno ', p_id_turno, ' cancelado; seña: ', v_resultado),
        'agenda.Turno', p_id_turno, v_estado, 'cancelado', 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('cancelacion_turno', p_id_usuario, v_paciente, p_origen, v_mensaje,
                                        'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Turno cancelado' AS mensaje, p_id_turno AS id, v_reembolsado AS valor, v_resultado AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Marca un turno confirmado como 'realizado' o 'ausente' una vez que empezó.
-- La inasistencia retiene la seña.
DROP PROCEDURE IF EXISTS agenda.sp_marcar_turno//
CREATE PROCEDURE agenda.sp_marcar_turno(IN p_id_turno INT, IN p_estado VARCHAR(20), IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
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
        CALL auditoria.sp_registrar_log('cambio_estado_turno', p_id_usuario, v_paciente, p_origen, v_msg,
                                        'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El estado debe ser realizado o ausente' FROM DUAL WHERE v_codigo IS NULL AND (p_estado IS NULL OR p_estado NOT IN ('realizado', 'ausente'))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52125 FROM DUAL WHERE p_estado IS NULL OR p_estado NOT IN ('realizado', 'ausente')));
    START TRANSACTION;
    SELECT e.nombre, t.id_paciente, t.fecha_hora_inicio INTO v_estado, v_paciente, v_inicio
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_estado IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52120 FROM DUAL WHERE v_estado IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Solo se marca un turno confirmado' FROM DUAL WHERE v_codigo IS NULL AND (v_estado <> 'confirmado')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52126 FROM DUAL WHERE v_estado <> 'confirmado'));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno todavía no empezó' FROM DUAL WHERE v_codigo IS NULL AND (v_inicio > COALESCE(@ahora_simulado, NOW()))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52127 FROM DUAL WHERE v_inicio > COALESCE(@ahora_simulado, NOW())));

    UPDATE agenda.Turno SET id_estado_turno = (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = p_estado) WHERE id_turno = p_id_turno AND v_codigo IS NULL;
    -- Si no vino (ausente), la seña pagada se retiene.
    SELECT ps.id_pago, ep.nombre INTO v_pago, v_estado_pago
      FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = p_id_turno;
    CALL pagos.sp_aplicar_reembolso(v_pago, 0, 'retenida', 'Inasistencia', p_id_usuario, p_origen,
                                    v_codigo IS NULL AND p_estado = 'ausente' AND v_pago IS NOT NULL AND v_estado_pago = 'pagada');
    CALL auditoria.sp_registrar_log('cambio_estado_turno', p_id_usuario, v_paciente, p_origen,
        CONCAT('Turno ', p_id_turno, ' marcado como ', p_estado), 'agenda.Turno', p_id_turno, v_estado, p_estado, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('cambio_estado_turno', p_id_usuario, v_paciente, p_origen, v_mensaje,
                                        'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, CONCAT('Turno marcado como ', p_estado) AS mensaje, p_id_turno AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
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
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
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
        CALL auditoria.sp_registrar_log('evaluacion_resuelta', p_id_usuario, v_paciente, p_origen, v_msg,
                                        'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT r.nombre, ev.id_turno, e.nombre, t.id_paciente INTO v_res_actual, v_turno, v_estado_turno, v_paciente
      FROM clinica.EvaluacionPrevia ev
      JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
      JOIN agenda.Turno t ON t.id_turno = ev.id_turno
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE ev.id_evaluacion = p_id_evaluacion;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La evaluación no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_res_actual IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52130 FROM DUAL WHERE v_res_actual IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La evaluación ya tiene resultado' FROM DUAL WHERE v_codigo IS NULL AND (v_res_actual <> 'pendiente')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52131 FROM DUAL WHERE v_res_actual <> 'pendiente'));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El resultado debe ser apto o no apto' FROM DUAL WHERE v_codigo IS NULL AND (p_resultado IS NULL OR p_resultado NOT IN ('apto', 'no apto'))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52132 FROM DUAL WHERE p_resultado IS NULL OR p_resultado NOT IN ('apto', 'no apto')));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La consulta todavía no se realizó' FROM DUAL WHERE v_codigo IS NULL AND (v_estado_turno <> 'realizado')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52133 FROM DUAL WHERE v_estado_turno <> 'realizado'));

    UPDATE clinica.EvaluacionPrevia
       SET id_resultado = (SELECT id_resultado FROM clinica.ResultadoEvaluacion WHERE nombre = p_resultado),
           observaciones = p_observaciones, fecha_resultado = COALESCE(@ahora_simulado, NOW())
     WHERE id_evaluacion = p_id_evaluacion AND v_codigo IS NULL;
    -- Si no es apta, se devuelve el 90% de la seña de la consulta.
    SELECT ps.id_pago, ps.monto, ep.nombre INTO v_pago, v_monto, v_estado_pago
      FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = v_turno;
    SET v_devuelto = COALESCE((SELECT ROUND(v_monto * 0.9, 2) FROM DUAL
                                WHERE v_codigo IS NULL AND p_resultado = 'no apto' AND v_pago IS NOT NULL AND v_estado_pago = 'pagada'), v_devuelto);
    CALL pagos.sp_aplicar_reembolso(v_pago, v_devuelto, 'reembolsada parcial', 'Evaluación no apta: se retiene el 10%', p_id_usuario, p_origen,
                                    v_codigo IS NULL AND p_resultado = 'no apto' AND v_pago IS NOT NULL AND v_estado_pago = 'pagada');
    CALL auditoria.sp_registrar_log('evaluacion_resuelta', p_id_usuario, v_paciente, p_origen,
        CONCAT('Evaluación ', p_id_evaluacion, ': ', p_resultado), 'clinica.EvaluacionPrevia', p_id_evaluacion, 'pendiente', p_resultado, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('evaluacion_resuelta', p_id_usuario, v_paciente, p_origen, v_mensaje,
                                        'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, CONCAT('Evaluación resuelta: ', p_resultado) AS mensaje, p_id_evaluacion AS id, v_devuelto AS valor, p_resultado AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Evaluaciones aptas que vencieron (6 meses) sin que la paciente agende la
-- cirugía: el instituto se queda con el dinero de la consulta. Es una tarea
-- diaria del sistema (n8n). Devuelve: valor = cantidad de evaluaciones vencidas.
DROP PROCEDURE IF EXISTS clinica.sp_vencer_evaluaciones//
CREATE PROCEDURE clinica.sp_vencer_evaluaciones(IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_cuenta INT DEFAULT 0;
    DECLARE v_cancelado INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_vencida', NULL, NULL, p_origen, v_msg,
                                        'clinica.EvaluacionPrevia', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';
    START TRANSACTION;
    -- Evaluaciones aptas de hace más de 6 meses, sin cirugía agendada y con la seña pagada:
    -- el instituto se queda con la seña de la consulta. Se resuelven todas juntas (sin cursor).
    DROP TEMPORARY TABLE IF EXISTS tmp_evaluaciones_vencidas;
    CREATE TEMPORARY TABLE tmp_evaluaciones_vencidas AS
    SELECT ev.id_evaluacion, ps.id_pago, ps.monto, t.id_paciente
      FROM clinica.EvaluacionPrevia ev
      JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado AND r.nombre = 'apto'
      JOIN agenda.Turno t ON t.id_turno = ev.id_turno
      JOIN pagos.PagoSena ps ON ps.id_turno = ev.id_turno
      JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago AND ep.nombre = 'pagada'
     WHERE ev.fecha_resultado + INTERVAL 6 MONTH < COALESCE(@ahora_simulado, NOW())
       AND NOT EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = ev.id_evaluacion AND t2.id_estado_turno <> v_cancelado);
    SET v_cuenta = (SELECT COUNT(*) FROM tmp_evaluaciones_vencidas);

    UPDATE pagos.PagoSena
       SET id_estado_pago = (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre = 'retenida'),
           monto_reembolsado = 0,
           fecha_resolucion = COALESCE(@ahora_simulado, NOW())
     WHERE id_pago IN (SELECT id_pago FROM tmp_evaluaciones_vencidas);

    -- Dos filas de log por evaluación: la retención de la seña y el vencimiento.
    INSERT INTO auditoria.Log (id_tipo_evento, id_usuario, id_paciente, id_origen, fecha_hora, descripcion,
                               ip_origen, tabla_afectada, id_registro_afectado, valor_anterior, valor_nuevo, exitoso)
    SELECT te.id_tipo_evento, NULL, v.id_paciente,
           COALESCE((SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = p_origen),
                    (SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = 'sistema')),
           COALESCE(@ahora_simulado, NOW()),
           CONCAT('Evaluación apta vencida sin agendar la cirugía: reembolsado $0 de $', v.monto, ' (retenida)'),
           NULL, 'pagos.PagoSena', v.id_pago, 'estado=pagada;reembolsado=0', 'estado=retenida;reembolsado=0', 1
      FROM tmp_evaluaciones_vencidas v
      JOIN auditoria.TipoEvento te ON te.nombre = 'retencion';
    INSERT INTO auditoria.Log (id_tipo_evento, id_usuario, id_paciente, id_origen, fecha_hora, descripcion,
                               ip_origen, tabla_afectada, id_registro_afectado, valor_anterior, valor_nuevo, exitoso)
    SELECT te.id_tipo_evento, NULL, NULL,
           COALESCE((SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = p_origen),
                    (SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = 'sistema')),
           COALESCE(@ahora_simulado, NOW()),
           CONCAT('La evaluación ', v.id_evaluacion, ' venció a los 6 meses'),
           NULL, 'clinica.EvaluacionPrevia', v.id_evaluacion, NULL, NULL, 1
      FROM tmp_evaluaciones_vencidas v
      JOIN auditoria.TipoEvento te ON te.nombre = 'evaluacion_vencida';
    DROP TEMPORARY TABLE IF EXISTS tmp_evaluaciones_vencidas;
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, CONCAT(v_cuenta, ' evaluaciones vencidas') AS mensaje, NULL AS id, v_cuenta AS valor, NULL AS dato;
END//

-- La paciente reclama una evaluación vencida: el instituto retiene el 50% de
-- la consulta y devuelve el resto. Solo se puede reclamar una vez.
DROP PROCEDURE IF EXISTS clinica.sp_reclamar_evaluacion//
CREATE PROCEDURE clinica.sp_reclamar_evaluacion(IN p_id_evaluacion INT, IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
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
        CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen, v_msg,
                                        'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';
    SELECT r.nombre, ev.id_turno, ev.fecha_resultado, ev.fecha_reclamo, t.id_paciente
      INTO v_res, v_turno, v_fecha_res, v_reclamo, v_paciente
      FROM clinica.EvaluacionPrevia ev
      JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
      JOIN agenda.Turno t ON t.id_turno = ev.id_turno
     WHERE ev.id_evaluacion = p_id_evaluacion;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La evaluación no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_res IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52130 FROM DUAL WHERE v_res IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Solo se reclama una evaluación apta' FROM DUAL WHERE v_codigo IS NULL AND (v_res <> 'apto')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52134 FROM DUAL WHERE v_res <> 'apto'));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La evaluación ya fue reclamada' FROM DUAL WHERE v_codigo IS NULL AND (v_reclamo IS NOT NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52135 FROM DUAL WHERE v_reclamo IS NOT NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La evaluación sigue vigente: todavía puede agendar la cirugía' FROM DUAL WHERE v_codigo IS NULL AND (v_fecha_res + INTERVAL 6 MONTH >= COALESCE(@ahora_simulado, NOW()))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52136 FROM DUAL WHERE v_fecha_res + INTERVAL 6 MONTH >= COALESCE(@ahora_simulado, NOW())));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La evaluación ya se usó para una cirugía' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = p_id_evaluacion AND t2.id_estado_turno <> v_cancelado))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52137 FROM DUAL WHERE EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = p_id_evaluacion AND t2.id_estado_turno <> v_cancelado)));

    UPDATE clinica.EvaluacionPrevia SET fecha_reclamo = COALESCE(@ahora_simulado, NOW()) WHERE id_evaluacion = p_id_evaluacion AND v_codigo IS NULL;
    SELECT ps.id_pago, ps.monto, ep.nombre INTO v_pago, v_monto, v_estado_pago
      FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = v_turno;
    -- Se devuelve la mitad de la seña de la consulta.
    SET v_devuelto = COALESCE((SELECT ROUND(v_monto * 0.5, 2) FROM DUAL
                                WHERE v_codigo IS NULL AND v_pago IS NOT NULL AND v_estado_pago IN ('pagada', 'retenida')), v_devuelto);
    CALL pagos.sp_aplicar_reembolso(v_pago, v_devuelto, 'reembolsada parcial', 'Reclamo de evaluación vencida: se retiene el 50%', p_id_usuario, p_origen,
                                    v_codigo IS NULL AND v_pago IS NOT NULL AND v_estado_pago IN ('pagada', 'retenida'));
    CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen,
        CONCAT('Reclamo de la evaluación ', p_id_evaluacion, ': se devuelven $', v_devuelto), 'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen, v_mensaje,
                                        'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Reclamo registrado' AS mensaje, p_id_evaluacion AS id, v_devuelto AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
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
    DECLARE v_cuenta INT DEFAULT 0;
    DECLARE v_canal INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_emitido', NULL, NULL, p_origen, v_msg,
                                        'beneficios.Cupon', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT COALESCE(MAX(id_cupon), 0) INTO v_max_antes FROM beneficios.Cupon;
    START TRANSACTION;
    -- Primero se arma la lista de cupones a emitir con un número de orden (n); el código y el
    -- secreto salen de ese número (el material no enseña UUID).
    DROP TEMPORARY TABLE IF EXISTS tmp_cupones_nuevos;
    CREATE TEMPORARY TABLE tmp_cupones_nuevos (
        n INT AUTO_INCREMENT PRIMARY KEY, id_regla INT, id_paciente INT, pct DECIMAL(5,2), vig INT);
    INSERT INTO tmp_cupones_nuevos (id_regla, id_paciente, pct, vig)
    SELECT cand.id_regla, cand.id_paciente, cand.pct, cand.vig
      FROM (
            -- frecuencia de visitas
            SELECT r.id_regla, p.id_paciente, r.porcentaje_descuento AS pct, r.vigencia_semanas AS vig
              FROM beneficios.ReglaBeneficio r
              JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla AND tr.nombre = 'frecuencia de visitas'
              JOIN personas.Paciente p ON p.id_usuario IS NOT NULL
             WHERE r.activa = 1
               AND (SELECT COUNT(*) FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre = 'realizado'
                     WHERE t.id_paciente = p.id_paciente
                       AND t.fecha_hora_inicio BETWEEN COALESCE(@ahora_simulado, NOW()) - INTERVAL r.ventana_dias DAY AND COALESCE(@ahora_simulado, NOW())) >= r.umbral
               AND NOT EXISTS (SELECT 1 FROM beneficios.Cupon c WHERE c.id_regla = r.id_regla AND c.id_paciente = p.id_paciente
                                  AND c.fecha_emision >= COALESCE(@ahora_simulado, NOW()) - INTERVAL r.ventana_dias DAY)
            UNION ALL
            -- gasto acumulado
            SELECT r.id_regla, g.id_paciente, r.porcentaje_descuento, r.vigencia_semanas
              FROM agenda.Numero nums
              JOIN beneficios.ReglaBeneficio r ON TRUE
              JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla AND tr.nombre = 'gasto acumulado'
              JOIN (SELECT t.id_paciente, SUM((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = t.id_turno), 0) / 100, 2))) AS gasto
                      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre = 'realizado'
                     GROUP BY t.id_paciente) g ON TRUE
              JOIN personas.Paciente p ON p.id_paciente = g.id_paciente AND p.id_usuario IS NOT NULL
             WHERE r.activa = 1
               AND nums.n BETWEEN 1 AND 30
               -- un cupón por cada múltiplo del umbral que la paciente ya superó y todavía no tiene
               AND nums.n > (SELECT COUNT(*) FROM beneficios.Cupon c WHERE c.id_regla = r.id_regla AND c.id_paciente = p.id_paciente)
               AND nums.n * r.umbral <= g.gasto
            UNION ALL
            -- promoción general: una vez por paciente con cuenta
            SELECT r.id_regla, p.id_paciente, r.porcentaje_descuento, r.vigencia_semanas
              FROM beneficios.ReglaBeneficio r
              JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla AND tr.nombre = 'promoción general'
              JOIN personas.Paciente p ON p.id_usuario IS NOT NULL
             WHERE r.activa = 1
               AND NOT EXISTS (SELECT 1 FROM beneficios.Cupon c WHERE c.id_regla = r.id_regla AND c.id_paciente = p.id_paciente)
           ) cand;

    INSERT INTO beneficios.Cupon (id_regla, id_paciente, codigo, secreto, porcentaje_descuento, fecha_emision, fecha_vencimiento)
    SELECT id_regla, id_paciente, CAST(100000 + v_max_antes + n AS CHAR), CAST((v_max_antes + n) * 7919 + id_regla * 104729 AS CHAR),
           pct, COALESCE(@ahora_simulado, NOW()), COALESCE(@ahora_simulado, NOW()) + INTERVAL vig WEEK
      FROM tmp_cupones_nuevos
     ORDER BY n;

    SELECT id_canal INTO v_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido';
    -- Aviso y log de cada cupón nuevo, todos juntos (sin cursor).
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, mensaje, fecha_programada)
    SELECT COALESCE((SELECT cn.id_canal FROM notificaciones.CanalNotificacion cn WHERE cn.nombre = 'Telegram' AND p.telegram_chat_id IS NOT NULL), v_canal),
           (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
           (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'cupón nuevo'),
           c.id_paciente, CONCAT('Tenés un cupón nuevo del ', ROUND(c.porcentaje_descuento, 0), '%: ', c.codigo, '.'), COALESCE(@ahora_simulado, NOW())
      FROM beneficios.Cupon c
      JOIN personas.Paciente p ON p.id_paciente = c.id_paciente
     WHERE c.id_cupon > v_max_antes;
    INSERT INTO auditoria.Log (id_tipo_evento, id_usuario, id_paciente, id_origen, fecha_hora, descripcion,
                               ip_origen, tabla_afectada, id_registro_afectado, valor_anterior, valor_nuevo, exitoso)
    SELECT te.id_tipo_evento, NULL, c.id_paciente,
           COALESCE((SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = p_origen),
                    (SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = 'sistema')),
           COALESCE(@ahora_simulado, NOW()), CONCAT('Cupón ', c.codigo, ' del ', c.porcentaje_descuento, '%'),
           NULL, 'beneficios.Cupon', c.id_cupon, NULL, NULL, 1
      FROM beneficios.Cupon c
      JOIN auditoria.TipoEvento te ON te.nombre = 'cupon_emitido'
     WHERE c.id_cupon > v_max_antes;
    SET v_cuenta = (SELECT COUNT(*) FROM beneficios.Cupon WHERE id_cupon > v_max_antes);
    DROP TEMPORARY TABLE IF EXISTS tmp_cupones_nuevos;
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, CONCAT(v_cuenta, ' cupones emitidos') AS mensaje, NULL AS id, v_cuenta AS valor, NULL AS dato;
END//

-- Pide el token vigente de un cupón (lo muestra la app o el QR de la paciente).
-- Devuelve: dato = token, valor = segundos que le quedan.
DROP PROCEDURE IF EXISTS beneficios.sp_generar_token_cupon//
CREATE PROCEDURE beneficios.sp_generar_token_cupon(IN p_codigo VARCHAR(50), IN p_id_paciente INT)
BEGIN
    -- Token = número del cupón * 7919 + número del tramo de 5 minutos actual (cambia cada 5 minutos).
    -- Tramo = AAAAMMDDHH * 12 + minutos DIV 5. "valor" = segundos que le quedan al tramo.
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_secreto VARCHAR(255);
    DECLARE v_pac INT;
    DECLARE v_turno INT;
    DECLARE v_venc DATETIME;
    DECLARE v_ahora DATETIME DEFAULT COALESCE(@ahora_simulado, NOW());
    DECLARE v_minuto INT;

    SET v_minuto = CAST(DATE_FORMAT(v_ahora, '%i') AS UNSIGNED);
    SELECT id_cupon, secreto, id_paciente, id_turno, fecha_vencimiento INTO v_id, v_secreto, v_pac, v_turno, v_venc
      FROM beneficios.Cupon WHERE codigo = p_codigo;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón no existe' FROM DUAL WHERE v_codigo IS NULL AND v_id IS NULL));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52140 FROM DUAL WHERE v_id IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón es de otra paciente' FROM DUAL WHERE v_codigo IS NULL AND p_id_paciente IS NOT NULL AND v_pac <> p_id_paciente));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52141 FROM DUAL WHERE p_id_paciente IS NOT NULL AND v_pac <> p_id_paciente));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón ya fue usado' FROM DUAL WHERE v_codigo IS NULL AND v_turno IS NOT NULL));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52142 FROM DUAL WHERE v_turno IS NOT NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón está vencido' FROM DUAL WHERE v_codigo IS NULL AND v_venc <= v_ahora));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52143 FROM DUAL WHERE v_venc <= v_ahora));

    SELECT 'OK' AS estado, 0 AS codigo, 'Token vigente por menos de 5 minutos' AS mensaje, v_id AS id,
           300 - ((v_minuto - 5 * (v_minuto DIV 5)) * 60 + CAST(DATE_FORMAT(v_ahora, '%s') AS UNSIGNED)) AS valor,
           CAST(v_id * 7919 + CAST(DATE_FORMAT(v_ahora, '%Y%m%d%H') AS UNSIGNED) * 12 + v_minuto DIV 5 AS CHAR) AS dato
      FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    -- Si el cupón existe pero no se puede usar, igual se devuelve su id (como antes).
    SELECT 'ERROR', v_codigo, v_mensaje, (SELECT v_id FROM DUAL WHERE v_codigo IN (52142, 52143)), NULL, NULL
      FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Valida un cupón con su token (RF-22). Acepta el tramo actual y el anterior
-- (margen por diferencia de relojes). Cada validación, aceptada o rechazada,
-- queda en el log. Devuelve: id = cupón, valor = % de descuento.
DROP PROCEDURE IF EXISTS beneficios.sp_validar_cupon//
CREATE PROCEDURE beneficios.sp_validar_cupon(
    IN p_codigo VARCHAR(50), IN p_token VARCHAR(20), IN p_id_paciente INT, IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    -- Acepta el token del tramo actual y el del anterior (margen por diferencia de relojes).
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_secreto VARCHAR(255);
    DECLARE v_pac INT;
    DECLARE v_turno INT;
    DECLARE v_venc DATETIME;
    DECLARE v_pct DECIMAL(5,2);
    DECLARE v_ahora DATETIME DEFAULT COALESCE(@ahora_simulado, NOW());
    DECLARE v_tramo BIGINT;

    SET v_tramo = CAST(DATE_FORMAT(v_ahora, '%Y%m%d%H') AS UNSIGNED) * 12 + CAST(DATE_FORMAT(v_ahora, '%i') AS UNSIGNED) DIV 5;
    SELECT id_cupon, secreto, id_paciente, id_turno, fecha_vencimiento, porcentaje_descuento
      INTO v_id, v_secreto, v_pac, v_turno, v_venc, v_pct
      FROM beneficios.Cupon WHERE codigo = p_codigo;

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón no existe' FROM DUAL WHERE v_codigo IS NULL AND v_id IS NULL));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52140 FROM DUAL WHERE v_id IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón es de otra paciente' FROM DUAL WHERE v_codigo IS NULL AND p_id_paciente IS NOT NULL AND v_pac <> p_id_paciente));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52141 FROM DUAL WHERE p_id_paciente IS NOT NULL AND v_pac <> p_id_paciente));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón ya fue usado' FROM DUAL WHERE v_codigo IS NULL AND v_turno IS NOT NULL));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52142 FROM DUAL WHERE v_turno IS NOT NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón está vencido' FROM DUAL WHERE v_codigo IS NULL AND v_venc <= v_ahora));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52143 FROM DUAL WHERE v_venc <= v_ahora));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El token es inválido o ya venció' FROM DUAL WHERE v_codigo IS NULL
                                         AND (p_token IS NULL OR p_token NOT IN (CAST(v_id * 7919 + v_tramo AS CHAR),
                                                                                 CAST(v_id * 7919 + v_tramo - 1 AS CHAR)))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52144 FROM DUAL WHERE p_token IS NULL OR p_token NOT IN (CAST(v_id * 7919 + v_tramo AS CHAR),
                                                                                                        CAST(v_id * 7919 + v_tramo - 1 AS CHAR))));

    -- Cada validación, aceptada o rechazada, queda en el log.
    CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_pac, p_origen, v_mensaje, 'beneficios.Cupon', v_id, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    CALL auditoria.sp_registrar_log('cupon_validado', p_id_usuario, v_pac, p_origen, 'Cupón validado con su token', 'beneficios.Cupon', v_id, NULL, NULL, 1, NULL, v_codigo IS NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Cupón válido' AS mensaje, v_id AS id, v_pct AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, v_id, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Aplica un cupón a un turno pendiente escaneando su QR antes del pago (RF-22).
DROP PROCEDURE IF EXISTS beneficios.sp_aplicar_cupon_a_turno//
CREATE PROCEDURE beneficios.sp_aplicar_cupon_a_turno(
    IN p_id_turno INT, IN p_codigo VARCHAR(50), IN p_token VARCHAR(20), IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_paciente INT;
    DECLARE v_estado VARCHAR(50);
    DECLARE v_cupon INT DEFAULT NULL;
    DECLARE v_secreto VARCHAR(255);
    DECLARE v_pac_cupon INT;
    DECLARE v_turno_cupon INT;
    DECLARE v_venc DATETIME;
    DECLARE v_tramo BIGINT DEFAULT (CAST(DATE_FORMAT(COALESCE(@ahora_simulado, NOW()), '%Y%m%d%H') AS UNSIGNED) * 12 + CAST(DATE_FORMAT(COALESCE(@ahora_simulado, NOW()), '%i') AS UNSIGNED) DIV 5);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, v_msg,
                                        'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT e.nombre, t.id_paciente INTO v_estado, v_paciente
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_estado IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52120 FROM DUAL WHERE v_estado IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón se aplica antes de pagar la seña (turno pendiente)' FROM DUAL WHERE v_codigo IS NULL AND (v_estado <> 'pendiente')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52145 FROM DUAL WHERE v_estado <> 'pendiente'));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno ya tiene un cupón' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM beneficios.Cupon WHERE id_turno = p_id_turno))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52146 FROM DUAL WHERE EXISTS (SELECT 1 FROM beneficios.Cupon WHERE id_turno = p_id_turno)));
    SELECT id_cupon, secreto, id_paciente, id_turno, fecha_vencimiento INTO v_cupon, v_secreto, v_pac_cupon, v_turno_cupon, v_venc
      FROM beneficios.Cupon WHERE codigo = p_codigo;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_cupon IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52140 FROM DUAL WHERE v_cupon IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón es de otra paciente' FROM DUAL WHERE v_codigo IS NULL AND (v_pac_cupon <> v_paciente)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52141 FROM DUAL WHERE v_pac_cupon <> v_paciente));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón ya fue usado' FROM DUAL WHERE v_codigo IS NULL AND (v_turno_cupon IS NOT NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52142 FROM DUAL WHERE v_turno_cupon IS NOT NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón está vencido' FROM DUAL WHERE v_codigo IS NULL AND (v_venc <= COALESCE(@ahora_simulado, NOW()))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52143 FROM DUAL WHERE v_venc <= COALESCE(@ahora_simulado, NOW())));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El token es inválido o ya venció' FROM DUAL WHERE v_codigo IS NULL AND (p_token IS NULL OR p_token NOT IN (CAST(v_cupon * 7919 + v_tramo AS CHAR), CAST(v_cupon * 7919 + v_tramo - 1 AS CHAR)))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52144 FROM DUAL WHERE p_token IS NULL OR p_token NOT IN (CAST(v_cupon * 7919 + v_tramo AS CHAR), CAST(v_cupon * 7919 + v_tramo - 1 AS CHAR))));

    START TRANSACTION;
    UPDATE beneficios.Cupon SET id_turno = p_id_turno WHERE id_cupon = v_cupon AND v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('cupon_validado', p_id_usuario, v_paciente, p_origen,
        CONCAT('Cupón ', p_codigo, ' aplicado al turno ', p_id_turno, ' con QR'), 'beneficios.Cupon', v_cupon, NULL, NULL, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, v_mensaje,
                                        'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Cupón aplicado' AS mensaje, v_cupon AS id,
           ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = p_id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = p_id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = p_id_turno), 0) / 100, 2)) * COALESCE((SELECT MAX(caz.porcentaje_sena) FROM agenda.TurnoProtocolo tpy JOIN clinica.Protocolo prz ON prz.id_protocolo = tpy.id_protocolo JOIN clinica.CategoriaProtocolo caz ON caz.id_categoria = prz.id_categoria WHERE tpy.id_turno = p_id_turno), 0) / 100, 0) AS valor, CAST((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = p_id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = p_id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = p_id_turno), 0) / 100, 2)) AS CHAR) AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//


-- =====================================================================
--  TARJETAS DE REGALO (RF-23)
-- =====================================================================

-- Vende una tarjeta de regalo (código largo y aleatorio, vigencia de 12 meses).
-- Devuelve: id = tarjeta, valor = monto, dato = código de la tarjeta.
DROP PROCEDURE IF EXISTS pagos.sp_comprar_tarjeta//
CREATE PROCEDURE pagos.sp_comprar_tarjeta(
    IN p_monto DECIMAL(12,2), IN p_medio_pago VARCHAR(50), IN p_comprador_nombre VARCHAR(100),
    IN p_comprador_telefono VARCHAR(30), IN p_id_usuario INT, IN p_origen VARCHAR(50), IN p_codigo VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_medio INT DEFAULT NULL;
    DECLARE v_codigo_tarjeta VARCHAR(50);
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen, v_msg,
                                        'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    -- Un dato opcional vacío ('') se toma como no informado (NULL).
    SET p_comprador_telefono = (SELECT p_comprador_telefono FROM DUAL WHERE p_comprador_telefono <> '');

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El monto de la tarjeta debe estar entre $20.000 y $5.000.000' FROM DUAL WHERE v_codigo IS NULL AND (p_monto IS NULL OR p_monto < 20000 OR p_monto > 5000000)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52150 FROM DUAL WHERE p_monto IS NULL OR p_monto < 20000 OR p_monto > 5000000));
    SELECT id_medio_pago INTO v_medio FROM pagos.MedioPago WHERE nombre = p_medio_pago;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Medio de pago inválido (una tarjeta de regalo no se paga con otra)' FROM DUAL WHERE v_codigo IS NULL AND (v_medio IS NULL OR p_medio_pago = 'tarjeta de regalo')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52151 FROM DUAL WHERE v_medio IS NULL OR p_medio_pago = 'tarjeta de regalo'));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Falta el nombre de quien compra' FROM DUAL WHERE v_codigo IS NULL AND (p_comprador_nombre IS NULL OR CHAR_LENGTH(p_comprador_nombre) < 2)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52152 FROM DUAL WHERE p_comprador_nombre IS NULL OR CHAR_LENGTH(p_comprador_nombre) < 2));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El teléfono debe tener de 10 a 13 dígitos' FROM DUAL WHERE v_codigo IS NULL AND (p_comprador_telefono IS NOT NULL AND p_comprador_telefono <> '' AND (CHAR_LENGTH(p_comprador_telefono) BETWEEN 10 AND 13 AND CAST(CAST(p_comprador_telefono AS UNSIGNED) AS CHAR) = p_comprador_telefono) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52032 FROM DUAL WHERE p_comprador_telefono IS NOT NULL AND p_comprador_telefono <> '' AND (CHAR_LENGTH(p_comprador_telefono) BETWEEN 10 AND 13 AND CAST(CAST(p_comprador_telefono AS UNSIGNED) AS CHAR) = p_comprador_telefono) = 0));

    START TRANSACTION;
    -- El código lo genera la aplicación y llega en p_codigo. Si no llega, se numera.
    SELECT COALESCE((SELECT p_codigo FROM DUAL WHERE p_codigo <> ''), CAST(1000000 + COALESCE(MAX(id_tarjeta), 0) + 1 AS CHAR)) INTO v_codigo_tarjeta FROM pagos.TarjetaRegalo;
    INSERT INTO pagos.TarjetaRegalo (id_medio_pago, codigo, monto_inicial, fecha_compra, fecha_vencimiento, comprador_nombre, comprador_telefono)
    SELECT v_medio, v_codigo_tarjeta, p_monto, COALESCE(@ahora_simulado, NOW()), COALESCE(@ahora_simulado, NOW()) + INTERVAL 12 MONTH, p_comprador_nombre, (SELECT p_comprador_telefono FROM DUAL WHERE p_comprador_telefono <> '') FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_tarjeta) INTO v_id FROM pagos.TarjetaRegalo WHERE codigo = v_codigo_tarjeta;
    CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen,
        CONCAT('Tarjeta de regalo de $', p_monto, ' comprada por ', p_comprador_nombre), 'pagos.TarjetaRegalo', v_id, NULL, CONCAT('monto=', p_monto), 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Tarjeta emitida' AS mensaje, v_id AS id, p_monto AS valor, v_codigo_tarjeta AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Saldo y vigencia de una tarjeta. Un código inexistente queda en el log
-- (intentos fallidos, modelo grupo 3 decisión 9) y no devuelve filas.
DROP PROCEDURE IF EXISTS pagos.sp_saldo_tarjeta//
CREATE PROCEDURE pagos.sp_saldo_tarjeta(IN p_codigo VARCHAR(50), IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_id INT DEFAULT NULL;
    SELECT id_tarjeta INTO v_id FROM pagos.TarjetaRegalo WHERE codigo = p_codigo;
    -- Una consulta con un código que no existe queda en el log.
    CALL auditoria.sp_registrar_log('tarjeta_rechazada', p_id_usuario, NULL, p_origen, 'Consulta de saldo con código inexistente',
                                    'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL, v_id IS NULL AND p_codigo IS NOT NULL AND p_codigo <> '');
    SELECT t.id_tarjeta, t.codigo, t.monto_inicial,
           COALESCE((SELECT SUM(m.monto) FROM pagos.MovimientoTarjeta m WHERE m.id_tarjeta = t.id_tarjeta), 0) AS gastado,
           t.monto_inicial - COALESCE((SELECT SUM(m.monto) FROM pagos.MovimientoTarjeta m WHERE m.id_tarjeta = t.id_tarjeta), 0) AS saldo,
           t.fecha_vencimiento, (t.fecha_vencimiento > COALESCE(@ahora_simulado, NOW())) AS vigente
      FROM pagos.TarjetaRegalo t WHERE t.id_tarjeta = v_id;
END//

-- Historial de una tarjeta de regalo: cada gasto (monto positivo) y cada
-- devolución (negativo), con el turno y la paciente. Código inexistente,
-- NULL o vacío: 0 filas.
DROP PROCEDURE IF EXISTS pagos.sp_movimientos_tarjeta//
CREATE PROCEDURE pagos.sp_movimientos_tarjeta(IN p_codigo VARCHAR(50))
BEGIN
    SELECT m.id_movimiento, m.fecha_movimiento, m.monto, COALESCE((SELECT 'gasto' FROM DUAL WHERE m.monto > 0), 'devolución') AS tipo,
           m.id_turno, p.apellido AS paciente, p.nombre AS paciente_nombre
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
    -- Sin límite (o fuera de 1 a 500) trae de a 50. LIMIT es el equivalente en MySQL del TOP de la cátedra.
    DECLARE v_limite INT DEFAULT 50;
    SET v_limite = COALESCE((SELECT p_limite FROM DUAL WHERE p_limite BETWEEN 1 AND 500), 50);
    SELECT n.id_notificacion, c.nombre AS canal, tn.nombre AS tipo, n.mensaje, n.fecha_programada, n.intentos, n.id_turno,
           COALESCE(p.apellido, pr.apellido) AS destinatario, COALESCE(p.nombre, pr.nombre) AS destinatario_nombre,
           p.telegram_chat_id,
           COALESCE((SELECT tp.telefono FROM personas.TelefonoPaciente tp WHERE tp.id_telefono_paciente = (SELECT MIN(tpx.id_telefono_paciente) FROM personas.TelefonoPaciente tpx WHERE tpx.id_paciente = p.id_paciente)),
                    (SELECT tf.telefono FROM personas.TelefonoProfesional tf WHERE tf.id_telefono_profesional = (SELECT MIN(tfx.id_telefono_profesional) FROM personas.TelefonoProfesional tfx WHERE tfx.id_profesional = pr.id_profesional))) AS telefono,
           COALESCE(p.email, pr.email) AS email
      FROM notificaciones.Notificacion n
      JOIN notificaciones.EstadoNotificacion en ON en.id_estado_notificacion = n.id_estado_notificacion AND en.nombre = 'pendiente'
      JOIN notificaciones.CanalNotificacion c ON c.id_canal = n.id_canal
      JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion
      LEFT JOIN personas.Paciente p ON p.id_paciente = n.id_paciente
      LEFT JOIN personas.Profesional pr ON pr.id_profesional = n.id_profesional
     WHERE n.fecha_programada <= COALESCE(@ahora_simulado, NOW())
     ORDER BY n.fecha_programada, n.id_notificacion
     LIMIT v_limite;
END//

-- n8n informa cómo salió el envío. Un fallo se reintenta hasta 3 veces; recién
-- al tercero queda 'fallida'.
DROP PROCEDURE IF EXISTS notificaciones.sp_marcar_notificacion//
CREATE PROCEDURE notificaciones.sp_marcar_notificacion(IN p_id_notificacion INT, IN p_resultado VARCHAR(20), IN p_detalle VARCHAR(500))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_estado VARCHAR(50);
    DECLARE v_intentos INT;
    DECLARE v_paciente INT;
    DECLARE v_nuevo VARCHAR(50);

    SELECT en.nombre, n.intentos, n.id_paciente INTO v_estado, v_intentos, v_paciente
      FROM notificaciones.Notificacion n JOIN notificaciones.EstadoNotificacion en ON en.id_estado_notificacion = n.id_estado_notificacion
     WHERE n.id_notificacion = p_id_notificacion;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La notificación no existe' FROM DUAL WHERE v_codigo IS NULL AND v_estado IS NULL));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52160 FROM DUAL WHERE v_estado IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La notificación ya no está pendiente' FROM DUAL WHERE v_codigo IS NULL AND v_estado <> 'pendiente'));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52161 FROM DUAL WHERE v_estado <> 'pendiente'));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El resultado debe ser enviada o fallida' FROM DUAL WHERE v_codigo IS NULL AND (p_resultado IS NULL OR p_resultado NOT IN ('enviada', 'fallida'))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52162 FROM DUAL WHERE p_resultado IS NULL OR p_resultado NOT IN ('enviada', 'fallida')));

    -- Enviada: queda enviada. Fallida: vuelve a pendiente para reintentar, salvo al tercer intento.
    SET v_nuevo = COALESCE((SELECT 'enviada' FROM DUAL WHERE p_resultado = 'enviada'),
                           (SELECT 'fallida' FROM DUAL WHERE v_intentos + 1 >= 3), 'pendiente');
    UPDATE notificaciones.Notificacion
       SET id_estado_notificacion = (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = v_nuevo),
           intentos = intentos + 1,
           fecha_envio = COALESCE((SELECT COALESCE(@ahora_simulado, NOW()) FROM DUAL WHERE p_resultado = 'enviada'), fecha_envio),
           detalle_error = (SELECT CAST(p_detalle AS CHAR(500)) FROM DUAL WHERE p_resultado = 'fallida')
     WHERE id_notificacion = p_id_notificacion AND v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('notificacion_enviada', NULL, v_paciente, 'sistema',
        CONCAT('Notificación ', p_id_notificacion, ': ', p_resultado, ' (intento ', v_intentos + 1, ')'),
        'notificaciones.Notificacion', p_id_notificacion, v_estado, v_nuevo, (p_resultado = 'enviada'), NULL, v_codigo IS NULL);
    SELECT 'OK' AS estado, 0 AS codigo, CONCAT('Notificación ', v_nuevo) AS mensaje, p_id_notificacion AS id, v_intentos + 1 AS valor, v_nuevo AS dato
      FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, (SELECT p_id_notificacion FROM DUAL WHERE v_codigo <> 52160), NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//


-- =====================================================================
--  ASISTENTE DE IA (RF-07, RF-14, RNF-06, RNF-10)
-- =====================================================================

-- Registra una pregunta al asistente y su respuesta. p_derivada = 1 cuando no
-- supo responder y se derivó al WhatsApp del instituto.
DROP PROCEDURE IF EXISTS asistente.sp_registrar_consulta//
CREATE PROCEDURE asistente.sp_registrar_consulta(
    IN p_id_paciente INT, IN p_origen VARCHAR(50), IN p_pregunta TEXT, IN p_respuesta TEXT,
    IN p_derivada SMALLINT, IN p_id_usuario INT)
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_origen INT DEFAULT NULL;
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen, v_msg,
                                        'asistente.ConsultaAsistente', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT id_origen INTO v_origen FROM agenda.Origen WHERE nombre = p_origen;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Origen inválido (terminal, web, gestion o sistema)' FROM DUAL WHERE v_codigo IS NULL AND (v_origen IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52070 FROM DUAL WHERE v_origen IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La pregunta está vacía' FROM DUAL WHERE v_codigo IS NULL AND (p_pregunta IS NULL OR CHAR_LENGTH(p_pregunta) < 3)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52170 FROM DUAL WHERE p_pregunta IS NULL OR CHAR_LENGTH(p_pregunta) < 3));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La paciente no existe' FROM DUAL WHERE v_codigo IS NULL AND (p_id_paciente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM personas.Paciente WHERE id_paciente = p_id_paciente))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52071 FROM DUAL WHERE p_id_paciente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM personas.Paciente WHERE id_paciente = p_id_paciente)));

    START TRANSACTION;
    INSERT INTO asistente.ConsultaAsistente (id_paciente, id_origen, pregunta, fecha_hora, derivada, respuesta)
    SELECT p_id_paciente, v_origen, p_pregunta, COALESCE(@ahora_simulado, NOW()),
            COALESCE(p_derivada, 0), p_respuesta FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_consulta) INTO v_id FROM asistente.ConsultaAsistente;
    CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen,
        COALESCE((SELECT 'Consulta derivada al WhatsApp del instituto' FROM DUAL WHERE COALESCE(p_derivada, 0) = 1), 'Consulta respondida por el asistente'),
        'asistente.ConsultaAsistente', v_id, NULL, NULL, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen, v_mensaje,
                                        'asistente.ConsultaAsistente', NULL, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Consulta registrada' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

DELIMITER ;
