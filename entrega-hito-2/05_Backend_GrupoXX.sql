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

-- Reloj del sistema. Si la sesión define @ahora_simulado, los SP usan esa hora
-- (sirve para cargar historia y para probar vencimientos sin esperar meses).
DROP FUNCTION IF EXISTS auditoria.fn_ahora//
CREATE FUNCTION auditoria.fn_ahora() RETURNS DATETIME
    NOT DETERMINISTIC NO SQL
BEGIN
    RETURN COALESCE(@ahora_simulado, CURRENT_TIMESTAMP);
END//

-- Escribe una fila en el log. Nunca falla: si el tipo de evento no existe no
-- escribe nada, y un usuario o paciente inexistente queda como NULL.
DROP PROCEDURE IF EXISTS auditoria.sp_registrar_log//
CREATE PROCEDURE auditoria.sp_registrar_log(
    IN p_tipo VARCHAR(50), IN p_id_usuario INT, IN p_id_paciente INT, IN p_origen VARCHAR(50),
    IN p_descripcion VARCHAR(2000), IN p_tabla VARCHAR(100), IN p_id_registro INT,
    IN p_anterior TEXT, IN p_nuevo TEXT, IN p_exitoso SMALLINT, IN p_ip VARCHAR(45))
BEGIN
    INSERT INTO auditoria.Log (id_tipo_evento, id_usuario, id_paciente, id_origen, fecha_hora, descripcion,
                               ip_origen, tabla_afectada, id_registro_afectado, valor_anterior, valor_nuevo, exitoso)
    SELECT te.id_tipo_evento,
           (SELECT u.id_usuario FROM seguridad.Usuario u WHERE u.id_usuario = p_id_usuario),
           (SELECT p.id_paciente FROM personas.Paciente p WHERE p.id_paciente = p_id_paciente),
           COALESCE((SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = p_origen),
                    (SELECT o.id_origen FROM agenda.Origen o WHERE o.nombre = 'sistema')),
           auditoria.fn_ahora(), SUBSTRING(p_descripcion FROM 1 FOR 500), p_ip, p_tabla, p_id_registro,
           p_anterior, p_nuevo, COALESCE(p_exitoso, 1)
    FROM auditoria.TipoEvento te
    WHERE te.nombre = p_tipo;
END//

-- Precio de un turno: suma de lo que costaba cada protocolo al agendar.
-- Validaciones de formato sin expresiones regulares (el material no las enseña).
-- Cada una devuelve 1 si el dato tiene buen formato y 0 si no. Usan solo LIKE, CAST,
-- CHAR_LENGTH y REPLACE. Son aproximaciones: no aceptan un DNI ni un teléfono que
-- empiece con cero, porque se compara el número con su texto.
DROP FUNCTION IF EXISTS personas.fn_es_dni//
CREATE FUNCTION personas.fn_es_dni(p_dni VARCHAR(20)) RETURNS SMALLINT
    DETERMINISTIC NO SQL
BEGIN
    RETURN CASE WHEN p_dni IS NULL THEN 0
                WHEN CHAR_LENGTH(p_dni) NOT BETWEEN 7 AND 8 THEN 0
                WHEN CAST(CAST(p_dni AS UNSIGNED) AS CHAR) = p_dni THEN 1
                ELSE 0 END;
END//

DROP FUNCTION IF EXISTS personas.fn_es_telefono//
CREATE FUNCTION personas.fn_es_telefono(p_telefono VARCHAR(30)) RETURNS SMALLINT
    DETERMINISTIC NO SQL
BEGIN
    DECLARE v_numero VARCHAR(30);
    SET v_numero = CASE WHEN p_telefono LIKE '+%' THEN SUBSTRING(p_telefono FROM 2) ELSE p_telefono END;
    RETURN CASE WHEN v_numero IS NULL THEN 0
                WHEN CHAR_LENGTH(v_numero) NOT BETWEEN 10 AND 13 THEN 0
                WHEN CAST(CAST(v_numero AS UNSIGNED) AS CHAR) = v_numero THEN 1
                ELSE 0 END;
END//

DROP FUNCTION IF EXISTS personas.fn_es_email//
CREATE FUNCTION personas.fn_es_email(p_email VARCHAR(200)) RETURNS SMALLINT
    DETERMINISTIC NO SQL
BEGIN
    RETURN CASE WHEN p_email IS NULL THEN 0
                WHEN p_email LIKE '% %' THEN 0
                WHEN CHAR_LENGTH(p_email) - CHAR_LENGTH(REPLACE(p_email, '@', '')) <> 1 THEN 0
                WHEN p_email LIKE '%_@_%._%' THEN 1
                ELSE 0 END;
END//

DROP FUNCTION IF EXISTS personas.fn_es_usuario//
CREATE FUNCTION personas.fn_es_usuario(p_usuario VARCHAR(100)) RETURNS SMALLINT
    DETERMINISTIC NO SQL
BEGIN
    RETURN CASE WHEN p_usuario IS NULL THEN 0
                WHEN CHAR_LENGTH(p_usuario) NOT BETWEEN 4 AND 50 THEN 0
                WHEN p_usuario LIKE '% %' OR p_usuario LIKE '%@%' THEN 0
                WHEN CAST(p_usuario AS BINARY) <> CAST(LOWER(p_usuario) AS BINARY) THEN 0
                ELSE 1 END;
END//

-- Minutos entre dos horas del mismo día (reemplaza a TIMESTAMPDIFF, que el material no enseña).
DROP FUNCTION IF EXISTS agenda.fn_minutos//
CREATE FUNCTION agenda.fn_minutos(p_inicio DATETIME, p_fin DATETIME) RETURNS INT
    DETERMINISTIC NO SQL
BEGIN
    RETURN (EXTRACT(HOUR FROM p_fin) - EXTRACT(HOUR FROM p_inicio)) * 60 + EXTRACT(MINUTE FROM p_fin) - EXTRACT(MINUTE FROM p_inicio);
END//

-- Carga en una tabla temporal los ids de una lista separada por comas ('3,7').
-- Reemplaza a JSON_TABLE: recorre el texto con WHILE, POSITION y SUBSTRING.
DROP PROCEDURE IF EXISTS agenda.sp_cargar_protocolos//
CREATE PROCEDURE agenda.sp_cargar_protocolos(IN p_csv VARCHAR(200))
BEGIN
    DECLARE v_resto VARCHAR(200);
    DECLARE v_pos INT;
    DROP TEMPORARY TABLE IF EXISTS agenda.tmp_protocolos_pedidos;
    CREATE TEMPORARY TABLE agenda.tmp_protocolos_pedidos (id INT);
    SET v_resto = COALESCE(p_csv, '');
    WHILE CHAR_LENGTH(v_resto) > 0 DO
        SET v_pos = POSITION(',' IN v_resto);
        IF v_pos = 0 THEN
            INSERT INTO agenda.tmp_protocolos_pedidos (id) VALUES (CAST(v_resto AS UNSIGNED));
            SET v_resto = '';
        ELSE
            INSERT INTO agenda.tmp_protocolos_pedidos (id) VALUES (CAST(SUBSTRING(v_resto FROM 1 FOR v_pos - 1) AS UNSIGNED));
            SET v_resto = SUBSTRING(v_resto FROM v_pos + 1);
        END IF;
    END WHILE;
