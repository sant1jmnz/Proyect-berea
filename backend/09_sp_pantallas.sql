-- Dermalia: stored procedures para las pantallas de Cupones, Consultas previas y Usuarios (MySQL 8).
-- Se corre después de 04_sp_sena_cancelar.sql:
--   mysql -u root -p < backend/09_sp_pantallas.sql
--
-- Las pantallas de Gestión necesitan listar lo que ya existe; el resto de las
-- acciones (emitir cupones, pedir el token, validar, cargar el resultado de una
-- evaluación, reclamar) ya están en 04_sp_sena_cancelar.sql.
-- Mismo manejo de errores que en la clase (PPT 006): EXIT HANDLER FOR SQLEXCEPTION,
-- GET DIAGNOSTICS y una fila con estado = 'ERROR'.

-- Que el servidor lea este archivo como UTF-8 (si no, las tildes se guardan rotas: "DepilaciÃ³n").
SET NAMES utf8mb4;

DELIMITER //

-- =============================================================================
-- Cupones de una paciente, buscada por DNI (pantalla Cupones de Gestión).
-- usado = 1 si ya se aplicó a un turno; vigente = 1 si todavía no venció.
-- DNI que no existe, NULL o vacío: 0 filas.
-- =============================================================================
DROP PROCEDURE IF EXISTS beneficios.sp_listar_cupones//
CREATE PROCEDURE beneficios.sp_listar_cupones(IN p_dni VARCHAR(20))
BEGIN
    DECLARE codigo_error INT DEFAULT 0;
    DECLARE mensaje_error VARCHAR(255) DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            codigo_error = MYSQL_ERRNO,
            mensaje_error = MESSAGE_TEXT;
        SELECT 'ERROR' AS estado, codigo_error AS codigo, mensaje_error AS mensaje;
    END;

    SELECT c.id_cupon, c.codigo, r.nombre AS regla, c.porcentaje_descuento,
           c.fecha_emision, c.fecha_vencimiento,
           (c.id_turno IS NOT NULL) AS usado,
           (c.fecha_vencimiento > COALESCE(@ahora_simulado, NOW())) AS vigente,
           p.id_paciente, p.apellido, p.nombre
      FROM beneficios.Cupon c
      INNER JOIN beneficios.ReglaBeneficio r ON c.id_regla = r.id_regla
      INNER JOIN personas.Paciente p ON c.id_paciente = p.id_paciente
     WHERE p.dni = p_dni
     ORDER BY c.fecha_vencimiento DESC;
END//

-- =============================================================================
-- Evaluaciones previas de cirugía (pantalla Consultas previas de Gestión).
-- p_solo_pendientes = 1: solo las que todavía no tienen resultado.
-- vence = 6 meses después del resultado (si fue apta y no agendó la cirugía, se vence).
-- =============================================================================
DROP PROCEDURE IF EXISTS clinica.sp_listar_evaluaciones//
CREATE PROCEDURE clinica.sp_listar_evaluaciones(IN p_solo_pendientes SMALLINT)
BEGIN
    DECLARE codigo_error INT DEFAULT 0;
    DECLARE mensaje_error VARCHAR(255) DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            codigo_error = MYSQL_ERRNO,
            mensaje_error = MESSAGE_TEXT;
        SELECT 'ERROR' AS estado, codigo_error AS codigo, mensaje_error AS mensaje;
    END;

    SELECT e.id_evaluacion, p.dni, p.apellido, p.nombre, pr.nombre AS protocolo,
           t.fecha_hora_inicio AS fecha_consulta, et.nombre AS estado_turno,
           COALESCE(r.nombre, 'pendiente') AS resultado, e.observaciones,
           e.fecha_resultado, e.fecha_resultado + INTERVAL 6 MONTH AS vence, e.fecha_reclamo
      FROM clinica.EvaluacionPrevia e
      INNER JOIN agenda.Turno t ON e.id_turno = t.id_turno
      INNER JOIN agenda.EstadoTurno et ON t.id_estado_turno = et.id_estado_turno
      INNER JOIN personas.Paciente p ON t.id_paciente = p.id_paciente
      INNER JOIN clinica.Protocolo pr ON e.id_protocolo = pr.id_protocolo
      LEFT JOIN clinica.ResultadoEvaluacion r ON e.id_resultado = r.id_resultado
     WHERE COALESCE(p_solo_pendientes, 0) = 0
        OR e.id_resultado IS NULL
        OR r.nombre = 'pendiente'
     ORDER BY t.fecha_hora_inicio DESC;
