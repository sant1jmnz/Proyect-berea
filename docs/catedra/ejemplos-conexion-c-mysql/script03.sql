USE CuartoAnio_2026;
-- 1. Eliminar el procedimiento si ya existe
DROP PROCEDURE IF EXISTS sp_obtener_alumnos;
-- 2. Cambiar delimitador y crear el SP
DELIMITER //
CREATE PROCEDURE sp_obtener_alumnos()
BEGIN
    SELECT idAlumno,apellido,nombre,mail FROM alumno;
END //
-- Restauramos el delimitador normal
DELIMITER ;

