/*
 =============================================================================
   BALDMAN SOFTWARE - SCRIPT DE PRUEBAS Y MATERIALIZACION (QA) - PROFUNDIZACION 02
   DATASET: BradFit          INTEGRANTES: Jimenez, Santiago
   PRUEBA 3: Consulta C - minimo, maximo y promedio por genero y acceso a clases (4 tablas)
   Compara: Caracol (sin optimizar) vs Cheetah A (#temp) / B (@tabla) / C (subconsultas)
 =============================================================================
*/
USE BradFit;
GO
SET DATEFORMAT ymd;
GO

-- =============================================================================
-- CARACOL: reunion completa primero; filtros y agrupamiento al final
-- =============================================================================
PRINT '--- CARACOL ---';
SELECT
    g.Nombre AS Genero,
    pm.AccesoClases AS AccesoClases,
    COUNT(*) AS CantidadSuscripciones,
    MIN(su.PrecioAbonado) AS PrecioMinimo,
    MAX(su.PrecioAbonado) AS PrecioMaximo,
    ROUND(AVG(su.PrecioAbonado), 2) AS PrecioPromedio
FROM Suscripcion su
INNER JOIN Socio s ON su.ID_Socio = s.ID_Socio
INNER JOIN Genero g ON s.ID_Genero = g.ID_Genero
INNER JOIN PlanMembresia pm ON su.ID_PlanMembresia = pm.ID_PlanMembresia
WHERE su.Estado = 'Activa'
GROUP BY g.Nombre, pm.AccesoClases
HAVING COUNT(*) >= 2;
GO

-- =============================================================================
-- CHEETAH - OPCION A: TABLA TEMPORAL (#) - Genera impacto en tempdb
-- =============================================================================
PRINT '--- CHEETAH A: #TABLAS ---';

CREATE TABLE #N1 (
    ID_Socio INT,
    ID_PlanMembresia INT,
    PrecioAbonado DECIMAL(10,2)
);
INSERT INTO #N1 (ID_Socio, ID_PlanMembresia, PrecioAbonado)
SELECT ID_Socio, ID_PlanMembresia, PrecioAbonado
FROM Suscripcion
WHERE Estado = 'Activa';
PRINT 'N1 (Suscripcion activa) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

CREATE TABLE #N2 (
    ID_Socio INT,
    ID_Genero INT
);
INSERT INTO #N2 (ID_Socio, ID_Genero)
SELECT ID_Socio, ID_Genero
FROM Socio;
PRINT 'N2 (Socio proyectado) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));


CREATE TABLE #N3 (
    ID_Genero INT,
    Nombre VARCHAR(20)
);
INSERT INTO #N3 (ID_Genero, Nombre)
SELECT ID_Genero, Nombre
FROM Genero;
PRINT 'N3 (Genero proyectado) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));


CREATE TABLE #N4 (
    ID_PlanMembresia INT,
    AccesoClases VARCHAR(10)
);
INSERT INTO #N4 (ID_PlanMembresia, AccesoClases)
SELECT ID_PlanMembresia, AccesoClases
FROM PlanMembresia;
PRINT 'N4 (PlanMembresia proyectada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));


CREATE TABLE #J1 (
    ID_PlanMembresia INT,
    PrecioAbonado DECIMAL(10,2),
    ID_Genero INT
);
INSERT INTO #J1 (ID_PlanMembresia, PrecioAbonado, ID_Genero)
SELECT a.ID_PlanMembresia, a.PrecioAbonado, b.ID_Genero
FROM #N1 a
INNER JOIN #N2 b ON a.ID_Socio = b.ID_Socio;
PRINT 'J1 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));


CREATE TABLE #J2 (
    ID_PlanMembresia INT,
    PrecioAbonado DECIMAL(10,2),
    Genero VARCHAR(20)
);
INSERT INTO #J2 (ID_PlanMembresia, PrecioAbonado, Genero)
SELECT a.ID_PlanMembresia, a.PrecioAbonado, c.Nombre
FROM #J1 a
INNER JOIN #N3 c ON a.ID_Genero = c.ID_Genero;
PRINT 'J2 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

