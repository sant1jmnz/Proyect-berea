-- Dermalia - Proyecto Informático I - Bases de Datos - Hito 2 (entrega final)
-- MySQL 8. Orden correcto: 03_ModeloSQL, 04_DatosSQL, 05_Backend (la secuencia se puede repetir).
--
-- Punto 5: funcionalidades en stored procedures, 8 reportes, auditoría con parámetros y los
-- dos reportes con versión _tuneado. Se corre después del 04; se puede repetir (DROP ... IF EXISTS).

-- ======================================================================
-- Tabla auxiliar de números
-- ======================================================================


-- ---------------------------------------------------------------------
-- Origen: 02b_numero.sql
-- ---------------------------------------------------------------------

-- Dermalia: tabla auxiliar de números (0 a 47) del backend.
-- Reemplaza a las consultas recursivas (WITH RECURSIVE), que el material de la cátedra no enseña:
-- los stored procedures la usan para partir una franja horaria en turnos de 30 minutos
-- (agenda.sp_horarios_libres) y para emitir un cupón por cada múltiplo del gasto
-- (beneficios.sp_emitir_cupones). No es una entidad del modelo: vive con el backend.
-- Se puede correr varias veces: solo agrega los números que faltan.

CREATE TABLE IF NOT EXISTS agenda.Numero (
    n INT PRIMARY KEY
);

INSERT INTO agenda.Numero (n)
SELECT v.n
  FROM (SELECT 0 AS n
    UNION ALL SELECT 1
    UNION ALL SELECT 2
    UNION ALL SELECT 3
    UNION ALL SELECT 4
    UNION ALL SELECT 5
    UNION ALL SELECT 6
    UNION ALL SELECT 7
    UNION ALL SELECT 8
    UNION ALL SELECT 9
    UNION ALL SELECT 10
    UNION ALL SELECT 11
    UNION ALL SELECT 12
    UNION ALL SELECT 13
    UNION ALL SELECT 14
    UNION ALL SELECT 15
    UNION ALL SELECT 16
    UNION ALL SELECT 17
    UNION ALL SELECT 18
    UNION ALL SELECT 19
    UNION ALL SELECT 20
    UNION ALL SELECT 21
    UNION ALL SELECT 22
    UNION ALL SELECT 23
    UNION ALL SELECT 24
    UNION ALL SELECT 25
    UNION ALL SELECT 26
    UNION ALL SELECT 27
    UNION ALL SELECT 28
    UNION ALL SELECT 29
    UNION ALL SELECT 30
    UNION ALL SELECT 31
    UNION ALL SELECT 32
    UNION ALL SELECT 33
    UNION ALL SELECT 34
    UNION ALL SELECT 35
    UNION ALL SELECT 36
    UNION ALL SELECT 37
    UNION ALL SELECT 38
    UNION ALL SELECT 39
    UNION ALL SELECT 40
    UNION ALL SELECT 41
    UNION ALL SELECT 42
    UNION ALL SELECT 43
    UNION ALL SELECT 44
    UNION ALL SELECT 45
    UNION ALL SELECT 46
    UNION ALL SELECT 47
       ) v
 WHERE NOT EXISTS (SELECT 1 FROM agenda.Numero x WHERE x.n = v.n);

-- ======================================================================
-- Funciones y stored procedures: seguridad, personas, clínica, agenda, protocolos
-- ======================================================================


-- ---------------------------------------------------------------------
-- Origen: 03_sp_semana3.sql
-- ---------------------------------------------------------------------

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
--   * las reglas de negocio se avisan con una fila 'ERROR' y un código propio (52xxx), y el SP termina con LEAVE;
--     el catálogo de códigos está en docs/11-pruebas-bbdd.md.
--   * toda acción relevante escribe en auditoria.Log SOLO desde acá.
-- Los SP de consulta (listados, búsquedas, reportes) devuelven directamente
-- el conjunto de filas.

DELIMITER //

-- =====================================================================
--  AUXILIARES
-- =====================================================================

-- Escribe una fila en el log. Nunca falla: si el tipo de evento no existe no
-- escribe nada, y un usuario o paciente inexistente queda como NULL.
DROP PROCEDURE IF EXISTS auditoria.sp_registrar_log//
CREATE PROCEDURE auditoria.sp_registrar_log(
    IN p_tipo VARCHAR(50), IN p_id_usuario INT, IN p_id_paciente INT, IN p_origen VARCHAR(50),
    IN p_descripcion VARCHAR(2000), IN p_tabla VARCHAR(100), IN p_id_registro INT,
    IN p_anterior TEXT, IN p_nuevo TEXT, IN p_exitoso SMALLINT, IN p_ip VARCHAR(45), IN p_registrar SMALLINT)
BEGIN
    INSERT INTO auditoria.Log (id_tipo_evento, id_usuario, id_paciente, id_origen, fecha_hora, descripcion,
                               ip_origen, tabla_afectada, id_registro_afectado, valor_anterior, valor_nuevo, exitoso)
    SELECT te.id_tipo_evento,
           (SELECT u.id_usuario FROM seguridad.Usuario u WHERE u.id_usuario = p_id_usuario),
           (SELECT p.id_paciente FROM personas.Paciente p WHERE p.id_paciente = p_id_paciente),
           COALESCE((SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = p_origen),
                    (SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = 'sistema')),
           COALESCE(@ahora_simulado, NOW()), CAST(p_descripcion AS CHAR(500)), p_ip, p_tabla, p_id_registro,
           p_anterior, p_nuevo, COALESCE(p_exitoso, 1)
    FROM auditoria.TipoEvento te
    WHERE te.nombre = p_tipo AND p_registrar = 1;
END//

-- Cambia el estado de un pago de seña y, si se pagó con tarjeta de regalo,
-- devuelve el saldo (movimiento negativo). Lo usan la cancelación, las
-- inasistencias y las evaluaciones. No devuelve filas: es interno.
-- p_estado: 'reembolsada', 'reembolsada parcial' o 'retenida'.
DROP PROCEDURE IF EXISTS pagos.sp_aplicar_reembolso//
CREATE PROCEDURE pagos.sp_aplicar_reembolso(
    IN p_id_pago INT, IN p_monto_reembolsado DECIMAL(12,2), IN p_estado VARCHAR(50),
    IN p_motivo VARCHAR(200), IN p_id_usuario INT, IN p_origen VARCHAR(50), IN p_ejecutar SMALLINT)
