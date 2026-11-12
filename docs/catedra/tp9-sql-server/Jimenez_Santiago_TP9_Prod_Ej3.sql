USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'TP9_Ej3')
    DROP DATABASE TP9_Ej3;
GO
CREATE DATABASE TP9_Ej3;
GO
USE TP9_Ej3;
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

CREATE TABLE Producto (
    ProductID      INT IDENTITY(1,1) PRIMARY KEY,
    Nombre         VARCHAR(50)   NOT NULL,
    Precio         DECIMAL(10,2) NOT NULL,
    Color          VARCHAR(20)   NOT NULL,
    Stock          INT           NOT NULL,
    ProductModelID INT           NOT NULL,
    FOREIGN KEY (ProductModelID) REFERENCES Modelo(ProductModelID)
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

-- Nombre, Precio, Color, Stock, ProductModelID
INSERT INTO Producto VALUES ('Notebook X1', 850.00, 'ROJO', 10, 2);
INSERT INTO Producto VALUES ('Monitor Z2', 600.00, 'ROJO', 5, 4);
INSERT INTO Producto VALUES ('Teclado K3', 45.00, 'ROJO', 30, 3);
INSERT INTO Producto VALUES ('Mouse M5', 25.00, 'NEGRO', 50, 3);
INSERT INTO Producto VALUES ('Campera T4', 300.00, 'ROJO', 15, 1);
INSERT INTO Producto VALUES ('Auriculares A6', 120.00, 'AZUL', 20, 2);
INSERT INTO Producto VALUES ('Tablet TB7', 700.00, 'ROJO', 8, 1);
INSERT INTO Producto VALUES ('Zapatillas Z9', 90.00, 'VERDE', 40, 4);
INSERT INTO Producto VALUES ('Router R8', 550.00, 'ROJO', 12, 4);
INSERT INTO Producto VALUES ('Impresora I10', 480.00, 'ROJO', 6, 3);
GO

-- OPCION A: TABLA TEMPORAL (#)
CREATE TABLE #TempProductosRojos (Nombre VARCHAR(50), ProductModelID INT);
INSERT INTO #TempProductosRojos SELECT Nombre, ProductModelID FROM Producto WHERE Color = 'ROJO';

SELECT Tmp.Nombre AS NombreProducto, M.Nombre AS NombreModelo
FROM #TempProductosRojos Tmp INNER JOIN Modelo M ON Tmp.ProductModelID = M.ProductModelID;

DROP TABLE #TempProductosRojos;
GO

-- OPCION B: VARIABLE TIPO TABLA (@)
DECLARE @VarProductosRojos TABLE (Nombre VARCHAR(50), ProductModelID INT);
INSERT INTO @VarProductosRojos SELECT Nombre, ProductModelID FROM Producto WHERE Color = 'ROJO';

SELECT Variable.Nombre AS NombreProducto, M.Nombre AS NombreModelo
FROM @VarProductosRojos Variable INNER JOIN Modelo M ON Variable.ProductModelID = M.ProductModelID;
GO

-- OPCION C: TABLA DERIVADA (subquery en FROM)
SELECT ProductoFiltrado.Nombre AS NombreProducto, M.Nombre AS NombreModelo
FROM (SELECT Nombre, ProductModelID FROM Producto WHERE Color = 'ROJO') AS ProductoFiltrado
INNER JOIN Modelo M ON ProductoFiltrado.ProductModelID = M.ProductModelID;
GO
