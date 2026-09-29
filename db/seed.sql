-- Datos de ejemplo para desarrollo. Precios y nombres ilustrativos.
USE dermalia;
GO
INSERT INTO Protocolo (nombre, palabras, duracion_min, precio) VALUES
 (N'Limpieza facial profunda', N'limpieza facial cutis acné', 60, 25000),
 (N'Peeling químico',          N'peeling manchas renovación', 45, 40000),
 (N'Mesoterapia facial',       N'meso hidratación arrugas',   45, 55000),
 (N'Depilación láser (zona chica)', N'laser depilación',      30, 18000);
INSERT INTO Profesional (nombre) VALUES (N'Dra. Ejemplo Uno'), (N'Lic. Ejemplo Dos');
GO
