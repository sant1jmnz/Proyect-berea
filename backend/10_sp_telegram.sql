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
-- Se carga después de 04_sp_sena_cancelar.sql. Mismas convenciones que el resto:
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

-- Avisa a la paciente que su turno cargado sin conexión se perdió: mientras la terminal o
-- Gestión estaban offline, ese horario lo tomó otra persona. El mensaje trae los horarios que
-- sí quedaban libres esa semana (los arma la app con agenda.sp_horarios_libres) para que reagende.
-- Sale por Telegram si la paciente lo vinculó; si no, queda como aviso de "WhatsApp asistido"
-- y lo ve la recepción en Avisos. Códigos 52180-52182 y 52189.
DROP PROCEDURE IF EXISTS notificaciones.sp_avisar_turno_perdido//
CREATE PROCEDURE notificaciones.sp_avisar_turno_perdido(IN p_id_paciente INT, IN p_inicio DATETIME, IN p_protocolo VARCHAR(100), IN p_opciones VARCHAR(600), IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_canal INT DEFAULT NULL;
    DECLARE v_telegram VARCHAR(50) DEFAULT NULL;
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_texto VARCHAR(1000);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' AS estado, 52189 AS codigo, 'No se pudo dejar el aviso' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_id_paciente IS NULL OR p_inicio IS NULL OR p_protocolo IS NULL OR p_protocolo = '' THEN
        SET v_codigo = 52180;
        SET v_mensaje = 'Faltan la paciente, el horario o el tratamiento';
    END IF;
    IF v_codigo IS NULL AND NOT EXISTS (SELECT 1 FROM personas.Paciente WHERE id_paciente = p_id_paciente) THEN
        SET v_codigo = 52181;
        SET v_mensaje = 'La paciente no existe';
    END IF;

    IF v_codigo IS NULL THEN
        SELECT telegram_chat_id INTO v_telegram FROM personas.Paciente WHERE id_paciente = p_id_paciente;
        SET v_canal = (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = IF(v_telegram IS NULL, 'WhatsApp asistido', 'Telegram'));
        SET v_texto = CONCAT('Tu turno de ', p_protocolo, ' del ', DATE_FORMAT(p_inicio, '%d/%m'), ' a las ', DATE_FORMAT(p_inicio, '%H:%i'),
                             ' no se pudo confirmar: ese horario se ocupó mientras el sistema estaba sin conexión. ',
                             IF(p_opciones IS NULL OR p_opciones = '', 'Escribinos o entrá al sitio para elegir otro horario.',
                                CONCAT('Esta semana quedan libres: ', p_opciones, '. Elegí uno desde el sitio, la terminal o escribinos.')));
        START TRANSACTION;
        INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, mensaje, fecha_programada)
        VALUES (v_canal,
                (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
                (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'turno perdido'),
                p_id_paciente, v_texto, COALESCE(@ahora_simulado, NOW()));
        SET v_id = LAST_INSERT_ID();
        CALL auditoria.sp_registrar_log('modificacion_paciente', NULL, p_id_paciente, COALESCE(p_origen, 'sistema'),
            CONCAT('Aviso de turno perdido por sincronización (', DATE_FORMAT(p_inicio, '%d/%m %H:%i'), ')'),
            'notificaciones.Notificacion', v_id, NULL, NULL, 1, NULL);
        COMMIT;
        SELECT 'OK' AS estado, 0 AS codigo, 'Aviso dejado' AS mensaje, v_id AS id, NULL AS valor, IF(v_telegram IS NULL, 'WhatsApp asistido', 'Telegram') AS dato;
    ELSE
        SELECT 'ERROR' AS estado, v_codigo AS codigo, v_mensaje AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END IF;
END//

-- =====================================================================
--  MEMORIA DEL BOT (en Vercel cada mensaje puede caer en otra instancia, así que la
--  charla y el paso del /start se guardan acá y no en la memoria del programa)
-- =====================================================================
-- Tablas aparte de las del modelo: son estado de la conversación, no datos del negocio.
-- Por eso los SP de abajo no escriben en el log de auditoría (un renglón por mensaje sería ruido).

DELIMITER ;

CREATE TABLE IF NOT EXISTS asistente.MensajeTelegram (
    id_mensaje INT AUTO_INCREMENT PRIMARY KEY,
    chat VARCHAR(50) NOT NULL,
    rol VARCHAR(10) NOT NULL CHECK (rol IN ('usuario', 'asistente')),
    texto TEXT NOT NULL,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX IX_MensajeTelegram_Chat (chat, id_mensaje)
);

CREATE TABLE IF NOT EXISTS asistente.EstadoTelegram (
    chat VARCHAR(50) PRIMARY KEY,
    paso VARCHAR(10) NOT NULL CHECK (paso IN ('dni', 'telefono')),
    dni VARCHAR(15) NULL,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

-- Los últimos mensajes del chat, del más viejo al más nuevo, para pasárselos a Gemini.
-- Solo mira los de las últimas 6 horas: una charla vieja no es contexto de la pregunta de hoy.
DROP PROCEDURE IF EXISTS asistente.sp_historial_telegram//
CREATE PROCEDURE asistente.sp_historial_telegram(IN p_chat VARCHAR(50), IN p_cantidad INT)
BEGIN
    DECLARE v_cantidad INT DEFAULT COALESCE(p_cantidad, 6);
    SELECT rol, texto
      FROM (SELECT id_mensaje, rol, texto FROM asistente.MensajeTelegram
             WHERE chat = p_chat AND fecha_hora >= NOW() - INTERVAL 6 HOUR
             ORDER BY id_mensaje DESC
             LIMIT v_cantidad) ultimos
     ORDER BY id_mensaje;
END//

-- Guarda una pregunta y su respuesta y deja solo los últimos 20 mensajes del chat.
DROP PROCEDURE IF EXISTS asistente.sp_guardar_mensajes_telegram//
CREATE PROCEDURE asistente.sp_guardar_mensajes_telegram(IN p_chat VARCHAR(50), IN p_pregunta TEXT, IN p_respuesta TEXT)
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_corte INT DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' AS estado, 52949 AS codigo, 'No se pudo guardar la charla' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_chat IS NULL OR p_chat = '' OR p_pregunta IS NULL OR p_pregunta = '' OR p_respuesta IS NULL OR p_respuesta = '' THEN
        SET v_codigo = 52940;
        SET v_mensaje = 'Faltan el chat, la pregunta o la respuesta';
    END IF;

    IF v_codigo IS NULL THEN
        START TRANSACTION;
        INSERT INTO asistente.MensajeTelegram (chat, rol, texto) VALUES (p_chat, 'usuario', LEFT(p_pregunta, 600));
        INSERT INTO asistente.MensajeTelegram (chat, rol, texto) VALUES (p_chat, 'asistente', LEFT(p_respuesta, 600));
        SELECT MIN(id_mensaje) INTO v_corte
          FROM (SELECT id_mensaje FROM asistente.MensajeTelegram WHERE chat = p_chat ORDER BY id_mensaje DESC LIMIT 20) ultimos;
        DELETE FROM asistente.MensajeTelegram WHERE chat = p_chat AND id_mensaje < v_corte;
        COMMIT;
        SELECT 'OK' AS estado, 0 AS codigo, 'Charla guardada' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    ELSE
        SELECT 'ERROR' AS estado, v_codigo AS codigo, v_mensaje AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END IF;
END//

-- Borra la charla guardada de un chat (comando /limpiar). Devuelve en valor cuántos mensajes borró.
DROP PROCEDURE IF EXISTS asistente.sp_limpiar_historial_telegram//
CREATE PROCEDURE asistente.sp_limpiar_historial_telegram(IN p_chat VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_borrados INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' AS estado, 52959 AS codigo, 'No se pudo limpiar la charla' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_chat IS NULL OR p_chat = '' THEN
        SET v_codigo = 52950;
        SET v_mensaje = 'Falta el chat';
    END IF;

    IF v_codigo IS NULL THEN
        START TRANSACTION;
        DELETE FROM asistente.MensajeTelegram WHERE chat = p_chat;
        SET v_borrados = ROW_COUNT();
        COMMIT;
        SELECT 'OK' AS estado, 0 AS codigo, 'Charla borrada' AS mensaje, NULL AS id, v_borrados AS valor, NULL AS dato;
    ELSE
        SELECT 'ERROR' AS estado, v_codigo AS codigo, v_mensaje AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END IF;
END//

-- En qué paso del /start está el chat (dni o telefono) y el DNI ya escrito. Vence a los 30 minutos.
DROP PROCEDURE IF EXISTS asistente.sp_estado_telegram//
CREATE PROCEDURE asistente.sp_estado_telegram(IN p_chat VARCHAR(50))
BEGIN
    SELECT paso, dni FROM asistente.EstadoTelegram
     WHERE chat = p_chat AND fecha_hora >= NOW() - INTERVAL 30 MINUTE;
END//

-- Guarda el paso del /start; con p_paso NULL borra el estado (la vinculación terminó o se canceló).
DROP PROCEDURE IF EXISTS asistente.sp_guardar_estado_telegram//
CREATE PROCEDURE asistente.sp_guardar_estado_telegram(IN p_chat VARCHAR(50), IN p_paso VARCHAR(10), IN p_dni VARCHAR(15))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'ERROR' AS estado, 52949 AS codigo, 'No se pudo guardar el paso' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_chat IS NULL OR p_chat = '' THEN
        SET v_codigo = 52941;
        SET v_mensaje = 'Falta el chat';
    ELSEIF p_paso IS NOT NULL AND p_paso NOT IN ('dni', 'telefono') THEN
        SET v_codigo = 52942;
        SET v_mensaje = 'Paso inválido (dni o telefono)';
    END IF;

    IF v_codigo IS NULL THEN
        IF p_paso IS NULL THEN
            DELETE FROM asistente.EstadoTelegram WHERE chat = p_chat;
        ELSE
            REPLACE INTO asistente.EstadoTelegram (chat, paso, dni, fecha_hora) VALUES (p_chat, p_paso, p_dni, NOW());
        END IF;
        SELECT 'OK' AS estado, 0 AS codigo, 'Paso guardado' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    ELSE
        SELECT 'ERROR' AS estado, v_codigo AS codigo, v_mensaje AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END IF;
END//

DELIMITER ;
