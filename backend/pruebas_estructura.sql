-- Pruebas de la estructura: cada restricción de codigobasededatossolotablas.sql
-- rechaza lo que tiene que rechazar y deja pasar lo válido.
-- Se corre después de crear las tablas:
--   mysql -u root -p < backend/codigobasededatossolotablas.sql
--   mysql -u root -p < backend/pruebas_estructura.sql
-- Todo va dentro de una transacción que al final se deshace (ROLLBACK): las
-- tablas quedan vacías como estaban. Solo queda el schema "pruebas" con el
-- resultado, que se borra al final.

-- La conexión en utf8mb4, así los textos con tildes llegan bien.
SET NAMES utf8mb4;

DROP DATABASE IF EXISTS pruebas;
CREATE DATABASE pruebas;

-- MEMORY no participa de la transacción: el resultado sobrevive al ROLLBACK.
CREATE TABLE pruebas.Resultado (
    n INT AUTO_INCREMENT PRIMARY KEY,
    caso VARCHAR(200) NOT NULL,
    esperado VARCHAR(10) NOT NULL,
    obtenido VARCHAR(10) NOT NULL,
    detalle VARCHAR(300)
) ENGINE = MEMORY;

DELIMITER //

-- Ejecuta una sentencia y anota si pasó o falló, sin cortar el script.
CREATE PROCEDURE pruebas.probar(IN p_caso VARCHAR(200), IN p_sql TEXT, IN p_debe_fallar TINYINT)
BEGIN
    DECLARE v_error VARCHAR(300) DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        BEGIN
            GET DIAGNOSTICS CONDITION 1 v_error = MESSAGE_TEXT;
        END;
    SET @sentencia = p_sql;
    PREPARE st FROM @sentencia;
    EXECUTE st;
    DEALLOCATE PREPARE st;
    INSERT INTO pruebas.Resultado (caso, esperado, obtenido, detalle)
    VALUES (p_caso, IF(p_debe_fallar, 'falla', 'pasa'), IF(v_error IS NULL, 'pasa', 'falla'), v_error);
END//

DELIMITER ;

START TRANSACTION;

-- ---------- Datos válidos mínimos (tienen que pasar) ----------