BEGIN
    -- SP interno: lo usan otros SP. Con p_ejecutar = 0 no hace nada; así quien lo llama decide,
    -- sin IF, si se reembolsa o se retiene (llama dos veces, cada una con su condición).
    -- No devuelve filas (para no mezclarse con la respuesta de quien lo llama): deja el resultado
    -- en @reembolso_codigo (NULL = se hizo, 0 = no se ejecutó, 52xxx = no se pudo) y @reembolso_mensaje.
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_monto DECIMAL(12,2);
    DECLARE v_estado VARCHAR(50);
    DECLARE v_medio VARCHAR(50);
    DECLARE v_turno INT;
    DECLARE v_paciente INT;

    SET v_codigo = (SELECT 0 FROM DUAL WHERE COALESCE(p_ejecutar, 0) <> 1);
    SELECT ps.monto, ep.nombre, mp.nombre, ps.id_turno, t.id_paciente
      INTO v_monto, v_estado, v_medio, v_turno, v_paciente
      FROM pagos.PagoSena ps
      JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
      JOIN pagos.MedioPago mp ON mp.id_medio_pago = ps.id_medio_pago
      JOIN agenda.Turno t ON t.id_turno = ps.id_turno
     WHERE ps.id_pago = p_id_pago;

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El pago de seña no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_monto IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52100 FROM DUAL WHERE v_monto IS NULL));
    -- Solo se resuelve una seña 'pagada'. Única excepción: una seña retenida al vencer
    -- una evaluación puede pasar a 'reembolsada parcial' si la paciente reclama.
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La seña ya fue resuelta (reembolsada o retenida)' FROM DUAL WHERE v_codigo IS NULL AND (v_estado <> 'pagada' AND NOT (v_estado = 'retenida' AND p_estado = 'reembolsada parcial'))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52101 FROM DUAL WHERE v_estado <> 'pagada' AND NOT (v_estado = 'retenida' AND p_estado = 'reembolsada parcial')));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El monto a reembolsar no es válido' FROM DUAL WHERE v_codigo IS NULL AND (p_monto_reembolsado IS NULL OR p_monto_reembolsado < 0 OR p_monto_reembolsado > v_monto)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52102 FROM DUAL WHERE p_monto_reembolsado IS NULL OR p_monto_reembolsado < 0 OR p_monto_reembolsado > v_monto));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Estado de pago inválido' FROM DUAL WHERE v_codigo IS NULL AND (p_estado NOT IN ('reembolsada', 'reembolsada parcial', 'retenida'))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52103 FROM DUAL WHERE p_estado NOT IN ('reembolsada', 'reembolsada parcial', 'retenida')));

    UPDATE pagos.PagoSena
       SET id_estado_pago = (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre = p_estado),
           monto_reembolsado = p_monto_reembolsado,
           fecha_resolucion = COALESCE(@ahora_simulado, NOW())
     WHERE id_pago = p_id_pago AND v_codigo IS NULL;

    -- Si la seña se había pagado con tarjeta de regalo, lo reembolsado vuelve a la tarjeta.
    INSERT INTO pagos.MovimientoTarjeta (id_tarjeta, id_turno, monto, fecha_movimiento)
    SELECT m.id_tarjeta, v_turno, -p_monto_reembolsado, COALESCE(@ahora_simulado, NOW())
      FROM pagos.MovimientoTarjeta m
     WHERE m.id_turno = v_turno AND m.monto > 0
       AND m.id_movimiento = (SELECT MIN(m2.id_movimiento) FROM pagos.MovimientoTarjeta m2 WHERE m2.id_turno = v_turno AND m2.monto > 0)
       AND v_codigo IS NULL AND v_medio = 'tarjeta de regalo' AND p_monto_reembolsado > 0;

    CALL auditoria.sp_registrar_log(COALESCE((SELECT 'reembolso' FROM DUAL WHERE p_monto_reembolsado > 0), 'retencion'), p_id_usuario, v_paciente, p_origen,
        CONCAT(p_motivo, ': reembolsado $', p_monto_reembolsado, ' de $', v_monto, ' (', p_estado, ')'),
        'pagos.PagoSena', p_id_pago, CONCAT('estado=', v_estado, ';reembolsado=0'),
        CONCAT('estado=', p_estado, ';reembolsado=', p_monto_reembolsado), 1, NULL, v_codigo IS NULL);
    SET @reembolso_codigo = v_codigo;
    SET @reembolso_mensaje = v_mensaje;
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
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_desc_log VARCHAR(100) DEFAULT NULL;
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_password VARCHAR(255);
    DECLARE v_rol VARCHAR(50);
    DECLARE v_fallidos INT DEFAULT 0;
    DECLARE v_paciente INT DEFAULT NULL;
    DECLARE v_profesional INT DEFAULT NULL;

    SELECT u.id_usuario, u.password, r.nombre
      INTO v_id, v_password, v_rol
      FROM seguridad.Usuario u JOIN seguridad.Rol r ON r.id_rol = u.id_rol
     WHERE u.nombre_usuario = p_usuario AND u.activo = 1;
    -- Intentos fallidos de los últimos 15 minutos, contados desde el último ingreso correcto.
    SELECT COUNT(*) INTO v_fallidos
      FROM auditoria.Log l JOIN auditoria.TipoEvento te ON te.id_tipo_evento = l.id_tipo_evento
     WHERE te.nombre = 'intento_fallido' AND l.id_usuario = v_id
       AND l.fecha_hora >= COALESCE(@ahora_simulado, NOW()) - INTERVAL 15 MINUTE
       AND l.fecha_hora > COALESCE((SELECT MAX(l2.fecha_hora) FROM auditoria.Log l2
                                     JOIN auditoria.TipoEvento t2 ON t2.id_tipo_evento = l2.id_tipo_evento
                                    WHERE t2.nombre = 'inicio_sesion' AND l2.id_usuario = v_id), '1970-01-01');

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Falta el usuario o la contraseña' FROM DUAL WHERE v_codigo IS NULL
                                         AND (p_usuario IS NULL OR p_usuario = '' OR p_password IS NULL OR p_password = '')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52010 FROM DUAL WHERE p_usuario IS NULL OR p_usuario = '' OR p_password IS NULL OR p_password = ''));
    SET v_desc_log = COALESCE(v_desc_log, (SELECT 'Usuario inexistente o inactivo' FROM DUAL WHERE v_codigo IS NULL AND v_id IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Usuario o contraseña incorrectos' FROM DUAL WHERE v_codigo IS NULL AND v_id IS NULL));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52011 FROM DUAL WHERE v_id IS NULL));
    SET v_desc_log = COALESCE(v_desc_log, (SELECT 'Cuenta bloqueada por intentos fallidos' FROM DUAL WHERE v_codigo IS NULL AND v_fallidos >= 5));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Cuenta bloqueada 15 minutos por demasiados intentos' FROM DUAL WHERE v_codigo IS NULL AND v_fallidos >= 5));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52012 FROM DUAL WHERE v_fallidos >= 5));
    SET v_desc_log = COALESCE(v_desc_log, (SELECT 'Contraseña incorrecta' FROM DUAL WHERE v_codigo IS NULL AND v_password <> p_password));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Usuario o contraseña incorrectos' FROM DUAL WHERE v_codigo IS NULL AND v_password <> p_password));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52011 FROM DUAL WHERE v_password <> p_password));

    SELECT id_paciente INTO v_paciente FROM personas.Paciente WHERE id_usuario = v_id AND v_codigo IS NULL;
    SELECT id_profesional INTO v_profesional FROM personas.Profesional WHERE id_usuario = v_id AND v_codigo IS NULL;
    -- Si faltan los datos (52010) no se registra nada; si el usuario no existe, el intento queda sin usuario.
    CALL auditoria.sp_registrar_log('intento_fallido', v_id, NULL, p_origen, v_desc_log, 'seguridad.Usuario', v_id, NULL, NULL, 0, p_ip,
                                    v_codigo IN (52011, 52012));
    CALL auditoria.sp_registrar_log('inicio_sesion', v_id, v_paciente, p_origen,
        CONCAT('Ingreso como ', v_rol), 'seguridad.Usuario', v_id, NULL, NULL, 1, p_ip, v_codigo IS NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Ingreso correcto' AS mensaje, v_id AS id,
           COALESCE(v_paciente, v_profesional) AS valor, v_rol AS dato
      FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, (SELECT v_id FROM DUAL WHERE v_codigo = 52012), NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Cierre de sesión: solo deja el evento 'cierre_sesion' en el log (la app
-- es quien cierra la ventana). Devuelve error si el usuario no existe.
DROP PROCEDURE IF EXISTS seguridad.sp_cerrar_sesion//
CREATE PROCEDURE seguridad.sp_cerrar_sesion(IN p_id_usuario INT, IN p_origen VARCHAR(50), IN p_ip VARCHAR(45))
BEGIN
    DECLARE v_existe SMALLINT;
    SET v_existe = EXISTS (SELECT 1 FROM seguridad.Usuario WHERE id_usuario = p_id_usuario);
    CALL auditoria.sp_registrar_log('cierre_sesion', p_id_usuario, NULL, p_origen, 'Cierre de sesión',
                                    'seguridad.Usuario', p_id_usuario, NULL, NULL, 1, p_ip, v_existe);
    SELECT 'OK' AS estado, 0 AS codigo, 'Sesión cerrada' AS mensaje, p_id_usuario AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_existe = 1
    UNION ALL
    SELECT 'ERROR', 52013, 'El usuario no existe', NULL, NULL, NULL FROM DUAL WHERE v_existe = 0;
END//

-- Cuenta opcional de una paciente (RF-15): se vincula con su DNI.
DROP PROCEDURE IF EXISTS seguridad.sp_crear_cuenta_paciente//
CREATE PROCEDURE seguridad.sp_crear_cuenta_paciente(
    IN p_dni VARCHAR(15), IN p_nombre_usuario VARCHAR(50), IN p_email VARCHAR(100),
    IN p_password VARCHAR(255), IN p_origen VARCHAR(50))
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_paciente INT DEFAULT NULL;
    DECLARE v_cuenta INT DEFAULT NULL;
    DECLARE v_usuario INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cuenta_creada', NULL, v_paciente, p_origen, v_msg,
                                        'seguridad.Usuario', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT id_paciente, id_usuario INTO v_paciente, v_cuenta FROM personas.Paciente WHERE dni = p_dni;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'No hay una paciente con ese DNI' FROM DUAL WHERE v_codigo IS NULL AND (v_paciente IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52020 FROM DUAL WHERE v_paciente IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Esa paciente ya tiene cuenta' FROM DUAL WHERE v_codigo IS NULL AND (v_cuenta IS NOT NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52021 FROM DUAL WHERE v_cuenta IS NOT NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo' FROM DUAL WHERE v_codigo IS NULL AND (p_nombre_usuario IS NULL OR (CHAR_LENGTH(p_nombre_usuario) BETWEEN 4 AND 50) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52022 FROM DUAL WHERE p_nombre_usuario IS NULL OR (CHAR_LENGTH(p_nombre_usuario) BETWEEN 4 AND 50) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El email no es válido' FROM DUAL WHERE v_codigo IS NULL AND (p_email IS NULL OR (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52023 FROM DUAL WHERE p_email IS NULL OR (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La contrasena no puede estar vacia' FROM DUAL WHERE v_codigo IS NULL AND (p_password IS NULL OR p_password = '')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52024 FROM DUAL WHERE p_password IS NULL OR p_password = ''));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Ese usuario o email ya está en uso' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario OR email = p_email))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52025 FROM DUAL WHERE EXISTS (SELECT 1 FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario OR email = p_email)));

    START TRANSACTION;
    INSERT INTO seguridad.Usuario (id_rol, nombre_usuario, email, password)
    SELECT (SELECT id_rol FROM seguridad.Rol WHERE nombre = 'paciente'), p_nombre_usuario, p_email, p_password FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_usuario) INTO v_usuario FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario;
    UPDATE personas.Paciente SET id_usuario = v_usuario WHERE id_paciente = v_paciente AND v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('cuenta_creada', v_usuario, v_paciente, p_origen, 'Cuenta de paciente creada',
                                    'seguridad.Usuario', v_usuario, NULL, p_nombre_usuario, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('cuenta_creada', NULL, v_paciente, p_origen, v_mensaje,
                                        'seguridad.Usuario', NULL, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Cuenta creada' AS mensaje, v_usuario AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
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
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, v_msg,
                                        'personas.Paciente', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    -- Un dato opcional vacío ('') se toma como no informado (NULL).
    SET p_email = (SELECT p_email FROM DUAL WHERE p_email <> '');

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El DNI debe tener 7 u 8 dígitos' FROM DUAL WHERE v_codigo IS NULL AND (p_dni IS NULL OR (CHAR_LENGTH(p_dni) BETWEEN 7 AND 8 AND CAST(CAST(p_dni AS UNSIGNED) AS CHAR) = p_dni) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52030 FROM DUAL WHERE p_dni IS NULL OR (CHAR_LENGTH(p_dni) BETWEEN 7 AND 8 AND CAST(CAST(p_dni AS UNSIGNED) AS CHAR) = p_dni) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Nombre y apellido deben tener al menos 2 letras' FROM DUAL WHERE v_codigo IS NULL AND (p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(p_apellido) < 2)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52031 FROM DUAL WHERE p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(p_apellido) < 2));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El teléfono debe tener de 10 a 13 dígitos' FROM DUAL WHERE v_codigo IS NULL AND (p_telefono IS NULL OR (CHAR_LENGTH(p_telefono) BETWEEN 10 AND 13 AND CAST(CAST(p_telefono AS UNSIGNED) AS CHAR) = p_telefono) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52032 FROM DUAL WHERE p_telefono IS NULL OR (CHAR_LENGTH(p_telefono) BETWEEN 10 AND 13 AND CAST(CAST(p_telefono AS UNSIGNED) AS CHAR) = p_telefono) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La fecha de nacimiento no es válida' FROM DUAL WHERE v_codigo IS NULL AND (p_fecha_nacimiento IS NULL OR p_fecha_nacimiento >= CURRENT_DATE)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52033 FROM DUAL WHERE p_fecha_nacimiento IS NULL OR p_fecha_nacimiento >= CURRENT_DATE));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El email no es válido' FROM DUAL WHERE v_codigo IS NULL AND (p_email IS NOT NULL AND p_email <> '' AND (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52034 FROM DUAL WHERE p_email IS NOT NULL AND p_email <> '' AND (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Ya existe una paciente con ese DNI' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM personas.Paciente WHERE dni = p_dni))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52035 FROM DUAL WHERE EXISTS (SELECT 1 FROM personas.Paciente WHERE dni = p_dni)));

    START TRANSACTION;
    INSERT INTO personas.Paciente (dni, nombre, apellido, fecha_nacimiento, fecha_alta, email)
    SELECT p_dni, p_nombre, p_apellido, p_fecha_nacimiento, COALESCE(@ahora_simulado, NOW()), (SELECT p_email FROM DUAL WHERE p_email <> '') FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_paciente) INTO v_id FROM personas.Paciente WHERE dni = p_dni;
    INSERT INTO personas.TelefonoPaciente (id_paciente, telefono) SELECT v_id, p_telefono FROM DUAL WHERE v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, v_id, p_origen,
        'Alta de paciente DNI', 'personas.Paciente', v_id, NULL, p_apellido, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'personas.Paciente', NULL, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Paciente creada' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Modifica nombre, apellido, email y, si viene, agrega un teléfono nuevo.
