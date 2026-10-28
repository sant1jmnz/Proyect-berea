CREATE DATABASE IF NOT EXISTS CuartoAnio_2026;
USE CuartoAnio_2026;

CREATE TABLE IF NOT EXISTS alumno (
    idAlumno INT AUTO_INCREMENT PRIMARY KEY,
    apellido VARCHAR(50),
    nombre VARCHAR(50),
    mail VARCHAR(50)
);

INSERT INTO alumno ( apellido, nombre,mail ) VALUES ('LINARES','PABLO','pablo.linares@bue.edu.ar');
INSERT INTO alumno ( apellido, nombre,mail ) VALUES ('BEREA', 'CYNTHIA','cynthia.berea@bue.edu.ar');