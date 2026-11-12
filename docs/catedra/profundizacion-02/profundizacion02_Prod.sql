/*
 =============================================================================
   BALDMAN SOFTWARE - SCRIPT DE PRODUCCION OPTIMIZADO (PROFUNDIZACION 02)
   DATASET: BradFit - Sistema de Gestion de Gimnasios
   INTEGRANTES: Jimenez, Santiago
 =============================================================================
*/
USE BradFit;
GO

SET DATEFORMAT ymd;
GO

-- =============================================================================
-- CONSULTA A: Agregacion + filtro de grupo (HAVING)
-- Que planes de membresia recaudaron mas de $60.000 en total?
-- Pipeline: FROM (JOIN) -> GROUP BY -> HAVING -> SELECT
-- =============================================================================
SELECT
    pm.Nombre AS NombrePlan,
    COUNT(*) AS CantidadSuscripciones,
    SUM(su.PrecioAbonado) AS TotalRecaudado
FROM Suscripcion su
INNER JOIN PlanMembresia pm ON su.ID_PlanMembresia = pm.ID_PlanMembresia
GROUP BY pm.Nombre
HAVING SUM(su.PrecioAbonado) > 60000
ORDER BY TotalRecaudado DESC;
GO

-- =============================================================================
-- CONSULTA B: Pipeline completo WHERE + GROUP BY + HAVING
-- Por medio de pago, cuanto se cobro en pagos aprobados de socios activos durante 2025? Solo medios que superan $50.000.
-- Pipeline: FROM -> WHERE (filas) -> GROUP BY -> HAVING (grupos) -> SELECT
-- =============================================================================
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
HAVING SUM(p.Monto) > 50000
ORDER BY TotalCobrado DESC;
GO

-- =============================================================================
-- CONSULTA C: Agrupamiento multitabla (4 tablas) + MIN / MAX / ROUND(AVG(), 2)
-- Por genero y acceso a clases, precio minimo, maximo y promedio de las suscripciones activas (grupos con 2 o mas).
-- Pipeline: FROM (4 tablas) -> WHERE -> GROUP BY -> HAVING -> SELECT
-- =============================================================================
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
HAVING COUNT(*) >= 2
ORDER BY g.Nombre, pm.AccesoClases;
GO

-- =============================================================================
-- CONSULTA D: COUNT(*) contra COUNT(columna): evaluacion de nulos
-- Por duracion de plan, cuantas filas hay en total y cuantas tienen suscripcion real? El LEFT JOIN deja NULL en los planes sin ventas; el HAVING muestra solo grupos con datos incompletos.
-- Pipeline: FROM (LEFT JOIN) -> WHERE -> GROUP BY -> HAVING -> SELECT
-- =============================================================================
SELECT
    pm.DuracionMeses AS DuracionMeses,
    COUNT(*) AS TotalFilas,
    COUNT(su.ID_Suscripcion) AS FilasConSuscripcion,
    COUNT(*) - COUNT(su.ID_Suscripcion) AS PlanesSinSuscripcion
FROM PlanMembresia pm
LEFT JOIN Suscripcion su ON pm.ID_PlanMembresia = su.ID_PlanMembresia
WHERE pm.Precio > 10000
GROUP BY pm.DuracionMeses
HAVING COUNT(*) != COUNT(su.ID_Suscripcion)
ORDER BY pm.DuracionMeses;
GO