END//

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
cuerpo: BEGIN
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
        SELECT 'ERROR' AS estado, 52100 AS codigo, 'El pago de seña no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    -- Solo se resuelve una seña 'pagada'. Única excepción: una seña retenida al vencer
    -- una evaluación puede pasar a 'reembolsada parcial' si la paciente reclama.
    IF v_estado <> 'pagada' AND NOT (v_estado = 'retenida' AND p_estado = 'reembolsada parcial') THEN
        SELECT 'ERROR' AS estado, 52101 AS codigo, 'La seña ya fue resuelta (reembolsada o retenida)' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_monto_reembolsado IS NULL OR p_monto_reembolsado < 0 OR p_monto_reembolsado > v_monto THEN
        SELECT 'ERROR' AS estado, 52102 AS codigo, 'El monto a reembolsar no es válido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_estado NOT IN ('reembolsada', 'reembolsada parcial', 'retenida') THEN
        SELECT 'ERROR' AS estado, 52103 AS codigo, 'Estado de pago inválido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    SET v_anterior = CAST(v_estado AS CHAR);
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
           AND m.id_movimiento = (SELECT MIN(m2.id_movimiento) FROM pagos.MovimientoTarjeta m2 WHERE m2.id_turno = v_turno AND m2.monto > 0);
    END IF;

    CALL auditoria.sp_registrar_log(CASE WHEN p_monto_reembolsado > 0 THEN 'reembolso' ELSE 'retencion' END, p_id_usuario, v_paciente, p_origen,
        p_motivo,
        'pagos.PagoSena', p_id_pago, v_anterior,
        CAST(p_estado AS CHAR), 1, NULL);
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
                'Usuario inexistente o inactivo', 'seguridad.Usuario', NULL, NULL, NULL, 0, p_ip);
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
                'Ingreso como', 'seguridad.Usuario', v_id, NULL, NULL, 1, p_ip);
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
cuerpo: BEGIN
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
                                        'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT id_paciente, id_usuario INTO v_paciente, v_cuenta FROM personas.Paciente WHERE dni = p_dni;
    IF v_paciente IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cuenta_creada', NULL, v_paciente, p_origen, 'No hay una paciente con ese DNI',
                                                'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52020 AS codigo, 'No hay una paciente con ese DNI' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_cuenta IS NOT NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cuenta_creada', NULL, v_paciente, p_origen, 'Esa paciente ya tiene cuenta',
                                                'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52021 AS codigo, 'Esa paciente ya tiene cuenta' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_nombre_usuario IS NULL OR personas.fn_es_usuario(p_nombre_usuario) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cuenta_creada', NULL, v_paciente, p_origen, 'El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo',
                                                'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52022 AS codigo, 'El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_email IS NULL OR personas.fn_es_email(p_email) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cuenta_creada', NULL, v_paciente, p_origen, 'El email no es válido',
                                                'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52023 AS codigo, 'El email no es válido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_password IS NULL OR TRIM(p_password) = '' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cuenta_creada', NULL, v_paciente, p_origen, 'La contrasena no puede estar vacia',
                                                'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52024 AS codigo, 'La contrasena no puede estar vacia' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario OR email = p_email) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cuenta_creada', NULL, v_paciente, p_origen, 'Ese usuario o email ya está en uso',
                                                'seguridad.Usuario', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52025 AS codigo, 'Ese usuario o email ya está en uso' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    INSERT INTO seguridad.Usuario (id_rol, nombre_usuario, email, password)
    VALUES ((SELECT id_rol FROM seguridad.Rol WHERE nombre = 'paciente'), p_nombre_usuario, p_email, p_password);
    SELECT MAX(id_usuario) INTO v_usuario FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario;
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
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, v_msg,
                                        'personas.Paciente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_dni IS NULL OR personas.fn_es_dni(p_dni) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, 'El DNI debe tener 7 u 8 dígitos',
                                                'personas.Paciente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52030 AS codigo, 'El DNI debe tener 7 u 8 dígitos' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(TRIM(p_apellido)) < 2 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, 'Nombre y apellido deben tener al menos 2 letras',
                                                'personas.Paciente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52031 AS codigo, 'Nombre y apellido deben tener al menos 2 letras' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_telefono IS NULL OR personas.fn_es_telefono(p_telefono) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, 'El teléfono debe tener de 10 a 13 dígitos',
                                                'personas.Paciente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52032 AS codigo, 'El teléfono debe tener de 10 a 13 dígitos' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_fecha_nacimiento IS NULL OR p_fecha_nacimiento >= CURRENT_DATE THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, 'La fecha de nacimiento no es válida',
                                                'personas.Paciente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52033 AS codigo, 'La fecha de nacimiento no es válida' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_email IS NOT NULL AND p_email <> '' AND personas.fn_es_email(p_email) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, 'El email no es válido',
                                                'personas.Paciente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52034 AS codigo, 'El email no es válido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM personas.Paciente WHERE dni = p_dni) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, NULL, p_origen, 'Ya existe una paciente con ese DNI',
                                                'personas.Paciente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52035 AS codigo, 'Ya existe una paciente con ese DNI' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    INSERT INTO personas.Paciente (dni, nombre, apellido, fecha_nacimiento, fecha_alta, email)
    VALUES (p_dni, TRIM(p_nombre), TRIM(p_apellido), p_fecha_nacimiento, auditoria.fn_ahora(), NULLIF(TRIM(p_email), ''));
    SELECT MAX(id_paciente) INTO v_id FROM personas.Paciente WHERE dni = p_dni;
    INSERT INTO personas.TelefonoPaciente (id_paciente, telefono) VALUES (v_id, p_telefono);
    CALL auditoria.sp_registrar_log('alta_paciente', p_id_usuario, v_id, p_origen,
        'Alta de paciente DNI', 'personas.Paciente', v_id, NULL, TRIM(p_apellido), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Paciente creada' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
END//

-- Modifica nombre, apellido, email y, si viene, agrega un teléfono nuevo.
DROP PROCEDURE IF EXISTS personas.sp_modificar_paciente//
CREATE PROCEDURE personas.sp_modificar_paciente(
    IN p_id_paciente INT, IN p_nombre VARCHAR(50), IN p_apellido VARCHAR(50), IN p_email VARCHAR(100),
    IN p_telefono_nuevo VARCHAR(30), IN p_origen VARCHAR(50), IN p_id_usuario INT)
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_antes VARCHAR(400);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, v_msg,
                                        'personas.Paciente', p_id_paciente, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT nombre INTO v_antes
      FROM personas.Paciente WHERE id_paciente = p_id_paciente;
    IF v_antes IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, 'La paciente no existe',
                                                'personas.Paciente', p_id_paciente, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52036 AS codigo, 'La paciente no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(TRIM(p_apellido)) < 2 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, 'Nombre y apellido deben tener al menos 2 letras',
                                                'personas.Paciente', p_id_paciente, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52031 AS codigo, 'Nombre y apellido deben tener al menos 2 letras' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_email IS NOT NULL AND p_email <> '' AND personas.fn_es_email(p_email) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, 'El email no es válido',
                                                'personas.Paciente', p_id_paciente, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52034 AS codigo, 'El email no es válido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_telefono_nuevo IS NOT NULL AND p_telefono_nuevo <> '' AND personas.fn_es_telefono(p_telefono_nuevo) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, 'El teléfono debe tener de 10 a 13 dígitos',
                                                'personas.Paciente', p_id_paciente, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52032 AS codigo, 'El teléfono debe tener de 10 a 13 dígitos' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    UPDATE personas.Paciente
       SET nombre = TRIM(p_nombre), apellido = TRIM(p_apellido), email = NULLIF(TRIM(p_email), '')
     WHERE id_paciente = p_id_paciente;
    IF p_telefono_nuevo IS NOT NULL AND p_telefono_nuevo <> '' THEN
        INSERT INTO personas.TelefonoPaciente (id_paciente, telefono)
        SELECT p_id_paciente, p_telefono_nuevo
         WHERE NOT EXISTS (SELECT 1 FROM personas.TelefonoPaciente WHERE id_paciente = p_id_paciente AND telefono = p_telefono_nuevo);
    END IF;
    CALL auditoria.sp_registrar_log('modificacion_paciente', p_id_usuario, p_id_paciente, p_origen, 'Datos de la paciente modificados',
        'personas.Paciente', p_id_paciente, v_antes, TRIM(p_nombre), 1, NULL);
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
           (SELECT tp.telefono FROM personas.TelefonoPaciente tp
             WHERE tp.id_telefono_paciente = (SELECT MIN(tpx.id_telefono_paciente) FROM personas.TelefonoPaciente tpx WHERE tpx.id_paciente = p.id_paciente)) AS telefonos,
           (p.id_usuario IS NOT NULL) AS tiene_cuenta
      FROM personas.Paciente p
     WHERE CHAR_LENGTH(v_texto) >= 3
       AND (p.dni = v_texto
            OR POSITION(v_texto IN p.nombre) > 0
            OR POSITION(v_texto IN p.apellido) > 0
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
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_usuario INT;
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, v_msg,
                                        'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_matricula IS NULL OR TRIM(p_matricula) = '' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, 'Falta la matrícula',
                                                'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52040 AS codigo, 'Falta la matrícula' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(TRIM(p_apellido)) < 2 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, 'Nombre y apellido deben tener al menos 2 letras',
                                                'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52031 AS codigo, 'Nombre y apellido deben tener al menos 2 letras' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_email IS NULL OR personas.fn_es_email(p_email) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, 'El email no es válido',
                                                'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52034 AS codigo, 'El email no es válido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_telefono IS NULL OR personas.fn_es_telefono(p_telefono) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, 'El teléfono debe tener de 10 a 13 dígitos',
                                                'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52032 AS codigo, 'El teléfono debe tener de 10 a 13 dígitos' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_nombre_usuario IS NULL OR personas.fn_es_usuario(p_nombre_usuario) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, 'El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo',
                                                'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52022 AS codigo, 'El usuario debe tener de 4 a 50 letras minúsculas, números, punto, guion o guion bajo' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_password IS NULL OR TRIM(p_password) = '' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, 'La contrasena no puede estar vacia',
                                                'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52024 AS codigo, 'La contrasena no puede estar vacia' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM personas.Profesional WHERE matricula = p_matricula) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, 'Ya existe un profesional con esa matrícula',
                                                'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52041 AS codigo, 'Ya existe un profesional con esa matrícula' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario OR email = p_email) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen, 'Ese usuario o email ya está en uso',
                                                'personas.Profesional', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52025 AS codigo, 'Ese usuario o email ya está en uso' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    INSERT INTO seguridad.Usuario (id_rol, nombre_usuario, email, password)
    VALUES ((SELECT id_rol FROM seguridad.Rol WHERE nombre = 'profesional'), p_nombre_usuario, p_email, p_password);
    SELECT MAX(id_usuario) INTO v_usuario FROM seguridad.Usuario WHERE nombre_usuario = p_nombre_usuario;
    INSERT INTO personas.Profesional (id_usuario, matricula, nombre, apellido, email)
    VALUES (v_usuario, TRIM(p_matricula), TRIM(p_nombre), TRIM(p_apellido), p_email);
    SELECT MAX(id_profesional) INTO v_id FROM personas.Profesional WHERE matricula = TRIM(p_matricula);
    INSERT INTO personas.TelefonoProfesional (id_profesional, telefono) VALUES (v_id, p_telefono);
    CALL auditoria.sp_registrar_log('alta_profesional', p_id_usuario, NULL, p_origen,
        'Alta del profesional',
        'personas.Profesional', v_id, NULL, p_nombre_usuario, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Profesional creado' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
END//

-- Modifica los datos del profesional o lo da de baja (p_activo = 0). No se
-- puede dar de baja a quien tiene turnos futuros sin cancelar.
DROP PROCEDURE IF EXISTS personas.sp_modificar_profesional//
CREATE PROCEDURE personas.sp_modificar_profesional(
    IN p_id_profesional INT, IN p_nombre VARCHAR(50), IN p_apellido VARCHAR(50), IN p_email VARCHAR(100),
    IN p_activo SMALLINT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_antes VARCHAR(400);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen, v_msg,
                                        'personas.Profesional', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT apellido INTO v_antes
      FROM personas.Profesional WHERE id_profesional = p_id_profesional;
    IF v_antes IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen, 'El profesional no existe',
                                                'personas.Profesional', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52042 AS codigo, 'El profesional no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 2 OR p_apellido IS NULL OR CHAR_LENGTH(TRIM(p_apellido)) < 2 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen, 'Nombre y apellido deben tener al menos 2 letras',
                                                'personas.Profesional', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52031 AS codigo, 'Nombre y apellido deben tener al menos 2 letras' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_email IS NULL OR personas.fn_es_email(p_email) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen, 'El email no es válido',
                                                'personas.Profesional', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52034 AS codigo, 'El email no es válido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_activo IS NULL OR p_activo NOT IN (0, 1) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen, 'El estado activo debe ser 0 o 1',
                                                'personas.Profesional', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52043 AS codigo, 'El estado activo debe ser 0 o 1' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_activo = 0 AND EXISTS (
            SELECT 1 FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
             WHERE t.id_profesional = p_id_profesional AND t.fecha_hora_inicio > auditoria.fn_ahora()
               AND e.nombre IN ('pendiente', 'confirmado')) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen, 'No se puede dar de baja: tiene turnos futuros sin cancelar',
                                                'personas.Profesional', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52044 AS codigo, 'No se puede dar de baja: tiene turnos futuros sin cancelar' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    UPDATE personas.Profesional SET nombre = TRIM(p_nombre), apellido = TRIM(p_apellido), email = p_email, activo = p_activo
     WHERE id_profesional = p_id_profesional;
    CALL auditoria.sp_registrar_log('modificacion_profesional', p_id_usuario, NULL, p_origen,
        CASE WHEN p_activo = 0 THEN 'Baja del profesional' ELSE 'Datos del profesional modificados' END,
        'personas.Profesional', p_id_profesional, v_antes,
        TRIM(p_apellido), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Profesional modificado' AS mensaje, p_id_profesional AS id, NULL AS valor, NULL AS dato;
END//

-- Carga una franja de disponibilidad. No puede superponerse con otra franja
-- activa del mismo profesional ese día.
DROP PROCEDURE IF EXISTS personas.sp_cargar_disponibilidad//
CREATE PROCEDURE personas.sp_cargar_disponibilidad(
    IN p_id_profesional INT, IN p_fecha DATE, IN p_hora_inicio TIME, IN p_hora_fin TIME,
    IN p_origen VARCHAR(50), IN p_id_usuario INT)
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, v_msg,
                                        'personas.Disponibilidad', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF NOT EXISTS (SELECT 1 FROM personas.Profesional WHERE id_profesional = p_id_profesional AND activo = 1) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, 'El profesional no existe o está dado de baja',
                                                'personas.Disponibilidad', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52045 AS codigo, 'El profesional no existe o está dado de baja' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_fecha IS NULL OR p_hora_inicio IS NULL OR p_hora_fin IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, 'Faltan la fecha o las horas',
                                                'personas.Disponibilidad', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52046 AS codigo, 'Faltan la fecha o las horas' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_hora_fin <= p_hora_inicio THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, 'La hora de fin debe ser posterior a la de inicio',
                                                'personas.Disponibilidad', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52047 AS codigo, 'La hora de fin debe ser posterior a la de inicio' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_fecha < DATE(auditoria.fn_ahora()) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, 'No se puede cargar disponibilidad en el pasado',
                                                'personas.Disponibilidad', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52048 AS codigo, 'No se puede cargar disponibilidad en el pasado' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM personas.Disponibilidad d
                WHERE d.id_profesional = p_id_profesional AND d.fecha = p_fecha AND d.activa = 1
                  AND d.hora_inicio < p_hora_fin AND d.hora_fin > p_hora_inicio) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, 'La franja se superpone con otra ya cargada',
                                                'personas.Disponibilidad', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52049 AS codigo, 'La franja se superpone con otra ya cargada' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    INSERT INTO personas.Disponibilidad (id_profesional, fecha, hora_inicio, hora_fin) VALUES (p_id_profesional, p_fecha, p_hora_inicio, p_hora_fin);
    SELECT MAX(id_disponibilidad) INTO v_id FROM personas.Disponibilidad
     WHERE id_profesional = p_id_profesional AND fecha = p_fecha AND hora_inicio = p_hora_inicio AND hora_fin = p_hora_fin;
    CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen,
        'Alta de franja',
        'personas.Disponibilidad', v_id, NULL, p_fecha, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Franja cargada' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
END//

-- Baja (lógica) de una franja. No se puede si hay turnos activos dentro de ella.
DROP PROCEDURE IF EXISTS personas.sp_baja_disponibilidad//
CREATE PROCEDURE personas.sp_baja_disponibilidad(IN p_id_disponibilidad INT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
cuerpo: BEGIN
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
                                        'personas.Disponibilidad', p_id_disponibilidad, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT id_profesional, fecha, hora_inicio, hora_fin, activa INTO v_prof, v_fecha, v_ini, v_fin, v_activa
      FROM personas.Disponibilidad WHERE id_disponibilidad = p_id_disponibilidad FOR UPDATE;
    IF v_prof IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, 'La franja no existe',
                                                'personas.Disponibilidad', p_id_disponibilidad, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52050 AS codigo, 'La franja no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_activa = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, 'La franja ya estaba dada de baja',
                                                'personas.Disponibilidad', p_id_disponibilidad, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52051 AS codigo, 'La franja ya estaba dada de baja' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
                WHERE t.id_profesional = v_prof AND e.nombre IN ('pendiente', 'confirmado')
                  AND t.fecha_hora_inicio < TIMESTAMP(v_fecha, v_fin) AND t.fecha_hora_fin > TIMESTAMP(v_fecha, v_ini)) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen, 'Hay turnos sin cancelar dentro de esa franja',
                                                'personas.Disponibilidad', p_id_disponibilidad, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52052 AS codigo, 'Hay turnos sin cancelar dentro de esa franja' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    UPDATE personas.Disponibilidad SET activa = 0 WHERE id_disponibilidad = p_id_disponibilidad;
    CALL auditoria.sp_registrar_log('cambio_disponibilidad', p_id_usuario, NULL, p_origen,
        'Baja de franja',
        'personas.Disponibilidad', p_id_disponibilidad, 'activa=1', 'activa=0', 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Franja dada de baja' AS mensaje, p_id_disponibilidad AS id, NULL AS valor, NULL AS dato;
END//

-- Habilita (o quita) un protocolo a un profesional (RF-18).
DROP PROCEDURE IF EXISTS clinica.sp_asignar_protocolo//
CREATE PROCEDURE clinica.sp_asignar_protocolo(
    IN p_id_profesional INT, IN p_id_protocolo INT, IN p_habilitar SMALLINT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen, v_msg,
                                        'clinica.ProfesionalProtocolo', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF NOT EXISTS (SELECT 1 FROM personas.Profesional WHERE id_profesional = p_id_profesional) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen, 'El profesional no existe',
                                                'clinica.ProfesionalProtocolo', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52042 AS codigo, 'El profesional no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM clinica.Protocolo WHERE id_protocolo = p_id_protocolo) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen, 'El protocolo no existe',
                                                'clinica.ProfesionalProtocolo', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52060 AS codigo, 'El protocolo no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_habilitar IS NULL OR p_habilitar NOT IN (0, 1) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen, 'El parámetro habilitar debe ser 0 o 1',
                                                'clinica.ProfesionalProtocolo', p_id_profesional, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52043 AS codigo, 'El parámetro habilitar debe ser 0 o 1' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    IF p_habilitar = 1 THEN
        INSERT INTO clinica.ProfesionalProtocolo (id_profesional, id_protocolo)
        SELECT p_id_profesional, p_id_protocolo
         WHERE NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo WHERE id_profesional = p_id_profesional AND id_protocolo = p_id_protocolo);
    ELSE
        DELETE FROM clinica.ProfesionalProtocolo WHERE id_profesional = p_id_profesional AND id_protocolo = p_id_protocolo;
    END IF;
    CALL auditoria.sp_registrar_log('asignacion_protocolo', p_id_usuario, NULL, p_origen,
        CASE WHEN p_habilitar = 1 THEN 'Se habilita' ELSE 'Se quita' END,
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
        CALL agenda.sp_cargar_protocolos(p_protocolos_csv);
        SELECT pr.id_profesional, pr.apellido AS profesional, pr.nombre AS profesional_nombre, pr.matricula
          FROM personas.Profesional pr
         WHERE pr.activo = 1
           AND NOT EXISTS (SELECT 1 FROM agenda.tmp_protocolos_pedidos jt
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
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, v_msg,
                                        'clinica.Protocolo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF NOT EXISTS (SELECT 1 FROM clinica.CategoriaProtocolo WHERE id_categoria = p_id_categoria) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'La categoría no existe',
                                                'clinica.Protocolo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52061 AS codigo, 'La categoría no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 3 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'El nombre debe tener al menos 3 caracteres',
                                                'clinica.Protocolo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52062 AS codigo, 'El nombre debe tener al menos 3 caracteres' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_precio IS NULL OR p_precio <= 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'El precio debe ser mayor a cero',
                                                'clinica.Protocolo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52063 AS codigo, 'El precio debe ser mayor a cero' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_duracion_min IS NULL OR p_duracion_min <= 0 OR p_duracion_min > 600 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'La duración debe estar entre 1 y 600 minutos',
                                                'clinica.Protocolo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52064 AS codigo, 'La duración debe estar entre 1 y 600 minutos' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM clinica.Protocolo WHERE nombre = TRIM(p_nombre)) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'Ya existe un protocolo con ese nombre',
                                                'clinica.Protocolo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52065 AS codigo, 'Ya existe un protocolo con ese nombre' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    INSERT INTO clinica.Protocolo (id_categoria, nombre, descripcion, precio, duracion_min)
    VALUES (p_id_categoria, TRIM(p_nombre), p_descripcion, p_precio, p_duracion_min);
    SELECT MAX(id_protocolo) INTO v_id FROM clinica.Protocolo WHERE nombre = TRIM(p_nombre);
    CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'Alta del protocolo',
        'clinica.Protocolo', v_id, NULL, CAST(p_precio AS CHAR), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Protocolo creado' AS mensaje, v_id AS id, p_precio AS valor, NULL AS dato;
END//

-- Cambia precio, duración, descripción o lo da de baja (p_activo = 0). Los
-- turnos ya agendados conservan el precio de cuando se reservaron.
DROP PROCEDURE IF EXISTS clinica.sp_modificar_protocolo//
CREATE PROCEDURE clinica.sp_modificar_protocolo(
    IN p_id_protocolo INT, IN p_nombre VARCHAR(100), IN p_descripcion VARCHAR(500), IN p_precio DECIMAL(12,2),
    IN p_duracion_min INT, IN p_activo SMALLINT, IN p_origen VARCHAR(50), IN p_id_usuario INT)
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_antes VARCHAR(400);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, v_msg,
                                        'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT CAST(precio AS CHAR) INTO v_antes
      FROM clinica.Protocolo WHERE id_protocolo = p_id_protocolo;
    IF v_antes IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'El protocolo no existe',
                                                'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52060 AS codigo, 'El protocolo no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_nombre IS NULL OR CHAR_LENGTH(TRIM(p_nombre)) < 3 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'El nombre debe tener al menos 3 caracteres',
                                                'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52062 AS codigo, 'El nombre debe tener al menos 3 caracteres' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_precio IS NULL OR p_precio <= 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'El precio debe ser mayor a cero',
                                                'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52063 AS codigo, 'El precio debe ser mayor a cero' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_duracion_min IS NULL OR p_duracion_min <= 0 OR p_duracion_min > 600 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'La duración debe estar entre 1 y 600 minutos',
                                                'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52064 AS codigo, 'La duración debe estar entre 1 y 600 minutos' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_activo IS NULL OR p_activo NOT IN (0, 1) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'El estado activo debe ser 0 o 1',
                                                'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52043 AS codigo, 'El estado activo debe ser 0 o 1' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM clinica.Protocolo WHERE nombre = TRIM(p_nombre) AND id_protocolo <> p_id_protocolo) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen, 'Ya existe un protocolo con ese nombre',
                                                'clinica.Protocolo', p_id_protocolo, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52065 AS codigo, 'Ya existe un protocolo con ese nombre' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    UPDATE clinica.Protocolo
       SET nombre = TRIM(p_nombre), descripcion = p_descripcion, precio = p_precio, duracion_min = p_duracion_min, activo = p_activo
     WHERE id_protocolo = p_id_protocolo;
    CALL auditoria.sp_registrar_log('cambio_protocolo', p_id_usuario, NULL, p_origen,
        CASE WHEN p_activo = 0 THEN 'Baja del protocolo' ELSE 'Protocolo modificado' END, 'clinica.Protocolo', p_id_protocolo, v_antes,
        CAST(p_precio AS CHAR), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Protocolo modificado' AS mensaje, p_id_protocolo AS id, p_precio AS valor, NULL AS dato;
END//

-- Catálogo y buscador por palabra clave (RF-05/06). Con texto vacío o NULL
-- devuelve todo el catálogo; con p_id_categoria NULL, todas las categorías.
-- p_incluir_bajas = 1 incluye también los protocolos dados de baja (lo usa la
-- pantalla de administración de protocolos); con 0 o NULL, solo los activos.
DROP PROCEDURE IF EXISTS clinica.sp_listar_protocolos//
CREATE PROCEDURE clinica.sp_listar_protocolos(IN p_texto VARCHAR(100), IN p_id_categoria INT, IN p_incluir_bajas SMALLINT)
BEGIN
    DECLARE v_texto VARCHAR(100) DEFAULT TRIM(COALESCE(p_texto, ''));
    SELECT p.id_protocolo, p.nombre, p.descripcion, c.id_categoria, c.nombre AS categoria, p.precio, p.duracion_min,
           c.porcentaje_sena, ROUND(p.precio * c.porcentaje_sena / 100, 0) AS sena, c.requiere_evaluacion, p.activo
      FROM clinica.Protocolo p
      JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
     WHERE (p.activo = 1 OR COALESCE(p_incluir_bajas, 0) = 1)
       AND (p_id_categoria IS NULL OR p.id_categoria = p_id_categoria)
       AND (v_texto = '' OR POSITION(v_texto IN p.nombre) > 0 OR POSITION(v_texto IN p.descripcion) > 0
            OR POSITION(v_texto IN c.nombre) > 0)
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
        CALL agenda.sp_cargar_protocolos(p_protocolos_csv);
        SELECT COUNT(DISTINCT jt.id) INTO v_pedidos
          FROM agenda.tmp_protocolos_pedidos jt;
        SELECT COUNT(*), COALESCE(SUM(p.duracion_min), 0) INTO v_n, v_dur
          FROM clinica.Protocolo p
         WHERE p.activo = 1
           AND p.id_protocolo IN (SELECT DISTINCT jt.id FROM agenda.tmp_protocolos_pedidos jt);
    END IF;
    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';

    IF v_pedidos <= 0 OR v_n <> v_pedidos OR v_dur <= 0 THEN
        SELECT NULL AS id_profesional, NULL AS profesional, NULL AS inicio, NULL AS fin FROM DUAL WHERE 1 = 0;
    ELSE
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
         WHERE s.inicio + INTERVAL v_dur MINUTE <= s.fin_franja
           AND s.inicio > auditoria.fn_ahora()
           AND NOT EXISTS (SELECT 1 FROM agenda.Turno t
                            WHERE t.id_profesional = s.id_profesional AND t.id_estado_turno <> v_cancelado
                              AND t.fecha_hora_inicio < s.inicio + INTERVAL v_dur MINUTE AND t.fecha_hora_fin > s.inicio)
           AND NOT EXISTS (SELECT 1 FROM agenda.tmp_protocolos_pedidos jt
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
cuerpo: BEGIN
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
            v_msg, 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT id_origen INTO v_id_origen FROM agenda.Origen WHERE nombre = p_origen;
    IF v_id_origen IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'Origen inválido (terminal, web, gestion o sistema)', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52070 AS codigo, 'Origen inválido (terminal, web, gestion o sistema)' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM personas.Paciente WHERE id_paciente = p_id_paciente) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'La paciente no existe', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52071 AS codigo, 'La paciente no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_protocolos_csv IS NULL OR TRIM(p_protocolos_csv) = '' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'El turno necesita al menos un protocolo', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52072 AS codigo, 'El turno necesita al menos un protocolo' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_inicio IS NULL OR p_inicio <= auditoria.fn_ahora() THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'El turno debe ser en el futuro', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52073 AS codigo, 'El turno debe ser en el futuro' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    -- Se bloquea al profesional: dos reservas simultáneas del mismo horario se atienden de a una.
    SELECT id_profesional INTO v_n FROM personas.Profesional WHERE id_profesional = p_id_profesional AND activo = 1 FOR UPDATE;
    IF v_n = 0 OR v_n IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'El profesional no existe o está dado de baja', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52074 AS codigo, 'El profesional no existe o está dado de baja' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    CALL agenda.sp_cargar_protocolos(p_protocolos_csv);
    SELECT COUNT(DISTINCT jt.id) INTO v_pedidos
      FROM agenda.tmp_protocolos_pedidos jt;
    SELECT COUNT(*), COALESCE(SUM(p.duracion_min), 0), COALESCE(SUM(c.requiere_evaluacion), 0), MIN(CASE WHEN c.requiere_evaluacion = 1 THEN p.id_protocolo END)
      INTO v_n, v_dur, v_cirugias, v_cirugia
      FROM clinica.Protocolo p JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
     WHERE p.activo = 1
       AND p.id_protocolo IN (SELECT DISTINCT jt.id FROM agenda.tmp_protocolos_pedidos jt);
    IF v_pedidos = 0 OR v_n <> v_pedidos THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'Algún protocolo no existe o está dado de baja', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52075 AS codigo, 'Algún protocolo no existe o está dado de baja' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM agenda.tmp_protocolos_pedidos jt
                WHERE NOT EXISTS (SELECT 1 FROM clinica.ProfesionalProtocolo pp
                                   WHERE pp.id_profesional = p_id_profesional AND pp.id_protocolo = jt.id)) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'El profesional no realiza alguno de los protocolos pedidos', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52076 AS codigo, 'El profesional no realiza alguno de los protocolos pedidos' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_cirugias > 1 OR (v_cirugias = 1 AND v_n > 1) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'Una cirugía se agenda sola, sin otros protocolos', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52077 AS codigo, 'Una cirugía se agenda sola, sin otros protocolos' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_id_cirugia_consulta IS NOT NULL THEN
        IF v_cirugias > 0 THEN
            ROLLBACK;
            CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                        'La consulta previa no puede incluir una cirugía', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
            SELECT 'ERROR' AS estado, 52078 AS codigo, 'La consulta previa no puede incluir una cirugía' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
            LEAVE cuerpo;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM clinica.Protocolo p JOIN clinica.CategoriaProtocolo c ON c.id_categoria = p.id_categoria
                        WHERE p.id_protocolo = p_id_cirugia_consulta AND p.activo = 1 AND c.requiere_evaluacion = 1) THEN
            ROLLBACK;
            CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                        'La consulta previa debe ser para una cirugía existente', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
            SELECT 'ERROR' AS estado, 52079 AS codigo, 'La consulta previa debe ser para una cirugía existente' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
            LEAVE cuerpo;
        END IF;
    END IF;

    SET v_fin = p_inicio + INTERVAL v_dur MINUTE;
    SELECT id_estado_turno INTO v_cancelado FROM agenda.EstadoTurno WHERE nombre = 'cancelado';
    SELECT id_estado_turno INTO v_pendiente FROM agenda.EstadoTurno WHERE nombre = 'pendiente';

    IF NOT EXISTS (SELECT 1 FROM personas.Disponibilidad d
                    WHERE d.id_profesional = p_id_profesional AND d.activa = 1 AND d.fecha = DATE(p_inicio)
                      AND DATE(v_fin) = DATE(p_inicio) AND d.hora_inicio <= TIME(p_inicio) AND d.hora_fin >= TIME(v_fin)) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'El horario está fuera de la disponibilidad del profesional', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52080 AS codigo, 'El horario está fuera de la disponibilidad del profesional' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM agenda.Turno t WHERE t.id_profesional = p_id_profesional AND t.id_estado_turno <> v_cancelado
                  AND t.fecha_hora_inicio < v_fin AND t.fecha_hora_fin > p_inicio) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'El profesional ya tiene un turno en ese horario', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52081 AS codigo, 'El profesional ya tiene un turno en ese horario' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM agenda.Turno t WHERE t.id_paciente = p_id_paciente AND t.id_estado_turno <> v_cancelado
                  AND t.fecha_hora_inicio < v_fin AND t.fecha_hora_fin > p_inicio) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                    'La paciente ya tiene un turno en ese horario', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52082 AS codigo, 'La paciente ya tiene un turno en ese horario' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    -- Cirugía: hace falta una evaluación apta, de menos de 6 meses y sin usar.
    IF v_cirugias = 1 THEN
        SELECT MAX(ev.id_evaluacion) INTO v_eval
          FROM clinica.EvaluacionPrevia ev
          JOIN agenda.Turno tc ON tc.id_turno = ev.id_turno
          JOIN clinica.ResultadoEvaluacion r ON r.id_resultado = ev.id_resultado
         WHERE tc.id_paciente = p_id_paciente AND ev.id_protocolo = v_cirugia AND r.nombre = 'apto'
           AND ev.fecha_resultado + INTERVAL 6 MONTH >= auditoria.fn_ahora()
           AND NOT EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = ev.id_evaluacion AND t2.id_estado_turno <> v_cancelado);
        IF v_eval IS NULL THEN
            ROLLBACK;
            CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                        'La cirugía necesita una consulta previa con resultado apto de menos de 6 meses', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
            SELECT 'ERROR' AS estado, 52083 AS codigo, 'La cirugía necesita una consulta previa con resultado apto de menos de 6 meses' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
            LEAVE cuerpo;
        END IF;
    END IF;

    -- Cupón (opcional): de la paciente, vigente y sin usar.
    IF p_codigo_cupon IS NOT NULL AND TRIM(p_codigo_cupon) <> '' THEN
        SELECT id_cupon, id_paciente, id_turno, fecha_vencimiento INTO v_cupon, v_cupon_pac, v_cupon_turno, v_cupon_venc
          FROM beneficios.Cupon WHERE codigo = TRIM(p_codigo_cupon) FOR UPDATE;
        IF v_cupon IS NULL THEN
            ROLLBACK;
            CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                        'El cupón no existe', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
            SELECT 'ERROR' AS estado, 52084 AS codigo, 'El cupón no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
            LEAVE cuerpo;
        END IF;
        IF v_cupon_pac <> p_id_paciente THEN
            ROLLBACK;
            CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                        'El cupón es de otra paciente', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
            SELECT 'ERROR' AS estado, 52085 AS codigo, 'El cupón es de otra paciente' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
            LEAVE cuerpo;
        END IF;
        IF v_cupon_turno IS NOT NULL THEN
            ROLLBACK;
            CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                        'El cupón ya fue usado', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
            SELECT 'ERROR' AS estado, 52086 AS codigo, 'El cupón ya fue usado' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
            LEAVE cuerpo;
        END IF;
        IF v_cupon_venc <= auditoria.fn_ahora() THEN
            ROLLBACK;
            CALL auditoria.sp_registrar_log('turno_rechazado', p_id_usuario, p_id_paciente, p_origen,
                        'El cupón está vencido', 'agenda.Turno', NULL, NULL, NULL, 0, NULL);
            SELECT 'ERROR' AS estado, 52087 AS codigo, 'El cupón está vencido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
            LEAVE cuerpo;
        END IF;
    END IF;

    INSERT INTO agenda.Turno (id_paciente, id_profesional, id_estado_turno, id_origen, id_evaluacion_previa,
                              fecha_hora_inicio, fecha_hora_fin, fecha_creacion)
    VALUES (p_id_paciente, p_id_profesional, v_pendiente, v_id_origen, v_eval, p_inicio, v_fin, auditoria.fn_ahora());
    SELECT MAX(id_turno) INTO v_id_turno FROM agenda.Turno
     WHERE id_paciente = p_id_paciente AND id_profesional = p_id_profesional AND fecha_hora_inicio = p_inicio;

    INSERT INTO agenda.TurnoProtocolo (id_turno, id_protocolo, precio_aplicado)
    SELECT v_id_turno, p.id_protocolo, p.precio
      FROM clinica.Protocolo p
     WHERE p.id_protocolo IN (SELECT DISTINCT jt.id FROM agenda.tmp_protocolos_pedidos jt);

    IF v_cupon IS NOT NULL THEN
        UPDATE beneficios.Cupon SET id_turno = v_id_turno WHERE id_cupon = v_cupon;
        CALL auditoria.sp_registrar_log('cupon_validado', p_id_usuario, p_id_paciente, p_origen,
            'Cupón', 'beneficios.Cupon', v_cupon, NULL, NULL, 1, NULL);
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
        'Turno',
        'agenda.Turno', v_id_turno, NULL, CAST(p_inicio AS CHAR), 1, NULL);
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
CREATE PROCEDURE agenda.sp_buscar_turnos(IN p_texto VARCHAR(100), IN p_solo_vigentes SMALLINT)
BEGIN
    DECLARE v_texto VARCHAR(100) DEFAULT TRIM(COALESCE(p_texto, ''));
    SELECT t.id_turno, p.id_paciente, p.apellido AS paciente, p.nombre AS paciente_nombre, p.dni,
           (SELECT tp2.telefono FROM personas.TelefonoPaciente tp2 WHERE tp2.id_telefono_paciente = (SELECT MIN(tp2x.id_telefono_paciente) FROM personas.TelefonoPaciente tp2x WHERE tp2x.id_paciente = p.id_paciente)) AS telefono,
           pr.apellido AS profesional, pr.nombre AS profesional_nombre, t.fecha_hora_inicio, t.fecha_hora_fin,
           e.nombre AS estado, o.nombre AS origen,
           (SELECT MIN(pt.nombre) FROM agenda.TurnoProtocolo tp JOIN clinica.Protocolo pt ON pt.id_protocolo = tp.id_protocolo WHERE tp.id_turno = t.id_turno) AS protocolos,
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
            (SELECT MAX(n.id_notificacion) FROM notificaciones.Notificacion n
               JOIN notificaciones.TipoNotificacion tn ON tn.id_tipo_notificacion = n.id_tipo_notificacion AND tn.nombre = 'recordatorio de turno'
              WHERE n.id_turno = t.id_turno)
      LEFT JOIN notificaciones.CanalNotificacion ca ON ca.id_canal = nr.id_canal
      LEFT JOIN notificaciones.EstadoNotificacion es ON es.id_estado_notificacion = nr.id_estado_notificacion
     WHERE CHAR_LENGTH(v_texto) >= 3
       AND (p.dni = v_texto
            OR POSITION(v_texto IN p.nombre) > 0 OR POSITION(v_texto IN p.apellido) > 0
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
    SELECT t.id_turno, p.id_paciente, p.apellido AS paciente, p.nombre AS paciente_nombre, p.dni,
           (SELECT tp2.telefono FROM personas.TelefonoPaciente tp2 WHERE tp2.id_telefono_paciente = (SELECT MIN(tp2x.id_telefono_paciente) FROM personas.TelefonoPaciente tp2x WHERE tp2x.id_paciente = p.id_paciente)) AS telefono,
           pr.apellido AS profesional, pr.nombre AS profesional_nombre, t.fecha_hora_inicio, t.fecha_hora_fin,
           e.nombre AS estado, o.nombre AS origen,
           (SELECT MIN(pt.nombre) FROM agenda.TurnoProtocolo tp JOIN clinica.Protocolo pt ON pt.id_protocolo = tp.id_protocolo WHERE tp.id_turno = t.id_turno) AS protocolos,
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
cuerpo: BEGIN
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
        CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, v_msg),
                                        'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT e.nombre, t.id_paciente, t.fecha_hora_inicio INTO v_estado, v_paciente, v_inicio
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno FOR UPDATE;
    IF v_estado IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, 'El turno no existe'),
                                                'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52110 AS codigo, 'El turno no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_estado <> 'pendiente' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, 'Solo se paga la seña de un turno pendiente'),
                                                'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52111 AS codigo, 'Solo se paga la seña de un turno pendiente' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_inicio <= auditoria.fn_ahora() THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, 'El turno ya empezó o pasó'),
                                                'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52112 AS codigo, 'El turno ya empezó o pasó' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM pagos.PagoSena WHERE id_turno = p_id_turno) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, 'El turno ya tiene un pago de seña'),
                                                'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52113 AS codigo, 'El turno ya tiene un pago de seña' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    SELECT id_medio_pago INTO v_medio FROM pagos.MedioPago WHERE nombre = p_medio_pago;
    IF v_medio IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, 'Medio de pago inválido'),
                                                'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52114 AS codigo, 'Medio de pago inválido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    SET v_monto = agenda.fn_sena(p_id_turno);
    IF v_monto <= 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, 'El turno no tiene una seña para cobrar'),
                                                'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52115 AS codigo, 'El turno no tiene una seña para cobrar' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    IF p_medio_pago = 'tarjeta de regalo' THEN
        IF EXISTS (SELECT 1 FROM beneficios.Cupon WHERE id_turno = p_id_turno) THEN
            SET v_tipo_log = 'tarjeta_rechazada', v_desc_log = 'Un turno con cupón no puede pagarse con tarjeta de regalo';
            ROLLBACK;
            CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, 'Un cupón y una tarjeta de regalo no se pueden usar en el mismo turno'),
                                                    'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
            SELECT 'ERROR' AS estado, 52116 AS codigo, 'Un cupón y una tarjeta de regalo no se pueden usar en el mismo turno' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
            LEAVE cuerpo;
        END IF;
        SELECT id_tarjeta, fecha_vencimiento INTO v_tarjeta, v_venc
          FROM pagos.TarjetaRegalo WHERE codigo = p_codigo_tarjeta FOR UPDATE;
        IF v_tarjeta IS NULL OR v_venc <= auditoria.fn_ahora() OR pagos.fn_saldo_tarjeta(v_tarjeta) < v_monto THEN
            SET v_tipo_log = 'tarjeta_rechazada',
                v_desc_log = CASE WHEN v_tarjeta IS NULL THEN 'Código de tarjeta inexistente' ELSE CASE WHEN v_venc <= auditoria.fn_ahora() THEN 'Tarjeta vencida' ELSE 'Saldo insuficiente' END END;
            ROLLBACK;
            CALL auditoria.sp_registrar_log(v_tipo_log, p_id_usuario, v_paciente, p_origen, COALESCE(v_desc_log, 'La tarjeta de regalo no existe, está vencida o no tiene saldo suficiente'),
                                                    'pagos.PagoSena', NULL, NULL, NULL, 0, NULL);
            SELECT 'ERROR' AS estado, 52117 AS codigo, 'La tarjeta de regalo no existe, está vencida o no tiene saldo suficiente' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
            LEAVE cuerpo;
        END IF;
    END IF;

    -- El código lo genera la aplicación (escritorio o web) y llega en p_codigo_operacion. Si no llega,
    -- se arma con la fecha (AAAAMMDD) y el número de turno, todo junto como número.
    SET v_codigo = COALESCE(NULLIF(TRIM(p_codigo_operacion), ''),
                            CAST(CAST(DATE_FORMAT(auditoria.fn_ahora(), '%Y%m%d') AS UNSIGNED) * 100000 + p_id_turno AS CHAR));
    INSERT INTO pagos.PagoSena (id_turno, id_estado_pago, id_medio_pago, monto, fecha_pago, codigo_operacion)
    VALUES (p_id_turno, (SELECT id_estado_pago FROM pagos.EstadoPago WHERE nombre = 'pagada'), v_medio, v_monto,
            auditoria.fn_ahora(), v_codigo);
    SELECT MAX(id_pago) INTO v_pago FROM pagos.PagoSena WHERE codigo_operacion = v_codigo;
    UPDATE agenda.Turno SET id_estado_turno = (SELECT id_estado_turno FROM agenda.EstadoTurno WHERE nombre = 'confirmado')
     WHERE id_turno = p_id_turno;
    IF v_tarjeta IS NOT NULL THEN
        INSERT INTO pagos.MovimientoTarjeta (id_tarjeta, id_turno, monto, fecha_movimiento)
        VALUES (v_tarjeta, p_id_turno, v_monto, auditoria.fn_ahora());
        CALL auditoria.sp_registrar_log('tarjeta_usada', p_id_usuario, v_paciente, p_origen,
            'Gasto de $', 'pagos.MovimientoTarjeta', v_tarjeta, NULL,
            CAST(pagos.fn_saldo_tarjeta(v_tarjeta) AS CHAR), 1, NULL);
    END IF;

    -- Avisos: confirmación ahora y recordatorio 24 horas antes (Telegram si la paciente lo vinculó).
    SELECT CASE WHEN telegram_chat_id IS NOT NULL THEN (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'Telegram') ELSE (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido') END
      INTO v_canal FROM personas.Paciente WHERE id_paciente = v_paciente;
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada)
    VALUES (v_canal, (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
            (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'confirmación'), v_paciente, p_id_turno,
            'Tu turno quedó confirmado.',
            auditoria.fn_ahora());
    SET v_programada = CASE WHEN v_inicio - INTERVAL 24 HOUR > auditoria.fn_ahora() THEN v_inicio - INTERVAL 24 HOUR ELSE auditoria.fn_ahora() END;
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada)
    VALUES (v_canal, (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
            (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'recordatorio de turno'), v_paciente, p_id_turno,
            'Recordatorio de tu turno.',
            v_programada);

    CALL auditoria.sp_registrar_log('pago_registrado', p_id_usuario, v_paciente, p_origen,
        'Seña de $', 'pagos.PagoSena', v_pago, NULL,
        CAST(v_monto AS CHAR), 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Seña registrada, turno confirmado' AS mensaje, v_pago AS id, v_monto AS valor, v_codigo AS dato;
END//

-- Cancela un turno pendiente o confirmado. Con más de 24 horas de anticipación
-- la seña se reembolsa al 100%; con menos, queda retenida (RF-10). Si el turno
-- tenía un cupón y se reembolsa, el cupón vuelve a quedar disponible.
-- Devuelve: valor = monto reembolsado, dato = qué pasó con la seña.
DROP PROCEDURE IF EXISTS agenda.sp_cancelar_turno//
CREATE PROCEDURE agenda.sp_cancelar_turno(IN p_id_turno INT, IN p_id_usuario INT, IN p_origen VARCHAR(50))
cuerpo: BEGIN
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
                                        'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    START TRANSACTION;
    SELECT e.nombre, t.id_paciente, t.fecha_hora_inicio INTO v_estado, v_paciente, v_inicio
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno FOR UPDATE;
    IF v_estado IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cancelacion_turno', p_id_usuario, v_paciente, p_origen, 'El turno no existe',
                                                'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52120 AS codigo, 'El turno no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_estado NOT IN ('pendiente', 'confirmado') THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cancelacion_turno', p_id_usuario, v_paciente, p_origen, 'Solo se cancela un turno pendiente o confirmado',
                                                'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52121 AS codigo, 'Solo se cancela un turno pendiente o confirmado' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_inicio <= auditoria.fn_ahora() THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cancelacion_turno', p_id_usuario, v_paciente, p_origen, 'El turno ya empezó o pasó',
                                                'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52122 AS codigo, 'El turno ya empezó o pasó' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    SET v_total = (v_inicio > auditoria.fn_ahora() + INTERVAL 24 HOUR);

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
    SELECT CASE WHEN telegram_chat_id IS NOT NULL THEN (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'Telegram') ELSE (SELECT id_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido') END
      INTO v_canal FROM personas.Paciente WHERE id_paciente = v_paciente;
    INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada)
    VALUES (v_canal, (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
            (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'cancelación'), v_paciente, p_id_turno,
            'Tu turno fue cancelado.',
            auditoria.fn_ahora());

    CALL auditoria.sp_registrar_log('cancelacion_turno', p_id_usuario, v_paciente, p_origen,
        'Turno',
        'agenda.Turno', p_id_turno, v_estado, 'cancelado', 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Turno cancelado' AS mensaje, p_id_turno AS id, v_reembolsado AS valor, v_resultado AS dato;
END//

-- Marca un turno confirmado como 'realizado' o 'ausente' una vez que empezó.
-- La inasistencia retiene la seña.
DROP PROCEDURE IF EXISTS agenda.sp_marcar_turno//
CREATE PROCEDURE agenda.sp_marcar_turno(IN p_id_turno INT, IN p_estado VARCHAR(20), IN p_id_usuario INT, IN p_origen VARCHAR(50))
cuerpo: BEGIN
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
                                        'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_estado IS NULL OR p_estado NOT IN ('realizado', 'ausente') THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_estado_turno', p_id_usuario, v_paciente, p_origen, 'El estado debe ser realizado o ausente',
                                                'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52125 AS codigo, 'El estado debe ser realizado o ausente' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    START TRANSACTION;
    SELECT e.nombre, t.id_paciente, t.fecha_hora_inicio INTO v_estado, v_paciente, v_inicio
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno FOR UPDATE;
    IF v_estado IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_estado_turno', p_id_usuario, v_paciente, p_origen, 'El turno no existe',
                                                'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52120 AS codigo, 'El turno no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_estado <> 'confirmado' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_estado_turno', p_id_usuario, v_paciente, p_origen, 'Solo se marca un turno confirmado',
                                                'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52126 AS codigo, 'Solo se marca un turno confirmado' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_inicio > auditoria.fn_ahora() THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cambio_estado_turno', p_id_usuario, v_paciente, p_origen, 'El turno todavía no empezó',
                                                'agenda.Turno', p_id_turno, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52127 AS codigo, 'El turno todavía no empezó' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
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
        'Turno', 'agenda.Turno', p_id_turno, v_estado, p_estado, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Turno marcado' AS mensaje, p_id_turno AS id, NULL AS valor, NULL AS dato;
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
cuerpo: BEGIN
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
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_resuelta', p_id_usuario, v_paciente, p_origen, 'La evaluación no existe',
                                                'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52130 AS codigo, 'La evaluación no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_res_actual <> 'pendiente' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_resuelta', p_id_usuario, v_paciente, p_origen, 'La evaluación ya tiene resultado',
                                                'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52131 AS codigo, 'La evaluación ya tiene resultado' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_resultado IS NULL OR p_resultado NOT IN ('apto', 'no apto') THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_resuelta', p_id_usuario, v_paciente, p_origen, 'El resultado debe ser apto o no apto',
                                                'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52132 AS codigo, 'El resultado debe ser apto o no apto' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_estado_turno <> 'realizado' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_resuelta', p_id_usuario, v_paciente, p_origen, 'La consulta todavía no se realizó',
                                                'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52133 AS codigo, 'La consulta todavía no se realizó' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
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
        'Evaluación', 'clinica.EvaluacionPrevia', p_id_evaluacion, 'pendiente', p_resultado, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Evaluación resuelta' AS mensaje, p_id_evaluacion AS id, v_devuelto AS valor, p_resultado AS dato;
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
        CALL auditoria.sp_registrar_log('evaluacion_vencida', NULL, NULL, p_origen, v_msg,
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
            'La evaluación', 'clinica.EvaluacionPrevia', v_eval, NULL, NULL, 1, NULL);
        SET v_cuenta = v_cuenta + 1;
    END LOOP;
    CLOSE cur;
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Evaluaciones vencidas' AS mensaje, NULL AS id, v_cuenta AS valor, NULL AS dato;
END//

-- La paciente reclama una evaluación vencida: el instituto retiene el 50% de
-- la consulta y devuelve el resto. Solo se puede reclamar una vez.
DROP PROCEDURE IF EXISTS clinica.sp_reclamar_evaluacion//
CREATE PROCEDURE clinica.sp_reclamar_evaluacion(IN p_id_evaluacion INT, IN p_id_usuario INT, IN p_origen VARCHAR(50))
cuerpo: BEGIN
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
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen, 'La evaluación no existe',
                                                'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52130 AS codigo, 'La evaluación no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_res <> 'apto' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen, 'Solo se reclama una evaluación apta',
                                                'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52134 AS codigo, 'Solo se reclama una evaluación apta' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_reclamo IS NOT NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen, 'La evaluación ya fue reclamada',
                                                'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52135 AS codigo, 'La evaluación ya fue reclamada' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_fecha_res + INTERVAL 6 MONTH >= auditoria.fn_ahora() THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen, 'La evaluación sigue vigente: todavía puede agendar la cirugía',
                                                'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52136 AS codigo, 'La evaluación sigue vigente: todavía puede agendar la cirugía' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM agenda.Turno t2 WHERE t2.id_evaluacion_previa = p_id_evaluacion AND t2.id_estado_turno <> v_cancelado) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen, 'La evaluación ya se usó para una cirugía',
                                                'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52137 AS codigo, 'La evaluación ya se usó para una cirugía' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    UPDATE clinica.EvaluacionPrevia SET fecha_reclamo = auditoria.fn_ahora() WHERE id_evaluacion = p_id_evaluacion;
    SELECT ps.id_pago, ps.monto, ep.nombre INTO v_pago, v_monto, v_estado_pago
      FROM pagos.PagoSena ps JOIN pagos.EstadoPago ep ON ep.id_estado_pago = ps.id_estado_pago WHERE ps.id_turno = v_turno;
    IF v_pago IS NOT NULL AND v_estado_pago IN ('pagada', 'retenida') THEN
        SET v_devuelto = ROUND(v_monto * 0.5, 2);
        CALL pagos.sp_aplicar_reembolso(v_pago, v_devuelto, 'reembolsada parcial', 'Reclamo de evaluación vencida: se retiene el 50%', p_id_usuario, p_origen);
    END IF;
    CALL auditoria.sp_registrar_log('evaluacion_reclamo', p_id_usuario, v_paciente, p_origen,
        'Reclamo de la evaluación', 'clinica.EvaluacionPrevia', p_id_evaluacion, NULL, NULL, 1, NULL);
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
        CALL auditoria.sp_registrar_log('cupon_emitido', NULL, NULL, p_origen, v_msg,
                                        'beneficios.Cupon', NULL, NULL, NULL, 0, NULL);
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
                       AND t.fecha_hora_inicio BETWEEN auditoria.fn_ahora() - INTERVAL r.ventana_dias DAY AND auditoria.fn_ahora()) >= r.umbral
               AND NOT EXISTS (SELECT 1 FROM beneficios.Cupon c WHERE c.id_regla = r.id_regla AND c.id_paciente = p.id_paciente
                                  AND c.fecha_emision >= auditoria.fn_ahora() - INTERVAL r.ventana_dias DAY)
            UNION ALL
            -- gasto acumulado
            SELECT r.id_regla, g.id_paciente, r.porcentaje_descuento, r.vigencia_semanas
              FROM agenda.Numero nums
              JOIN beneficios.ReglaBeneficio r ON TRUE
              JOIN beneficios.TipoRegla tr ON tr.id_tipo_regla = r.id_tipo_regla AND tr.nombre = 'gasto acumulado'
              JOIN (SELECT t.id_paciente, SUM(agenda.fn_precio_final(t.id_turno)) AS gasto
                      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno AND e.nombre = 'realizado'
                     GROUP BY t.id_paciente) g ON TRUE
              JOIN personas.Paciente p ON p.id_paciente = g.id_paciente AND p.id_usuario IS NOT NULL
             WHERE r.activa = 1
               AND nums.n BETWEEN 1 AND 30
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

    INSERT INTO beneficios.Cupon (id_regla, id_paciente, codigo, secreto, porcentaje_descuento, fecha_emision, fecha_vencimiento)
    SELECT id_regla, id_paciente, CAST(100000 + v_max_antes + n AS CHAR), CAST((v_max_antes + n) * 7919 + id_regla * 104729 AS CHAR),
           pct, auditoria.fn_ahora(), auditoria.fn_ahora() + INTERVAL vig WEEK
      FROM tmp_cupones_nuevos
     ORDER BY n;

    SELECT id_canal INTO v_canal FROM notificaciones.CanalNotificacion WHERE nombre = 'WhatsApp asistido';
    OPEN cur;
    leer: LOOP
        FETCH cur INTO v_id, v_pac, v_pct, v_codigo;
        IF v_fin = 1 THEN LEAVE leer; END IF;
        INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, mensaje, fecha_programada)
        SELECT COALESCE((SELECT cn.id_canal FROM notificaciones.CanalNotificacion cn WHERE cn.nombre = 'Telegram' AND p.telegram_chat_id IS NOT NULL), v_canal),
               (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = 'pendiente'),
               (SELECT id_tipo_notificacion FROM notificaciones.TipoNotificacion WHERE nombre = 'cupón nuevo'),
               v_pac, 'Tenés un cupón nuevo.', auditoria.fn_ahora()
          FROM personas.Paciente p WHERE p.id_paciente = v_pac;
        CALL auditoria.sp_registrar_log('cupon_emitido', NULL, v_pac, p_origen,
            'Cupón', 'beneficios.Cupon', v_id, NULL, NULL, 1, NULL);
        SET v_cuenta = v_cuenta + 1;
    END LOOP;
    CLOSE cur;
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Cupones emitidos' AS mensaje, NULL AS id, v_cuenta AS valor, NULL AS dato;
END//

-- Token rotativo del cupón: se renueva cada 5 minutos y no se guarda; sale de
-- una cuenta simple (suma y resto) con el secreto del cupón y el tramo de 5 minutos
-- actual (RNF-14; es una cuenta simple, se aclara en la defensa).
DROP FUNCTION IF EXISTS beneficios.fn_token_cupon//
CREATE FUNCTION beneficios.fn_token_cupon(p_secreto VARCHAR(255), p_tramo BIGINT) RETURNS VARCHAR(8)
    DETERMINISTIC NO SQL
BEGIN
    RETURN CAST(MOD(CAST(p_secreto AS UNSIGNED) + p_tramo * 104729, 1000003) AS CHAR);
END//

-- Tramo de 5 minutos de una fecha: horas desde el comienzo del día de la fecha por 12,
-- más el tramo dentro de la hora (0 a 11). Cambia cada 5 minutos.
DROP FUNCTION IF EXISTS beneficios.fn_tramo//
CREATE FUNCTION beneficios.fn_tramo(p_fecha DATETIME) RETURNS BIGINT
    DETERMINISTIC NO SQL
BEGIN
    RETURN CAST(DATE_FORMAT(p_fecha, '%Y%m%d%H') AS UNSIGNED) * 12 + FLOOR(EXTRACT(MINUTE FROM p_fecha) / 5);
END//

-- Segundos que le quedan al tramo de 5 minutos de una fecha.
DROP FUNCTION IF EXISTS beneficios.fn_segundos_del_tramo//
CREATE FUNCTION beneficios.fn_segundos_del_tramo(p_fecha DATETIME) RETURNS INT
    DETERMINISTIC NO SQL
BEGIN
    RETURN 300 - (MOD(EXTRACT(MINUTE FROM p_fecha), 5) * 60 + EXTRACT(SECOND FROM p_fecha));
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
               beneficios.fn_segundos_del_tramo(auditoria.fn_ahora()) AS valor, beneficios.fn_token_cupon(v_secreto, beneficios.fn_tramo(auditoria.fn_ahora())) AS dato;
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
    DECLARE v_tramo BIGINT DEFAULT beneficios.fn_tramo(auditoria.fn_ahora());
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
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_paciente INT;
    DECLARE v_estado VARCHAR(50);
    DECLARE v_cupon INT DEFAULT NULL;
    DECLARE v_secreto VARCHAR(255);
    DECLARE v_pac_cupon INT;
    DECLARE v_turno_cupon INT;
    DECLARE v_venc DATETIME;
    DECLARE v_tramo BIGINT DEFAULT beneficios.fn_tramo(auditoria.fn_ahora());
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, v_msg,
                                        'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT e.nombre, t.id_paciente INTO v_estado, v_paciente
      FROM agenda.Turno t JOIN agenda.EstadoTurno e ON e.id_estado_turno = t.id_estado_turno
     WHERE t.id_turno = p_id_turno FOR UPDATE;
    IF v_estado IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, 'El turno no existe',
                                                'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52120 AS codigo, 'El turno no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_estado <> 'pendiente' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, 'El cupón se aplica antes de pagar la seña (turno pendiente)',
                                                'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52145 AS codigo, 'El cupón se aplica antes de pagar la seña (turno pendiente)' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF EXISTS (SELECT 1 FROM beneficios.Cupon WHERE id_turno = p_id_turno) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, 'El turno ya tiene un cupón',
                                                'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52146 AS codigo, 'El turno ya tiene un cupón' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    SELECT id_cupon, secreto, id_paciente, id_turno, fecha_vencimiento INTO v_cupon, v_secreto, v_pac_cupon, v_turno_cupon, v_venc
      FROM beneficios.Cupon WHERE codigo = p_codigo FOR UPDATE;
    IF v_cupon IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, 'El cupón no existe',
                                                'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52140 AS codigo, 'El cupón no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_pac_cupon <> v_paciente THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, 'El cupón es de otra paciente',
                                                'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52141 AS codigo, 'El cupón es de otra paciente' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_turno_cupon IS NOT NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, 'El cupón ya fue usado',
                                                'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52142 AS codigo, 'El cupón ya fue usado' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF v_venc <= auditoria.fn_ahora() THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, 'El cupón está vencido',
                                                'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52143 AS codigo, 'El cupón está vencido' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_token IS NULL OR UPPER(p_token) NOT IN (beneficios.fn_token_cupon(v_secreto, v_tramo), beneficios.fn_token_cupon(v_secreto, v_tramo - 1)) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('cupon_rechazado', p_id_usuario, v_paciente, p_origen, 'El token es inválido o ya venció',
                                                'beneficios.Cupon', v_cupon, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52144 AS codigo, 'El token es inválido o ya venció' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    UPDATE beneficios.Cupon SET id_turno = p_id_turno WHERE id_cupon = v_cupon;
    CALL auditoria.sp_registrar_log('cupon_validado', p_id_usuario, v_paciente, p_origen,
        'Cupón', 'beneficios.Cupon', v_cupon, NULL, NULL, 1, NULL);
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
    IN p_comprador_telefono VARCHAR(30), IN p_id_usuario INT, IN p_origen VARCHAR(50), IN p_codigo VARCHAR(50))
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_medio INT DEFAULT NULL;
    DECLARE v_codigo VARCHAR(50);
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen, v_msg,
                                        'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    IF p_monto IS NULL OR p_monto < 20000 OR p_monto > 5000000 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen, 'El monto de la tarjeta debe estar entre $20.000 y $5.000.000',
                                                'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52150 AS codigo, 'El monto de la tarjeta debe estar entre $20.000 y $5.000.000' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    SELECT id_medio_pago INTO v_medio FROM pagos.MedioPago WHERE nombre = p_medio_pago;
    IF v_medio IS NULL OR p_medio_pago = 'tarjeta de regalo' THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen, 'Medio de pago inválido (una tarjeta de regalo no se paga con otra)',
                                                'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52151 AS codigo, 'Medio de pago inválido (una tarjeta de regalo no se paga con otra)' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_comprador_nombre IS NULL OR CHAR_LENGTH(TRIM(p_comprador_nombre)) < 2 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen, 'Falta el nombre de quien compra',
                                                'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52152 AS codigo, 'Falta el nombre de quien compra' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_comprador_telefono IS NOT NULL AND p_comprador_telefono <> '' AND personas.fn_es_telefono(p_comprador_telefono) = 0 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen, 'El teléfono debe tener de 10 a 13 dígitos',
                                                'pagos.TarjetaRegalo', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52032 AS codigo, 'El teléfono debe tener de 10 a 13 dígitos' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    -- El código lo genera la aplicación y llega en p_codigo. Si no llega, se numera.
    SELECT COALESCE(NULLIF(TRIM(p_codigo), ''), CAST(1000000 + COALESCE(MAX(id_tarjeta), 0) + 1 AS CHAR)) INTO v_codigo FROM pagos.TarjetaRegalo;
    INSERT INTO pagos.TarjetaRegalo (id_medio_pago, codigo, monto_inicial, fecha_compra, fecha_vencimiento, comprador_nombre, comprador_telefono)
    VALUES (v_medio, v_codigo, p_monto, auditoria.fn_ahora(), auditoria.fn_ahora() + INTERVAL 12 MONTH, TRIM(p_comprador_nombre), NULLIF(p_comprador_telefono, ''));
    SELECT MAX(id_tarjeta) INTO v_id FROM pagos.TarjetaRegalo WHERE codigo = v_codigo;
    CALL auditoria.sp_registrar_log('tarjeta_comprada', p_id_usuario, NULL, p_origen,
        'Tarjeta de regalo de $', 'pagos.TarjetaRegalo', v_id, NULL, CAST(p_monto AS CHAR), 1, NULL);
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
    SELECT m.id_movimiento, m.fecha_movimiento, m.monto, CASE WHEN m.monto > 0 THEN 'gasto' ELSE 'devolución' END AS tipo,
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
    -- p_limite ya no se usa: el material no enseña LIMIT, así que trae todos los pendientes.
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
     WHERE n.fecha_programada <= auditoria.fn_ahora()
     ORDER BY n.fecha_programada, n.id_notificacion;
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
        SET v_nuevo = CASE WHEN p_resultado = 'enviada' THEN 'enviada' ELSE CASE WHEN v_intentos + 1 >= 3 THEN 'fallida' ELSE 'pendiente' END END;
        UPDATE notificaciones.Notificacion
           SET id_estado_notificacion = (SELECT id_estado_notificacion FROM notificaciones.EstadoNotificacion WHERE nombre = v_nuevo),
               intentos = intentos + 1,
               fecha_envio = CASE WHEN p_resultado = 'enviada' THEN auditoria.fn_ahora() ELSE fecha_envio END,
               detalle_error = CASE WHEN p_resultado = 'fallida' THEN SUBSTRING(p_detalle FROM 1 FOR 500) ELSE NULL END
         WHERE id_notificacion = p_id_notificacion;
        CALL auditoria.sp_registrar_log('notificacion_enviada', NULL, v_paciente, 'sistema',
            'Notificación',
            'notificaciones.Notificacion', p_id_notificacion, v_estado, v_nuevo, CASE WHEN p_resultado = 'enviada' THEN 1 ELSE 0 END, NULL);
        SELECT 'OK' AS estado, 0 AS codigo, 'Notificación actualizada' AS mensaje, p_id_notificacion AS id, v_intentos + 1 AS valor, v_nuevo AS dato;
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
    -- Sin filtro: el material no enseña expresiones regulares, así que el texto se guarda tal cual.
    RETURN p_texto;
END//

-- Registra una pregunta al asistente y su respuesta. p_derivada = 1 cuando no
-- supo responder y se derivó al WhatsApp del instituto.
DROP PROCEDURE IF EXISTS asistente.sp_registrar_consulta//
CREATE PROCEDURE asistente.sp_registrar_consulta(
    IN p_id_paciente INT, IN p_origen VARCHAR(50), IN p_pregunta TEXT, IN p_respuesta TEXT,
    IN p_derivada SMALLINT, IN p_id_usuario INT)
cuerpo: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT '';
    DECLARE v_origen INT DEFAULT NULL;
    DECLARE v_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        ROLLBACK;
        CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen, v_msg,
                                        'asistente.ConsultaAsistente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, v_errno AS codigo, v_msg AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
    END;

    SELECT id_origen INTO v_origen FROM agenda.Origen WHERE nombre = p_origen;
    IF v_origen IS NULL THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen, 'Origen inválido (terminal, web, gestion o sistema)',
                                                'asistente.ConsultaAsistente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52070 AS codigo, 'Origen inválido (terminal, web, gestion o sistema)' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_pregunta IS NULL OR CHAR_LENGTH(TRIM(p_pregunta)) < 3 THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen, 'La pregunta está vacía',
                                                'asistente.ConsultaAsistente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52170 AS codigo, 'La pregunta está vacía' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;
    IF p_id_paciente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM personas.Paciente WHERE id_paciente = p_id_paciente) THEN
        ROLLBACK;
        CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen, 'La paciente no existe',
                                                'asistente.ConsultaAsistente', NULL, NULL, NULL, 0, NULL);
        SELECT 'ERROR' AS estado, 52071 AS codigo, 'La paciente no existe' AS mensaje, NULL AS id, NULL AS valor, NULL AS dato;
        LEAVE cuerpo;
    END IF;

    START TRANSACTION;
    INSERT INTO asistente.ConsultaAsistente (id_paciente, id_origen, pregunta, fecha_hora, derivada, respuesta)
    VALUES (p_id_paciente, v_origen, asistente.fn_filtrar_datos_personales(TRIM(p_pregunta)), auditoria.fn_ahora(),
            COALESCE(p_derivada, 0), asistente.fn_filtrar_datos_personales(p_respuesta));
    SELECT MAX(id_consulta) INTO v_id FROM asistente.ConsultaAsistente;
    CALL auditoria.sp_registrar_log('consulta_asistente', p_id_usuario, p_id_paciente, p_origen,
        CASE WHEN COALESCE(p_derivada, 0) = 1 THEN 'Consulta derivada al WhatsApp del instituto' ELSE 'Consulta respondida por el asistente' END,
        'asistente.ConsultaAsistente', v_id, NULL, NULL, 1, NULL);
    COMMIT;
    SELECT 'OK' AS estado, 0 AS codigo, 'Consulta registrada' AS mensaje, v_id AS id, NULL AS valor, NULL AS dato;
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
           ROUND(SUM(agenda.fn_minutos(t.fecha_hora_inicio, t.fecha_hora_fin)) / 60, 1) AS horas_agendadas,
           SUM(CASE WHEN e.nombre = 'realizado'
                    THEN (SELECT SUM(tp.precio_aplicado) FROM agenda.TurnoProtocolo tp WHERE tp.id_turno = t.id_turno)
                    ELSE 0 END) AS facturado
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
           SUM(CASE WHEN ep.nombre IN ('retenida', 'reembolsada parcial') THEN ps.monto - COALESCE(ps.monto_reembolsado, 0) ELSE 0 END) AS retenido,
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
           COALESCE(SUM(CASE WHEN x.estado IN ('cancelado', 'ausente') AND x.estado_sena IN ('retenida', 'reembolsada parcial')
                             THEN x.monto - COALESCE(x.reembolsado, 0) END), 0) AS sena_retenida
      FROM (SELECT CASE WHEN v_semana THEN DATE_FORMAT(t.fecha_hora_inicio, '%x-S%v') ELSE DATE_FORMAT(t.fecha_hora_inicio, '%Y-%m') END AS periodo,
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
           SUM(r.nombre = 'apto' AND tc.id_turno IS NULL AND ev.fecha_resultado + INTERVAL 6 MONTH < auditoria.fn_ahora()) AS vencidas_sin_cirugia,
           SUM(ev.fecha_reclamo IS NOT NULL) AS reclamos,
           COALESCE(SUM(CASE WHEN ep.nombre IN ('retenida', 'reembolsada parcial') THEN ps.monto - COALESCE(ps.monto_reembolsado, 0) END), 0) AS consulta_retenida
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
           ROUND(100 * COALESCE(o.horas, 0) / NULLIF(d.horas, 0), 1) AS ocupacion_pct
      FROM personas.Profesional pr
      LEFT JOIN (SELECT dd.id_profesional, SUM((EXTRACT(HOUR FROM dd.hora_fin) - EXTRACT(HOUR FROM dd.hora_inicio)) * 60 + EXTRACT(MINUTE FROM dd.hora_fin) - EXTRACT(MINUTE FROM dd.hora_inicio)) / 60 AS horas
                   FROM personas.Disponibilidad dd
                  WHERE dd.activa = 1 AND dd.fecha BETWEEN p_desde AND p_hasta
                  GROUP BY dd.id_profesional) d ON d.id_profesional = pr.id_profesional
      LEFT JOIN (SELECT t.id_profesional, COUNT(*) AS turnos, SUM(agenda.fn_minutos(t.fecha_hora_inicio, t.fecha_hora_fin)) / 60 AS horas
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
           SUM(c.id_turno IS NULL AND c.fecha_vencimiento <= auditoria.fn_ahora()) AS vencidos_sin_usar,
           SUM(c.id_turno IS NULL AND c.fecha_vencimiento > auditoria.fn_ahora()) AS vigentes,
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
    SELECT t.id_tarjeta, SUBSTRING(t.codigo FROM 1 FOR 7) AS codigo, t.comprador_nombre, mp.nombre AS medio_compra,
           DATE(t.fecha_compra) AS fecha_compra, DATE(t.fecha_vencimiento) AS vence,
           t.monto_inicial,
           COALESCE(SUM(CASE WHEN m.monto > 0 THEN m.monto END), 0) AS gastado,
           COALESCE(-SUM(CASE WHEN m.monto < 0 THEN m.monto END), 0) AS devuelto,
           t.monto_inicial - COALESCE(SUM(m.monto), 0) AS saldo,
           COUNT(m.id_movimiento) AS movimientos,
           MAX(m.fecha_movimiento) AS ultimo_uso,
           CASE WHEN t.fecha_vencimiento <= auditoria.fn_ahora() THEN 'vencida'
                WHEN t.monto_inicial - COALESCE(SUM(m.monto), 0) <= 0 THEN 'agotada'
                WHEN COUNT(m.id_movimiento) = 0 THEN 'sin uso'
                ELSE 'en uso' END AS situacion
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
           ROUND(SUM(agenda.fn_minutos(a.fecha_hora_inicio, a.fecha_hora_fin)) / 60, 1) AS horas_agendadas,
           SUM(CASE WHEN e.nombre = 'realizado' THEN f.total ELSE 0 END) AS facturado
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
           SUM(CASE WHEN e.nombre IN ('retenida', 'reembolsada parcial') THEN a.monto - COALESCE(a.monto_reembolsado, 0) ELSE 0 END) AS retenido,
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

