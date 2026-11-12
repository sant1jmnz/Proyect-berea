USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'TP9_Ej2')
    DROP DATABASE TP9_Ej2;
GO
CREATE DATABASE TP9_Ej2;
GO
USE TP9_Ej2;
GO

-- =======================================================
-- DDL
-- =======================================================
CREATE TABLE Categoria (
    CategoriaID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre      VARCHAR(50) NOT NULL
);
GO

CREATE TABLE Producto (
    ProductID   INT IDENTITY(1,1) PRIMARY KEY,
    Nombre      VARCHAR(50)   NOT NULL,
    Precio      DECIMAL(10,2) NOT NULL,
    Color       VARCHAR(20)   NOT NULL,
    Stock       INT           NOT NULL,
    CategoriaID INT           NOT NULL,
    FOREIGN KEY (CategoriaID) REFERENCES Categoria(CategoriaID)
);
GO

-- =======================================================
-- DML - datos de prueba
-- =======================================================
INSERT INTO Categoria (Nombre) VALUES ('Electronica');
INSERT INTO Categoria (Nombre) VALUES ('Indumentaria');
INSERT INTO Categoria (Nombre) VALUES ('Hogar');
GO

-- Nombre, Precio, Color, Stock, CategoriaID
INSERT INTO Producto VALUES ('Notebook X1', 850.00, 'ROJO', 10, 1);
INSERT INTO Producto VALUES ('Monitor Z2', 600.00, 'NEGRO', 5, 1);
INSERT INTO Producto VALUES ('Campera T4', 300.00, 'ROJO', 15, 2);
INSERT INTO Producto VALUES ('Teclado K3', 45.00, 'ROJO', 30, 1);
INSERT INTO Producto VALUES ('Zapatillas Z9', 90.00, 'VERDE', 40, 2);
INSERT INTO Producto VALUES ('Mouse M5', 25.00, 'NEGRO', 50, 1);
INSERT INTO Producto VALUES ('Tablet TB7', 700.00, 'ROJO', 8, 1);
INSERT INTO Producto VALUES ('Router R8', 550.00, 'ROJO', 12, 1);
INSERT INTO Producto VALUES ('Impresora I10', 480.00, 'ROJO', 6, 1);
INSERT INTO Producto VALUES ('Auriculares A6', 120.00, 'AZUL', 20, 1);
GO

-- OPCION A: TABLA TEMPORAL (#)
-- Guarda la categoria filtrada en una tabla temporal.
CREATE TABLE #TempCategoriaElectronica (CategoriaID INT, Nombre VARCHAR(50));
INSERT INTO #TempCategoriaElectronica
SELECT CategoriaID, Nombre FROM Categoria WHERE Nombre = 'Electronica';

SELECT P.Nombre, P.Precio
FROM Producto P
INNER JOIN #TempCategoriaElectronica C ON P.CategoriaID = C.CategoriaID;

DROP TABLE #TempCategoriaElectronica;
GO

-- OPCION B: VARIABLE TIPO TABLA (@)
DECLARE @VarCategoriaElectronica TABLE (CategoriaID INT, Nombre VARCHAR(50));
INSERT INTO @VarCategoriaElectronica
SELECT CategoriaID, Nombre FROM Categoria WHERE Nombre = 'Electronica';

SELECT P.Nombre, P.Precio
FROM Producto P
INNER JOIN @VarCategoriaElectronica C ON P.CategoriaID = C.CategoriaID;
GO

-- OPCION C: TABLA DERIVADA (subquery en FROM)
SELECT P.Nombre, P.Precio
FROM Producto P
INNER JOIN (
    SELECT CategoriaID, Nombre
    FROM Categoria
    WHERE Nombre = 'Electronica'
) AS C ON P.CategoriaID = C.CategoriaID;
GO
