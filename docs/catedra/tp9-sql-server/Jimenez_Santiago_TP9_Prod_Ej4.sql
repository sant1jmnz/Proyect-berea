USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'TP9_Ej4')
    DROP DATABASE TP9_Ej4;
GO
CREATE DATABASE TP9_Ej4;
GO
USE TP9_Ej4;
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
    Descripcion       VARCHAR(200) NOT NULL
);
GO

CREATE TABLE Producto (
    ProductID         INT IDENTITY(1,1) PRIMARY KEY,
    Nombre            VARCHAR(50)   NOT NULL,
    Precio            DECIMAL(10,2) NOT NULL,
    Color             VARCHAR(20)   NOT NULL,
    ProductModelID    INT           NOT NULL,
    ProductCategoryID INT           NOT NULL,
    FOREIGN KEY (ProductModelID)    REFERENCES Modelo(ProductModelID),
    FOREIGN KEY (ProductCategoryID) REFERENCES Categoria(ProductCategoryID)
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

INSERT INTO Categoria (Nombre, Descripcion) VALUES ('Electronica', 'Articulos de electronica y tecnologia');
INSERT INTO Categoria (Nombre, Descripcion) VALUES ('Indumentaria', 'Ropa y accesorios de vestir');
INSERT INTO Categoria (Nombre, Descripcion) VALUES ('Informatica', 'Equipos de electronica avanzada');
INSERT INTO Categoria (Nombre, Descripcion) VALUES ('Deportes', 'Articulos deportivos y outdoor');
GO

-- Nombre, Precio, Color, ProductModelID, ProductCategoryID
INSERT INTO Producto VALUES ('Notebook X1', 850.00, 'ROJO', 2, 1);
INSERT INTO Producto VALUES ('Monitor Z2', 600.00, 'ROJO', 4, 3);
INSERT INTO Producto VALUES ('Teclado K3', 45.00, 'ROJO', 3, 1);
INSERT INTO Producto VALUES ('Campera T4', 300.00, 'ROJO', 1, 2);
INSERT INTO Producto VALUES ('Mouse M5', 25.00, 'NEGRO', 3, 1);
INSERT INTO Producto VALUES ('Tablet TB7', 700.00, 'ROJO', 2, 4);
INSERT INTO Producto VALUES ('Router R8', 550.00, 'ROJO', 4, 3);
INSERT INTO Producto VALUES ('Zapatillas Z9', 90.00, 'VERDE', 1, 4);
INSERT INTO Producto VALUES ('Impresora I10', 480.00, 'ROJO', 3, 1);
INSERT INTO Producto VALUES ('Auriculares A6', 120.00, 'AZUL', 2, 1);
GO

-- OPCION A: TABLA TEMPORAL (#)
CREATE TABLE #TempProductoFiltrado4 (
    Nombre            VARCHAR(50),
    ProductModelID    INT,
    ProductCategoryID INT
);
INSERT INTO #TempProductoFiltrado4
SELECT Nombre, ProductModelID, ProductCategoryID FROM Producto WHERE Color = 'ROJO';

CREATE TABLE #TempCategoriaFiltrada4 (ProductCategoryID INT, Nombre VARCHAR(50));
INSERT INTO #TempCategoriaFiltrada4
SELECT ProductCategoryID, Nombre FROM Categoria WHERE Descripcion LIKE '%Electronica%';

SELECT PF.Nombre AS NombreProducto, M.Nombre AS NombreModelo, CF.Nombre AS NombreCategoria
FROM #TempProductoFiltrado4 PF
INNER JOIN Modelo M ON PF.ProductModelID = M.ProductModelID
INNER JOIN #TempCategoriaFiltrada4 CF ON PF.ProductCategoryID = CF.ProductCategoryID;

DROP TABLE #TempProductoFiltrado4;
DROP TABLE #TempCategoriaFiltrada4;
GO

-- OPCION B: VARIABLE TIPO TABLA (@)
DECLARE @VarProductoFiltrado4 TABLE (
    Nombre            VARCHAR(50),
    ProductModelID    INT,
    ProductCategoryID INT
);
INSERT INTO @VarProductoFiltrado4
SELECT Nombre, ProductModelID, ProductCategoryID FROM Producto WHERE Color = 'ROJO';

DECLARE @VarCategoriaFiltrada4 TABLE (ProductCategoryID INT, Nombre VARCHAR(50));
INSERT INTO @VarCategoriaFiltrada4
SELECT ProductCategoryID, Nombre FROM Categoria WHERE Descripcion LIKE '%Electronica%';

SELECT PF.Nombre AS NombreProducto, M.Nombre AS NombreModelo, CF.Nombre AS NombreCategoria
FROM @VarProductoFiltrado4 PF
INNER JOIN Modelo M ON PF.ProductModelID = M.ProductModelID
INNER JOIN @VarCategoriaFiltrada4 CF ON PF.ProductCategoryID = CF.ProductCategoryID;
GO

-- OPCION C: TABLA DERIVADA (subquery en FROM)
SELECT ProductoFiltrado.Nombre AS NombreProducto, M.Nombre AS NombreModelo, CF.Nombre AS NombreCategoria
FROM (SELECT Nombre, ProductModelID, ProductCategoryID FROM Producto WHERE Color = 'ROJO') AS ProductoFiltrado
INNER JOIN Modelo M ON ProductoFiltrado.ProductModelID = M.ProductModelID
INNER JOIN (SELECT ProductCategoryID, Nombre FROM Categoria WHERE Descripcion LIKE '%Electronica%') AS CF
    ON ProductoFiltrado.ProductCategoryID = CF.ProductCategoryID;
GO
