/*
 =============================================================================
   BALDMAN SOFTWARE - SCRIPT DE PRUEBAS Y MATERIALIZACION (QA) - PROFUNDIZACION 02
   DATASET: BradFit          INTEGRANTES: Jimenez, Santiago
   PRUEBA 2: Consulta B - pagos aprobados de socios activos en 2025 (WHERE + HAVING)
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
    p.MedioPago AS MedioPago,
    COUNT(*) AS CantidadPagos,
    SUM(p.Monto) AS TotalCobrado
FROM Pago p
INNER JOIN Socio s ON p.ID_Socio = s.ID_Socio
WHERE p.Estado = 'Aprobado'
  AND s.Estado = 'Activo'
  AND p.Fecha >= '20250101'
  AND p.Fecha <= '20251231'
GROUP BY p.MedioPago
HAVING SUM(p.Monto) > 50000;
GO

-- =============================================================================
-- CHEETAH - OPCION A: TABLA TEMPORAL (#) - Genera impacto en tempdb
-- =============================================================================
PRINT '--- CHEETAH A: #TABLAS ---';
CREATE TABLE #N1 (
    ID_Socio INT,
    MedioPago VARCHAR(20),
    Monto DECIMAL(10,2)
);
INSERT INTO #N1 (ID_Socio, MedioPago, Monto)
SELECT ID_Socio, MedioPago, Monto
FROM Pago
WHERE Estado = 'Aprobado'
  AND Fecha >= '20250101'
  AND Fecha <= '20251231';
PRINT 'N1 (Pago filtrado) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));


CREATE TABLE #N2 (
    ID_Socio INT
);
INSERT INTO #N2 (ID_Socio)
SELECT ID_Socio
FROM Socio
WHERE Estado = 'Activo';
PRINT 'N2 (Socio filtrado) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));


CREATE TABLE #N3 (
    MedioPago VARCHAR(20),
    Monto DECIMAL(10,2)
);
INSERT INTO #N3 (MedioPago, Monto)
SELECT n1.MedioPago, n1.Monto
FROM #N1 n1
INNER JOIN #N2 n2 ON n1.ID_Socio = n2.ID_Socio;
PRINT 'N3 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));


CREATE TABLE #N4 (
    MedioPago VARCHAR(20),
    CantidadPagos INT,
    TotalCobrado DECIMAL(12,2)
);
INSERT INTO #N4 (MedioPago, CantidadPagos, TotalCobrado)
SELECT MedioPago, COUNT(*), SUM(Monto)
FROM #N3
GROUP BY MedioPago;
PRINT 'N4 (grupos) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

SELECT
    MedioPago,
    CantidadPagos,
    TotalCobrado
FROM #N4
WHERE TotalCobrado > 50000;
PRINT 'Resultado final filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DROP TABLE #N1;
DROP TABLE #N2;
DROP TABLE #N3;
DROP TABLE #N4;
GO

-- =============================================================================
-- CHEETAH - OPCION B: VARIABLE TIPO TABLA (@) - Ideal dentro de Stored Procedures.
-- =============================================================================
PRINT '--- CHEETAH B: @VARIABLES TABLA ---';

DECLARE @N1 TABLE (
    ID_Socio INT,
    MedioPago VARCHAR(20),
    Monto DECIMAL(10,2)
);
INSERT INTO @N1 (ID_Socio, MedioPago, Monto)
SELECT ID_Socio, MedioPago, Monto
FROM Pago
WHERE Estado = 'Aprobado'
  AND Fecha >= '20250101'
  AND Fecha <= '20251231';
PRINT 'N1 (Pago filtrado) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N2 TABLE (
    ID_Socio INT
);
INSERT INTO @N2 (ID_Socio)
SELECT ID_Socio
FROM Socio
WHERE Estado = 'Activo';
PRINT 'N2 (Socio filtrado) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N3 TABLE (
    MedioPago VARCHAR(20),
    Monto DECIMAL(10,2)
);
INSERT INTO @N3 (MedioPago, Monto)
SELECT n1.MedioPago, n1.Monto
FROM @N1 n1
INNER JOIN @N2 n2 ON n1.ID_Socio = n2.ID_Socio;
PRINT 'N3 (reunion) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DECLARE @N4 TABLE (
    MedioPago VARCHAR(20),
    CantidadPagos INT,
    TotalCobrado DECIMAL(12,2)
);
INSERT INTO @N4 (MedioPago, CantidadPagos, TotalCobrado)
SELECT MedioPago, COUNT(*), SUM(Monto)
FROM @N3
GROUP BY MedioPago;
PRINT 'N4 (grupos) filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

SELECT
    MedioPago,
    CantidadPagos,
    TotalCobrado
FROM @N4
WHERE TotalCobrado > 50000;
PRINT 'Resultado final filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- =============================================================================
-- CHEETAH - OPCION C: SUBCONSULTAS ANIDADAS (tablas derivadas en linea)
-- =============================================================================
PRINT '--- CHEETAH C: SUBCONSULTAS ---';
SELECT
    N4.MedioPago,
    N4.CantidadPagos,
    N4.TotalCobrado
FROM (
    SELECT N3.MedioPago, COUNT(*) AS CantidadPagos, SUM(N3.Monto) AS TotalCobrado
    FROM (
        SELECT N1.MedioPago, N1.Monto
        FROM (SELECT ID_Socio, MedioPago, Monto
              FROM Pago
              WHERE Estado = 'Aprobado' AND Fecha >= '20250101' AND Fecha <= '20251231') N1
        INNER JOIN (SELECT ID_Socio FROM Socio WHERE Estado = 'Activo') N2
            ON N1.ID_Socio = N2.ID_Socio
    ) N3
    GROUP BY N3.MedioPago
) N4
WHERE N4.TotalCobrado > 50000;
GO
