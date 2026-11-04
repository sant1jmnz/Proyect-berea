-- Dermalia: stored procedures de la Semana 3 (MySQL 8).
-- Se corre después de codigobasededatossolotablas.sql y 02_datos.sql:
--   mysql -u root -p < backend/03_sp_semana3.sql
--
-- Contenido: auxiliares (reloj, log, reembolso), login y cuentas, ABM de
-- pacientes, profesionales, disponibilidad y protocolos, horarios libres,
-- alta de turno y búsqueda de turnos.
--
-- Convención de todos los SP que escriben (como pide la cátedra, PPT 006):
--   * un EXIT HANDLER FOR SQLEXCEPTION atrapa cualquier error, deshace la
--     transacción, deja el fallo en el log y DEVUELVE UNA FILA DE ERROR;
--   * toda respuesta tiene las mismas 6 columnas:
--       estado ('OK' o 'ERROR'), codigo (0 o el número de error), mensaje,
--       id (lo que se creó o modificó), valor (un monto) y dato (un texto).
--   * las reglas de negocio se avisan con SIGNAL y un código propio (52xxx);
--     el catálogo de códigos está en docs/11-pruebas-bbdd.md.
--   * toda acción relevante escribe en auditoria.Log SOLO desde acá.
-- Los SP de consulta (listados, búsquedas, reportes) devuelven directamente
-- el conjunto de filas.

DELIMITER //

-- =====================================================================
--  AUXILIARES
-- =====================================================================

-- Reloj del sistema. Si la sesión define @ahora_simulado, los SP usan esa hora
-- (sirve para cargar historia y para probar vencimientos sin esperar meses).
DROP FUNCTION IF EXISTS auditoria.fn_ahora//
CREATE FUNCTION auditoria.fn_ahora() RETURNS DATETIME
    NOT DETERMINISTIC NO SQL
BEGIN
    RETURN COALESCE(@ahora_simulado, NOW());
END//

-- Escribe una fila en el log. Nunca falla: si el tipo de evento no existe no
-- escribe nada, y un usuario o paciente inexistente queda como NULL.
DROP PROCEDURE IF EXISTS auditoria.sp_registrar_log//
CREATE PROCEDURE auditoria.sp_registrar_log(
    IN p_tipo VARCHAR(50), IN p_id_usuario INT, IN p_id_paciente INT, IN p_origen VARCHAR(50),
    IN p_descripcion VARCHAR(2000), IN p_tabla VARCHAR(100), IN p_id_registro INT,
    IN p_anterior LONGTEXT, IN p_nuevo LONGTEXT, IN p_exitoso TINYINT, IN p_ip VARCHAR(45))
BEGIN
    INSERT INTO auditoria.Log (id_tipo_evento, id_usuario, id_paciente, id_origen, fecha_hora, descripcion,
                               ip_origen, tabla_afectada, id_registro_afectado, valor_anterior, valor_nuevo, exitoso)
    SELECT te.id_tipo_evento,
           (SELECT u.id_usuario FROM seguridad.Usuario u WHERE u.id_usuario = p_id_usuario),
           (SELECT p.id_paciente FROM personas.Paciente p WHERE p.id_paciente = p_id_paciente),
           COALESCE((SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = p_origen),
                    (SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = 'sistema')),
           auditoria.fn_ahora(), LEFT(p_descripcion, 500), p_ip, p_tabla, p_id_registro,
           p_anterior, p_nuevo, COALESCE(p_exitoso, 1)
    FROM auditoria.TipoEvento te
    WHERE te.nombre = p_tipo;
END//

-- Precio de un turno: suma de lo que costaba cada protocolo al agendar.
DROP FUNCTION IF EXISTS agenda.fn_precio_total//
CREATE FUNCTION agenda.fn_precio_total(p_id_turno INT) RETURNS DECIMAL(14,2)
    NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN COALESCE((SELECT SUM(tp.precio_aplicado) FROM agenda.TurnoProtocolo tp WHERE tp.id_turno = p_id_turno), 0);
END//

-- Descuento del cupón aplicado al turno (0 si no tiene).
DROP FUNCTION IF EXISTS agenda.fn_descuento//
CREATE FUNCTION agenda.fn_descuento(p_id_turno INT) RETURNS DECIMAL(14,2)
    NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN ROUND(agenda.fn_precio_total(p_id_turno) *
                 COALESCE((SELECT c.porcentaje_descuento FROM beneficios.Cupon c WHERE c.id_turno = p_id_turno), 0) / 100, 2);
END//

-- Precio final del turno: el precio de lista menos el descuento del cupón.
DROP FUNCTION IF EXISTS agenda.fn_precio_final//
CREATE FUNCTION agenda.fn_precio_final(p_id_turno INT) RETURNS DECIMAL(14,2)
    NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN agenda.fn_precio_total(p_id_turno) - agenda.fn_descuento(p_id_turno);
END//

-- Seña: el porcentaje más alto de las categorías de los protocolos del turno
-- (30% en general, 40% en cirugías) sobre el precio final, redondeada al peso.
DROP FUNCTION IF EXISTS agenda.fn_sena//
CREATE FUNCTION agenda.fn_sena(p_id_turno INT) RETURNS DECIMAL(12,2)
    NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN ROUND(agenda.fn_precio_final(p_id_turno) *
                 COALESCE((SELECT MAX(c.porcentaje_sena)
                           FROM agenda.TurnoProtocolo tp
                           JOIN clinica.Protocolo p ON p.id_protocolo = tp.id_protocolo
                           JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
                           WHERE tp.id_turno = p_id_turno), 0) / 100, 0);
END//