END//

-- =============================================================================
-- Usuarios del personal (pantalla Usuarios de Gestión).
-- No hay registro libre: el personal entra a los datos de las pacientes, así que
-- solo la administración crea usuarios. Cada uno queda en la base y sirve para
-- ingresar desde cualquier PC conectada a esa base.
-- =============================================================================

-- Lista el personal (no las cuentas de pacientes). activo = 1 si puede ingresar.
DROP PROCEDURE IF EXISTS seguridad.sp_listar_usuarios//
CREATE PROCEDURE seguridad.sp_listar_usuarios()
BEGIN
    DECLARE codigo_error INT DEFAULT 0;
    DECLARE mensaje_error VARCHAR(255) DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            codigo_error = MYSQL_ERRNO,
            mensaje_error = MESSAGE_TEXT;
        SELECT 'ERROR' AS estado, codigo_error AS codigo, mensaje_error AS mensaje;
    END;

    SELECT u.id_usuario, u.nombre_usuario, u.email, r.nombre AS rol, u.activo, u.fecha_creacion
      FROM seguridad.Usuario u
      INNER JOIN seguridad.Rol r ON u.id_rol = r.id_rol
     WHERE r.nombre <> 'paciente'
     ORDER BY r.nombre, u.nombre_usuario;
END//

