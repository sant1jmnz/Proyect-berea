/*
 =============================================================================
   BALDMAN SOFTWARE - SCRIPT DE PRUEBAS Y MATERIALIZACION (QA) - PROFUNDIZACION 02
   DATASET: BradFit          INTEGRANTES: Jimenez, Santiago
   PRUEBA 1: Consulta A - total recaudado por plan (HAVING)
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
    pm.Nombre AS NombrePlan,
    COUNT(*) AS CantidadSuscripciones,
    SUM(su.PrecioAbonado) AS TotalRecaudado
FROM Suscripcion su
INNER JOIN PlanMembresia pm ON su.ID_PlanMembresia = pm.ID_PlanMembresia
GROUP BY pm.Nombre
HAVING SUM(su.PrecioAbonado) > 60000;
GO

-- =============================================================================
-- CHEETAH - OPCION A: TABLA TEMPORAL (#) - Genera impacto en tempdb
-- =============================================================================
PRINT '--- CHEETAH A: #TABLAS ---';

CREATE TABLE #N1 (
    ID_PlanMembresia INT,
    Nombre VARCHAR(50)
);
INSERT INTO #N1 (ID_PlanMembresia, Nombre)
SELECT ID_PlanMembresia, Nombre
FROM PlanMembresia;
PRINT 'N1 (PlanMembresia proyectada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

CREATE TABLE #N2 (
    ID_PlanMembresia INT,
    PrecioAbonado DECIMAL(10,2)
);
INSERT INTO #N2 (ID_PlanMembresia, PrecioAbonado)
SELECT ID_PlanMembresia, PrecioAbonado
FROM Suscripcion;
PRINT 'N2 (Suscripcion proyectada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

CREATE TABLE #N3 (
    Nombre VARCHAR(50),
    PrecioAbonado DECIMAL(10,2)
);
INSERT INTO #N3 (Nombre, PrecioAbonado)
SELECT n1.Nombre, n2.PrecioAbonado
FROM #N1 n1
INNER JOIN #N2 n2 ON n1.ID_PlanMembresia = n2.ID_PlanMembresia;
PRINT 'N3 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

CREATE TABLE #N4 (
    Nombre VARCHAR(50),
    CantidadSuscripciones INT,
    TotalRecaudado DECIMAL(12,2)
);
INSERT INTO #N4 (Nombre, CantidadSuscripciones, TotalRecaudado)
SELECT Nombre, COUNT(*), SUM(PrecioAbonado)
FROM #N3
GROUP BY Nombre;
PRINT 'N4 (grupos) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

SELECT
    Nombre AS NombrePlan,
    CantidadSuscripciones,
    TotalRecaudado
FROM #N4
WHERE TotalRecaudado > 60000;
PRINT 'Resultado final filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DROP TABLE #N1;
DROP TABLE #N2;
DROP TABLE #N3;
DROP TABLE #N4;
GO

-- =============================================================================
-- CHEETAH - OPCION B: VARIABLE TIPO TABLA (@) - Ideal dentro de Stored Procedures
-- =============================================================================
PRINT '--- CHEETAH B: @VARIABLES TABLA ---';

DECLARE @N1 TABLE (
    ID_PlanMembresia INT,
    Nombre VARCHAR(50)
);
INSERT INTO @N1 (ID_PlanMembresia, Nombre)
SELECT ID_PlanMembresia, Nombre
FROM PlanMembresia;
PRINT 'N1 (PlanMembresia proyectada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N2 TABLE (
    ID_PlanMembresia INT,
    PrecioAbonado DECIMAL(10,2)
);
INSERT INTO @N2 (ID_PlanMembresia, PrecioAbonado)
SELECT ID_PlanMembresia, PrecioAbonado
FROM Suscripcion;
PRINT 'N2 (Suscripcion proyectada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N3 TABLE (
    Nombre VARCHAR(50),
    PrecioAbonado DECIMAL(10,2)
);
INSERT INTO @N3 (Nombre, PrecioAbonado)
SELECT n1.Nombre, n2.PrecioAbonado
FROM @N1 n1
INNER JOIN @N2 n2 ON n1.ID_PlanMembresia = n2.ID_PlanMembresia;
PRINT 'N3 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N4 TABLE (
    Nombre VARCHAR(50),
    CantidadSuscripciones INT,
    TotalRecaudado DECIMAL(12,2)
);
INSERT INTO @N4 (Nombre, CantidadSuscripciones, TotalRecaudado)
SELECT Nombre, COUNT(*), SUM(PrecioAbonado)
FROM @N3
GROUP BY Nombre;
PRINT 'N4 (grupos) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

SELECT
    Nombre AS NombrePlan,
    CantidadSuscripciones,
    TotalRecaudado
FROM @N4
WHERE TotalRecaudado > 60000;
PRINT 'Resultado final filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- =============================================================================
-- CHEETAH - OPCION C: SUBCONSULTAS ANIDADAS (tablas derivadas en linea)
-- =============================================================================
PRINT '--- CHEETAH C: SUBCONSULTAS ---';
SELECT
    N4.Nombre AS NombrePlan,
    N4.CantidadSuscripciones,
    N4.TotalRecaudado
FROM (
    SELECT N3.Nombre, COUNT(*) AS CantidadSuscripciones, SUM(N3.PrecioAbonado) AS TotalRecaudado
    FROM (
        SELECT N1.Nombre, N2.PrecioAbonado
        FROM (SELECT ID_PlanMembresia, Nombre FROM PlanMembresia) N1
        INNER JOIN (SELECT ID_PlanMembresia, PrecioAbonado FROM Suscripcion) N2
            ON N1.ID_PlanMembresia = N2.ID_PlanMembresia
    ) N3
    GROUP BY N3.Nombre
) N4
WHERE N4.TotalRecaudado > 60000;
GO