CALL pruebas.probar('Rol', "INSERT INTO seguridad.Rol (id_rol, nombre) VALUES (1, 'paciente'), (2, 'profesional')", 0);
CALL pruebas.probar('Usuarios', "INSERT INTO seguridad.Usuario (id_usuario, id_rol, nombre_usuario, email, password_hash) VALUES (1, 1, 'msosa', 'msosa@mail.com', 'x'), (2, 2, 'dra.ruiz', 'ruiz@dermalia.com', 'x'), (3, 1, 'cgomez', 'cgomez@mail.com', 'x')", 0);
CALL pruebas.probar('Paciente con tildes y fecha DATE', "INSERT INTO personas.Paciente (id_paciente, id_usuario, dni, nombre, apellido, fecha_nacimiento) VALUES (1, 1, '30111222', 'María', 'Peñalba Núñez', '1990-05-14')", 0);
CALL pruebas.probar('Paciente sin cuenta', "INSERT INTO personas.Paciente (id_paciente, dni, nombre, apellido, fecha_nacimiento) VALUES (2, '33222111', 'Carla', 'Gómez', '1995-01-20')", 0);
CALL pruebas.probar('Profesional', "INSERT INTO personas.Profesional (id_profesional, id_usuario, matricula, nombre, apellido) VALUES (1, 2, 'MN-1234', 'Laura', 'Ruiz')", 0);
CALL pruebas.probar('Dos teléfonos distintos', "INSERT INTO personas.TelefonoPaciente (id_paciente, telefono) VALUES (1, '1155550102'), (1, '1144443333')", 0);
CALL pruebas.probar('Disponibilidad válida', "INSERT INTO personas.Disponibilidad (id_profesional, fecha, hora_inicio, hora_fin) VALUES (1, '2026-11-02', '09:00', '13:00')", 0);
CALL pruebas.probar('Categoría', "INSERT INTO clinica.CategoriaProtocolo (id_categoria, nombre, porcentaje_sena) VALUES (1, 'Faciales y corporales', 30)", 0);
CALL pruebas.probar('Protocolo', "INSERT INTO clinica.Protocolo (id_protocolo, id_categoria, nombre, precio, duracion_min) VALUES (1, 1, 'Limpieza facial profunda', 25000, 60)", 0);
CALL pruebas.probar('Estado del turno', "INSERT INTO agenda.EstadoTurno (id_estado_turno, nombre) VALUES (1, 'confirmado')", 0);
CALL pruebas.probar('Origen', "INSERT INTO agenda.Origen (id_origen, nombre) VALUES (1, 'web')", 0);
CALL pruebas.probar('Dos turnos', "INSERT INTO agenda.Turno (id_turno, id_paciente, id_profesional, id_estado_turno, id_origen, fecha_hora_inicio, fecha_hora_fin) VALUES (1, 1, 1, 1, 1, '2026-11-02 09:00', '2026-11-02 10:00'), (2, 2, 1, 1, 1, '2026-11-02 10:00', '2026-11-02 11:00')", 0);
CALL pruebas.probar('Estado del pago', "INSERT INTO pagos.EstadoPago (id_estado_pago, nombre) VALUES (1, 'pagada')", 0);
CALL pruebas.probar('Medio de pago', "INSERT INTO pagos.MedioPago (id_medio_pago, nombre) VALUES (1, 'tarjeta simulada')", 0);
CALL pruebas.probar('Pago de seña', "INSERT INTO pagos.PagoSena (id_turno, id_estado_pago, id_medio_pago, monto, fecha_pago, monto_reembolsado) VALUES (1, 1, 1, 7500, NOW(), 0)", 0);
CALL pruebas.probar('Tarjeta de regalo', "INSERT INTO pagos.TarjetaRegalo (id_tarjeta, id_medio_pago, codigo, monto_inicial, fecha_compra, fecha_vencimiento) VALUES (1, 1, 'REGALO-8F2K-91QZ', 300000, '2026-10-01', '2027-04-01')", 0);
CALL pruebas.probar('Movimiento negativo (devolución)', "INSERT INTO pagos.MovimientoTarjeta (id_tarjeta, id_turno, monto) VALUES (1, 2, -5000)", 0);
CALL pruebas.probar('Tipo de regla', "INSERT INTO beneficios.TipoRegla (id_tipo_regla, nombre) VALUES (1, 'frecuencia de visitas')", 0);
CALL pruebas.probar('Regla de 4 semanas', "INSERT INTO beneficios.ReglaBeneficio (id_regla, id_tipo_regla, nombre, umbral, porcentaje_descuento, vigencia_semanas, ventana_dias) VALUES (1, 1, '2 visitas en un mes', 2, 10, 4, 30)", 0);
CALL pruebas.probar('Cupón aplicado al turno 1', "INSERT INTO beneficios.Cupon (id_regla, id_paciente, id_turno, codigo, secreto, porcentaje_descuento, fecha_vencimiento) VALUES (1, 1, 1, 'CUP-0001', 's3', 10, '2026-12-31')", 0);
CALL pruebas.probar('Canal de notificación', "INSERT INTO notificaciones.CanalNotificacion (id_canal, nombre) VALUES (1, 'Telegram')", 0);
CALL pruebas.probar('Estado de notificación', "INSERT INTO notificaciones.EstadoNotificacion (id_estado_notificacion, nombre) VALUES (1, 'pendiente')", 0);
CALL pruebas.probar('Tipo de notificación', "INSERT INTO notificaciones.TipoNotificacion (id_tipo_notificacion, nombre) VALUES (1, 'recordatorio de turno')", 0);
CALL pruebas.probar('Aviso a una paciente', "INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_turno, mensaje, fecha_programada) VALUES (1, 1, 1, 1, 1, 'Mañana tenés turno', '2026-11-01 09:00')", 0);
CALL pruebas.probar('Aviso a un profesional', "INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_profesional, mensaje, fecha_programada) VALUES (1, 1, 1, 1, 'Nuevo turno', '2026-11-01 09:00')", 0);

-- ---------- Casos inválidos (tienen que fallar) ----------

