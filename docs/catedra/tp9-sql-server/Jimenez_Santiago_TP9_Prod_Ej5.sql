USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'TP9_Ej5')
    DROP DATABASE TP9_Ej5;
GO
CREATE DATABASE TP9_Ej5;
GO
USE TP9_Ej5;
GO

-- =======================================================
-- Limpieza
-- =======================================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Producto') AND type IN (N'U'))
    DROP TABLE dbo.Producto;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Modelo') AND type IN (N'U'))
    DROP TABLE dbo.Modelo;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Categoria') AND type IN (N'U'))
    DROP TABLE dbo.Categoria;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Proveedor') AND type IN (N'U'))
    DROP TABLE dbo.Proveedor;
GO

-- =======================================================
-- DDL
-- =======================================================
CREATE TABLE Modelo (
    ProductModelID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre         VARCHAR(50)  NOT NULL,
    Descripcion    VARCHAR(200) NOT NULL
);
GO

CREATE TABLE Categoria (
    ProductCategoryID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre            VARCHAR(50)  NOT NULL,
    Descripcion       VARCHAR(200) NOT NULL,
    Tipo              VARCHAR(30)  NOT NULL
);
GO

CREATE TABLE Proveedor (
    ProveedorID INT IDENTITY(1,1) PRIMARY KEY,
    RazonSocial VARCHAR(100) NOT NULL,
    Ciudad      VARCHAR(50)  NOT NULL
);
GO

CREATE TABLE Producto (
    ProductID         INT IDENTITY(1,1) PRIMARY KEY,
    Nombre            VARCHAR(50)   NOT NULL,
    Precio            DECIMAL(10,2) NOT NULL,
    Color             VARCHAR(20)   NOT NULL,
    ProductModelID    INT           NOT NULL,
    ProductCategoryID INT           NOT NULL,
    ProveedorID       INT           NOT NULL,

    FOREIGN KEY (ProductModelID)    REFERENCES Modelo(ProductModelID),
    FOREIGN KEY (ProductCategoryID) REFERENCES Categoria(ProductCategoryID),
    FOREIGN KEY (ProveedorID)       REFERENCES Proveedor(ProveedorID)
);
GO

-- =======================================================
-- DML - datos de prueba
-- =======================================================
INSERT INTO Modelo (Nombre, Descripcion) VALUES ('Standard', 'Linea estandar');
INSERT INTO Modelo (Nombre, Descripcion) VALUES ('Pro', 'Linea profesional');
INSERT INTO Modelo (Nombre, Descripcion) VALUES ('Lite', 'Linea economica');
INSERT INTO Modelo (Nombre, Descripcion) VALUES ('Max', 'Linea premium');
GO

INSERT INTO Categoria (Nombre, Descripcion, Tipo) VALUES ('Electronica', 'Articulos de electronica y tecnologia', 'TECNOLOGIA');
INSERT INTO Categoria (Nombre, Descripcion, Tipo) VALUES ('Indumentaria', 'Ropa y accesorios de vestir', 'MODA');
INSERT INTO Categoria (Nombre, Descripcion, Tipo) VALUES ('Informatica', 'Equipos de electronica avanzada', 'TECNOLOGIA');
INSERT INTO Categoria (Nombre, Descripcion, Tipo) VALUES ('Deportes', 'Articulos deportivos y outdoor', 'DEPORTES');
GO

INSERT INTO Proveedor (RazonSocial, Ciudad) VALUES ('TecnoSA', 'Buenos Aires');
INSERT INTO Proveedor (RazonSocial, Ciudad) VALUES ('ImportCba', 'Cordoba');
INSERT INTO Proveedor (RazonSocial, Ciudad) VALUES ('GlobalTech', 'Buenos Aires');
INSERT INTO Proveedor (RazonSocial, Ciudad) VALUES ('SurProveedores', 'Rosario');
INSERT INTO Proveedor (RazonSocial, Ciudad) VALUES ('NorteDistribuidora', 'Buenos Aires');
GO

-- Nombre, Precio, Color, ProductModelID, ProductCategoryID, ProveedorID
INSERT INTO Producto VALUES ('Notebook X1',   850.00, 'ROJO',  2, 1, 1);
INSERT INTO Producto VALUES ('Monitor Z2',    600.00, 'ROJO',  4, 3, 3);
INSERT INTO Producto VALUES ('Teclado K3',     45.00, 'ROJO',  3, 1, 1);
INSERT INTO Producto VALUES ('Campera T4',    300.00, 'ROJO',  1, 2, 4);
INSERT INTO Producto VALUES ('Mouse M5',       25.00, 'NEGRO', 3, 1, 1);
INSERT INTO Producto VALUES ('Auriculares A6', 120.00,'AZUL',  2, 1, 2);
INSERT INTO Producto VALUES ('Tablet TB7',    700.00, 'ROJO',  2, 4, 1);
INSERT INTO Producto VALUES ('Router R8',     550.00, 'ROJO',  4, 3, 5);
INSERT INTO Producto VALUES ('Zapatillas Z9',  90.00, 'VERDE', 1, 4, 2);
INSERT INTO Producto VALUES ('Impresora I10', 480.00, 'ROJO',  3, 1, 3);
GO

