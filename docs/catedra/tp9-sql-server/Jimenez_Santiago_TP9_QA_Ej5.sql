USE TP9_Ej5;
GO

INSERT INTO Producto VALUES ('Notebook X1', 850.00, 'ROJO', 2, 1, 1);
INSERT INTO Producto VALUES ('Monitor Z2', 600.00, 'ROJO', 4, 3, 3);
INSERT INTO Producto VALUES ('Teclado K3', 45.00, 'ROJO', 3, 1, 1);
INSERT INTO Producto VALUES ('Campera T4', 300.00, 'ROJO', 1, 2, 4);
INSERT INTO Producto VALUES ('Mouse M5', 25.00, 'NEGRO', 3, 1, 1);
INSERT INTO Producto VALUES ('Auriculares A6', 120.00, 'AZUL', 2, 1, 2);
INSERT INTO Producto VALUES ('Tablet TB7', 700.00, 'ROJO', 2, 4, 1);
INSERT INTO Producto VALUES ('Router R8', 550.00, 'ROJO', 4, 3, 5);
INSERT INTO Producto VALUES ('Zapatillas Z9', 90.00, 'VERDE', 1, 4, 2);
INSERT INTO Producto VALUES ('Impresora I10', 480.00, 'ROJO', 3, 1, 3);
INSERT INTO Producto VALUES ('Smart TV S11', 1200.00, 'ROJO', 2, 3, 1);
INSERT INTO Producto VALUES ('Parlante P12', 150.00, 'ROJO', 1, 1, 4);
INSERT INTO Producto VALUES ('Cargador C13', 18.00, 'BLANCO', 3, 3, 3);
INSERT INTO Producto VALUES ('Disco Externo D14', 700.00, 'ROJO', 2, 1, 5);
INSERT INTO Producto VALUES ('Pendrive P15', 12.00, 'AZUL', 3, 3, 1);
INSERT INTO Producto VALUES ('Camara Web C16', 650.00, 'ROJO', 1, 1, 3);
INSERT INTO Producto VALUES ('Webcam Pro C17', 95.00, 'NEGRO', 2, 3, 2);
INSERT INTO Producto VALUES ('Pantalla P18', 680.00, 'ROJO', 4, 1, 1);
INSERT INTO Producto VALUES ('Jean J19', 48.00, 'AZUL', 1, 2, 4);
INSERT INTO Producto VALUES ('Remera R20', 15.00, 'BLANCO', 3, 2, 2);
INSERT INTO Producto VALUES ('Buzo B21', 32.00, 'GRIS', 1, 2, 4);
INSERT INTO Producto VALUES ('Gorra G22', 12.00, 'NEGRO', 3, 4, 2);
INSERT INTO Producto VALUES ('Notebook Pro N23', 980.00, 'ROJO', 2, 1, 5);
INSERT INTO Producto VALUES ('Pantalon P24', 55.00, 'MARRON', 1, 2, 4);
INSERT INTO Producto VALUES ('Bufanda B25', 20.00, 'ROJO', 4, 2, 2);
INSERT INTO Producto VALUES ('Medias M26', 8.00, 'NEGRO', 3, 4, 2);
INSERT INTO Producto VALUES ('Cinturon C27', 18.00, 'MARRON', 1, 2, 4);
INSERT INTO Producto VALUES ('Camisa C28', 38.00, 'AZUL', 2, 2, 2);
INSERT INTO Producto VALUES ('Router Pro R29', 720.00, 'ROJO', 4, 3, 3);
INSERT INTO Producto VALUES ('Mancuernas M30', 55.00, 'NEGRO', 3, 4, 4);
INSERT INTO Producto VALUES ('Bicicleta B31', 900.00, 'ROJO', 4, 4, 4);
INSERT INTO Producto VALUES ('Tablet Max T32', 820.00, 'ROJO', 4, 1, 1);
INSERT INTO Producto VALUES ('Raqueta R33', 62.00, 'ROJO', 2, 4, 2);
INSERT INTO Producto VALUES ('Monitor Pro M34', 950.00, 'ROJO', 2, 3, 5);
INSERT INTO Producto VALUES ('Tablet Lite T35', 380.00, 'ROJO', 3, 3, 1);
INSERT INTO Producto VALUES ('Mouse Gamer M36', 40.00, 'ROJO', 4, 1, 3);
INSERT INTO Producto VALUES ('Teclado Mec T37', 520.00, 'ROJO', 2, 1, 3);
INSERT INTO Producto VALUES ('Zapatillas Run Z38', 88.00, 'ROJO', 1, 4, 4);
INSERT INTO Producto VALUES ('Campera Dep C39', 105.00, 'ROJO', 3, 2, 2);
INSERT INTO Producto VALUES ('Monitor Curvo M40', 920.00, 'ROJO', 4, 3, 1);
GO

