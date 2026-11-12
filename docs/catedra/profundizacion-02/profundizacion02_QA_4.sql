/*
 =============================================================================
   BALDMAN SOFTWARE - SCRIPT DE PRUEBAS Y MATERIALIZACION (QA) - PROFUNDIZACION 02
   DATASET: BradFit          INTEGRANTES: Jimenez, Santiago
   PRUEBA 4: Consulta D - COUNT(*) contra COUNT(columna) por duracion de plan
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
    pm.DuracionMeses AS DuracionMeses,
    COUNT(*) AS TotalFilas,
    COUNT(su.ID_Suscripcion) AS FilasConSuscripcion,
    COUNT(*) - COUNT(su.ID_Suscripcion) AS PlanesSinSuscripcion
FROM PlanMembresia pm
LEFT JOIN Suscripcion su ON pm.ID_PlanMembresia = su.ID_PlanMembresia
WHERE pm.Precio > 10000
GROUP BY pm.DuracionMeses
HAVING COUNT(*) != COUNT(su.ID_Suscripcion);
GO

-- =============================================================================
-- CHEETAH - OPCION A: TABLA TEMPORAL (#) - Genera impacto en tempdb
-- =============================================================================
PRINT '--- CHEETAH A: #TABLAS ---';

CREATE TABLE #N1 (
    ID_PlanMembresia INT,
    DuracionMeses INT
);
INSERT INTO #N1 (ID_PlanMembresia, DuracionMeses)
SELECT ID_PlanMembresia, DuracionMeses
FROM PlanMembresia
WHERE Precio > 10000;
PRINT 'N1 (PlanMembresia filtrada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

CREATE TABLE #N2 (
    ID_PlanMembresia INT,
    ID_Suscripcion INT
);
INSERT INTO #N2 (ID_PlanMembresia, ID_Suscripcion)
SELECT ID_PlanMembresia, ID_Suscripcion
FROM Suscripcion;
PRINT 'N2 (Suscripcion proyectada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

CREATE TABLE #N3 (
    DuracionMeses INT,
    ID_Suscripcion INT NULL
);
INSERT INTO #N3 (DuracionMeses, ID_Suscripcion)
SELECT n1.DuracionMeses, n2.ID_Suscripcion
FROM #N1 n1
LEFT JOIN #N2 n2 ON n1.ID_PlanMembresia = n2.ID_PlanMembresia;
PRINT 'N3 (reunion externa) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

CREATE TABLE #N4 (
    DuracionMeses INT,
    TotalFilas INT,
    FilasConSuscripcion INT
);
INSERT INTO #N4 (DuracionMeses, TotalFilas, FilasConSuscripcion)
SELECT DuracionMeses, COUNT(*), COUNT(ID_Suscripcion)
FROM #N3
GROUP BY DuracionMeses;
PRINT 'N4 (grupos) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

SELECT
    DuracionMeses,
    TotalFilas,
    FilasConSuscripcion,
    TotalFilas - FilasConSuscripcion AS PlanesSinSuscripcion
FROM #N4
WHERE TotalFilas != FilasConSuscripcion;
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
    DuracionMeses INT
);
INSERT INTO @N1 (ID_PlanMembresia, DuracionMeses)
SELECT ID_PlanMembresia, DuracionMeses
FROM PlanMembresia
WHERE Precio > 10000;
PRINT 'N1 (PlanMembresia filtrada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N2 TABLE (
    ID_PlanMembresia INT,
    ID_Suscripcion INT
);
INSERT INTO @N2 (ID_PlanMembresia, ID_Suscripcion)
SELECT ID_PlanMembresia, ID_Suscripcion
FROM Suscripcion;
PRINT 'N2 (Suscripcion proyectada) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N3 TABLE (
    DuracionMeses INT,
    ID_Suscripcion INT NULL
);
INSERT INTO @N3 (DuracionMeses, ID_Suscripcion)
SELECT n1.DuracionMeses, n2.ID_Suscripcion
FROM @N1 n1
LEFT JOIN @N2 n2 ON n1.ID_PlanMembresia = n2.ID_PlanMembresia;
PRINT 'N3 (reunion externa) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N4 TABLE (
    DuracionMeses INT,
    TotalFilas INT,
    FilasConSuscripcion INT
);
INSERT INTO @N4 (DuracionMeses, TotalFilas, FilasConSuscripcion)
SELECT DuracionMeses, COUNT(*), COUNT(ID_Suscripcion)
FROM @N3
GROUP BY DuracionMeses;
PRINT 'N4 (grupos) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

SELECT
    DuracionMeses,
    TotalFilas,
    FilasConSuscripcion,
    TotalFilas - FilasConSuscripcion AS PlanesSinSuscripcion
FROM @N4
WHERE TotalFilas != FilasConSuscripcion;
PRINT 'Resultado final filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- =============================================================================
-- CHEETAH - OPCION C: SUBCONSULTAS ANIDADAS (tablas derivadas en linea)
-- =============================================================================
PRINT '--- CHEETAH C: SUBCONSULTAS ---';
SELECT
    N4.DuracionMeses,
    N4.TotalFilas,
    N4.FilasConSuscripcion,
    N4.TotalFilas - N4.FilasConSuscripcion AS PlanesSinSuscripcion
FROM (
    SELECT N3.DuracionMeses, COUNT(*) AS TotalFilas, COUNT(N3.ID_Suscripcion) AS FilasConSuscripcion
    FROM (
        SELECT N1.DuracionMeses, N2.ID_Suscripcion
        FROM (SELECT ID_PlanMembresia, DuracionMeses
              FROM PlanMembresia
              WHERE Precio > 10000) N1
        LEFT JOIN (SELECT ID_PlanMembresia, ID_Suscripcion FROM Suscripcion) N2
            ON N1.ID_PlanMembresia = N2.ID_PlanMembresia
    ) N3
    GROUP BY N3.DuracionMeses
) N4
WHERE N4.TotalFilas != N4.FilasConSuscripcion;
GO
