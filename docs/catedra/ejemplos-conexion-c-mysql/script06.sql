USE CuartoAnio_2026;

DROP TABLE alumno;

CREATE TABLE alumno (
    idAlumno INT AUTO_INCREMENT PRIMARY KEY,
    apellido VARCHAR(50),
    nombre VARCHAR(50),
    mail VARCHAR(50),
    fechaNacimiento DATE
);

INSERT INTO alumno ( apellido, nombre,mail,fechaNacimiento) VALUES ('LINARES','PABLO','pablo.linares@bue.edu.ar','1973-08-23');
INSERT INTO alumno ( apellido, nombre,mail,fechaNacimiento) VALUES ('BEREA', 'CYNTHIA','cynthia.berea@bue.edu.ar','1977-05-21');
INSERT INTO alumno ( apellido, nombre,mail,fechaNacimiento) VALUES ('IOPPOLO', 'SERGIO','sergio.ioppolo@bue.edu.ar','1966-08-09');