DROP PROCEDURE IF EXISTS personas.sp_modificar_paciente//
CREATE PROCEDURE personas.sp_modificar_paciente(
    IN p_id_paciente INT, IN p_nombre VARCHAR(50), IN p_apellido VARCHAR(50), IN p_email VARCHAR(100),
    IN p_telefono_nuevo VARCHAR(30), IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_antes VARCHAR(400);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, v_msg,
                                        'personas.Paciente', p_id_paciente, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    -- Un dato opcional vacío ('') se toma como no informado (NULL).
    SET p_telefono_nuevo = (SELECT p_telefono_nuevo FROM DUAL WHERE p_telefono_nuevo <> '');
    SET p_email = (SELECT p_email FROM DUAL WHERE p_email <> '');

    SELECT nombre INTO v_antes
      FROM personas.Paciente WHERE id_paciente = p_id_paciente;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La paciente no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_antes IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52036 FROM DUAL WHERE v_antes IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Nombre y apellido deben tener al menos 2 letras' FROM DUAL WHERE v_codigo IS NULL AND (p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(p_apellido) < 2)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52031 FROM DUAL WHERE p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(p_apellido) < 2));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El email no es válido' FROM DUAL WHERE v_codigo IS NULL AND (p_email IS NOT NULL AND p_email <> '' AND (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52034 FROM DUAL WHERE p_email IS NOT NULL AND p_email <> '' AND (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El teléfono debe tener de 10 a 13 dígitos' FROM DUAL WHERE v_codigo IS NULL AND (p_telefono_nuevo IS NOT NULL AND p_telefono_nuevo <> '' AND (CHAR_LENGTH(p_telefono_nuevo) BETWEEN 10 AND 13 AND CAST(CAST(p_telefono_nuevo AS UNSIGNED) AS CHAR) = p_telefono_nuevo) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52032 FROM DUAL WHERE p_telefono_nuevo IS NOT NULL AND p_telefono_nuevo <> '' AND (CHAR_LENGTH(p_telefono_nuevo) BETWEEN 10 AND 13 AND CAST(CAST(p_telefono_nuevo AS UNSIGNED) AS CHAR) = p_telefono_nuevo) = 0));

    START TRANSACTION;
    UPDATE personas.Paciente
       SET nombre = p_nombre, apellido = p_apellido, email = (SELECT p_email FROM DUAL WHERE p_email <> '')
     WHERE id_paciente = p_id_paciente AND v_codigo IS NULL;
    -- Un teléfono nuevo se agrega (si no estaba).
    INSERT INTO personas.TelefonoPaciente (id_paciente, telefono)
    SELECT p_id_paciente, p_telefono_nuevo FROM DUAL
     WHERE v_codigo IS NULL AND p_telefono_nuevo IS NOT NULL AND p_telefono_nuevo <> ''
       AND NOT EXISTS (SELECT 1 FROM personas.TelefonoPaciente WHERE id_paciente = p_id_paciente AND telefono = p_telefono_nuevo);
    CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, 'Datos de la paciente modificados',
        'personas.Paciente', p_id_paciente, v_antes, p_nombre, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, v_mensaje,
                                        'personas.Paciente', p_id_paciente, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Paciente modificada' AS mensaje, p_id_paciente AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Búsqueda por nombre, apellido, DNI o teléfono (RF-13). Con texto vacío o
-- de menos de 3 caracteres no devuelve nada.
DROP PROCEDURE IF EXISTS personas.sp_buscar_paciente//
CREATE PROCEDURE personas.sp_buscar_paciente(IN p_texto VARCHAR(100))
BEGIN
    DECLARE v_texto VARCHAR(100) DEFAULT COALESCE(p_texto, '');
    SELECT p.id_paciente, p.dni, p.nombre, p.apellido, p.fecha_nacimiento, p.email,
           (SELECT tp.telefono FROM personas.TelefonoPaciente tp
             WHERE tp.id_telefono_paciente = (SELECT MIN(tpx.id_telefono_paciente) FROM personas.TelefonoPaciente tpx WHERE tpx.id_paciente = p.id_paciente)) AS telefonos,
           (p.id_usuario IS NOT NULL) AS tiene_cuenta
      FROM personas.Paciente p
     WHERE CHAR_LENGTH(v_texto) >= 3
       AND (p.dni = v_texto
            OR p.nombre = v_texto
            OR p.apellido = v_texto
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
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_usuario INT;
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, v_msg,
                                        'personas.Profesional', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Falta la matrícula' FROM DUAL WHERE v_codigo IS NULL AND (p_matricula IS NULL OR p_matricula = '')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52040 FROM DUAL WHERE p_matricula IS NULL OR p_matricula = ''));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Nombre y apellido deben tener al menos 2 letras' FROM DUAL WHERE v_codigo IS NULL AND (p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(p_apellido) < 2)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52031 FROM DUAL WHERE p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(p_apellido) < 2));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El email no es válido' FROM DUAL WHERE v_codigo IS NULL AND (p_email IS NULL OR (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52034 FROM DUAL WHERE p_email IS NULL OR (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El teléfono debe tener de 10 a 13 dígitos' FROM DUAL WHERE v_codigo IS NULL AND (p_telefono IS NULL OR (CHAR_LENGTH(p_telefono) BETWEEN 10 AND 13 AND CAST(CAST(p_telefono AS UNSIGNED) AS CHAR) = p_telefono) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52032 FROM DUAL WHERE p_telefono IS NULL OR (CHAR_LENGTH(p_telefono) BETWEEN 10 AND 13 AND CAST(CAST(p_telefono AS UNSIGNED) AS CHAR) = p_telefono) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo' FROM DUAL WHERE v_codigo IS NULL AND (p_nombre_usuario IS NULL OR (CHAR_LENGTH(p_nombre_usuario) BETWEEN 4 AND 50) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52022 FROM DUAL WHERE p_nombre_usuario IS NULL OR (CHAR_LENGTH(p_nombre_usuario) BETWEEN 4 AND 50) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La contrasena no puede estar vacia' FROM DUAL WHERE v_codigo IS NULL AND (p_password IS NULL OR p_password = '')));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52024 FROM DUAL WHERE p_password IS NULL OR p_password = ''));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Ya existe un profesional con esa matrícula' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM personas.Profesional WHERE matricula = p_matricula))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52041 FROM DUAL WHERE EXISTS (SELECT 1 FROM personas.Profesional WHERE matricula = p_matricula)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Ese usuario o email ya está en uso' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario OR email = p_email))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52025 FROM DUAL WHERE EXISTS (SELECT 1 FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario OR email = p_email)));

    START TRANSACTION;
    INSERT INTO seguridad.Usuario (id_rol, nombre_usuario, email, password)
    SELECT (SELECT id_rol FROM seguridad.Rol WHERE nombre = 'profesional'), p_nombre_usuario, p_email, p_password FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_usuario) INTO v_usuario FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario;
    INSERT INTO personas.Profesional (id_usuario, matricula, nombre, apellido, email)
    SELECT v_usuario, p_matricula, p_nombre, p_apellido, p_email FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_profesional) INTO v_id FROM personas.Profesional WHERE matricula = p_matricula;
    INSERT INTO personas.TelefonoProfesional (id_profesional, telefono) SELECT v_id, p_telefono FROM DUAL WHERE v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen,
        'Alta del profesional',
        'personas.Profesional', v_id, NULL, p_nombre_usuario, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'personas.Profesional', NULL, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Profesional creado' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Modifica los datos del profesional o lo da de baja (p_activo = 0). No se
-- puede dar de baja a quien tiene turnos futuros sin cancelar.
DROP PROCEDURE IF EXISTS personas.sp_modificar_profesional//
CREATE PROCEDURE personas.sp_modificar_profesional(
    IN p_id_profesional INT, IN p_nombre VARCHAR(50), IN p_apellido VARCHAR(50), IN p_email VARCHAR(100),
    IN p_activo SMALLINT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_antes VARCHAR(400);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen, v_msg,
                                        'personas.Profesional', p_id_profesional, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT apellido INTO v_antes
      FROM personas.Profesional WHERE id_profesional = p_id_profesional;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El profesional no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_antes IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52042 FROM DUAL WHERE v_antes IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Nombre y apellido deben tener al menos 2 letras' FROM DUAL WHERE v_codigo IS NULL AND (p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(p_apellido) < 2)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52031 FROM DUAL WHERE p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(p_apellido) < 2));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El email no es válido' FROM DUAL WHERE v_codigo IS NULL AND (p_email IS NULL OR (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52034 FROM DUAL WHERE p_email IS NULL OR (CHAR_LENGTH(p_email) BETWEEN 5 AND 100) = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El estado activo debe ser 0 o 1' FROM DUAL WHERE v_codigo IS NULL AND (p_activo IS NULL OR p_activo NOT IN (0, 1))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52043 FROM DUAL WHERE p_activo IS NULL OR p_activo NOT IN (0, 1)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'No se puede dar de baja: tiene turnos futuros sin cancelar' FROM DUAL WHERE v_codigo IS NULL AND p_activo = 0 AND EXISTS (
            SELECT 1 FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
             WHERE t.id_profesional = p_id_profesional AND t.fecha_hora_inicio > COALESCE(@ahora_simulado, NOW())
               AND e.nombre IN ('pendiente', 'confirmado'))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52044 FROM DUAL WHERE p_activo = 0 AND EXISTS (
            SELECT 1 FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
             WHERE t.id_profesional = p_id_profesional AND t.fecha_hora_inicio > COALESCE(@ahora_simulado, NOW())
               AND e.nombre IN ('pendiente', 'confirmado'))));

    START TRANSACTION;
    UPDATE personas.Profesional SET nombre = p_nombre, apellido = p_apellido, email = p_email, activo = p_activo
     WHERE id_profesional = p_id_profesional AND v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen,
        COALESCE((SELECT 'Baja del profesional' FROM DUAL WHERE p_activo = 0), 'Datos del profesional modificados'),
        'personas.Profesional', p_id_profesional, v_antes,
        p_apellido, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'personas.Profesional', p_id_profesional, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Profesional modificado' AS mensaje, p_id_profesional AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Carga una franja de disponibilidad. No puede superponerse con otra franja
-- activa del mismo profesional ese día.
DROP PROCEDURE IF EXISTS personas.sp_cargar_disponibilidad//
CREATE PROCEDURE personas.sp_cargar_disponibilidad(
    IN p_id_profesional INT, IN p_fecha DATE, IN p_hora_inicio TIME, IN p_hora_fin TIME,
    IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, v_msg,
                                        'personas.Disponibilidad', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El profesional no existe o está dado de baja' FROM DUAL WHERE v_codigo IS NULL AND (NOT EXISTS (SELECT 1 FROM personas.Profesional WHERE id_profesional = p_id_profesional AND activo = 1))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52045 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM personas.Profesional WHERE id_profesional = p_id_profesional AND activo = 1)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Faltan la fecha o las horas' FROM DUAL WHERE v_codigo IS NULL AND (p_fecha IS NULL OR p_hora_inicio IS NULL OR p_hora_fin IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52046 FROM DUAL WHERE p_fecha IS NULL OR p_hora_inicio IS NULL OR p_hora_fin IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La hora de fin debe ser posterior a la de inicio' FROM DUAL WHERE v_codigo IS NULL AND (p_hora_fin <= p_hora_inicio)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52047 FROM DUAL WHERE p_hora_fin <= p_hora_inicio));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'No se puede cargar disponibilidad en el pasado' FROM DUAL WHERE v_codigo IS NULL AND (p_fecha < DATE(COALESCE(@ahora_simulado, NOW())))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52048 FROM DUAL WHERE p_fecha < DATE(COALESCE(@ahora_simulado, NOW()))));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La franja se superpone con otra ya cargada' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM personas.Disponibilidad d
                WHERE d.id_profesional = p_id_profesional AND d.fecha = p_fecha AND d.activa = 1
                  AND d.hora_inicio < p_hora_fin AND d.hora_fin > p_hora_inicio))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52049 FROM DUAL WHERE EXISTS (SELECT 1 FROM personas.Disponibilidad d
                WHERE d.id_profesional = p_id_profesional AND d.fecha = p_fecha AND d.activa = 1
                  AND d.hora_inicio < p_hora_fin AND d.hora_fin > p_hora_inicio)));

    START TRANSACTION;
    INSERT INTO personas.Disponibilidad (id_profesional, fecha, hora_inicio, hora_fin) SELECT p_id_profesional, p_fecha, p_hora_inicio, p_hora_fin FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_disponibilidad) INTO v_id FROM personas.Disponibilidad
     WHERE id_profesional = p_id_profesional AND fecha = p_fecha AND hora_inicio = p_hora_inicio AND hora_fin = p_hora_fin;
    CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen,
        CONCAT('Alta de franja ', p_fecha, ' ', p_hora_inicio, '-', p_hora_fin, ' del profesional ', p_id_profesional),
        'personas.Disponibilidad', v_id, NULL, p_fecha, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'personas.Disponibilidad', NULL, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Franja cargada' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Baja (lógica) de una franja. No se puede si hay turnos activos dentro de ella.