-- OPCION A: TABLA TEMPORAL (#)
-- Guarda Producto, Categoria y Proveedor filtrados, cada uno en una tabla temporal.
CREATE TABLE #TempProductoFiltrado5 (
    Nombre            VARCHAR(50),
    ProductModelID    INT,
    ProductCategoryID INT,
    ProveedorID       INT
);
INSERT INTO #TempProductoFiltrado5
SELECT Nombre, ProductModelID, ProductCategoryID, ProveedorID
FROM Producto
WHERE Color = 'ROJO' AND Precio > 500;

CREATE TABLE #TempCategoriaFiltrada5 (
    ProductCategoryID INT,
    Nombre            VARCHAR(50)
);
INSERT INTO #TempCategoriaFiltrada5
SELECT ProductCategoryID, Nombre
FROM Categoria
WHERE Tipo = 'TECNOLOGIA';

CREATE TABLE #TempProveedorFiltrado5 (
    ProveedorID INT,
    RazonSocial VARCHAR(100)
);
INSERT INTO #TempProveedorFiltrado5
SELECT ProveedorID, RazonSocial
FROM Proveedor
WHERE Ciudad = 'Buenos Aires';

SELECT
    ProductoFiltrado.Nombre AS NombreProducto,
    M.Nombre  AS NombreModelo,
    CF.Nombre AS NombreCategoria,
    PV.RazonSocial
FROM #TempProductoFiltrado5 ProductoFiltrado
INNER JOIN Modelo M                 ON ProductoFiltrado.ProductModelID    = M.ProductModelID
INNER JOIN #TempCategoriaFiltrada5 CF   ON ProductoFiltrado.ProductCategoryID = CF.ProductCategoryID
INNER JOIN #TempProveedorFiltrado5 PV   ON ProductoFiltrado.ProveedorID       = PV.ProveedorID;

DROP TABLE #TempProductoFiltrado5;
DROP TABLE #TempCategoriaFiltrada5;
DROP TABLE #TempProveedorFiltrado5;
GO

-- OPCION B: VARIABLE TIPO TABLA (@)
-- Guarda Producto, Categoria y Proveedor filtrados, cada uno en una variable.
DECLARE @VarProductoFiltrado5 TABLE (
    Nombre            VARCHAR(50),
    ProductModelID    INT,
    ProductCategoryID INT,
    ProveedorID       INT
);
INSERT INTO @VarProductoFiltrado5
SELECT Nombre, ProductModelID, ProductCategoryID, ProveedorID
FROM Producto
WHERE Color = 'ROJO' AND Precio > 500;

DECLARE @VarCategoriaFiltrada5 TABLE (
    ProductCategoryID INT,
    Nombre            VARCHAR(50)
);
INSERT INTO @VarCategoriaFiltrada5
SELECT ProductCategoryID, Nombre
FROM Categoria
WHERE Tipo = 'TECNOLOGIA';

DECLARE @VarProveedorFiltrado5 TABLE (
    ProveedorID INT,
    RazonSocial VARCHAR(100)
);
INSERT INTO @VarProveedorFiltrado5
SELECT ProveedorID, RazonSocial
FROM Proveedor
WHERE Ciudad = 'Buenos Aires';

SELECT
    ProductoFiltrado.Nombre AS NombreProducto,
    M.Nombre  AS NombreModelo,
    CF.Nombre AS NombreCategoria,
    PV.RazonSocial
FROM @VarProductoFiltrado5 ProductoFiltrado
INNER JOIN Modelo M                ON ProductoFiltrado.ProductModelID    = M.ProductModelID
INNER JOIN @VarCategoriaFiltrada5 CF  ON ProductoFiltrado.ProductCategoryID = CF.ProductCategoryID
INNER JOIN @VarProveedorFiltrado5 PV  ON ProductoFiltrado.ProveedorID       = PV.ProveedorID;
GO

-- OPCION C: TABLA DERIVADA (subquery en FROM)
-- El motor guarda Producto, Categoria y Proveedor filtrados internamente, sin crear tablas.
SELECT
    ProductoFiltrado.Nombre AS NombreProducto,
    M.Nombre  AS NombreModelo,
    CF.Nombre AS NombreCategoria,
    PV.RazonSocial
FROM (
    SELECT Nombre, ProductModelID, ProductCategoryID, ProveedorID
    FROM Producto
    WHERE Color = 'ROJO' AND Precio > 500
) AS ProductoFiltrado
INNER JOIN Modelo M ON ProductoFiltrado.ProductModelID = M.ProductModelID
INNER JOIN (
    SELECT ProductCategoryID, Nombre
    FROM Categoria
    WHERE Tipo = 'TECNOLOGIA'
) AS CF ON ProductoFiltrado.ProductCategoryID = CF.ProductCategoryID
INNER JOIN (
    SELECT ProveedorID, RazonSocial
    FROM Proveedor
    WHERE Ciudad = 'Buenos Aires'
) AS PV ON ProductoFiltrado.ProveedorID = PV.ProveedorID;
GO