CREATE TABLE #J3 (
    Genero VARCHAR(20),
    AccesoClases VARCHAR(10),
    PrecioAbonado DECIMAL(10,2)
);
INSERT INTO #J3 (Genero, AccesoClases, PrecioAbonado)
SELECT a.Genero, d.AccesoClases, a.PrecioAbonado
FROM #J2 a
INNER JOIN #N4 d ON a.ID_PlanMembresia = d.ID_PlanMembresia;
PRINT 'J3 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

CREATE TABLE #G (
    Genero VARCHAR(20),
    AccesoClases VARCHAR(10),
    Cantidad INT,
    Minimo DECIMAL(10,2),
    Maximo DECIMAL(10,2),
    Promedio DECIMAL(12,6)
);
INSERT INTO #G (Genero, AccesoClases, Cantidad, Minimo, Maximo, Promedio)
SELECT Genero, AccesoClases, COUNT(*), MIN(PrecioAbonado), MAX(PrecioAbonado), AVG(PrecioAbonado)
FROM #J3
GROUP BY Genero, AccesoClases;
PRINT 'G (grupos) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

SELECT
    Genero,
    AccesoClases,
    Cantidad AS CantidadSuscripciones,
    Minimo AS PrecioMinimo,
    Maximo AS PrecioMaximo,
    ROUND(Promedio, 2) AS PrecioPromedio
FROM #G
WHERE Cantidad >= 2;
PRINT 'Resultado final filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DROP TABLE #N1;
DROP TABLE #N2;
DROP TABLE #N3;
DROP TABLE #N4;
DROP TABLE #J1;
DROP TABLE #J2;
DROP TABLE #J3;
DROP TABLE #G;
GO

-- =============================================================================
-- CHEETAH - OPCION B: VARIABLE TIPO TABLA (@) - Ideal dentro de Stored Procedures
-- =============================================================================
PRINT '--- CHEETAH B: @VARIABLES TABLA ---';

DECLARE @N1 TABLE (
    ID_Socio INT,
    ID_PlanMembresia INT,
    PrecioAbonado DECIMAL(10,2)
);
INSERT INTO @N1 (ID_Socio, ID_PlanMembresia, PrecioAbonado)
SELECT ID_Socio, ID_PlanMembresia, PrecioAbonado
FROM Suscripcion
WHERE Estado = 'Activa';
PRINT 'N1 (Suscripcion activa) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N2 TABLE (
    ID_Socio INT,
    ID_Genero INT
);
INSERT INTO @N2 (ID_Socio, ID_Genero)
SELECT ID_Socio, ID_Genero
FROM Socio;
PRINT 'N2 (Socio proyectado) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N3 TABLE (
    ID_Genero INT,
    Nombre VARCHAR(20)
);
INSERT INTO @N3 (ID_Genero, Nombre)
SELECT ID_Genero, Nombre
FROM Genero;
PRINT 'N3 (Genero proyectado) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N4 TABLE (
    ID_PlanMembresia INT,
    AccesoClases VARCHAR(10)
);
INSERT INTO @N4 (ID_PlanMembresia, AccesoClases)
SELECT ID_PlanMembresia, AccesoClases
FROM PlanMembresia;
PRINT 'N4 (PlanMembresia proyectada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @J1 TABLE (
    ID_PlanMembresia INT,
    PrecioAbonado DECIMAL(10,2),
    ID_Genero INT
);
INSERT INTO @J1 (ID_PlanMembresia, PrecioAbonado, ID_Genero)
SELECT a.ID_PlanMembresia, a.PrecioAbonado, b.ID_Genero
FROM @N1 a
INNER JOIN @N2 b ON a.ID_Socio = b.ID_Socio;
PRINT 'J1 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @J2 TABLE (
    ID_PlanMembresia INT,
    PrecioAbonado DECIMAL(10,2),
    Genero VARCHAR(20)
);
INSERT INTO @J2 (ID_PlanMembresia, PrecioAbonado, Genero)
SELECT a.ID_PlanMembresia, a.PrecioAbonado, c.Nombre
FROM @J1 a
INNER JOIN @N3 c ON a.ID_Genero = c.ID_Genero;
PRINT 'J2 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @J3 TABLE (
    Genero VARCHAR(20),
    AccesoClases VARCHAR(10),
    PrecioAbonado DECIMAL(10,2)
);
INSERT INTO @J3 (Genero, AccesoClases, PrecioAbonado)
SELECT a.Genero, d.AccesoClases, a.PrecioAbonado
FROM @J2 a
INNER JOIN @N4 d ON a.ID_PlanMembresia = d.ID_PlanMembresia;
PRINT 'J3 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @G TABLE (
    Genero VARCHAR(20),
    AccesoClases VARCHAR(10),
    Cantidad INT,
    Minimo DECIMAL(10,2),
    Maximo DECIMAL(10,2),
    Promedio DECIMAL(12,6)
);
INSERT INTO @G (Genero, AccesoClases, Cantidad, Minimo, Maximo, Promedio)
SELECT Genero, AccesoClases, COUNT(*), MIN(PrecioAbonado), MAX(PrecioAbonado), AVG(PrecioAbonado)
FROM @J3
GROUP BY Genero, AccesoClases;
PRINT 'G (grupos) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