-- Alta de un usuario del personal. p_id_admin es quien lo crea: tiene que ser
-- un usuario activo con rol administrador. p_rol: 'recepcion' o 'administrador'
-- (los profesionales se dan de alta en la pantalla Profesionales, con su matrícula).
DROP PROCEDURE IF EXISTS seguridad.sp_alta_usuario//
CREATE PROCEDURE seguridad.sp_alta_usuario(
    IN p_id_admin INT, IN p_nombre_usuario VARCHAR(50), IN p_email VARCHAR(100),
    IN p_password VARCHAR(255), IN p_rol VARCHAR(50), IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE codigo_error INT DEFAULT 0;
    DECLARE mensaje_error VARCHAR(500) DEFAULT '';
    DECLARE v_es_admin SMALLINT DEFAULT 0;
    DECLARE v_id_rol INT DEFAULT NULL;
    DECLARE v_usuario INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            codigo_error = MYSQL_ERRNO,
            mensaje_error = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_usuario', p_id_admin, NULL, p_origen, mensaje_error,
                                        'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, codigo_error AS codigo, mensaje_error AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SET v_es_admin = EXISTS (SELECT 1 FROM seguridad.Usuario u INNER JOIN seguridad.Rol r ON u.id_rol = r.id_rol
                              WHERE u.id_usuario = p_id_admin AND u.activo = 1 AND r.nombre = 'administrador');
    SELECT id_rol INTO v_id_rol FROM seguridad.Rol
     WHERE nombre = p_rol AND (nombre = 'recepcion' OR nombre = 'administrador');

    IF v_es_admin = 0 THEN
        SET v_codigo = 52014;
        SET v_mensaje = 'Solo la administración puede crear usuarios';
    ELSEIF v_id_rol IS NULL THEN
        SET v_codigo = 52015;
        SET v_mensaje = 'El rol tiene que ser recepcion o administrador';
    ELSEIF p_nombre_usuario IS NULL OR (CHAR_LENGTH(p_nombre_usuario) BETWEEN 4 AND 50) = 0 THEN
        SET v_codigo = 52022;
        SET v_mensaje = 'El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo';
    ELSEIF p_email IS NULL OR (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0 THEN
        SET v_codigo = 52023;
        SET v_mensaje = 'El email no es válido';
    ELSEIF p_password IS NULL OR (CHAR_LENGTH(p_password) BETWEEN 6 AND 50) = 0 THEN
        SET v_codigo = 52016;
        SET v_mensaje = 'La contraseña debe tener de 6 a 50 caracteres';
    ELSEIF EXISTS (SELECT 1 FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario OR email = p_email) THEN
        SET v_codigo = 52025;
        SET v_mensaje = 'Ese usuario o email ya está en uso';
    END IF;

    IF v_codigo IS NULL THEN
        START TRANSACTION;
        INSERT INTO seguridad.Usuario (id_rol, nombre_usuario, email, password)
        VALUES (v_id_rol, p_nombre_usuario, p_email, p_password);
        SELECT id_usuario INTO v_usuario FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario;
        CALL auditoria.sp_registrar_log('alta_usuario', p_id_admin, NULL, p_origen, 'Usuario del personal creado',
                                        'seguridad.Usuario', v_usuario, NULL, p_nombre_usuario, 1, NULL);
        COMMIT;
        SELECT 'OK' AS estado, 0 AS codigo, 'Usuario creado' AS mensaje, v_usuario AS id, NULL AS valor, p_rol AS dato;
    ELSE
        CALL auditoria.sp_registrar_log('alta_usuario', p_id_admin, NULL, p_origen, v_mensaje,
                                        'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_codigo AS codigo, v_mensaje AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END IF;
END//

-- Cambio de la propia contraseña: hay que saber la actual.
DROP PROCEDURE IF EXISTS seguridad.sp_cambiar_clave//
CREATE PROCEDURE seguridad.sp_cambiar_clave(
    IN p_id_usuario INT, IN p_clave_actual VARCHAR(255), IN p_clave_nueva VARCHAR(255), IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE codigo_error INT DEFAULT 0;
    DECLARE mensaje_error VARCHAR(500) DEFAULT '';
    DECLARE v_password VARCHAR(255) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            codigo_error = MYSQL_ERRNO,
            mensaje_error = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'ERROR' AS estado, codigo_error AS codigo, mensaje_error AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT password INTO v_password FROM seguridad.Usuario WHERE id_usuario = p_id_usuario AND activo = 1;

    IF v_password IS NULL THEN
        SET v_codigo = 52013;
        SET v_mensaje = 'El usuario no existe';
    ELSEIF p_clave_actual IS NULL OR v_password <> p_clave_actual THEN
        SET v_codigo = 52017;
        SET v_mensaje = 'La contraseña actual no es correcta';
    ELSEIF p_clave_nueva IS NULL OR (CHAR_LENGTH(p_clave_nueva) BETWEEN 6 AND 50) = 0 THEN
        SET v_codigo = 52016;
        SET v_mensaje = 'La contraseña debe tener de 6 a 50 caracteres';
    END IF;

    IF v_codigo IS NULL THEN
        START TRANSACTION;
        UPDATE seguridad.Usuario SET password = p_clave_nueva WHERE id_usuario = p_id_usuario;
        CALL auditoria.sp_registrar_log('cambio_clave', p_id_usuario, NULL, p_origen, 'Cambio de contraseña',
                                        'seguridad.Usuario', p_id_usuario, NULL, NULL, 1, NULL);
        COMMIT;
        SELECT 'OK' AS estado, 0 AS codigo, 'Contraseña cambiada' AS mensaje, p_id_usuario AS id, NULL AS valor, NULL AS dato;
    ELSE
        CALL auditoria.sp_registrar_log('cambio_clave', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'seguridad.Usuario', p_id_usuario, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_codigo AS codigo, v_mensaje AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END IF;
END//

DELIMITER ;