SELECT P.Nombre, M.Nombre, C.Nombre, Pr.RazonSocial
FROM Producto P
INNER JOIN Modelo M ON P.ProductModelID = M.ProductModelID
INNER JOIN Categoria C ON P.ProductCategoryID = C.ProductCategoryID
INNER JOIN Proveedor Pr ON P.ProveedorID = Pr.ProveedorID
WHERE P.Color = 'ROJO' AND P.Precio > 500 AND C.Tipo = 'TECNOLOGIA' AND Pr.Ciudad = 'Buenos Aires';
GO

SELECT ProductoFiltrado.Nombre AS NombreProducto, M.Nombre AS NombreModelo, CF.Nombre AS NombreCategoria, PV.RazonSocial
FROM (
    SELECT Nombre, ProductModelID, ProductCategoryID, ProveedorID
    FROM Producto
    WHERE Color = 'ROJO' AND Precio > 500
) AS ProductoFiltrado
INNER JOIN Modelo M ON ProductoFiltrado.ProductModelID = M.ProductModelID
INNER JOIN (SELECT ProductCategoryID, Nombre FROM Categoria WHERE Tipo = 'TECNOLOGIA') AS CF
    ON ProductoFiltrado.ProductCategoryID = CF.ProductCategoryID
INNER JOIN (SELECT ProveedorID, RazonSocial FROM Proveedor WHERE Ciudad = 'Buenos Aires') AS PV
    ON ProductoFiltrado.ProveedorID = PV.ProveedorID;
GO

(
    SELECT P.Nombre, M.Nombre, C.Nombre, Pr.RazonSocial
    FROM Producto P
    INNER JOIN Modelo M ON P.ProductModelID = M.ProductModelID
    INNER JOIN Categoria C ON P.ProductCategoryID = C.ProductCategoryID
    INNER JOIN Proveedor Pr ON P.ProveedorID = Pr.ProveedorID
    WHERE P.Color = 'ROJO' AND P.Precio > 500 AND C.Tipo = 'TECNOLOGIA' AND Pr.Ciudad = 'Buenos Aires'
)
EXCEPT
(
    SELECT ProductoFiltrado.Nombre, M.Nombre, CF.Nombre, PV.RazonSocial
    FROM (SELECT Nombre, ProductModelID, ProductCategoryID, ProveedorID FROM Producto WHERE Color = 'ROJO' AND Precio > 500) AS ProductoFiltrado
    INNER JOIN Modelo M ON ProductoFiltrado.ProductModelID = M.ProductModelID
    INNER JOIN (SELECT ProductCategoryID, Nombre FROM Categoria WHERE Tipo = 'TECNOLOGIA') AS CF
        ON ProductoFiltrado.ProductCategoryID = CF.ProductCategoryID
    INNER JOIN (SELECT ProveedorID, RazonSocial FROM Proveedor WHERE Ciudad = 'Buenos Aires') AS PV
        ON ProductoFiltrado.ProveedorID = PV.ProveedorID
);
GO
