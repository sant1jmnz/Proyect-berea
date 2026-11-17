-- Dermalia: stored procedures para las pantallas de Cupones y de Consultas previas (MySQL 8).
-- Se corre después de 04_sp_semana4.sql:
--   mysql -u root -p < backend/09_sp_pantallas.sql
--
-- Las pantallas de Gestión necesitan listar lo que ya existe; el resto de las
-- acciones (emitir cupones, pedir el token, validar, cargar el resultado de una
-- evaluación, reclamar) ya están en 04_sp_semana4.sql.
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

DELIMITER ;