SELECT
    Genero,
    AccesoClases,
    Cantidad AS CantidadSuscripciones,
    Minimo AS PrecioMinimo,
    Maximo AS PrecioMaximo,
    ROUND(Promedio, 2) AS PrecioPromedio
FROM @G
WHERE Cantidad >= 2;
PRINT 'Resultado final filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- =============================================================================
-- CHEETAH - OPCION C: SUBCONSULTAS ANIDADAS (tablas derivadas en linea)
-- =============================================================================
PRINT '--- CHEETAH C: SUBCONSULTAS ---';
SELECT
    G.Genero,
    G.AccesoClases,
    G.Cantidad AS CantidadSuscripciones,
    G.Minimo AS PrecioMinimo,
    G.Maximo AS PrecioMaximo,
    ROUND(G.Promedio, 2) AS PrecioPromedio
FROM (
    SELECT J3.Genero, J3.AccesoClases, COUNT(*) AS Cantidad,
           MIN(J3.PrecioAbonado) AS Minimo, MAX(J3.PrecioAbonado) AS Maximo, AVG(J3.PrecioAbonado) AS Promedio
    FROM (
        SELECT J2.Genero, N4.AccesoClases, J2.PrecioAbonado
        FROM (
            SELECT J1.ID_PlanMembresia, J1.PrecioAbonado, N3.Nombre AS Genero
            FROM (
                SELECT N1.ID_PlanMembresia, N1.PrecioAbonado, N2.ID_Genero
                FROM (SELECT ID_Socio, ID_PlanMembresia, PrecioAbonado
                      FROM Suscripcion
                      WHERE Estado = 'Activa') N1
                INNER JOIN (SELECT ID_Socio, ID_Genero FROM Socio) N2 ON N1.ID_Socio = N2.ID_Socio
            ) J1
            INNER JOIN (SELECT ID_Genero, Nombre FROM Genero) N3 ON J1.ID_Genero = N3.ID_Genero
        ) J2
        INNER JOIN (SELECT ID_PlanMembresia, AccesoClases FROM PlanMembresia) N4
            ON J2.ID_PlanMembresia = N4.ID_PlanMembresia
    ) J3
    GROUP BY J3.Genero, J3.AccesoClases
) G
WHERE G.Cantidad >= 2;
GO