DROP PROCEDURE IF EXISTS personas.sp_baja_disponibilidad//
CREATE PROCEDURE personas.sp_baja_disponibilidad(IN p_id_disponibilidad INT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_prof INT DEFAULT NULL;
    DECLARE v_fecha DATE;
    DECLARE v_ini TIME;
    DECLARE v_fin TIME;
    DECLARE v_activa SMALLINT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, v_msg,
                                        'personas.Disponibilidad', p_id_disponibilidad, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT id_profesional, fecha, hora_inicio, hora_fin, activa INTO v_prof, v_fecha, v_ini, v_fin, v_activa
      FROM personas.Disponibilidad WHERE id_disponibilidad = p_id_disponibilidad;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La franja no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_prof IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52050 FROM DUAL WHERE v_prof IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La franja ya estaba dada de baja' FROM DUAL WHERE v_codigo IS NULL AND (v_activa = 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52051 FROM DUAL WHERE v_activa = 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Hay turnos sin cancelar dentro de esa franja' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
                WHERE t.id_profesional = v_prof AND e.nombre IN ('pendiente', 'confirmado')
                  AND t.fecha_hora_inicio < (v_fecha + INTERVAL (EXTRACT(HOUR FROM v_fin) * 60 + EXTRACT(MINUTE FROM v_fin)) MINUTE) AND t.fecha_hora_fin > (v_fecha + INTERVAL (EXTRACT(HOUR FROM v_ini) * 60 + EXTRACT(MINUTE FROM v_ini)) MINUTE)))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52052 FROM DUAL WHERE EXISTS (SELECT 1 FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
                WHERE t.id_profesional = v_prof AND e.nombre IN ('pendiente', 'confirmado')
                  AND t.fecha_hora_inicio < (v_fecha + INTERVAL (EXTRACT(HOUR FROM v_fin) * 60 + EXTRACT(MINUTE FROM v_fin)) MINUTE) AND t.fecha_hora_fin > (v_fecha + INTERVAL (EXTRACT(HOUR FROM v_ini) * 60 + EXTRACT(MINUTE FROM v_ini)) MINUTE))));

    UPDATE personas.Disponibilidad SET activa = 0 WHERE id_disponibilidad = p_id_disponibilidad AND v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen,
        CONCAT('Baja de franja ', v_fecha, ' ', v_ini, '-', v_fin, ' del profesional ', v_prof),
        'personas.Disponibilidad', p_id_disponibilidad, 'activa=1', 'activa=0', 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'personas.Disponibilidad', p_id_disponibilidad, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Franja dada de baja' AS mensaje, p_id_disponibilidad AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Habilita (o quita) un protocolo a un profesional (RF-18).
DROP PROCEDURE IF EXISTS clinica.sp_asignar_protocolo//
CREATE PROCEDURE clinica.sp_asignar_protocolo(
    IN p_id_profesional INT, IN p_id_protocolo INT, IN p_habilitar SMALLINT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen, v_msg,
                                        'clinica.ProfesionalProtocolo', p_id_profesional, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El profesional no existe' FROM DUAL WHERE v_codigo IS NULL AND (NOT EXISTS (SELECT 1 FROM personas.Profesional WHERE id_profesional = p_id_profesional))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52042 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM personas.Profesional WHERE id_profesional = p_id_profesional)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El protocolo no existe' FROM DUAL WHERE v_codigo IS NULL AND (NOT EXISTS (SELECT 1 FROM clinica.Protocolo WHERE id_protocolo = p_id_protocolo))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52060 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM clinica.Protocolo WHERE id_protocolo = p_id_protocolo)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El parámetro habilitar debe ser 0 o 1' FROM DUAL WHERE v_codigo IS NULL AND (p_habilitar IS NULL OR p_habilitar NOT IN (0, 1))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52043 FROM DUAL WHERE p_habilitar IS NULL OR p_habilitar NOT IN (0, 1)));

    START TRANSACTION;
    -- p_habilitar = 1 agrega la relación (si no estaba); 0 la quita.
    INSERT INTO clinica.ProfesionalProtocolo (id_profesional, id_protocolo)
    SELECT p_id_profesional, p_id_protocolo FROM DUAL
     WHERE v_codigo IS NULL AND p_habilitar = 1
       AND NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo WHERE id_profesional = p_id_profesional AND id_protocolo = p_id_protocolo);
    DELETE FROM clinica.ProfesionalProtocolo
     WHERE id_profesional = p_id_profesional AND id_protocolo = p_id_protocolo AND p_habilitar = 0 AND v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen,
        CONCAT(COALESCE((SELECT 'Se habilita' FROM DUAL WHERE p_habilitar = 1), 'Se quita'), ' el protocolo ', p_id_protocolo, ' al profesional ', p_id_profesional),
        'clinica.ProfesionalProtocolo', p_id_profesional, NULL, NULL, 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'clinica.ProfesionalProtocolo', p_id_profesional, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Asignación actualizada' AS mensaje, p_id_profesional AS id, NULL AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Profesionales activos habilitados para TODOS los protocolos pedidos (RF-18).
-- p_protocolos_csv: ids separados por coma, por ejemplo '3,7'.
DROP PROCEDURE IF EXISTS personas.sp_profesionales_para_protocolos//
CREATE PROCEDURE personas.sp_profesionales_para_protocolos(IN p_protocolo1 INT, IN p_protocolo2 INT, IN p_protocolo3 INT)
BEGIN
    -- Profesionales activos que hacen TODOS los protocolos pedidos (hasta 3; los que no se usan van en NULL).
    DECLARE v_pedidos INT DEFAULT 0;
    SET v_pedidos = (SELECT COUNT(*) FROM (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL) x);
    SELECT pr.id_profesional, pr.apellido AS profesional, pr.nombre AS profesional_nombre, pr.matricula
      FROM personas.Profesional pr
     WHERE pr.activo = 1 AND v_pedidos > 0
       AND NOT EXISTS (SELECT 1 FROM (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL) jt
                        WHERE NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo pp
                                           WHERE pp.id_profesional = pr.id_profesional AND pp.id_protocolo = jt.id))
     ORDER BY pr.apellido, pr.nombre;
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
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, v_msg,
                                        'clinica.Protocolo', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La categoría no existe' FROM DUAL WHERE v_codigo IS NULL AND (NOT EXISTS (SELECT 1 FROM clinica.CategoriaProtocolo WHERE id_categoria = p_id_categoria))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52061 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM clinica.CategoriaProtocolo WHERE id_categoria = p_id_categoria)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El nombre debe tener al menos 3 caracteres' FROM DUAL WHERE v_codigo IS NULL AND (p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 3)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52062 FROM DUAL WHERE p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 3));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El precio debe ser mayor a cero' FROM DUAL WHERE v_codigo IS NULL AND (p_precio IS NULL OR p_precio <= 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52063 FROM DUAL WHERE p_precio IS NULL OR p_precio <= 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La duración debe estar entre 1 y 600 minutos' FROM DUAL WHERE v_codigo IS NULL AND (p_duracion_min IS NULL OR p_duracion_min <= 0 OR p_duracion_min > 600)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52064 FROM DUAL WHERE p_duracion_min IS NULL OR p_duracion_min <= 0 OR p_duracion_min > 600));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Ya existe un protocolo con ese nombre' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM clinica.Protocolo WHERE nombre = p_nombre))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52065 FROM DUAL WHERE EXISTS (SELECT 1 FROM clinica.Protocolo WHERE nombre = p_nombre)));

    START TRANSACTION;
    INSERT INTO clinica.Protocolo (id_categoria, nombre, descripcion, precio, duracion_min)
    SELECT p_id_categoria, p_nombre, p_descripcion, p_precio, p_duracion_min FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_protocolo) INTO v_id FROM clinica.Protocolo WHERE nombre = p_nombre;
    CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'Alta del protocolo',
        'clinica.Protocolo', v_id, NULL, CAST(p_precio AS CHAR), 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'clinica.Protocolo', NULL, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Protocolo creado' AS mensaje, v_id AS id, p_precio AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Cambia precio, duración, descripción o lo da de baja (p_activo = 0). Los
-- turnos ya agendados conservan el precio de cuando se reservaron.
DROP PROCEDURE IF EXISTS clinica.sp_modificar_protocolo//
CREATE PROCEDURE clinica.sp_modificar_protocolo(
    IN p_id_protocolo INT, IN p_nombre VARCHAR(100), IN p_descripcion VARCHAR(500), IN p_precio DECIMAL(12,2),
    IN p_duracion_min INT, IN p_activo SMALLINT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_antes VARCHAR(400);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, v_msg,
                                        'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT CAST(precio AS CHAR) INTO v_antes
      FROM clinica.Protocolo WHERE id_protocolo = p_id_protocolo;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El protocolo no existe' FROM DUAL WHERE v_codigo IS NULL AND (v_antes IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52060 FROM DUAL WHERE v_antes IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El nombre debe tener al menos 3 caracteres' FROM DUAL WHERE v_codigo IS NULL AND (p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 3)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52062 FROM DUAL WHERE p_nombre IS NULL OR CHAR_LENGTH(p_nombre) < 3));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El precio debe ser mayor a cero' FROM DUAL WHERE v_codigo IS NULL AND (p_precio IS NULL OR p_precio <= 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52063 FROM DUAL WHERE p_precio IS NULL OR p_precio <= 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La duración debe estar entre 1 y 600 minutos' FROM DUAL WHERE v_codigo IS NULL AND (p_duracion_min IS NULL OR p_duracion_min <= 0 OR p_duracion_min > 600)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52064 FROM DUAL WHERE p_duracion_min IS NULL OR p_duracion_min <= 0 OR p_duracion_min > 600));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El estado activo debe ser 0 o 1' FROM DUAL WHERE v_codigo IS NULL AND (p_activo IS NULL OR p_activo NOT IN (0, 1))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52043 FROM DUAL WHERE p_activo IS NULL OR p_activo NOT IN (0, 1)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Ya existe un protocolo con ese nombre' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM clinica.Protocolo WHERE nombre = p_nombre AND id_protocolo <> p_id_protocolo))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52065 FROM DUAL WHERE EXISTS (SELECT 1 FROM clinica.Protocolo WHERE nombre = p_nombre AND id_protocolo <> p_id_protocolo)));

    START TRANSACTION;
    UPDATE clinica.Protocolo
       SET nombre = p_nombre, descripcion = p_descripcion, precio = p_precio, duracion_min = p_duracion_min, activo = p_activo
     WHERE id_protocolo = p_id_protocolo AND v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen,
        COALESCE((SELECT 'Baja del protocolo' FROM DUAL WHERE p_activo = 0), 'Protocolo modificado'), 'clinica.Protocolo', p_id_protocolo, v_antes,
        CAST(p_precio AS CHAR), 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, v_mensaje,
                                        'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Protocolo modificado' AS mensaje, p_id_protocolo AS id, p_precio AS valor, NULL AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Catálogo y buscador por palabra clave (RF-05/06). Con texto vacío o NULL