CALL pruebas.probar('Segundo pago de seña para el mismo turno', "INSERT INTO pagos.PagoSena (id_turno, id_estado_pago, id_medio_pago, monto, fecha_pago) VALUES (1, 1, 1, 7500, NOW())", 1);
CALL pruebas.probar('Reembolso mayor que lo pagado', "INSERT INTO pagos.PagoSena (id_turno, id_estado_pago, id_medio_pago, monto, fecha_pago, monto_reembolsado) VALUES (2, 1, 1, 7500, NOW(), 9000)", 1);
CALL pruebas.probar('Segundo cupón en el mismo turno', "INSERT INTO beneficios.Cupon (id_regla, id_paciente, id_turno, codigo, secreto, porcentaje_descuento, fecha_vencimiento) VALUES (1, 1, 1, 'CUP-0002', 's4', 10, '2026-12-31')", 1);
CALL pruebas.probar('Cupón que vence antes de emitirse', "INSERT INTO beneficios.Cupon (id_regla, id_paciente, codigo, secreto, porcentaje_descuento, fecha_emision, fecha_vencimiento) VALUES (1, 1, 'CUP-0003', 's5', 10, '2026-12-31', '2026-01-01')", 1);
CALL pruebas.probar('Segunda evaluación para el mismo turno', "INSERT INTO clinica.EvaluacionPrevia (id_turno, id_protocolo) VALUES (2, 1), (2, 1)", 1);
CALL pruebas.probar('Dos pacientes con la misma cuenta', "INSERT INTO personas.Paciente (id_usuario, dni, nombre, apellido, fecha_nacimiento) VALUES (1, '40111222', 'Otra', 'Persona', '2000-01-01')", 1);
CALL pruebas.probar('Dos profesionales con la misma cuenta', "INSERT INTO personas.Profesional (id_usuario, matricula, nombre, apellido) VALUES (2, 'MN-9999', 'Otro', 'Médico')", 1);
CALL pruebas.probar('Teléfono repetido de la misma paciente', "INSERT INTO personas.TelefonoPaciente (id_paciente, telefono) VALUES (1, '1155550102')", 1);
CALL pruebas.probar('Disponibilidad que termina antes de empezar', "INSERT INTO personas.Disponibilidad (id_profesional, fecha, hora_inicio, hora_fin) VALUES (1, '2026-11-02', '13:00', '09:00')", 1);
CALL pruebas.probar('Notificación sin destinatario', "INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, mensaje, fecha_programada) VALUES (1, 1, 1, 'Sin nadie', NOW())", 1);
CALL pruebas.probar('Notificación a paciente y profesional a la vez', "INSERT INTO notificaciones.Notificacion (id_canal, id_estado_notificacion, id_tipo_notificacion, id_paciente, id_profesional, mensaje, fecha_programada) VALUES (1, 1, 1, 1, 1, 'A los dos', NOW())", 1);
CALL pruebas.probar('Movimiento de tarjeta en cero', "INSERT INTO pagos.MovimientoTarjeta (id_tarjeta, id_turno, monto) VALUES (1, 2, 0)", 1);
CALL pruebas.probar('Tarjeta que vence antes de comprarse', "INSERT INTO pagos.TarjetaRegalo (id_medio_pago, codigo, monto_inicial, fecha_compra, fecha_vencimiento) VALUES (1, 'REGALO-X', 1000, '2026-10-01', '2026-09-01')", 1);
CALL pruebas.probar('Regla con vigencia de 1 semana', "INSERT INTO beneficios.ReglaBeneficio (id_tipo_regla, nombre, umbral, porcentaje_descuento, vigencia_semanas) VALUES (1, 'corta', 2, 10, 1)", 1);
CALL pruebas.probar('Regla con vigencia de 9 semanas', "INSERT INTO beneficios.ReglaBeneficio (id_tipo_regla, nombre, umbral, porcentaje_descuento, vigencia_semanas) VALUES (1, 'larga', 2, 10, 9)", 1);
CALL pruebas.probar('Activo con un valor que no es 0 ni 1', "INSERT INTO clinica.Protocolo (id_categoria, nombre, precio, duracion_min, activo) VALUES (1, 'Raro', 1000, 30, 2)", 1);
CALL pruebas.probar('Turno que termina antes de empezar', "INSERT INTO agenda.Turno (id_paciente, id_profesional, id_estado_turno, id_origen, fecha_hora_inicio, fecha_hora_fin) VALUES (1, 1, 1, 1, '2026-11-02 12:00', '2026-11-02 11:00')", 1);
CALL pruebas.probar('Turno con una paciente que no existe', "INSERT INTO agenda.Turno (id_paciente, id_profesional, id_estado_turno, id_origen, fecha_hora_inicio, fecha_hora_fin) VALUES (999, 1, 1, 1, '2026-11-03 09:00', '2026-11-03 10:00')", 1);

-- Las tildes y la eñe vuelven tal cual se guardaron (se compara en binario,
-- porque la intercalación utf8mb4_0900_ai_ci no distingue "n" de "ñ").
INSERT INTO pruebas.Resultado (caso, esperado, obtenido)
SELECT 'Tildes y eñe se leen igual', 'pasa',
       IF(CAST(apellido AS BINARY) = CAST('Peñalba Núñez' AS BINARY), 'pasa', 'falla')
FROM personas.Paciente WHERE id_paciente = 1;

ROLLBACK;

-- ---------- Resultado ----------

SELECT n, caso, esperado, obtenido, IF(esperado = obtenido, 'OK', 'ERROR') AS resultado, detalle
FROM pruebas.Resultado ORDER BY n;

SELECT COUNT(*) AS casos, SUM(esperado = obtenido) AS ok, SUM(esperado <> obtenido) AS errores
FROM pruebas.Resultado;

DROP DATABASE pruebas;