-- Cambia el estado de un pago de seña y, si se pagó con tarjeta de regalo,
-- devuelve el saldo (movimiento negativo). Lo usan la cancelación, las
-- inasistencias y las evaluaciones. No devuelve filas: es interno.
-- p_estado: 'reembolsada', 'reembolsada parcial' o 'retenida'.
DROP PROCEDURE IF EXISTS pagos.sp_aplicar_reembolso//
CREATE PROCEDURE pagos.sp_aplicar_reembolso(
    IN p_id_pago INT, IN p_monto_reembolsado DECIMAL(12,2), IN p_estado VARCHAR(50),
    IN p_motivo VARCHAR(200), IN p_id_usuario INT, IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_monto DECIMAL(12,2);
    DECLARE v_estado VARCHAR(50);
    DECLARE v_medio VARCHAR(50);
    DECLARE v_turno INT;
    DECLARE v_paciente INT;
    DECLARE v_anterior VARCHAR(300);

    SELECT ps.monto, ep.nombre, mp.nombre, ps.id_turno, t.id_paciente
      INTO v_monto, v_estado, v_medio, v_turno, v_paciente
      FROM pagos.PagoSena ps
      JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
      JOIN pagos.MedioPago mp ON mp.id_medio_pago = ps.id_medio_pago
      JOIN agenda.Turno t ON t.id_turno = ps.id_turno
     WHERE ps.id_pago = p_id_pago FOR UPDATE;

    IF v_monto IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52100, MESSAGE_TEXT = 'El pago de seña no existe';
    END IF;
    -- Solo se resuelve una seña 'pagada'. Única excepción: una seña retenida al vencer
    -- una evaluación puede pasar a 'reembolsada parcial' si la paciente reclama.
    IF v_estado <> 'pagada' AND NOT (v_estado = 'retenida' AND p_estado = 'reembolsada parcial') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52101, MESSAGE_TEXT = 'La seña ya fue resuelta (reembolsada o retenida)';
    END IF;
    IF p_monto_reembolsado IS NULL OR p_monto_reembolsado < 0 OR p_monto_reembolsado > v_monto THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52102, MESSAGE_TEXT = 'El monto a reembolsar no es válido';
    END IF;
    IF p_estado NOT IN ('reembolsada', 'reembolsada parcial', 'retenida') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52103, MESSAGE_TEXT = 'Estado de pago inválido';
    END IF;

    SET v_anterior = CONCAT('estado=', v_estado, ';reembolsado=0');
    UPDATE pagos.PagoSena
       SET id_estado_pago = (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre = p_estado),
           monto_reembolsado = p_monto_reembolsado,
           fecha_resolucion = auditoria.fn_ahora()
     WHERE id_pago = p_id_pago;

    IF v_medio = 'tarjeta de regalo' AND p_monto_reembolsado > 0 THEN
        INSERT INTO pagos.MovimientoTarjeta (id_tarjeta, id_turno, monto, fecha_movimiento)
        SELECT m.id_tarjeta, v_turno, -p_monto_reembolsado, auditoria.fn_ahora()
          FROM pagos.MovimientoTarjeta m
         WHERE m.id_turno = v_turno AND m.monto > 0
         ORDER BY m.id_movimiento LIMIT 1;
    END IF;

    CALL auditoria.sp_registrar_log(IF(p_monto_reembolsado > 0, 'reembolso', 'retencion'), p_id_usuario, v_paciente, p_origen,
        CONCAT(p_motivo, ': reembolsado $', p_monto_reembolsado, ' de $', v_monto, ' (', p_estado, ')'),
        'pagos.PagoSena', p_id_pago, v_anterior,
        CONCAT('estado=', p_estado, ';reembolsado=', p_monto_reembolsado), 1, NULL);
END//


-- =====================================================================
--  SEGURIDAD: login, cierre de sesión y cuenta de la paciente (RF-15, RF-20)
-- =====================================================================

-- Ingreso al sistema. La contrasena se compara tal cual, sin encriptar.
-- Tras 5 intentos fallidos en 15 minutos la cuenta se bloquea temporalmente;
-- los intentos se cuentan desde el log (modelo, grupo 4, decisión 6).
DROP PROCEDURE IF EXISTS seguridad.sp_login//
CREATE PROCEDURE seguridad.sp_login(
    IN p_usuario VARCHAR(50), IN p_password VARCHAR(255), IN p_ip VARCHAR(45), IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_password VARCHAR(255);
    DECLARE v_rol VARCHAR(50);
    DECLARE v_fallidos INT DEFAULT 0;
    DECLARE v_paciente INT DEFAULT NULL;
    DECLARE v_profesional INT DEFAULT NULL;

    IF p_usuario IS NULL OR TRIM(p_usuario) = '' OR p_password IS NULL OR p_password = '' THEN
        SELECT 'ERROR' AS estado, 52010 AS codigo, 'Falta el usuario o la contraseña' AS mensaje,
               NULL AS id, NULL AS valor, NULL AS dato;
    ELSE
        SELECT u.id_usuario, u.password, r.nombre
          INTO v_id, v_password, v_rol
          FROM seguridad.Usuario u JOIN seguridad.Rol r ON r.id_rol = u.id_rol
         WHERE u.nombre_usuario = p_usuario AND u.activo = 1;

        IF v_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_fallidos
              FROM auditoria.Log l JOIN auditoria.TipoEvento te ON te.id_tipo_evento = l.id_tipo_evento
             WHERE te.nombre = 'intento_fallido' AND l.id_usuario = v_id
               AND l.fecha_hora >= auditoria.fn_ahora() - INTERVAL 15 MINUTE
               AND l.fecha_hora > COALESCE((SELECT MAX(l2.fecha_hora) FROM auditoria.Log l2
                                             JOIN auditoria.TipoEvento t2 ON t2.id_tipo_evento = l2.id_tipo_evento
                                            WHERE t2.nombre = 'inicio_sesion' AND l2.id_usuario = v_id), '1970-01-01');
        END IF;

        IF v_id IS NULL THEN
            CALL auditoria.sp_registrar_log('intento_fallido', NULL, NULL, p_origen,
                CONCAT('Usuario inexistente o inactivo: ', LEFT(p_usuario, 50)), 'seguridad.Usuario', NULL, NULL, NULL, 0, p_ip);
            SELECT 'ERROR' AS estado, 52011 AS codigo, 'Usuario o contraseña incorrectos' AS mensaje,
                   NULL AS id, NULL AS valor, NULL AS dato;
        ELSEIF v_fallidos >= 5 THEN
            CALL auditoria.sp_registrar_log('intento_fallido', v_id, NULL, p_origen,
                'Cuenta bloqueada por intentos fallidos', 'seguridad.Usuario', v_id, NULL, NULL, 0, p_ip);
            SELECT 'ERROR' AS estado, 52012 AS codigo, 'Cuenta bloqueada 15 minutos por demasiados intentos' AS mensaje,
                   v_id AS id, NULL AS valor, NULL AS dato;
        ELSEIF v_password <> p_password THEN
            CALL auditoria.sp_registrar_log('intento_fallido', v_id, NULL, p_origen,
                'Contraseña incorrecta', 'seguridad.Usuario', v_id, NULL, NULL, 0, p_ip);
            SELECT 'ERROR' AS estado, 52011 AS codigo, 'Usuario o contraseña incorrectos' AS mensaje,
                   NULL AS id, NULL AS valor, NULL AS dato;
        ELSE
            SELECT id_paciente INTO v_paciente FROM personas.Paciente WHERE id_usuario = v_id;
            SELECT id_profesional INTO v_profesional FROM personas.Profesional WHERE id_usuario = v_id;
            CALL auditoria.sp_registrar_log('inicio_sesion', v_id, v_paciente, p_origen,
                CONCAT('Ingreso como ', v_rol), 'seguridad.Usuario', v_id, NULL, NULL, 1, p_ip);
            -- id = usuario; valor = id de paciente o profesional si corresponde; dato = rol
            SELECT 'OK' AS estado, 0 AS codigo, 'Ingreso correcto' AS mensaje, v_id AS id,
                   COALESCE(v_paciente, v_profesional) AS valor, v_rol AS dato;
        END IF;
    END IF;
END//

-- Cierre de sesión: solo deja el evento 'cierre_sesion' en el log (la app
-- es quien cierra la ventana). Devuelve error si el usuario no existe.
DROP PROCEDURE IF EXISTS seguridad.sp_cerrar_sesion//
CREATE PROCEDURE seguridad.sp_cerrar_sesion(IN p_id_usuario INT, IN p_origen VARCHAR(50), IN p_ip VARCHAR(45))
BEGIN
    IF EXISTS (SELECT 1 FROM seguridad.Usuario WHERE id_usuario = p_id_usuario) THEN
        CALL auditoria.sp_registrar_log('cierre_sesion', p_id_usuario, NULL, p_origen, 'Cierre de sesión',
                                        'seguridad.Usuario', p_id_usuario, NULL, NULL, 1, p_ip);
        SELECT 'OK' AS estado, 0 AS codigo, 'Sesión cerrada' AS mensaje, p_id_usuario AS id, NULL AS valor, NULL AS dato;
    ELSE
        SELECT 'ERROR' AS estado, 52013 AS codigo, 'El usuario no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END IF;
END//

-- Cuenta opcional de una paciente (RF-15): se vincula con su DNI.
DROP PROCEDURE IF EXISTS seguridad.sp_crear_cuenta_paciente//
CREATE PROCEDURE seguridad.sp_crear_cuenta_paciente(
    IN p_dni VARCHAR(15), IN p_nombre_usuario VARCHAR(50), IN p_email VARCHAR(100),
    IN p_password VARCHAR(255), IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_paciente INT DEFAULT NULL;
    DECLARE v_cuenta INT DEFAULT NULL;
    DECLARE v_usuario INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cuenta_creada', NULL, v_paciente, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT id_paciente, id_usuario INTO v_paciente, v_cuenta FROM personas.Paciente WHERE dni = p_dni;
    IF v_paciente IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52020, MESSAGE_TEXT = 'No hay una paciente con ese DNI';
    END IF;
    IF v_cuenta IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52021, MESSAGE_TEXT = 'Esa paciente ya tiene cuenta';
    END IF;
    IF p_nombre_usuario IS NULL OR NOT REGEXP_LIKE(p_nombre_usuario, '^[a-z0-9._-]{4,50}$', 'c') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52022, MESSAGE_TEXT = 'El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo';
    END IF;
    IF p_email IS NULL OR p_email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52023, MESSAGE_TEXT = 'El email no es válido';
    END IF;
    IF p_password IS NULL OR TRIM(p_password) = '' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52024, MESSAGE_TEXT = 'La contrasena no puede estar vacia';
    END IF;
    IF EXISTS (SELECT 1 FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario OR email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52025, MESSAGE_TEXT = 'Ese usuario o email ya está en uso';
    END IF;

    START TRANSACTION;
    INSERT INTO seguridad.Usuario (id_rol, nombre_usuario, email, password)
    VALUES ((SELECT id_rol FROM seguridad.Rol WHERE nombre = 'paciente'), p_nombre_usuario, p_email, p_password);
    SET v_usuario = LAST_INSERT_ID();
    UPDATE personas.Paciente SET id_usuario = v_usuario WHERE id_paciente = v_paciente;
    CALL auditoria.sp_registrar_log('cuenta_creada', v_usuario, v_paciente, p_origen, 'Cuenta de paciente creada',
                                    'seguridad.Usuario', v_usuario, NULL, p_nombre_usuario, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Cuenta creada' AS mensaje, v_usuario AS id, NULL AS valor, NULL AS dato;
END//


-- =====================================================================
--  PACIENTES
-- =====================================================================

-- Alta de paciente. Mismas validaciones que el frontend (frontend/comun/validaciones):
-- DNI de 7 u 8 dígitos, teléfono de 10 a 13 dígitos, nombre y apellido de 2 a 60 letras.
DROP PROCEDURE IF EXISTS personas.sp_alta_paciente//
CREATE PROCEDURE personas.sp_alta_paciente(
    IN p_dni VARCHAR(15), IN p_nombre VARCHAR(50), IN p_apellido VARCHAR(50), IN p_fecha_nacimiento DATE,
    IN p_email VARCHAR(100), IN p_telefono VARCHAR(30), IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'personas.Paciente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_dni IS NULL OR p_dni NOT REGEXP '^[0-9]{7,8}$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52030, MESSAGE_TEXT = 'El DNI debe tener 7 u 8 dígitos';
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(TRIM(p_apellido)) < 2 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52031, MESSAGE_TEXT = 'Nombre y apellido deben tener al menos 2 letras';
    END IF;
    IF p_telefono IS NULL OR p_telefono NOT REGEXP '^[+]?[0-9]{10,13}$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52032, MESSAGE_TEXT = 'El teléfono debe tener de 10 a 13 dígitos';
    END IF;
    IF p_fecha_nacimiento IS NULL OR p_fecha_nacimiento >= CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52033, MESSAGE_TEXT = 'La fecha de nacimiento no es válida';
    END IF;
    IF p_email IS NOT NULL AND p_email <> '' AND p_email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52034, MESSAGE_TEXT = 'El email no es válido';
    END IF;
    IF EXISTS (SELECT 1 FROM personas.Paciente WHERE dni = p_dni) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52035, MESSAGE_TEXT = 'Ya existe una paciente con ese DNI';
    END IF;

    START TRANSACTION;
    INSERT INTO personas.Paciente (dni, nombre, apellido, fecha_nacimiento, fecha_alta, email)
    VALUES (p_dni, TRIM(p_nombre), TRIM(p_apellido), p_fecha_nacimiento, auditoria.fn_ahora(), NULLIF(TRIM(p_email), ''));
    SET v_id = LAST_INSERT_ID();
    INSERT INTO personas.TelefonoPaciente (id_paciente, telefono) VALUES (v_id, p_telefono);
    CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, v_id, p_origen,
        CONCAT('Alta de paciente DNI ', p_dni), 'personas.Paciente', v_id, NULL, CONCAT(TRIM(p_apellido), ', ', TRIM(p_nombre)), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Paciente creada' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
END//

-- Modifica nombre, apellido, email y, si viene, agrega un teléfono nuevo.
DROP PROCEDURE IF EXISTS personas.sp_modificar_paciente//
CREATE PROCEDURE personas.sp_modificar_paciente(
    IN p_id_paciente INT, IN p_nombre VARCHAR(50), IN p_apellido VARCHAR(50), IN p_email VARCHAR(100),
    IN p_telefono_nuevo VARCHAR(30), IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_antes VARCHAR(400);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'personas.Paciente', p_id_paciente, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT CONCAT(apellido, ', ', nombre, ' <', COALESCE(email, ''), '>') INTO v_antes
      FROM personas.Paciente WHERE id_paciente = p_id_paciente;
    IF v_antes IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52036, MESSAGE_TEXT = 'La paciente no existe';
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(TRIM(p_apellido)) < 2 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52031, MESSAGE_TEXT = 'Nombre y apellido deben tener al menos 2 letras';
    END IF;
    IF p_email IS NOT NULL AND p_email <> '' AND p_email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52034, MESSAGE_TEXT = 'El email no es válido';
    END IF;
    IF p_telefono_nuevo IS NOT NULL AND p_telefono_nuevo <> '' AND p_telefono_nuevo NOT REGEXP '^[+]?[0-9]{10,13}$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52032, MESSAGE_TEXT = 'El teléfono debe tener de 10 a 13 dígitos';
    END IF;

    START TRANSACTION;
    UPDATE personas.Paciente
       SET nombre = TRIM(p_nombre), apellido = TRIM(p_apellido), email = NULLIF(TRIM(p_email), '')
     WHERE id_paciente = p_id_paciente;
    IF p_telefono_nuevo IS NOT NULL AND p_telefono_nuevo <> '' THEN
        INSERT IGNORE INTO personas.TelefonoPaciente (id_paciente, telefono) VALUES (p_id_paciente, p_telefono_nuevo);
    END IF;
    CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, 'Datos de la paciente modificados',
        'personas.Paciente', p_id_paciente, v_antes, CONCAT(TRIM(p_apellido), ', ', TRIM(p_nombre), ' <', COALESCE(p_email, ''), '>'), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Paciente modificada' AS mensaje, p_id_paciente AS id, NULL AS valor, NULL AS dato;
END//

-- Búsqueda por nombre, apellido, DNI o teléfono (RF-13). Con texto vacío o
-- de menos de 3 caracteres no devuelve nada.
DROP PROCEDURE IF EXISTS personas.sp_buscar_paciente//
CREATE PROCEDURE personas.sp_buscar_paciente(IN p_texto VARCHAR(100))
BEGIN
    DECLARE v_texto VARCHAR(100) DEFAULT TRIM(COALESCE(p_texto, ''));
    SELECT p.id_paciente, p.dni, p.nombre, p.apellido, p.fecha_nacimiento, p.email,
           (SELECT GROUP_CONCAT(tp.telefono ORDER BY tp.id_telefono_paciente SEPARATOR ', ')
              FROM personas.TelefonoPaciente tp WHERE tp.id_paciente = p.id_paciente) AS telefonos,
           (p.id_usuario IS NOT NULL) AS tiene_cuenta
      FROM personas.Paciente p
     WHERE CHAR_LENGTH(v_texto) >= 3
       AND (p.dni = v_texto
            OR p.nombre LIKE CONCAT('%', v_texto, '%')
            OR p.apellido LIKE CONCAT('%', v_texto, '%')
            OR CONCAT(p.nombre, ' ', p.apellido) LIKE CONCAT('%', v_texto, '%')
            OR EXISTS (SELECT 1 FROM personas.TelefonoPaciente tp
                        WHERE tp.id_paciente = p.id_paciente AND tp.telefono = v_texto))
     ORDER BY p.apellido, p.nombre;
END//


-- =====================================================================
--  PROFESIONALES Y DISPONIBILIDAD (RF-03, RF-18)
-- =====================================================================

-- Alta de profesional: crea su cuenta propia (rol profesional), que es obligatoria.
DROP PROCEDURE IF EXISTS personas.sp_alta_profesional//
CREATE PROCEDURE personas.sp_alta_profesional(
    IN p_matricula VARCHAR(30), IN p_nombre VARCHAR(50), IN p_apellido VARCHAR(50), IN p_email VARCHAR(100),
    IN p_telefono VARCHAR(30), IN p_nombre_usuario VARCHAR(50), IN p_password VARCHAR(255),
    IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_usuario INT;
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_matricula IS NULL OR TRIM(p_matricula) = '' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52040, MESSAGE_TEXT = 'Falta la matrícula';
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(TRIM(p_apellido)) < 2 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52031, MESSAGE_TEXT = 'Nombre y apellido deben tener al menos 2 letras';
    END IF;
    IF p_email IS NULL OR p_email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52034, MESSAGE_TEXT = 'El email no es válido';
    END IF;
    IF p_telefono IS NULL OR p_telefono NOT REGEXP '^[+]?[0-9]{10,13}$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52032, MESSAGE_TEXT = 'El teléfono debe tener de 10 a 13 dígitos';
    END IF;
    IF p_nombre_usuario IS NULL OR NOT REGEXP_LIKE(p_nombre_usuario, '^[a-z0-9._-]{4,50}$', 'c') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52022, MESSAGE_TEXT = 'El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo';
    END IF;
    IF p_password IS NULL OR TRIM(p_password) = '' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52024, MESSAGE_TEXT = 'La contrasena no puede estar vacia';
    END IF;
    IF EXISTS (SELECT 1 FROM personas.Profesional WHERE matricula = p_matricula) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52041, MESSAGE_TEXT = 'Ya existe un profesional con esa matrícula';
    END IF;
    IF EXISTS (SELECT 1 FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario OR email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52025, MESSAGE_TEXT = 'Ese usuario o email ya está en uso';
    END IF;

    START TRANSACTION;
    INSERT INTO seguridad.Usuario (id_rol, nombre_usuario, email, password)
    VALUES ((SELECT id_rol FROM seguridad.Rol WHERE nombre = 'profesional'), p_nombre_usuario, p_email, p_password);
    SET v_usuario = LAST_INSERT_ID();
    INSERT INTO personas.Profesional (id_usuario, matricula, nombre, apellido, email)
    VALUES (v_usuario, TRIM(p_matricula), TRIM(p_nombre), TRIM(p_apellido), p_email);
    SET v_id = LAST_INSERT_ID();
    INSERT INTO personas.TelefonoProfesional (id_profesional, telefono) VALUES (v_id, p_telefono);
    CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen,
        CONCAT('Alta del profesional ', TRIM(p_apellido), ', ', TRIM(p_nombre), ' (', TRIM(p_matricula), ')'),
        'personas.Profesional', v_id, NULL, p_nombre_usuario, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Profesional creado' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
END//

-- Modifica los datos del profesional o lo da de baja (p_activo = 0). No se
-- puede dar de baja a quien tiene turnos futuros sin cancelar.
DROP PROCEDURE IF EXISTS personas.sp_modificar_profesional//
CREATE PROCEDURE personas.sp_modificar_profesional(
    IN p_id_profesional INT, IN p_nombre VARCHAR(50), IN p_apellido VARCHAR(50), IN p_email VARCHAR(100),
    IN p_activo TINYINT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_antes VARCHAR(400);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'personas.Profesional', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT CONCAT(apellido, ', ', nombre, ' <', email, '> activo=', activo) INTO v_antes
      FROM personas.Profesional WHERE id_profesional = p_id_profesional;
    IF v_antes IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52042, MESSAGE_TEXT = 'El profesional no existe';
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(TRIM(p_apellido)) < 2 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52031, MESSAGE_TEXT = 'Nombre y apellido deben tener al menos 2 letras';
    END IF;
    IF p_email IS NULL OR p_email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52034, MESSAGE_TEXT = 'El email no es válido';
    END IF;
    IF p_activo IS NULL OR p_activo NOT IN (0, 1) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52043, MESSAGE_TEXT = 'El estado activo debe ser 0 o 1';
    END IF;
    IF p_activo = 0 AND EXISTS (
            SELECT 1 FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
             WHERE t.id_profesional = p_id_profesional AND t.fecha_hora_inicio > auditoria.fn_ahora()
               AND e.nombre IN ('pendiente', 'confirmado')) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52044, MESSAGE_TEXT = 'No se puede dar de baja: tiene turnos futuros sin cancelar';
    END IF;

    START TRANSACTION;
    UPDATE personas.Profesional SET nombre = TRIM(p_nombre), apellido = TRIM(p_apellido), email = p_email, activo = p_activo
     WHERE id_profesional = p_id_profesional;
    CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen,
        IF(p_activo = 0, 'Baja del profesional', 'Datos del profesional modificados'),
        'personas.Profesional', p_id_profesional, v_antes,
        CONCAT(TRIM(p_apellido), ', ', TRIM(p_nombre), ' <', p_email, '> activo=', p_activo), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Profesional modificado' AS mensaje, p_id_profesional AS id, NULL AS valor, NULL AS dato;
END//

-- Carga una franja de disponibilidad. No puede superponerse con otra franja
-- activa del mismo profesional ese día.
DROP PROCEDURE IF EXISTS personas.sp_cargar_disponibilidad//
CREATE PROCEDURE personas.sp_cargar_disponibilidad(
    IN p_id_profesional INT, IN p_fecha DATE, IN p_hora_inicio TIME, IN p_hora_fin TIME,
    IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'personas.Disponibilidad', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF NOT EXISTS (SELECT 1 FROM personas.Profesional WHERE id_profesional = p_id_profesional AND activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52045, MESSAGE_TEXT = 'El profesional no existe o está dado de baja';
    END IF;
    IF p_fecha IS NULL OR p_hora_inicio IS NULL OR p_hora_fin IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52046, MESSAGE_TEXT = 'Faltan la fecha o las horas';
    END IF;
    IF p_hora_fin <= p_hora_inicio THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52047, MESSAGE_TEXT = 'La hora de fin debe ser posterior a la de inicio';
    END IF;
    IF p_fecha < DATE(auditoria.fn_ahora()) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52048, MESSAGE_TEXT = 'No se puede cargar disponibilidad en el pasado';
    END IF;
    IF EXISTS (SELECT 1 FROM personas.Disponibilidad d
                WHERE d.id_profesional = p_id_profesional AND d.fecha = p_fecha AND d.activa = 1
                  AND d.hora_inicio < p_hora_fin AND d.hora_fin > p_hora_inicio) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52049, MESSAGE_TEXT = 'La franja se superpone con otra ya cargada';
    END IF;

    START TRANSACTION;
    INSERT INTO personas.Disponibilidad (id_profesional, fecha, hora_inicio, hora_fin) VALUES (p_id_profesional, p_fecha, p_hora_inicio, p_hora_fin);
    SET v_id = LAST_INSERT_ID();
    CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen,
        CONCAT('Alta de franja ', p_fecha, ' ', p_hora_inicio, '-', p_hora_fin, ' del profesional ', p_id_profesional),
        'personas.Disponibilidad', v_id, NULL, CONCAT(p_fecha, ' ', p_hora_inicio, '-', p_hora_fin), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Franja cargada' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
END//

-- Baja (lógica) de una franja. No se puede si hay turnos activos dentro de ella.
DROP PROCEDURE IF EXISTS personas.sp_baja_disponibilidad//
CREATE PROCEDURE personas.sp_baja_disponibilidad(IN p_id_disponibilidad INT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_prof INT DEFAULT NULL;
    DECLARE v_fecha DATE;
    DECLARE v_ini TIME;
    DECLARE v_fin TIME;
    DECLARE v_activa TINYINT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'personas.Disponibilidad', p_id_disponibilidad, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT id_profesional, fecha, hora_inicio, hora_fin, activa INTO v_prof, v_fecha, v_ini, v_fin, v_activa
      FROM personas.Disponibilidad WHERE id_disponibilidad = p_id_disponibilidad FOR UPDATE;
    IF v_prof IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52050, MESSAGE_TEXT = 'La franja no existe';
    END IF;
    IF v_activa = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52051, MESSAGE_TEXT = 'La franja ya estaba dada de baja';
    END IF;
    IF EXISTS (SELECT 1 FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
                WHERE t.id_profesional = v_prof AND e.nombre IN ('pendiente', 'confirmado')
                  AND t.fecha_hora_inicio < TIMESTAMP(v_fecha, v_fin) AND t.fecha_hora_fin > TIMESTAMP(v_fecha, v_ini)) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52052, MESSAGE_TEXT = 'Hay turnos sin cancelar dentro de esa franja';
    END IF;

    UPDATE personas.Disponibilidad SET activa = 0 WHERE id_disponibilidad = p_id_disponibilidad;
    CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen,
        CONCAT('Baja de franja ', v_fecha, ' ', v_ini, '-', v_fin, ' del profesional ', v_prof),
        'personas.Disponibilidad', p_id_disponibilidad, 'activa=1', 'activa=0', 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Franja dada de baja' AS mensaje, p_id_disponibilidad AS id, NULL AS valor, NULL AS dato;
END//

-- Habilita (o quita) un protocolo a un profesional (RF-18).
DROP PROCEDURE IF EXISTS clinica.sp_asignar_protocolo//
CREATE PROCEDURE clinica.sp_asignar_protocolo(
    IN p_id_profesional INT, IN p_id_protocolo INT, IN p_habilitar TINYINT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'clinica.ProfesionalProtocolo', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF NOT EXISTS (SELECT 1 FROM personas.Profesional WHERE id_profesional = p_id_profesional) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52042, MESSAGE_TEXT = 'El profesional no existe';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM clinica.Protocolo WHERE id_protocolo = p_id_protocolo) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52060, MESSAGE_TEXT = 'El protocolo no existe';
    END IF;
    IF p_habilitar IS NULL OR p_habilitar NOT IN (0, 1) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52043, MESSAGE_TEXT = 'El parámetro habilitar debe ser 0 o 1';
    END IF;

    START TRANSACTION;
    IF p_habilitar = 1 THEN
        INSERT IGNORE INTO clinica.ProfesionalProtocolo (id_profesional, id_protocolo) VALUES (p_id_profesional, p_id_protocolo);
    ELSE
        DELETE FROM clinica.ProfesionalProtocolo WHERE id_profesional = p_id_profesional AND id_protocolo = p_id_protocolo;
    END IF;
    CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen,
        CONCAT(IF(p_habilitar = 1, 'Se habilita', 'Se quita'), ' el protocolo ', p_id_protocolo, ' al profesional ', p_id_profesional),
        'clinica.ProfesionalProtocolo', p_id_profesional, NULL, NULL, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Asignación actualizada' AS mensaje, p_id_profesional AS id, NULL AS valor, NULL AS dato;
END//

-- Profesionales activos habilitados para TODOS los protocolos pedidos (RF-18).
-- p_protocolos_csv: ids separados por coma, por ejemplo '3,7'.
DROP PROCEDURE IF EXISTS personas.sp_profesionales_para_protocolos//
CREATE PROCEDURE personas.sp_profesionales_para_protocolos(IN p_protocolos_csv VARCHAR(200))
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SELECT NULL AS id_profesional, NULL AS profesional, NULL AS matricula FROM DUAL WHERE 1 = 0;
    IF p_protocolos_csv IS NULL OR TRIM(p_protocolos_csv) = '' THEN
        SELECT NULL AS id_profesional, NULL AS profesional, NULL AS matricula FROM DUAL WHERE 1 = 0;
    ELSE
        SELECT pr.id_profesional, CONCAT(pr.apellido, ', ', pr.nombre) AS profesional, pr.matricula
          FROM personas.Profesional pr
         WHERE pr.activo = 1
           AND NOT EXISTS (SELECT 1 FROM JSON_TABLE(CONCAT('[', p_protocolos_csv, ']'), '$[*]' COLUMNS (id INT PATH '$')) jt
                            WHERE NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo pp
                                               WHERE pp.id_profesional = pr.id_profesional AND pp.id_protocolo = jt.id))
         ORDER BY pr.apellido, pr.nombre;
    END IF;
END//


-- =====================================================================
--  PROTOCOLOS (RF-05, RF-06, RNF-08: la recepción actualiza precios sin ayuda técnica)
-- =====================================================================

-- Alta de un protocolo en el catálogo (RNF-08: la recepción actualiza
-- precios y protocolos sin ayuda técnica). Valida categoría, nombre único,
-- precio mayor a cero y duración entre 1 y 600 minutos.
-- Devuelve: id = protocolo nuevo, valor = su precio.
DROP PROCEDURE IF EXISTS clinica.sp_alta_protocolo//
CREATE PROCEDURE clinica.sp_alta_protocolo(
    IN p_id_categoria INT, IN p_nombre VARCHAR(100), IN p_descripcion VARCHAR(500), IN p_precio DECIMAL(12,2),
    IN p_duracion_min INT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'clinica.Protocolo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF NOT EXISTS (SELECT 1 FROM clinica.CategoriaProtocolo WHERE id_categoria = p_id_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52061, MESSAGE_TEXT = 'La categoría no existe';
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 3 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52062, MESSAGE_TEXT = 'El nombre debe tener al menos 3 caracteres';
    END IF;
    IF p_precio IS NULL OR p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52063, MESSAGE_TEXT = 'El precio debe ser mayor a cero';
    END IF;
    IF p_duracion_min IS NULL OR p_duracion_min <= 0 OR p_duracion_min > 600 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52064, MESSAGE_TEXT = 'La duración debe estar entre 1 y 600 minutos';
    END IF;
    IF EXISTS (SELECT 1 FROM clinica.Protocolo WHERE nombre = TRIM(p_nombre)) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52065, MESSAGE_TEXT = 'Ya existe un protocolo con ese nombre';
    END IF;

    START TRANSACTION;
    INSERT INTO clinica.Protocolo (id_categoria, nombre, descripcion, precio, duracion_min)
    VALUES (p_id_categoria, TRIM(p_nombre), p_descripcion, p_precio, p_duracion_min);
    SET v_id = LAST_INSERT_ID();
    CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, CONCAT('Alta del protocolo ', TRIM(p_nombre)),
        'clinica.Protocolo', v_id, NULL, CONCAT('precio=', p_precio, ';duracion=', p_duracion_min), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Protocolo creado' AS mensaje, v_id AS id, p_precio AS valor, NULL AS dato;
END//

-- Cambia precio, duración, descripción o lo da de baja (p_activo = 0). Los
-- turnos ya agendados conservan el precio de cuando se reservaron.
DROP PROCEDURE IF EXISTS clinica.sp_modificar_protocolo//
CREATE PROCEDURE clinica.sp_modificar_protocolo(
    IN p_id_protocolo INT, IN p_nombre VARCHAR(100), IN p_descripcion VARCHAR(500), IN p_precio DECIMAL(12,2),
    IN p_duracion_min INT, IN p_activo TINYINT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_antes VARCHAR(400);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, CONCAT('Error ', v_errno, ': ', v_msg),
                                        'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT CONCAT('nombre=', nombre, ';precio=', precio, ';duracion=', duracion_min, ';activo=', activo) INTO v_antes
      FROM clinica.Protocolo WHERE id_protocolo = p_id_protocolo;
    IF v_antes IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52060, MESSAGE_TEXT = 'El protocolo no existe';
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 3 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52062, MESSAGE_TEXT = 'El nombre debe tener al menos 3 caracteres';
    END IF;
    IF p_precio IS NULL OR p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52063, MESSAGE_TEXT = 'El precio debe ser mayor a cero';
    END IF;
    IF p_duracion_min IS NULL OR p_duracion_min <= 0 OR p_duracion_min > 600 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52064, MESSAGE_TEXT = 'La duración debe estar entre 1 y 600 minutos';
    END IF;
    IF p_activo IS NULL OR p_activo NOT IN (0, 1) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52043, MESSAGE_TEXT = 'El estado activo debe ser 0 o 1';
    END IF;
    IF EXISTS (SELECT 1 FROM clinica.Protocolo WHERE nombre = TRIM(p_nombre) AND id_protocolo <> p_id_protocolo) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52065, MESSAGE_TEXT = 'Ya existe un protocolo con ese nombre';
    END IF;

    START TRANSACTION;
    UPDATE clinica.Protocolo
       SET nombre = TRIM(p_nombre), descripcion = p_descripcion, precio = p_precio, duracion_min = p_duracion_min, activo = p_activo
     WHERE id_protocolo = p_id_protocolo;
    CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen,
        IF(p_activo = 0, 'Baja del protocolo', 'Protocolo modificado'), 'clinica.Protocolo', p_id_protocolo, v_antes,
        CONCAT('nombre=', TRIM(p_nombre), ';precio=', p_precio, ';duracion=', p_duracion_min, ';activo=', p_activo), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Protocolo modificado' AS mensaje, p_id_protocolo AS id, p_precio AS valor, NULL AS dato;
END//

-- Catálogo y buscador por palabra clave (RF-05/06). Con texto vacío o NULL
-- devuelve todo el catálogo; con p_id_categoria NULL, todas las categorías.
-- p_incluir_bajas = 1 incluye también los protocolos dados de baja (lo usa la
-- pantalla de administración de protocolos); con 0 o NULL, solo los activos.
DROP PROCEDURE IF EXISTS clinica.sp_listar_protocolos//
CREATE PROCEDURE clinica.sp_listar_protocolos(IN p_texto VARCHAR(100), IN p_id_categoria INT, IN p_incluir_bajas TINYINT)
BEGIN
    DECLARE v_texto VARCHAR(100) DEFAULT TRIM(COALESCE(p_texto, ''));
    SELECT p.id_protocolo, p.nombre, p.descripcion, c.id_categoria, c.nombre AS categoria, p.precio, p.duracion_min,
           c.porcentaje_sena, ROUND(p.precio * c.porcentaje_sena / 100, 0) AS sena, c.requiere_evaluacion, p.activo
      FROM clinica.Protocolo p
      JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
     WHERE (p.activo = 1 OR COALESCE(p_incluir_bajas, 0) = 1)
       AND (p_id_categoria IS NULL OR p.id_categoria = p_id_categoria)
       AND (v_texto = '' OR p.nombre LIKE CONCAT('%', v_texto, '%') OR p.descripcion LIKE CONCAT('%', v_texto, '%')
            OR c.nombre LIKE CONCAT('%', v_texto, '%'))
     ORDER BY c.id_categoria, p.nombre;
END//


-- =====================================================================
--  AGENDA: horarios libres, alta de turno y búsqueda (RF-01, RF-02, RF-04, RF-12, RF-13, RF-16)
-- =====================================================================

-- Horarios realmente disponibles de un día (cada 30 minutos) para uno o varios
-- protocolos (p_protocolos_csv = '3,7'). Muestra solo profesionales activos que
-- hacen todos los protocolos, dentro de su disponibilidad, sin pisar otros
-- turnos y en el futuro. p_id_profesional NULL = todos.
DROP PROCEDURE IF EXISTS agenda.sp_horarios_libres//
CREATE PROCEDURE agenda.sp_horarios_libres(IN p_fecha DATE, IN p_protocolos_csv VARCHAR(200), IN p_id_profesional INT)
BEGIN
    DECLARE v_pedidos INT DEFAULT 0;
    DECLARE v_n INT DEFAULT 0;
    DECLARE v_dur INT DEFAULT 0;
    DECLARE v_cancelado INT;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_pedidos = -1;

    IF p_fecha IS NOT NULL AND p_protocolos_csv IS NOT NULL AND TRIM(p_protocolos_csv) <> '' THEN
        SELECT COUNT(DISTINCT jt.id) INTO v_pedidos
          FROM JSON_TABLE(CONCAT('[', p_protocolos_csv, ']'), '$[*]' COLUMNS (id INT PATH '$')) jt;
        SELECT COUNT(*), COALESCE(SUM(p.duracion_min), 0) INTO v_n, v_dur
          FROM clinica.Protocolo p
         WHERE p.activo = 1
           AND p.id_protocolo IN (SELECT DISTINCT jt.id FROM JSON_TABLE(CONCAT('[', p_protocolos_csv, ']'), '$[*]' COLUMNS (id INT PATH '$')) jt);
    END IF;
    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';

    IF v_pedidos <= 0 OR v_n <> v_pedidos OR v_dur <= 0 THEN
        SELECT NULL AS id_profesional, NULL AS profesional, NULL AS inicio, NULL AS fin FROM DUAL WHERE 1 = 0;
    ELSE
        WITH RECURSIVE slots AS (
            SELECT d.id_profesional, TIMESTAMP(d.fecha, d.hora_inicio) AS inicio, TIMESTAMP(d.fecha, d.hora_fin) AS fin_franja
              FROM personas.Disponibilidad d
             WHERE d.fecha = p_fecha AND d.activa = 1 AND (p_id_profesional IS NULL OR d.id_profesional = p_id_profesional)
            UNION ALL
            SELECT s.id_profesional, s.inicio + INTERVAL 30 MINUTE, s.fin_franja
              FROM slots s
             WHERE s.inicio + INTERVAL 30 MINUTE < s.fin_franja
        )
        SELECT s.id_profesional, CONCAT(pr.apellido, ', ', pr.nombre) AS profesional,
               s.inicio, s.inicio + INTERVAL v_dur MINUTE AS fin
          FROM slots s
          JOIN personas.Profesional pr ON pr.id_profesional = s.id_profesional AND pr.activo = 1
         WHERE s.inicio + INTERVAL v_dur MINUTE <= s.fin_franja
           AND s.inicio > auditoria.fn_ahora()
           AND NOT EXISTS (SELECT 1 FROM agenda.Turno t
                            WHERE t.id_profesional = s.id_profesional AND t.id_estado_turno <> v_cancelado
                              AND t.fecha_hora_inicio < s.inicio + INTERVAL v_dur MINUTE AND t.fecha_hora_fin > s.inicio)
           AND NOT EXISTS (SELECT 1 FROM JSON_TABLE(CONCAT('[', p_protocolos_csv, ']'), '$[*]' COLUMNS (id INT PATH '$')) jt
                            WHERE NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo pp
                                               WHERE pp.id_profesional = s.id_profesional AND pp.id_protocolo = jt.id))
         ORDER BY s.inicio, pr.apellido;
    END IF;
END//

-- Agenda un turno (queda 'pendiente' hasta que se registre la seña).
--   p_protocolos_csv     ids separados por coma, por ejemplo '3,7'
--   p_origen             'terminal', 'web', 'gestion' o 'sistema'
--   p_codigo_cupon       cupón de la paciente (opcional)
--   p_id_cirugia_consulta si no es NULL, el turno es la CONSULTA PREVIA para esa cirugía
-- Devuelve: id = turno, valor = seña a pagar, dato = precio final.
-- Reglas: sin superposición del profesional ni de la paciente (RF-04), dentro de
-- su disponibilidad, solo protocolos que el profesional hace (RF-18), una
-- cirugía solo con una evaluación apta de menos de 6 meses (RF-25), cupón de
-- la paciente, vigente y sin usar (RF-17). Si es una cirugía, la seña de la
-- consulta previa se devuelve.
DROP PROCEDURE IF EXISTS agenda.sp_alta_turno//
CREATE PROCEDURE agenda.sp_alta_turno(
    IN p_id_paciente INT, IN p_id_profesional INT, IN p_inicio DATETIME, IN p_protocolos_csv VARCHAR(200),
    IN p_origen VARCHAR(50), IN p_id_usuario INT, IN p_codigo_cupon VARCHAR(50), IN p_id_cirugia_consulta INT)
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_pedidos INT DEFAULT 0;
    DECLARE v_n INT DEFAULT 0;
    DECLARE v_dur INT DEFAULT 0;
    DECLARE v_cirugias INT DEFAULT 0;
    DECLARE v_fin DATETIME;
    DECLARE v_id_origen INT DEFAULT NULL;
    DECLARE v_id_turno INT;
    DECLARE v_eval INT DEFAULT NULL;
    DECLARE v_cirugia INT DEFAULT NULL;
    DECLARE v_pago_consulta INT DEFAULT NULL;
    DECLARE v_monto_consulta DECIMAL(12,2);
    DECLARE v_cupon INT DEFAULT NULL;
    DECLARE v_cupon_pac INT;
    DECLARE v_cupon_turno INT;
    DECLARE v_cupon_venc DATETIME;
    DECLARE v_cancelado INT;
    DECLARE v_pendiente INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
            CONCAT('Error ', v_errno, ': ', v_msg), 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT id_origen INTO v_id_origen FROM agenda.Origen WHERE nombre = p_origen;
    IF v_id_origen IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52070, MESSAGE_TEXT = 'Origen inválido (terminal, web, gestion o sistema)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM personas.Paciente WHERE id_paciente = p_id_paciente) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52071, MESSAGE_TEXT = 'La paciente no existe';
    END IF;
    IF p_protocolos_csv IS NULL OR TRIM(p_protocolos_csv) = '' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52072, MESSAGE_TEXT = 'El turno necesita al menos un protocolo';
    END IF;
    IF p_inicio IS NULL OR p_inicio <= auditoria.fn_ahora() THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52073, MESSAGE_TEXT = 'El turno debe ser en el futuro';
    END IF;

    -- Se bloquea al profesional: dos reservas simultáneas del mismo horario se atienden de a una.
    SELECT id_profesional INTO v_n FROM personas.Profesional WHERE id_profesional = p_id_profesional AND activo = 1 FOR UPDATE;
    IF v_n = 0 OR v_n IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52074, MESSAGE_TEXT = 'El profesional no existe o está dado de baja';
    END IF;

    SELECT COUNT(DISTINCT jt.id) INTO v_pedidos
      FROM JSON_TABLE(CONCAT('[', p_protocolos_csv, ']'), '$[*]' COLUMNS (id INT PATH '$')) jt;
    SELECT COUNT(*), COALESCE(SUM(p.duracion_min), 0), COALESCE(SUM(c.requiere_evaluacion), 0), MIN(CASE WHEN c.requiere_evaluacion = 1 THEN p.id_protocolo END)
      INTO v_n, v_dur, v_cirugias, v_cirugia
      FROM clinica.Protocolo p JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
     WHERE p.activo = 1
       AND p.id_protocolo IN (SELECT DISTINCT jt.id FROM JSON_TABLE(CONCAT('[', p_protocolos_csv, ']'), '$[*]' COLUMNS (id INT PATH '$')) jt);
    IF v_pedidos = 0 OR v_n <> v_pedidos THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52075, MESSAGE_TEXT = 'Algún protocolo no existe o está dado de baja';
    END IF;
    IF EXISTS (SELECT 1 FROM JSON_TABLE(CONCAT('[', p_protocolos_csv, ']'), '$[*]' COLUMNS (id INT PATH '$')) jt
                WHERE NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo pp
                                   WHERE pp.id_profesional = p_id_profesional AND pp.id_protocolo = jt.id)) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52076, MESSAGE_TEXT = 'El profesional no realiza alguno de los protocolos pedidos';
    END IF;
    IF v_cirugias > 1 OR (v_cirugias = 1 AND v_n > 1) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52077, MESSAGE_TEXT = 'Una cirugía se agenda sola, sin otros protocolos';
    END IF;
    IF p_id_cirugia_consulta IS NOT NULL THEN
        IF v_cirugias > 0 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52078, MESSAGE_TEXT = 'La consulta previa no puede incluir una cirugía';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM clinica.Protocolo p JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
                        WHERE p.id_protocolo = p_id_cirugia_consulta AND p.activo = 1 AND c.requiere_evaluacion = 1) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52079, MESSAGE_TEXT = 'La consulta previa debe ser para una cirugía existente';
        END IF;
    END IF;

    SET v_fin = p_inicio + INTERVAL v_dur MINUTE;
    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';
    SELECT id_estado_turno INTO v_pendiente FROM agenda.EstadoTurno WHERE nombre = 'pendiente';

    IF NOT EXISTS (SELECT 1 FROM personas.Disponibilidad d
                    WHERE d.id_profesional = p_id_profesional AND d.activa = 1 AND d.fecha = DATE(p_inicio)
                      AND DATE(v_fin) = DATE(p_inicio) AND d.hora_inicio <= TIME(p_inicio) AND d.hora_fin >= TIME(v_fin)) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52080, MESSAGE_TEXT = 'El horario está fuera de la disponibilidad del profesional';
    END IF;
    IF EXISTS (SELECT 1 FROM agenda.Turno t WHERE t.id_profesional = p_id_profesional AND t.id_estado_turno <> v_cancelado
                  AND t.fecha_hora_inicio < v_fin AND t.fecha_hora_fin > p_inicio) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52081, MESSAGE_TEXT = 'El profesional ya tiene un turno en ese horario';
    END IF;
    IF EXISTS (SELECT 1 FROM agenda.Turno t WHERE t.id_paciente = p_id_paciente AND t.id_estado_turno <> v_cancelado
                  AND t.fecha_hora_inicio < v_fin AND t.fecha_hora_fin > p_inicio) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52082, MESSAGE_TEXT = 'La paciente ya tiene un turno en ese horario';
    END IF;

    -- Cirugía: hace falta una evaluación apta, de menos de 6 meses y sin usar.
    IF v_cirugias = 1 THEN
        SELECT ev.id_evaluacion INTO v_eval
          FROM clinica.EvaluacionPrevia ev
          JOIN agenda.Turno tc ON tc.id_turno = ev.id_turno
          JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
         WHERE tc.id_paciente = p_id_paciente AND ev.id_protocolo = v_cirugia AND r.nombre = 'apto'
           AND ev.fecha_resultado + INTERVAL 6 MONTH >= auditoria.fn_ahora()
           AND NOT EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = ev.id_evaluacion AND t2.id_estado_turno <> v_cancelado)
         ORDER BY ev.fecha_resultado DESC LIMIT 1;
        IF v_eval IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52083, MESSAGE_TEXT = 'La cirugía necesita una consulta previa con resultado apto de menos de 6 meses';
        END IF;
    END IF;

    -- Cupón (opcional): de la paciente, vigente y sin usar.
    IF p_codigo_cupon IS NOT NULL AND TRIM(p_codigo_cupon) <> '' THEN
        SELECT id_cupon, id_paciente, id_turno, fecha_vencimiento INTO v_cupon, v_cupon_pac, v_cupon_turno, v_cupon_venc
          FROM beneficios.Cupon WHERE codigo = TRIM(p_codigo_cupon) FOR UPDATE;
        IF v_cupon IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52084, MESSAGE_TEXT = 'El cupón no existe';
        END IF;
        IF v_cupon_pac <> p_id_paciente THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52085, MESSAGE_TEXT = 'El cupón es de otra paciente';
        END IF;
        IF v_cupon_turno IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52086, MESSAGE_TEXT = 'El cupón ya fue usado';
        END IF;
        IF v_cupon_venc <= auditoria.fn_ahora() THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 52087, MESSAGE_TEXT = 'El cupón está vencido';
        END IF;
    END IF;

    INSERT INTO agenda.Turno (id_paciente, id_profesional, id_estado_turno, id_origen, id_evaluacion_previa,
                              fecha_hora_inicio, fecha_hora_fin, fecha_creacion)
    VALUES (p_id_paciente, p_id_profesional, v_pendiente, v_id_origen, v_eval, p_inicio, v_fin, auditoria.fn_ahora());
    SET v_id_turno = LAST_INSERT_ID();

    INSERT INTO agenda.TurnoProtocolo (id_turno, id_protocolo, precio_aplicado)
    SELECT v_id_turno, p.id_protocolo, p.precio
      FROM clinica.Protocolo p
     WHERE p.id_protocolo IN (SELECT DISTINCT jt.id FROM JSON_TABLE(CONCAT('[', p_protocolos_csv, ']'), '$[*]' COLUMNS (id INT PATH '$')) jt);

    IF v_cupon IS NOT NULL THEN
        UPDATE beneficios.Cupon SET id_turno = v_id_turno WHERE id_cupon = v_cupon;
        CALL auditoria.sp_registrar_log('cupon_validado', p_id_usuario, p_id_paciente, p_origen,
            CONCAT('Cupón ', TRIM(p_codigo_cupon), ' aplicado al turno ', v_id_turno), 'beneficios.Cupon', v_cupon, NULL, NULL, 1, NULL);
    END IF;

    IF p_id_cirugia_consulta IS NOT NULL THEN
        INSERT INTO clinica.EvaluacionPrevia (id_turno, id_protocolo, id_resultado)
        VALUES (v_id_turno, p_id_cirugia_consulta, (SELECT id_resultado FROM clinica.ResultadoEvaluacion WHERE nombre = 'pendiente'));
    END IF;

    IF v_eval IS NOT NULL THEN
        -- La paciente pasa a la cirugía: se le devuelve la seña de la consulta.
        SELECT ps.id_pago, ps.monto INTO v_pago_consulta, v_monto_consulta
          FROM clinica.EvaluacionPrevia ev JOIN pagos.PagoSena ps ON ps.id_turno = ev.id_turno
          JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago AND ep.nombre = 'pagada'
         WHERE ev.id_evaluacion = v_eval;
        IF v_pago_consulta IS NOT NULL THEN
            CALL pagos.sp_aplicar_reembolso(v_pago_consulta, v_monto_consulta, 'reembolsada',
                                            'Devolución de la consulta previa al agendar la cirugía', p_id_usuario, p_origen);
        END IF;
    END IF;

    CALL auditoria.sp_registrar_log('alta_turno', p_id_usuario, p_id_paciente, p_origen,
        CONCAT('Turno ', v_id_turno, ' con el profesional ', p_id_profesional, ' el ', p_inicio, ' (protocolos ', p_protocolos_csv, ')'),
        'agenda.Turno', v_id_turno, NULL, CONCAT('inicio=', p_inicio, ';fin=', v_fin), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Turno agendado' AS mensaje, v_id_turno AS id,
           agenda.fn_sena(v_id_turno) AS valor, CAST(agenda.fn_precio_final(v_id_turno) AS CHAR) AS dato;
END//

-- Busca turnos por DNI, teléfono, nombre o apellido (RF-12, RF-13, RF-16).
-- p_solo_vigentes = 1 muestra solo los pendientes o confirmados futuros.
-- Con texto NULL, vacío o de menos de 3 caracteres no devuelve nada.
-- Cada fila trae también el teléfono, la seña, el código de operación y el
-- último recordatorio del turno (canal, estado y cuándo sale).
DROP PROCEDURE IF EXISTS agenda.sp_buscar_turnos//
CREATE PROCEDURE agenda.sp_buscar_turnos(IN p_texto VARCHAR(100), IN p_solo_vigentes TINYINT)
BEGIN
    DECLARE v_texto VARCHAR(100) DEFAULT TRIM(COALESCE(p_texto, ''));
    SELECT t.id_turno, p.id_paciente, CONCAT(p.apellido, ', ', p.nombre) AS paciente, p.dni,
           (SELECT tp2.telefono FROM personas.TelefonoPaciente tp2 WHERE tp2.id_paciente = p.id_paciente ORDER BY tp2.id_telefono_paciente LIMIT 1) AS telefono,
           CONCAT(pr.apellido, ', ', pr.nombre) AS profesional, t.fecha_hora_inicio, t.fecha_hora_fin,
           e.nombre AS estado, o.nombre AS origen,
           (SELECT GROUP_CONCAT(pt.nombre ORDER BY pt.nombre SEPARATOR ' + ')
              FROM agenda.TurnoProtocolo tp JOIN clinica.Protocolo pt ON pt.id_protocolo = tp.id_protocolo
             WHERE tp.id_turno = t.id_turno) AS protocolos,
           agenda.fn_precio_final(t.id_turno) AS precio_final,
           agenda.fn_sena(t.id_turno) AS sena,
           COALESCE(ep.nombre, 'sin seña') AS estado_sena,
           ps.codigo_operacion,
           ca.nombre AS recordatorio_canal, es.nombre AS recordatorio_estado, nr.fecha_programada AS recordatorio_programado
      FROM agenda.Turno t
      JOIN personas.Paciente p ON p.id_paciente = t.id_paciente
      JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
      JOIN agenda.Origen o ON o.id_origen = t.id_origen
      LEFT JOIN pagos.PagoSena ps ON ps.id_turno = t.id_turno
      LEFT JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
      LEFT JOIN notificaciones.Notificacion nr ON nr.id_notificacion =
            (SELECT n.id_notificacion FROM notificaciones.Notificacion n
               JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion AND tn.nombre = 'recordatorio de turno'
              WHERE n.id_turno = t.id_turno ORDER BY n.id_notificacion DESC LIMIT 1)
      LEFT JOIN notificaciones.CanalNotificacion ca ON ca.id_canal = nr.id_canal
      LEFT JOIN notificaciones.EstadoNotificacion es ON es.id_estado_notificacion = nr.id_estado_notificacion
     WHERE CHAR_LENGTH(v_texto) >= 3
       AND (p.dni = v_texto
            OR p.nombre LIKE CONCAT('%', v_texto, '%') OR p.apellido LIKE CONCAT('%', v_texto, '%')
            OR CONCAT(p.nombre, ' ', p.apellido) LIKE CONCAT('%', v_texto, '%')
            OR EXISTS (SELECT 1 FROM personas.TelefonoPaciente tp3 WHERE tp3.id_paciente = p.id_paciente AND tp3.telefono = v_texto))
       AND (COALESCE(p_solo_vigentes, 0) = 0 OR (e.nombre IN ('pendiente', 'confirmado') AND t.fecha_hora_inicio > auditoria.fn_ahora()))
     ORDER BY t.fecha_hora_inicio DESC;
END//

-- Agenda de un período: todos los turnos con fecha de inicio entre p_desde y
-- p_hasta (inclusive), con las mismas columnas que sp_buscar_turnos. Lo usan la
-- pantalla de inicio y "Buscar turnos" sin texto. Con fechas NULL o invertidas: 0 filas.
DROP PROCEDURE IF EXISTS agenda.sp_turnos_del_periodo//
CREATE PROCEDURE agenda.sp_turnos_del_periodo(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT t.id_turno, p.id_paciente, CONCAT(p.apellido, ', ', p.nombre) AS paciente, p.dni,
           (SELECT tp2.telefono FROM personas.TelefonoPaciente tp2 WHERE tp2.id_paciente = p.id_paciente ORDER BY tp2.id_telefono_paciente LIMIT 1) AS telefono,
           CONCAT(pr.apellido, ', ', pr.nombre) AS profesional, t.fecha_hora_inicio, t.fecha_hora_fin,
           e.nombre AS estado, o.nombre AS origen,
           (SELECT GROUP_CONCAT(pt.nombre ORDER BY pt.nombre SEPARATOR ' + ')
              FROM agenda.TurnoProtocolo tp JOIN clinica.Protocolo pt ON pt.id_protocolo = tp.id_protocolo
             WHERE tp.id_turno = t.id_turno) AS protocolos,
           agenda.fn_precio_final(t.id_turno) AS precio_final,
           agenda.fn_sena(t.id_turno) AS sena,
           COALESCE(ep.nombre, 'sin seña') AS estado_sena,
           ps.codigo_operacion,
           ca.nombre AS recordatorio_canal, es.nombre AS recordatorio_estado, nr.fecha_programada AS recordatorio_programado
      FROM agenda.Turno t
      JOIN personas.Paciente p ON p.id_paciente = t.id_paciente
      JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
      JOIN agenda.Origen o ON o.id_origen = t.id_origen
      LEFT JOIN pagos.PagoSena ps ON ps.id_turno = t.id_turno
      LEFT JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
      LEFT JOIN notificaciones.Notificacion nr ON nr.id_notificacion =
            (SELECT n.id_notificacion FROM notificaciones.Notificacion n
               JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion AND tn.nombre = 'recordatorio de turno'
              WHERE n.id_turno = t.id_turno ORDER BY n.id_notificacion DESC LIMIT 1)
      LEFT JOIN notificaciones.CanalNotificacion ca ON ca.id_canal = nr.id_canal
      LEFT JOIN notificaciones.EstadoNotificacion es ON es.id_estado_notificacion = nr.id_estado_notificacion
     WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
     ORDER BY t.fecha_hora_inicio, t.id_turno;
END//

-- Todas las pacientes, para la pantalla Pacientes (primer teléfono y si tienen cuenta).
DROP PROCEDURE IF EXISTS personas.sp_listar_pacientes//
CREATE PROCEDURE personas.sp_listar_pacientes()
BEGIN
    SELECT p.id_paciente, p.dni, p.nombre, p.apellido, p.fecha_nacimiento, p.email,
           (SELECT tp.telefono FROM personas.TelefonoPaciente tp WHERE tp.id_paciente = p.id_paciente ORDER BY tp.id_telefono_paciente LIMIT 1) AS telefono,
           (p.id_usuario IS NOT NULL) AS tiene_cuenta
      FROM personas.Paciente p
     ORDER BY p.apellido, p.nombre;
END//

-- Todos los profesionales, para la pantalla Profesionales.
DROP PROCEDURE IF EXISTS personas.sp_listar_profesionales//
CREATE PROCEDURE personas.sp_listar_profesionales()
BEGIN
    SELECT pr.id_profesional, pr.nombre, pr.apellido, pr.matricula, pr.email, pr.activo
      FROM personas.Profesional pr
     ORDER BY pr.apellido, pr.nombre;
END//

-- Qué protocolos hace cada profesional (RF-18): un par por fila.
DROP PROCEDURE IF EXISTS clinica.sp_listar_profesional_protocolo//
CREATE PROCEDURE clinica.sp_listar_profesional_protocolo()
BEGIN
    SELECT pp.id_profesional, pp.id_protocolo FROM clinica.ProfesionalProtocolo pp ORDER BY pp.id_profesional, pp.id_protocolo;
END//

-- Franjas de atención activas desde p_desde en adelante (RF-03).
DROP PROCEDURE IF EXISTS personas.sp_listar_disponibilidad//
CREATE PROCEDURE personas.sp_listar_disponibilidad(IN p_desde DATE)
BEGIN
    SELECT d.id_disponibilidad, d.id_profesional, d.fecha, d.hora_inicio, d.hora_fin
      FROM personas.Disponibilidad d
     WHERE d.activa = 1 AND d.fecha >= p_desde
     ORDER BY d.id_profesional, d.fecha, d.hora_inicio;
END//

-- Avisos (notificaciones) de un período, para la pantalla Avisos.
DROP PROCEDURE IF EXISTS notificaciones.sp_listar_notificaciones//
CREATE PROCEDURE notificaciones.sp_listar_notificaciones(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT n.id_notificacion, n.id_turno, c.nombre AS canal, e.nombre AS estado, tn.nombre AS tipo, n.mensaje,
           n.fecha_programada, n.fecha_envio, n.intentos, n.detalle_error,
           CONCAT(p.apellido, ', ', p.nombre) AS paciente, p.dni,
           (SELECT tp.telefono FROM personas.TelefonoPaciente tp WHERE tp.id_paciente = p.id_paciente ORDER BY tp.id_telefono_paciente LIMIT 1) AS telefono,
           t.fecha_hora_inicio
      FROM notificaciones.Notificacion n
      JOIN notificaciones.CanalNotificacion c ON c.id_canal = n.id_canal
      JOIN notificaciones.EstadoNotificacion e ON e.id_estado_notificacion = n.id_estado_notificacion
      JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion
      JOIN personas.Paciente p ON p.id_paciente = n.id_paciente
      LEFT JOIN agenda.Turno t ON t.id_turno = n.id_turno
     WHERE n.fecha_programada >= p_desde AND n.fecha_programada < p_hasta + INTERVAL 1 DAY
     ORDER BY n.fecha_programada, n.id_notificacion;
END//

DELIMITER ;