-- devuelve todo el catálogo; con p_id_categoria NULL, todas las categorías.
-- p_incluir_bajas = 1 incluye también los protocolos dados de baja (lo usa la
-- pantalla de administración de protocolos); con 0 o NULL, solo los activos.
DROP PROCEDURE IF EXISTS clinica.sp_listar_protocolos//
CREATE PROCEDURE clinica.sp_listar_protocolos(IN p_texto VARCHAR(100), IN p_id_categoria INT, IN p_incluir_bajas SMALLINT)
BEGIN
    DECLARE v_texto VARCHAR(100) DEFAULT COALESCE(p_texto, '');
    SELECT p.id_protocolo, p.nombre, p.descripcion, c.id_categoria, c.nombre AS categoria, p.precio, p.duracion_min,
           c.porcentaje_sena, ROUND(p.precio * c.porcentaje_sena / 100, 0) AS sena, c.requiere_evaluacion, p.activo
      FROM clinica.Protocolo p
      JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
     WHERE (p.activo = 1 OR COALESCE(p_incluir_bajas, 0) = 1)
       AND (p_id_categoria IS NULL OR p.id_categoria = p_id_categoria)
       AND (v_texto = '' OR p.nombre = v_texto OR p.descripcion = v_texto
            OR c.nombre = v_texto)
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
CREATE PROCEDURE agenda.sp_horarios_libres(IN p_fecha DATE, IN p_protocolo1 INT, IN p_protocolo2 INT, IN p_protocolo3 INT, IN p_id_profesional INT)
BEGIN
    DECLARE v_pedidos INT DEFAULT 0;
    DECLARE v_n INT DEFAULT 0;
    DECLARE v_dur INT DEFAULT 0;
    DECLARE v_cancelado INT;

    -- Protocolos pedidos: hasta 3 (los que no se usan van en NULL). Todos tienen que existir y estar activos.
    SET v_pedidos = (SELECT COUNT(*) FROM (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL) x);
    SELECT COUNT(*), COALESCE(SUM(p.duracion_min), 0) INTO v_n, v_dur
      FROM clinica.Protocolo p
     WHERE p.activo = 1 AND p.id_protocolo IN (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL);
    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';

        -- Cada franja se parte en turnos de 30 minutos con la tabla de números.
    SELECT s.id_profesional, pr.apellido AS profesional, pr.nombre AS profesional_nombre,
               s.inicio, s.inicio + INTERVAL v_dur MINUTE AS fin
          FROM (SELECT d.id_profesional,
                       d.fecha + INTERVAL (EXTRACT(HOUR FROM d.hora_inicio) * 60 + EXTRACT(MINUTE FROM d.hora_inicio) + 30 * nm.n) MINUTE AS inicio,
                       d.fecha + INTERVAL (EXTRACT(HOUR FROM d.hora_fin) * 60 + EXTRACT(MINUTE FROM d.hora_fin)) MINUTE AS fin_franja
                  FROM personas.Disponibilidad d
                  JOIN agenda.Numero nm
                    ON EXTRACT(HOUR FROM d.hora_inicio) * 60 + EXTRACT(MINUTE FROM d.hora_inicio) + 30 * nm.n
                       < EXTRACT(HOUR FROM d.hora_fin) * 60 + EXTRACT(MINUTE FROM d.hora_fin)
                 WHERE d.fecha = p_fecha AND d.activa = 1 AND (p_id_profesional IS NULL OR d.id_profesional = p_id_profesional)) s
          JOIN personas.Profesional pr ON pr.id_profesional = s.id_profesional AND pr.activo = 1
         WHERE p_fecha IS NOT NULL AND v_pedidos > 0 AND v_n = v_pedidos AND v_dur > 0
           AND s.inicio + INTERVAL v_dur MINUTE <= s.fin_franja
           AND s.inicio > COALESCE(@ahora_simulado, NOW())
           AND NOT EXISTS (SELECT 1 FROM agenda.Turno t
                            WHERE t.id_profesional = s.id_profesional AND t.id_estado_turno <> v_cancelado
                              AND t.fecha_hora_inicio < s.inicio + INTERVAL v_dur MINUTE AND t.fecha_hora_fin > s.inicio)
           AND NOT EXISTS (SELECT 1 FROM (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL) jt
                            WHERE NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo pp
                                               WHERE pp.id_profesional = s.id_profesional AND pp.id_protocolo = jt.id))
         ORDER BY s.inicio, pr.apellido;
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
    IN p_id_paciente INT, IN p_id_profesional INT, IN p_inicio DATETIME, IN p_protocolo1 INT, IN p_protocolo2 INT, IN p_protocolo3 INT,
    IN p_origen VARCHAR(50), IN p_id_usuario INT, IN p_codigo_cupon VARCHAR(50), IN p_id_cirugia_consulta INT)
BEGIN
    DECLARE v_codigo INT DEFAULT NULL;
    DECLARE v_mensaje VARCHAR(255) DEFAULT NULL;
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
            v_msg, 'agenda.Turno', NULL, NULL, NULL, 0, NULL, 1);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT id_origen INTO v_id_origen FROM agenda.Origen WHERE nombre = p_origen;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Origen inválido (terminal, web, gestion o sistema)' FROM DUAL WHERE v_codigo IS NULL AND (v_id_origen IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52070 FROM DUAL WHERE v_id_origen IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La paciente no existe' FROM DUAL WHERE v_codigo IS NULL AND (NOT EXISTS (SELECT 1 FROM personas.Paciente WHERE id_paciente = p_id_paciente))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52071 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM personas.Paciente WHERE id_paciente = p_id_paciente)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno necesita al menos un protocolo' FROM DUAL WHERE v_codigo IS NULL AND (p_protocolo1 IS NULL AND p_protocolo2 IS NULL AND p_protocolo3 IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52072 FROM DUAL WHERE p_protocolo1 IS NULL AND p_protocolo2 IS NULL AND p_protocolo3 IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El turno debe ser en el futuro' FROM DUAL WHERE v_codigo IS NULL AND (p_inicio IS NULL OR p_inicio <= COALESCE(@ahora_simulado, NOW()))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52073 FROM DUAL WHERE p_inicio IS NULL OR p_inicio <= COALESCE(@ahora_simulado, NOW())));

    -- Se bloquea al profesional: dos reservas simultáneas del mismo horario se atienden de a una.
    SELECT id_profesional INTO v_n FROM personas.Profesional WHERE id_profesional = p_id_profesional AND activo = 1;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El profesional no existe o está dado de baja' FROM DUAL WHERE v_codigo IS NULL AND (v_n = 0 OR v_n IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52074 FROM DUAL WHERE v_n = 0 OR v_n IS NULL));

    -- Protocolos pedidos: hasta 3 (los que no se usan van en NULL).
    SET v_pedidos = (SELECT COUNT(*) FROM (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL) x);
    SELECT COUNT(*), COALESCE(SUM(p.duracion_min), 0), COALESCE(SUM(c.requiere_evaluacion), 0), MIN(p.id_protocolo + (c.requiere_evaluacion <> 1) * 1000000)
      INTO v_n, v_dur, v_cirugias, v_cirugia
      FROM clinica.Protocolo p JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
     WHERE p.activo = 1
       AND p.id_protocolo IN (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL);
    -- La cirugía pedida (si hay): el menor id entre los protocolos que requieren evaluación.
    SET v_cirugia = (SELECT v_cirugia FROM DUAL WHERE v_cirugia < 1000000);
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Algún protocolo no existe o está dado de baja' FROM DUAL WHERE v_codigo IS NULL AND (v_pedidos = 0 OR v_n <> v_pedidos)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52075 FROM DUAL WHERE v_pedidos = 0 OR v_n <> v_pedidos));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El profesional no realiza alguno de los protocolos pedidos' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL) jt
                WHERE NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo pp
                                   WHERE pp.id_profesional = p_id_profesional AND pp.id_protocolo = jt.id)))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52076 FROM DUAL WHERE EXISTS (SELECT 1 FROM (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL) jt
                WHERE NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo pp
                                   WHERE pp.id_profesional = p_id_profesional AND pp.id_protocolo = jt.id))));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'Una cirugía se agenda sola, sin otros protocolos' FROM DUAL WHERE v_codigo IS NULL AND (v_cirugias > 1 OR (v_cirugias = 1 AND v_n > 1))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52077 FROM DUAL WHERE v_cirugias > 1 OR (v_cirugias = 1 AND v_n > 1)));
    -- Reglas de la consulta previa (solo si el turno es la consulta previa de una cirugía).
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La consulta previa no puede incluir una cirugía' FROM DUAL WHERE v_codigo IS NULL AND p_id_cirugia_consulta IS NOT NULL AND (v_cirugias > 0)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52078 FROM DUAL WHERE p_id_cirugia_consulta IS NOT NULL AND v_cirugias > 0));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La consulta previa debe ser para una cirugía existente' FROM DUAL WHERE v_codigo IS NULL AND p_id_cirugia_consulta IS NOT NULL AND (NOT EXISTS (SELECT 1 FROM clinica.Protocolo p JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
                    WHERE p.id_protocolo = p_id_cirugia_consulta AND p.activo = 1 AND c.requiere_evaluacion = 1))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52079 FROM DUAL WHERE p_id_cirugia_consulta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM clinica.Protocolo p JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
                    WHERE p.id_protocolo = p_id_cirugia_consulta AND p.activo = 1 AND c.requiere_evaluacion = 1)));

    SET v_fin = p_inicio + INTERVAL v_dur MINUTE;
    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';
    SELECT id_estado_turno INTO v_pendiente FROM agenda.EstadoTurno WHERE nombre = 'pendiente';

    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El horario está fuera de la disponibilidad del profesional' FROM DUAL WHERE v_codigo IS NULL AND (NOT EXISTS (SELECT 1 FROM personas.Disponibilidad d
                    WHERE d.id_profesional = p_id_profesional AND d.activa = 1 AND d.fecha = DATE(p_inicio)
                      AND DATE(v_fin) = DATE(p_inicio) AND d.hora_inicio <= TIME(p_inicio) AND d.hora_fin >= TIME(v_fin)))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52080 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM personas.Disponibilidad d
                    WHERE d.id_profesional = p_id_profesional AND d.activa = 1 AND d.fecha = DATE(p_inicio)
                      AND DATE(v_fin) = DATE(p_inicio) AND d.hora_inicio <= TIME(p_inicio) AND d.hora_fin >= TIME(v_fin))));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El profesional ya tiene un turno en ese horario' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM agenda.Turno t WHERE t.id_profesional = p_id_profesional AND t.id_estado_turno <> v_cancelado
                  AND t.fecha_hora_inicio < v_fin AND t.fecha_hora_fin > p_inicio))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52081 FROM DUAL WHERE EXISTS (SELECT 1 FROM agenda.Turno t WHERE t.id_profesional = p_id_profesional AND t.id_estado_turno <> v_cancelado
                  AND t.fecha_hora_inicio < v_fin AND t.fecha_hora_fin > p_inicio)));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La paciente ya tiene un turno en ese horario' FROM DUAL WHERE v_codigo IS NULL AND (EXISTS (SELECT 1 FROM agenda.Turno t WHERE t.id_paciente = p_id_paciente AND t.id_estado_turno <> v_cancelado
                  AND t.fecha_hora_inicio < v_fin AND t.fecha_hora_fin > p_inicio))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52082 FROM DUAL WHERE EXISTS (SELECT 1 FROM agenda.Turno t WHERE t.id_paciente = p_id_paciente AND t.id_estado_turno <> v_cancelado
                  AND t.fecha_hora_inicio < v_fin AND t.fecha_hora_fin > p_inicio)));

    -- Cirugía: hace falta una evaluación apta, de menos de 6 meses y sin usar.
    -- Una cirugía necesita una evaluación apta de menos de 6 meses que no se haya usado.
    SELECT MAX(ev.id_evaluacion) INTO v_eval
      FROM clinica.EvaluacionPrevia ev
      JOIN agenda.Turno tc ON tc.id_turno = ev.id_turno
      JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
     WHERE v_cirugias = 1 AND tc.id_paciente = p_id_paciente AND ev.id_protocolo = v_cirugia AND r.nombre = 'apto'
       AND ev.fecha_resultado + INTERVAL 6 MONTH >= COALESCE(@ahora_simulado, NOW())
       AND NOT EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = ev.id_evaluacion AND t2.id_estado_turno <> v_cancelado);
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'La cirugía necesita una consulta previa con resultado apto de menos de 6 meses' FROM DUAL WHERE v_codigo IS NULL AND v_cirugias = 1 AND (v_eval IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52083 FROM DUAL WHERE v_cirugias = 1 AND v_eval IS NULL));

    -- Cupón (opcional): de la paciente, vigente y sin usar.
    -- Cupón (opcional): de la paciente, sin usar y vigente.
    SELECT id_cupon, id_paciente, id_turno, fecha_vencimiento INTO v_cupon, v_cupon_pac, v_cupon_turno, v_cupon_venc
      FROM beneficios.Cupon WHERE codigo = p_codigo_cupon;
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón no existe' FROM DUAL WHERE v_codigo IS NULL AND p_codigo_cupon <> '' AND (v_cupon IS NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52084 FROM DUAL WHERE p_codigo_cupon <> '' AND v_cupon IS NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón es de otra paciente' FROM DUAL WHERE v_codigo IS NULL AND p_codigo_cupon <> '' AND (v_cupon_pac <> p_id_paciente)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52085 FROM DUAL WHERE p_codigo_cupon <> '' AND v_cupon_pac <> p_id_paciente));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón ya fue usado' FROM DUAL WHERE v_codigo IS NULL AND p_codigo_cupon <> '' AND (v_cupon_turno IS NOT NULL)));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52086 FROM DUAL WHERE p_codigo_cupon <> '' AND v_cupon_turno IS NOT NULL));
    SET v_mensaje = COALESCE(v_mensaje, (SELECT 'El cupón está vencido' FROM DUAL WHERE v_codigo IS NULL AND p_codigo_cupon <> '' AND (v_cupon_venc <= COALESCE(@ahora_simulado, NOW()))));
    SET v_codigo = COALESCE(v_codigo, (SELECT 52087 FROM DUAL WHERE p_codigo_cupon <> '' AND v_cupon_venc <= COALESCE(@ahora_simulado, NOW())));

    INSERT INTO agenda.Turno (id_paciente, id_profesional, id_estado_turno, id_origen, id_evaluacion_previa,
                              fecha_hora_inicio, fecha_hora_fin, fecha_creacion)
    SELECT p_id_paciente, p_id_profesional, v_pendiente, v_id_origen, v_eval, p_inicio, v_fin, COALESCE(@ahora_simulado, NOW()) FROM DUAL WHERE v_codigo IS NULL;
    SELECT MAX(id_turno) INTO v_id_turno FROM agenda.Turno
     WHERE id_paciente = p_id_paciente AND id_profesional = p_id_profesional AND fecha_hora_inicio = p_inicio;

    INSERT INTO agenda.TurnoProtocolo (id_turno, id_protocolo, precio_aplicado)
    SELECT v_id_turno, p.id_protocolo, p.precio
      FROM clinica.Protocolo p
     WHERE p.id_protocolo IN (SELECT p_protocolo1 AS id FROM DUAL WHERE p_protocolo1 IS NOT NULL UNION SELECT p_protocolo2 FROM DUAL WHERE p_protocolo2 IS NOT NULL UNION SELECT p_protocolo3 FROM DUAL WHERE p_protocolo3 IS NOT NULL) AND v_codigo IS NULL;

    UPDATE beneficios.Cupon SET id_turno = v_id_turno WHERE id_cupon = v_cupon AND v_codigo IS NULL;
    CALL auditoria.sp_registrar_log('cupon_validado', p_id_usuario, p_id_paciente, p_origen,
        CONCAT('Cupón ', p_codigo_cupon, ' aplicado al turno ', v_id_turno), 'beneficios.Cupon', v_cupon, NULL, NULL, 1, NULL,
        v_codigo IS NULL AND v_cupon IS NOT NULL);

    -- Si es la consulta previa de una cirugía, queda una evaluación pendiente.
    INSERT INTO clinica.EvaluacionPrevia (id_turno, id_protocolo, id_resultado)
    SELECT v_id_turno, p_id_cirugia_consulta, (SELECT id_resultado FROM clinica.ResultadoEvaluacion WHERE nombre = 'pendiente')
      FROM DUAL WHERE v_codigo IS NULL AND p_id_cirugia_consulta IS NOT NULL;

    -- Al agendar la cirugía se devuelve la seña de su consulta previa.
    SELECT ps.id_pago, ps.monto INTO v_pago_consulta, v_monto_consulta
      FROM clinica.EvaluacionPrevia ev JOIN pagos.PagoSena ps ON ps.id_turno = ev.id_turno
      JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago AND ep.nombre = 'pagada'
     WHERE ev.id_evaluacion = v_eval;
    CALL pagos.sp_aplicar_reembolso(v_pago_consulta, v_monto_consulta, 'reembolsada',
                                    'Devolución de la consulta previa al agendar la cirugía', p_id_usuario, p_origen,
                                    v_codigo IS NULL AND v_pago_consulta IS NOT NULL);

    CALL auditoria.sp_registrar_log('alta_turno', p_id_usuario, p_id_paciente, p_origen,
        CONCAT('Turno ', v_id_turno, ' con el profesional ', p_id_profesional, ' el ', p_inicio),
        'agenda.Turno', v_id_turno, NULL, CAST(p_inicio AS CHAR), 1, NULL, v_codigo IS NULL);
    COMMIT;
    CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
            v_mensaje, 'agenda.Turno', NULL, NULL, NULL, 0, NULL, v_codigo IS NOT NULL);
    SELECT 'OK' AS estado, 0 AS codigo, 'Turno agendado' AS mensaje, v_id_turno AS id,
           ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = v_id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = v_id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = v_id_turno), 0) / 100, 2)) * COALESCE((SELECT MAX(caz.porcentaje_sena) FROM agenda.TurnoProtocolo tpy JOIN clinica.Protocolo prz ON prz.id_protocolo = tpy.id_protocolo JOIN clinica.CategoriaProtocolo caz ON caz.id_categoria = prz.id_categoria WHERE tpy.id_turno = v_id_turno), 0) / 100, 0) AS valor, CAST((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = v_id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = v_id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = v_id_turno), 0) / 100, 2)) AS CHAR) AS dato FROM DUAL WHERE v_codigo IS NULL
    UNION ALL
    SELECT 'ERROR', v_codigo, v_mensaje, NULL, NULL, NULL FROM DUAL WHERE v_codigo IS NOT NULL;
