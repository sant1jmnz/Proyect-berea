-- =====================================================================
--  BOT DE TELEGRAM (RF-11): vincular el Telegram de la paciente
-- =====================================================================
-- La base ya tenía la columna personas.Paciente.telegram_chat_id y los SP que
-- eligen Telegram como canal cuando la paciente lo tiene vinculado, pero nada la
-- llenaba. Estos SP los usa el bot (web/api/telegram.js o el flujo de n8n):
--   /start en el bot -> la paciente escribe su DNI y su teléfono -> sp_vincular_telegram
--   /salir           -> sp_desvincular_telegram
--   /turnos          -> sp_paciente_por_telegram + agenda.sp_buscar_turnos
--   cada minuto      -> sp_notificaciones_telegram + sp_marcar_notificacion
-- Se carga después de 04_sp_semana4.sql. Mismas convenciones que el resto:
-- validación con IF y código 529xx, log solo desde el SP, 6 columnas de respuesta.

DELIMITER //

-- Vincula un chat de Telegram con la paciente que tiene ese DNI y ese teléfono
-- (el teléfono es la prueba de que es ella: el DNI solo no alcanza). Los avisos
-- pendientes de sus turnos futuros pasan a salir por Telegram.
DROP PROCEDURE IF EXISTS personas.sp_vincular_telegram//
CREATE PROCEDURE personas.sp_vincular_telegram(IN p_dni VARCHAR(15), IN p_telefono VARCHAR(20), IN p_chat_id VARCHAR(50), IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_paciente INT DEFAULT NULL;
    DECLARE v_otra INT DEFAULT NULL;
    DECLARE v_anterior VARCHAR(50) DEFAULT NULL;
    DECLARE v_nombre VARCHAR(50) DEFAULT NULL;
    DECLARE v_pasados INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' AS estado, 52939 AS codigo, 'No se pudo vincular el Telegram' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF v_codigo IS NULL AND (p_dni IS NULL OR p_dni = '' OR p_telefono IS NULL OR p_telefono = '' OR p_chat_id IS NULL OR p_chat_id = '') THEN
        SET v_codigo = 52930;
        SET v_mensaje = 'Faltan el DNI, el teléfono o el chat de Telegram';
    END IF;
    IF v_codigo IS NULL THEN
        SELECT id_paciente, telegram_chat_id, nombre INTO v_paciente, v_anterior, v_nombre
          FROM personas.Paciente WHERE dni = p_dni;
        IF v_paciente IS NULL THEN
            SET v_codigo = 52931;
            SET v_mensaje = 'No hay ninguna paciente con ese DNI';
        END IF;
    END IF;
    IF v_codigo IS NULL AND NOT EXISTS (SELECT 1 FROM personas.TelefonoPaciente WHERE id_paciente = v_paciente AND telefono = p_telefono) THEN
        SET v_codigo = 52932;
        SET v_mensaje = 'El teléfono no coincide con el que dejaste al reservar';
    END IF;
    IF v_codigo IS NULL THEN
        SELECT id_paciente INTO v_otra FROM personas.Paciente WHERE telegram_chat_id = p_chat_id AND id_paciente <> v_paciente LIMIT 1;
        IF v_otra IS NOT NULL THEN
            SET v_codigo = 52933;
            SET v_mensaje = 'Ese Telegram ya está vinculado con otra paciente: primero escribí /salir';
        END IF;
    END IF;

    IF v_codigo IS NULL THEN
        START TRANSACTION;
        UPDATE personas.Paciente SET telegram_chat_id = p_chat_id WHERE id_paciente = v_paciente;
        -- los avisos que todavía no salieron, de turnos que no pasaron, ahora van por Telegram
        UPDATE notificaciones.Notificacion
           SET id_canal = (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'Telegram')
         WHERE id_paciente = v_paciente
           AND id_estado_notificacion = (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente')
           AND id_canal IN (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre IN ('WhatsApp', 'WhatsApp asistido'))
           AND fecha_programada >= COALESCE(@ahora_simulado, NOW());
        SET v_pasados = ROW_COUNT();
        CALL auditoria.sp_registrar_log('modificacion_paciente', NULL, v_paciente, COALESCE(p_origen, 'sistema'),
            CONCAT('Telegram vinculado; avisos que pasan a Telegram: ', v_pasados),
            'personas.Paciente', v_paciente, v_anterior, p_chat_id, 1, NULL);
        COMMIT;
        SELECT 'OK' AS estado, 0 AS codigo, 'Telegram vinculado' AS mensaje, v_paciente AS id, v_pasados AS valor, v_nombre AS dato;
    ELSE
        SELECT 'ERROR' AS estado, v_codigo AS codigo, v_mensaje AS mensaje, v_paciente AS id, NULL AS valor, NULL AS dato;
    END IF;
END//

-- Desvincula el chat (comando /salir): los avisos pendientes vuelven a la recepción (WhatsApp asistido).
DROP PROCEDURE IF EXISTS personas.sp_desvincular_telegram//
CREATE PROCEDURE personas.sp_desvincular_telegram(IN p_chat_id VARCHAR(50), IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_paciente INT DEFAULT NULL;
    DECLARE v_pasados INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' AS estado, 52939 AS codigo, 'No se pudo desvincular el Telegram' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT id_paciente INTO v_paciente FROM personas.Paciente WHERE telegram_chat_id = p_chat_id LIMIT 1;
    IF v_paciente IS NULL THEN
        SELECT 'ERROR' AS estado, 52934 AS codigo, 'Este Telegram no está vinculado con ninguna paciente' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    ELSE
        START TRANSACTION;
        UPDATE personas.Paciente SET telegram_chat_id = NULL WHERE id_paciente = v_paciente;
        UPDATE notificaciones.Notificacion
           SET id_canal = (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido')
         WHERE id_paciente = v_paciente
           AND id_estado_notificacion = (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente')
           AND id_canal = (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'Telegram');
        SET v_pasados = ROW_COUNT();
        CALL auditoria.sp_registrar_log('modificacion_paciente', NULL, v_paciente, COALESCE(p_origen, 'sistema'),
            CONCAT('Telegram desvinculado; avisos que vuelven a la recepción: ', v_pasados),
            'personas.Paciente', v_paciente, p_chat_id, NULL, 1, NULL);
        COMMIT;
        SELECT 'OK' AS estado, 0 AS codigo, 'Telegram desvinculado' AS mensaje, v_paciente AS id, v_pasados AS valor, NULL AS dato;
    END IF;
END//

-- Qué paciente tiene vinculado ese chat (para el comando /turnos). Sin coincidencias: 0 filas.
DROP PROCEDURE IF EXISTS personas.sp_paciente_por_telegram//
CREATE PROCEDURE personas.sp_paciente_por_telegram(IN p_chat_id VARCHAR(50))
BEGIN
    SELECT id_paciente, dni, nombre, apellido
      FROM personas.Paciente
     WHERE telegram_chat_id = p_chat_id;
END//

-- Avisos pendientes que salen por Telegram, los más viejos primero. Es como
-- notificaciones.sp_notificaciones_pendientes pero solo de este canal: así los avisos de
-- "WhatsApp asistido" que la recepción todavía no marcó no tapan a los de Telegram.
DROP PROCEDURE IF EXISTS notificaciones.sp_notificaciones_telegram//
CREATE PROCEDURE notificaciones.sp_notificaciones_telegram(IN p_limite INT)
BEGIN
    DECLARE v_limite INT DEFAULT 50;
    IF p_limite BETWEEN 1 AND 500 THEN
        SET v_limite = p_limite;
    END IF;
    SELECT n.id_notificacion, tn.nombre AS tipo, n.mensaje, n.fecha_programada, n.intentos, n.id_turno,
           p.nombre AS destinatario_nombre, p.telegram_chat_id
      FROM notificaciones.Notificacion n
      JOIN notificaciones.EstadoNotificacion en ON en.id_estado_notificacion = n.id_estado_notificacion AND en.nombre = 'pendiente'
      JOIN notificaciones.CanalNotificacion c ON c.id_canal = n.id_canal AND c.nombre = 'Telegram'
      JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion
      JOIN personas.Paciente p ON p.id_paciente = n.id_paciente
     WHERE n.fecha_programada <= COALESCE(@ahora_simulado, NOW())
     ORDER BY n.fecha_programada, n.id_notificacion
     LIMIT v_limite;
END//

DELIMITER ;
