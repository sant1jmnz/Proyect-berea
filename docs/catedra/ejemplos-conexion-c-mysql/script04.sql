USE Cuarto_Anio_2026;

-- 1. Eliminar el SP si ya existe para poder recrearlo limpiamente
DROP PROCEDURE IF EXISTS sp_obtener_alumnos;

DELIMITER //

CREATE PROCEDURE sp_obtener_alumnos()
BEGIN
    -- Declaración de variables para captura de errores
    DECLARE codigo_error INT DEFAULT 0;
    DECLARE mensaje_error VARCHAR(255) DEFAULT '';

    -- MANEJADOR DE EXCEPCIONES: Se activa si ocurre cualquier error SQL (SQLEXCEPTION)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Capturar el número y mensaje exacto del error que ocurrió
        GET DIAGNOSTICS CONDITION 1 
            codigo_error = MYSQL_ERRNO, 
            mensaje_error = MESSAGE_TEXT;
            
        -- Devolver una respuesta estructurada indicando el fallo
        SELECT 
            'ERROR' AS estado, 
            codigo_error AS codigo_sql, 
            mensaje_error AS descripcion_error;
    END;

    -- CÓDIGO PRINCIPAL
    -- Si la tabla o columnas no existen, saltará automáticamente al HANDLER
    SELECT idAlumno, apellido, nombre, mail FROM alumno;

END //

DELIMITER ;