END//

-- Busca turnos por DNI, teléfono, nombre o apellido (RF-12, RF-13, RF-16).
-- p_solo_vigentes = 1 muestra solo los pendientes o confirmados futuros.
-- Con texto NULL, vacío o de menos de 3 caracteres no devuelve nada.
-- Cada fila trae también el teléfono, la seña, el código de operación y el
-- último recordatorio del turno (canal, estado y cuándo sale).
DROP PROCEDURE IF EXISTS agenda.sp_buscar_turnos//
CREATE PROCEDURE agenda.sp_buscar_turnos(IN p_texto VARCHAR(100), IN p_solo_vigentes SMALLINT)
BEGIN
    DECLARE v_texto VARCHAR(100) DEFAULT COALESCE(p_texto, '');
    SELECT t.id_turno, p.id_paciente, p.apellido AS paciente, p.nombre AS paciente_nombre, p.dni,
           (SELECT tp2.telefono FROM personas.TelefonoPaciente tp2 WHERE tp2.id_telefono_paciente = (SELECT MIN(tp2x.id_telefono_paciente) FROM personas.TelefonoPaciente tp2x WHERE tp2x.id_paciente = p.id_paciente)) AS telefono,
           pr.apellido AS profesional, pr.nombre AS profesional_nombre, t.fecha_hora_inicio, t.fecha_hora_fin,
           e.nombre AS estado, o.nombre AS origen,
           (SELECT MIN(pt.nombre) FROM agenda.TurnoProtocolo tp JOIN clinica.Protocolo pt ON pt.id_protocolo = tp.id_protocolo WHERE tp.id_turno = t.id_turno) AS protocolos,
           (COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = t.id_turno), 0) / 100, 2)) AS precio_final,
           ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = t.id_turno), 0) / 100, 2)) * COALESCE((SELECT MAX(caz.porcentaje_sena) FROM agenda.TurnoProtocolo tpy JOIN clinica.Protocolo prz ON prz.id_protocolo = tpy.id_protocolo JOIN clinica.CategoriaProtocolo caz ON caz.id_categoria = prz.id_categoria WHERE tpy.id_turno = t.id_turno), 0) / 100, 0) AS sena,
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
            (SELECT MAX(n.id_notificacion) FROM notificaciones.Notificacion n
               JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion AND tn.nombre = 'recordatorio de turno'
              WHERE n.id_turno = t.id_turno)
      LEFT JOIN notificaciones.CanalNotificacion ca ON ca.id_canal = nr.id_canal
      LEFT JOIN notificaciones.EstadoNotificacion es ON es.id_estado_notificacion = nr.id_estado_notificacion
     WHERE CHAR_LENGTH(v_texto) >= 3
       AND (p.dni = v_texto
            OR p.nombre = v_texto OR p.apellido = v_texto
            OR EXISTS (SELECT 1 FROM personas.TelefonoPaciente tp3 WHERE tp3.id_paciente = p.id_paciente AND tp3.telefono = v_texto))
       AND (COALESCE(p_solo_vigentes, 0) = 0 OR (e.nombre IN ('pendiente', 'confirmado') AND t.fecha_hora_inicio > COALESCE(@ahora_simulado, NOW())))
     ORDER BY t.fecha_hora_inicio DESC;
END//

-- Agenda de un período: todos los turnos con fecha de inicio entre p_desde y
-- p_hasta (inclusive), con las mismas columnas que sp_buscar_turnos. Lo usan la
-- pantalla de inicio y "Buscar turnos" sin texto. Con fechas NULL o invertidas: 0 filas.
DROP PROCEDURE IF EXISTS agenda.sp_turnos_del_periodo//
CREATE PROCEDURE agenda.sp_turnos_del_periodo(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT t.id_turno, p.id_paciente, p.apellido AS paciente, p.nombre AS paciente_nombre, p.dni,
           (SELECT tp2.telefono FROM personas.TelefonoPaciente tp2 WHERE tp2.id_telefono_paciente = (SELECT MIN(tp2x.id_telefono_paciente) FROM personas.TelefonoPaciente tp2x WHERE tp2x.id_paciente = p.id_paciente)) AS telefono,
           pr.apellido AS profesional, pr.nombre AS profesional_nombre, t.fecha_hora_inicio, t.fecha_hora_fin,
           e.nombre AS estado, o.nombre AS origen,
           (SELECT MIN(pt.nombre) FROM agenda.TurnoProtocolo tp JOIN clinica.Protocolo pt ON pt.id_protocolo = tp.id_protocolo WHERE tp.id_turno = t.id_turno) AS protocolos,
           (COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = t.id_turno), 0) / 100, 2)) AS precio_final,
           ROUND((COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) - ROUND(COALESCE((SELECT SUM(tpz.precio_aplicado) FROM agenda.TurnoProtocolo tpz WHERE tpz.id_turno = t.id_turno), 0) * COALESCE((SELECT cuz.porcentaje_descuento FROM beneficios.Cupon cuz WHERE cuz.id_turno = t.id_turno), 0) / 100, 2)) * COALESCE((SELECT MAX(caz.porcentaje_sena) FROM agenda.TurnoProtocolo tpy JOIN clinica.Protocolo prz ON prz.id_protocolo = tpy.id_protocolo JOIN clinica.CategoriaProtocolo caz ON caz.id_categoria = prz.id_categoria WHERE tpy.id_turno = t.id_turno), 0) / 100, 0) AS sena,
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
            (SELECT MAX(n.id_notificacion) FROM notificaciones.Notificacion n
               JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion AND tn.nombre = 'recordatorio de turno'
              WHERE n.id_turno = t.id_turno)
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
           (SELECT tp.telefono FROM personas.TelefonoPaciente tp WHERE tp.id_telefono_paciente = (SELECT MIN(tpx.id_telefono_paciente) FROM personas.TelefonoPaciente tpx WHERE tpx.id_paciente = p.id_paciente)) AS telefono,
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
           p.apellido AS paciente, p.nombre AS paciente_nombre, p.dni,
           (SELECT tp.telefono FROM personas.TelefonoPaciente tp WHERE tp.id_telefono_paciente = (SELECT MIN(tpx.id_telefono_paciente) FROM personas.TelefonoPaciente tpx WHERE tpx.id_paciente = p.id_paciente)) AS telefono,
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

-- ======================================================================
-- Seña, cancelación, evaluaciones, tarjetas, cupones, notificaciones y asistente
-- ======================================================================


-- ---------------------------------------------------------------------
-- Origen: 04_sp_semana4.sql
-- ---------------------------------------------------------------------

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

-- ======================================================================
-- Reportes (8) y reporte de auditoría
-- ======================================================================


-- ---------------------------------------------------------------------
-- Origen: 05_reportes_semana5.sql
-- ---------------------------------------------------------------------

-- Dermalia: reportes y auditoría de la Semana 5 (MySQL 8).
-- Se corre después de 04_sp_semana4.sql:
--   mysql -u root -p < backend/05_reportes_semana5.sql
--
-- Consigna 5c: al menos 8 reportes de distinta índole, todos con funciones de
-- agrupamiento, reuniones (JOIN) y gestión de fechas. Consigna 5d: un reporte
-- de auditoría con parámetros y siempre con rango de fechas.
--
-- Todos reciben un rango de fechas (p_desde, p_hasta, ambos inclusive). Con
-- parámetros NULL o con p_desde > p_hasta devuelven 0 filas (sin error).
-- Los dos reportes con versión `_tuneado` están en 06_tuning_semana6.sql.

DELIMITER //

-- Reporte 1: turnos por período (mes) y profesional.
-- Cuántos turnos hubo, cómo terminaron, cuántas horas se agendaron y cuánto
-- se facturó (a precio de lista) en los realizados. p_id_profesional NULL = todos.
DROP PROCEDURE IF EXISTS agenda.sp_reporte_turnos_por_periodo_profesional//
CREATE PROCEDURE agenda.sp_reporte_turnos_por_periodo_profesional(
    IN p_desde DATE, IN p_hasta DATE, IN p_id_profesional INT)
BEGIN
    SELECT DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') AS periodo,
           pr.id_profesional,
           pr.apellido AS profesional, pr.nombre AS profesional_nombre,
           COUNT(*) AS turnos,
           SUM(e.nombre = 'realizado') AS realizados,
           SUM(e.nombre = 'cancelado') AS cancelados,
           SUM(e.nombre = 'ausente') AS ausentes,
           SUM(e.nombre IN ('pendiente', 'confirmado')) AS vigentes,
           ROUND(SUM(((EXTRACT(HOUR FROM t.fecha_hora_fin) - EXTRACT(HOUR FROM t.fecha_hora_inicio)) * 60 + EXTRACT(MINUTE FROM t.fecha_hora_fin) - EXTRACT(MINUTE FROM t.fecha_hora_inicio))) / 60, 1) AS horas_agendadas,
           SUM(COALESCE((SELECT (SELECT SUM(tp.precio_aplicado) FROM agenda.TurnoProtocolo tp WHERE tp.id_turno = t.id_turno)
                    FROM DUAL WHERE e.nombre = 'realizado'
                   ), 0)) AS facturado
      FROM agenda.Turno t
      JOIN personas.Profesional pr ON pr.id_profesional = t.id_profesional
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE DATE(t.fecha_hora_inicio) BETWEEN p_desde AND p_hasta
       AND (p_id_profesional IS NULL OR t.id_profesional = p_id_profesional)
     GROUP BY DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m'), pr.id_profesional, pr.apellido, pr.nombre
     ORDER BY periodo, profesional, profesional_nombre;
END//

-- Reporte 2: ingresos por seña, reembolsos y retenciones, por mes y medio de pago.
-- Lo retenido es lo que el instituto se queda de las señas ya resueltas.
DROP PROCEDURE IF EXISTS pagos.sp_reporte_ingresos_sena//
CREATE PROCEDURE pagos.sp_reporte_ingresos_sena(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT DATE_FORMAT(ps.fecha_pago, '%Y-%m') AS periodo,
           (SELECT mp.nombre FROM pagos.MedioPago mp WHERE mp.id_medio_pago = ps.id_medio_pago) AS medio_pago,
           COUNT(*) AS pagos,
           SUM(ps.monto) AS cobrado,
           SUM(COALESCE(ps.monto_reembolsado, 0)) AS reembolsado,
           SUM(COALESCE((SELECT ps.monto - COALESCE(ps.monto_reembolsado, 0) FROM DUAL WHERE ep.nombre IN ('retenida', 'reembolsada parcial')), 0)) AS retenido,
           SUM(ps.monto - COALESCE(ps.monto_reembolsado, 0)) AS neto
      FROM pagos.PagoSena ps
      JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
     WHERE DATE(ps.fecha_pago) BETWEEN p_desde AND p_hasta
     GROUP BY DATE_FORMAT(ps.fecha_pago, '%Y-%m'), ps.id_medio_pago
     ORDER BY periodo, medio_pago;
END//

-- Reporte 3: cancelaciones e inasistencias (los "turnos perdidos" de la MML).
-- p_agrupar: 'mes' (por defecto) o 'semana'. Muestra por origen cuántos turnos
-- se perdieron, la tasa de pérdida y la plata de señas retenida.
DROP PROCEDURE IF EXISTS agenda.sp_reporte_cancelaciones_inasistencias//
CREATE PROCEDURE agenda.sp_reporte_cancelaciones_inasistencias(IN p_desde DATE, IN p_hasta DATE, IN p_agrupar VARCHAR(10))
BEGIN
    DECLARE v_semana SMALLINT DEFAULT (p_agrupar = 'semana');
    SELECT x.periodo, x.origen,
           COUNT(*) AS turnos,
           SUM(x.estado = 'cancelado') AS cancelados,
           SUM(x.estado = 'cancelado' AND x.estado_sena = 'reembolsada') AS cancelados_con_aviso,
           SUM(x.estado = 'cancelado' AND x.estado_sena = 'retenida') AS cancelados_tarde,
           SUM(x.estado = 'ausente') AS ausentes,
           ROUND(100 * SUM(x.estado IN ('cancelado', 'ausente')) / COUNT(*), 1) AS tasa_perdida_pct,
           COALESCE(SUM((SELECT x.monto - COALESCE(x.reembolsado, 0) FROM DUAL WHERE x.estado IN ('cancelado', 'ausente') AND x.estado_sena IN ('retenida', 'reembolsada parcial')
                            )), 0) AS sena_retenida
      FROM (SELECT COALESCE((SELECT DATE_FORMAT(t.fecha_hora_inicio, '%x-S%v') FROM DUAL WHERE v_semana), DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m')) AS periodo,
                   o.nombre AS origen, e.nombre AS estado, ep.nombre AS estado_sena, ps.monto, ps.monto_reembolsado AS reembolsado
              FROM agenda.Turno t
              JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
              JOIN agenda.Origen o ON o.id_origen = t.id_origen
              LEFT JOIN pagos.PagoSena ps ON ps.id_turno = t.id_turno
              LEFT JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
             WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY) x
     GROUP BY x.periodo, x.origen
     ORDER BY x.periodo, x.origen;
END//

-- Reporte 4: evaluaciones previas y cirugías por resultado.
-- Por cirugía y resultado: cuántas evaluaciones, cuántas terminaron en una
-- cirugía agendada, cuántas vencieron sin agendar, en cuántos días se
-- decidieron y cuánta plata de consultas retuvo el instituto.
-- Se cuentan las consultas realizadas dentro del rango.
DROP PROCEDURE IF EXISTS clinica.sp_reporte_evaluaciones_cirugias//
CREATE PROCEDURE clinica.sp_reporte_evaluaciones_cirugias(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT cir.nombre AS cirugia,
           r.nombre AS resultado,
           COUNT(*) AS evaluaciones,
           COUNT(tc.id_turno) AS con_cirugia_agendada,
           SUM(r.nombre = 'apto' AND tc.id_turno IS NULL AND ev.fecha_resultado + INTERVAL 6 MONTH < COALESCE(@ahora_simulado, NOW())) AS vencidas_sin_cirugia,
           SUM(ev.fecha_reclamo IS NOT NULL) AS reclamos,
           COALESCE(SUM((SELECT ps.monto - COALESCE(ps.monto_reembolsado, 0) FROM DUAL WHERE ep.nombre IN ('retenida', 'reembolsada parcial'))), 0) AS consulta_retenida
      FROM clinica.EvaluacionPrevia ev
      JOIN clinica.Protocolo cir ON cir.id_protocolo = ev.id_protocolo
      JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
      JOIN agenda.Turno t ON t.id_turno = ev.id_turno
      LEFT JOIN agenda.Turno tc ON tc.id_evaluacion_previa = ev.id_evaluacion
      LEFT JOIN pagos.PagoSena ps ON ps.id_turno = ev.id_turno
      LEFT JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago
     WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
     GROUP BY cir.id_protocolo, cir.nombre, r.id_resultado, r.nombre
     ORDER BY cirugia, resultado;
END//

-- Reporte 5: protocolos más pedidos en un período (sin contar turnos cancelados).
-- Puesto en el ranking = 1 + cuántos protocolos tienen más pedidos (o los mismos y
-- un nombre anterior en el alfabeto); porcentaje sobre el total de pedidos.
-- p_limite NULL = 10. Se arma con tablas temporales, como el Cheetah A del material:
-- primero se filtra y se agrupa, después se compara. n2 es una copia de n1 porque
-- MySQL no deja usar dos veces la misma tabla temporal en una consulta.
DROP PROCEDURE IF EXISTS clinica.sp_reporte_protocolos_mas_pedidos//
CREATE PROCEDURE clinica.sp_reporte_protocolos_mas_pedidos(IN p_desde DATE, IN p_hasta DATE, IN p_limite INT)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n2;

    CREATE TEMPORARY TABLE tmp_pedidos_n1 AS
    SELECT p.id_protocolo, p.nombre AS protocolo, c.nombre AS categoria,
           COUNT(*) AS pedidos, SUM(tp.precio_aplicado) AS ingresos_lista
      FROM agenda.TurnoProtocolo tp
      JOIN agenda.Turno t ON t.id_turno = tp.id_turno
      JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre <> 'cancelado'
      JOIN clinica.Protocolo p ON p.id_protocolo = tp.id_protocolo
      JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
     WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
     GROUP BY p.id_protocolo, p.nombre, c.nombre;

    CREATE TEMPORARY TABLE tmp_pedidos_n2 AS
    SELECT id_protocolo, protocolo, pedidos
      FROM tmp_pedidos_n1;

    SELECT x.puesto, x.protocolo, x.categoria, x.pedidos, x.ingresos_lista,
           ROUND(100 * x.pedidos / x.total_pedidos, 1) AS porcentaje
      FROM (
            SELECT 1 + COUNT(m.id_protocolo) AS puesto,
                   a.protocolo, a.categoria, a.pedidos, a.ingresos_lista,
                   (SELECT SUM(pedidos) FROM tmp_pedidos_n2) AS total_pedidos
              FROM tmp_pedidos_n1 a
              LEFT JOIN tmp_pedidos_n2 m
                     ON m.pedidos > a.pedidos
                     OR (m.pedidos = a.pedidos AND m.protocolo < a.protocolo)
             GROUP BY a.id_protocolo, a.protocolo, a.categoria, a.pedidos, a.ingresos_lista
           ) x
     WHERE x.puesto <= COALESCE(p_limite, 10)
     ORDER BY x.puesto, x.protocolo;

    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos_n2;
END//

-- Reporte 6: ocupación por profesional = horas con turno / horas de disponibilidad.
DROP PROCEDURE IF EXISTS agenda.sp_reporte_ocupacion_profesional//
CREATE PROCEDURE agenda.sp_reporte_ocupacion_profesional(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT pr.id_profesional, pr.apellido AS profesional, pr.nombre AS profesional_nombre,
           ROUND(COALESCE(d.horas, 0), 1) AS horas_disponibles,
           ROUND(COALESCE(o.horas, 0), 1) AS horas_ocupadas,
           COALESCE(o.turnos, 0) AS turnos,
           ROUND(100 * COALESCE(o.horas, 0) / (SELECT d.horas FROM DUAL WHERE d.horas <> 0), 1) AS ocupacion_pct
      FROM personas.Profesional pr
      LEFT JOIN (SELECT dd.id_profesional, SUM((EXTRACT(HOUR FROM dd.hora_fin) - EXTRACT(HOUR FROM dd.hora_inicio)) * 60 + EXTRACT(MINUTE FROM dd.hora_fin) - EXTRACT(MINUTE FROM dd.hora_inicio)) / 60 AS horas
                   FROM personas.Disponibilidad dd
                  WHERE dd.activa = 1 AND dd.fecha BETWEEN p_desde AND p_hasta
                  GROUP BY dd.id_profesional) d ON d.id_profesional = pr.id_profesional
      LEFT JOIN (SELECT t.id_profesional, COUNT(*) AS turnos, SUM(((EXTRACT(HOUR FROM t.fecha_hora_fin) - EXTRACT(HOUR FROM t.fecha_hora_inicio)) * 60 + EXTRACT(MINUTE FROM t.fecha_hora_fin) - EXTRACT(MINUTE FROM t.fecha_hora_inicio))) / 60 AS horas
                   FROM agenda.Turno t
                   JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre <> 'cancelado'
                  WHERE t.fecha_hora_inicio >= p_desde AND t.fecha_hora_inicio < p_hasta + INTERVAL 1 DAY
                  GROUP BY t.id_profesional) o ON o.id_profesional = pr.id_profesional
     WHERE p_desde IS NOT NULL AND p_hasta IS NOT NULL AND p_desde <= p_hasta
       AND (d.horas IS NOT NULL OR o.horas IS NOT NULL)
     ORDER BY ocupacion_pct DESC, profesional;
END//

-- Reporte 7: uso de cupones y reglas de beneficio, por regla.
-- Cupones emitidos en el rango: cuántos se usaron, cuántos vencieron sin usar,
-- cuántos siguen vigentes, tasa de uso y descuento total otorgado.
DROP PROCEDURE IF EXISTS beneficios.sp_reporte_cupones//
CREATE PROCEDURE beneficios.sp_reporte_cupones(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT r.id_regla, r.nombre AS regla, tr.nombre AS tipo, r.porcentaje_descuento AS descuento_pct,
           COUNT(*) AS emitidos,
           SUM(c.id_turno IS NOT NULL) AS usados,
           SUM(c.id_turno IS NULL AND c.fecha_vencimiento <= COALESCE(@ahora_simulado, NOW())) AS vencidos_sin_usar,
           SUM(c.id_turno IS NULL AND c.fecha_vencimiento > COALESCE(@ahora_simulado, NOW())) AS vigentes,
           ROUND(100 * SUM(c.id_turno IS NOT NULL) / COUNT(*), 1) AS tasa_uso_pct,
           COALESCE(SUM(pt.total * c.porcentaje_descuento / 100), 0) AS descuento_otorgado
      FROM beneficios.Cupon c
      JOIN beneficios.ReglaBeneficio r ON r.id_regla = c.id_regla
      JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla
      LEFT JOIN (SELECT tp.id_turno, SUM(tp.precio_aplicado) AS total FROM agenda.TurnoProtocolo tp GROUP BY tp.id_turno) pt ON pt.id_turno = c.id_turno
     WHERE c.fecha_emision >= p_desde AND c.fecha_emision < p_hasta + INTERVAL 1 DAY
     GROUP BY r.id_regla, r.nombre, tr.nombre, r.porcentaje_descuento
     ORDER BY emitidos DESC, regla;
END//

-- Reporte 8: saldo y uso de las tarjetas de regalo compradas en el rango.
-- El código se muestra recortado: el código completo funciona como un billete.
DROP PROCEDURE IF EXISTS pagos.sp_reporte_tarjetas_regalo//
CREATE PROCEDURE pagos.sp_reporte_tarjetas_regalo(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT t.id_tarjeta, CAST(t.codigo AS CHAR(7)) AS codigo, t.comprador_nombre, mp.nombre AS medio_compra,
           DATE(t.fecha_compra) AS fecha_compra, DATE(t.fecha_vencimiento) AS vence,
           t.monto_inicial,
           COALESCE(SUM((m.monto > 0) * m.monto), 0) AS gastado,
           COALESCE(-SUM((m.monto < 0) * m.monto), 0) AS devuelto,
           t.monto_inicial - COALESCE(SUM(m.monto), 0) AS saldo,
           COUNT(m.id_movimiento) AS movimientos,
           MAX(m.fecha_movimiento) AS ultimo_uso,
           COALESCE((SELECT 'vencida' FROM DUAL WHERE t.fecha_vencimiento <= COALESCE(@ahora_simulado, NOW())),
                    (SELECT 'agotada' FROM DUAL WHERE t.monto_inicial - COALESCE(SUM(m.monto), 0) <= 0),
                    (SELECT 'sin uso' FROM DUAL WHERE COUNT(m.id_movimiento) = 0), 'en uso') AS situacion
      FROM pagos.TarjetaRegalo t
      JOIN pagos.MedioPago mp ON mp.id_medio_pago = t.id_medio_pago
      LEFT JOIN pagos.MovimientoTarjeta m ON m.id_tarjeta = t.id_tarjeta
     WHERE t.fecha_compra >= p_desde AND t.fecha_compra < p_hasta + INTERVAL 1 DAY
     GROUP BY t.id_tarjeta, t.codigo, t.comprador_nombre, mp.nombre, t.fecha_compra, t.fecha_vencimiento, t.monto_inicial
     ORDER BY t.fecha_compra, t.id_tarjeta;
END//

-- Reporte de auditoría (consigna 5d): quién hizo qué, cuándo y desde dónde.
-- El rango de fechas es obligatorio (p_hasta incluye todo ese día). Los demás
-- filtros son opcionales (NULL = sin filtrar):
--   p_tipo_evento  nombre del tipo ('inicio_sesion', 'alta_turno', ...)
--   p_id_usuario   quién hizo la acción
--   p_id_paciente  paciente involucrada
--   p_exitoso      1 = solo lo que salió bien, 0 = solo los fallos
--   p_origen       'terminal', 'web', 'gestion' o 'sistema'
DROP PROCEDURE IF EXISTS auditoria.sp_reporte_auditoria//
CREATE PROCEDURE auditoria.sp_reporte_auditoria(
    IN p_desde DATE, IN p_hasta DATE, IN p_tipo_evento VARCHAR(50), IN p_id_usuario INT,
    IN p_id_paciente INT, IN p_exitoso SMALLINT, IN p_origen VARCHAR(50))
BEGIN
    SELECT l.id_log, l.fecha_hora, te.nombre AS evento, COALESCE(u.nombre_usuario, '(sin usuario)') AS usuario,
           r.nombre AS rol, p.apellido AS paciente, p.nombre AS paciente_nombre, o.nombre AS origen,
           l.exitoso, l.descripcion, l.tabla_afectada, l.id_registro_afectado, l.valor_anterior, l.valor_nuevo, l.ip_origen
      FROM auditoria.Log l
      JOIN auditoria.TipoEvento te ON te.id_tipo_evento = l.id_tipo_evento
      JOIN agenda.Origen o ON o.id_origen = l.id_origen
      LEFT JOIN seguridad.Usuario u ON u.id_usuario = l.id_usuario
      LEFT JOIN seguridad.Rol r ON r.id_rol = u.id_rol
      LEFT JOIN personas.Paciente p ON p.id_paciente = l.id_paciente
     WHERE l.fecha_hora >= p_desde AND l.fecha_hora < p_hasta + INTERVAL 1 DAY
       AND (p_tipo_evento IS NULL OR te.nombre = p_tipo_evento)
       AND (p_id_usuario IS NULL OR l.id_usuario = p_id_usuario)
       AND (p_id_paciente IS NULL OR l.id_paciente = p_id_paciente)
       AND (p_exitoso IS NULL OR l.exitoso = p_exitoso)
       AND (p_origen IS NULL OR o.nombre = p_origen)
     ORDER BY l.fecha_hora, l.id_log;
END//

DELIMITER ;

-- ======================================================================
-- Reportes con tuning (_tuneado)
-- ======================================================================


-- ---------------------------------------------------------------------
-- Origen: 06_tuning_semana6.sql
-- ---------------------------------------------------------------------

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

-- Reporte 1 tuneado. Devuelve exactamente lo mismo que el original.
DROP PROCEDURE IF EXISTS agenda.sp_reporte_turnos_por_periodo_profesional_tuneado//
CREATE PROCEDURE agenda.sp_reporte_turnos_por_periodo_profesional_tuneado(
    IN p_desde DATE, IN p_hasta DATE, IN p_id_profesional INT)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n4;

    -- N1: Turno con la selección (fechas y profesional) y la proyección aplicadas
    CREATE TEMPORARY TABLE tmp_r1_n1 AS
    SELECT id_turno, id_profesional, id_estado_turno, fecha_hora_inicio, fecha_hora_fin
      FROM agenda.Turno
     WHERE DATE(fecha_hora_inicio) BETWEEN p_desde AND p_hasta
       AND (p_id_profesional IS NULL OR id_profesional = p_id_profesional);

    -- N2: EstadoTurno proyectado
    CREATE TEMPORARY TABLE tmp_r1_n2 AS
    SELECT id_estado_turno, nombre
      FROM agenda.EstadoTurno;

    -- N3: Profesional proyectado
    CREATE TEMPORARY TABLE tmp_r1_n3 AS
    SELECT id_profesional, apellido, nombre
      FROM personas.Profesional;

    -- N4: total de lista de cada turno de N1 (se junta TurnoProtocolo solo con esos turnos)
    CREATE TEMPORARY TABLE tmp_r1_n4 AS
    SELECT tp.id_turno, SUM(tp.precio_aplicado) AS total
      FROM agenda.TurnoProtocolo tp
      JOIN tmp_r1_n1 a ON a.id_turno = tp.id_turno
     GROUP BY tp.id_turno;

    -- Reunión final y agrupamiento
    SELECT DATE_FORMAT(a.fecha_hora_inicio, '%Y-%m') AS periodo,
           p.id_profesional,
           p.apellido AS profesional, p.nombre AS profesional_nombre,
           COUNT(*) AS turnos,
           SUM(e.nombre = 'realizado') AS realizados,
           SUM(e.nombre = 'cancelado') AS cancelados,
           SUM(e.nombre = 'ausente') AS ausentes,
           SUM(e.nombre IN ('pendiente', 'confirmado')) AS vigentes,
           ROUND(SUM(((EXTRACT(HOUR FROM a.fecha_hora_fin) - EXTRACT(HOUR FROM a.fecha_hora_inicio)) * 60 + EXTRACT(MINUTE FROM a.fecha_hora_fin) - EXTRACT(MINUTE FROM a.fecha_hora_inicio))) / 60, 1) AS horas_agendadas,
           SUM((e.nombre = 'realizado') * COALESCE(f.total, 0)) AS facturado
      FROM tmp_r1_n1 a
      JOIN tmp_r1_n3 p ON p.id_profesional = a.id_profesional
      JOIN tmp_r1_n2 e ON e.id_estado_turno = a.id_estado_turno
      LEFT JOIN tmp_r1_n4 f ON f.id_turno = a.id_turno
     GROUP BY DATE_FORMAT(a.fecha_hora_inicio, '%Y-%m'), p.id_profesional, p.apellido, p.nombre
     ORDER BY periodo, profesional, profesional_nombre;

    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n3;
    DROP TEMPORARY TABLE IF EXISTS tmp_r1_n4;
END//

-- Reporte 2 tuneado. Devuelve exactamente lo mismo que el original.
DROP PROCEDURE IF EXISTS pagos.sp_reporte_ingresos_sena_tuneado//
CREATE PROCEDURE pagos.sp_reporte_ingresos_sena_tuneado(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n3;

    -- N1: PagoSena con la selección (fechas) y la proyección aplicadas
    CREATE TEMPORARY TABLE tmp_r2_n1 AS
    SELECT id_medio_pago, id_estado_pago, monto, monto_reembolsado, fecha_pago
      FROM pagos.PagoSena
     WHERE DATE(fecha_pago) BETWEEN p_desde AND p_hasta;

    -- N2: EstadoPago proyectado
    CREATE TEMPORARY TABLE tmp_r2_n2 AS
    SELECT id_estado_pago, nombre
      FROM pagos.EstadoPago;

    -- N3: MedioPago proyectado
    CREATE TEMPORARY TABLE tmp_r2_n3 AS
    SELECT id_medio_pago, nombre
      FROM pagos.MedioPago;

    -- Reunión final y agrupamiento
    SELECT DATE_FORMAT(a.fecha_pago, '%Y-%m') AS periodo,
           m.nombre AS medio_pago,
           COUNT(*) AS pagos,
           SUM(a.monto) AS cobrado,
           SUM(COALESCE(a.monto_reembolsado, 0)) AS reembolsado,
           SUM(COALESCE((SELECT a.monto - COALESCE(a.monto_reembolsado, 0) FROM DUAL WHERE e.nombre IN ('retenida', 'reembolsada parcial')), 0)) AS retenido,
           SUM(a.monto - COALESCE(a.monto_reembolsado, 0)) AS neto
      FROM tmp_r2_n1 a
      JOIN tmp_r2_n2 e ON e.id_estado_pago = a.id_estado_pago
      JOIN tmp_r2_n3 m ON m.id_medio_pago = a.id_medio_pago
     GROUP BY DATE_FORMAT(a.fecha_pago, '%Y-%m'), a.id_medio_pago, m.nombre
     ORDER BY periodo, medio_pago;

    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n1;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n2;
    DROP TEMPORARY TABLE IF EXISTS tmp_r2_n3;
END//

DELIMITER ;

