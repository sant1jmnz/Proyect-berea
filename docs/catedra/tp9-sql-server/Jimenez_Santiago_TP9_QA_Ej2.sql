USE TP9_Ej2;
GO

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
INSERT INTO Producto VALUES ('Smart TV S11', 1200.00, 'NEGRO', 4, 1);
INSERT INTO Producto VALUES ('Parlante P12', 150.00, 'ROJO', 18, 1);
INSERT INTO Producto VALUES ('Cargador C13', 18.00, 'BLANCO', 60, 1);
INSERT INTO Producto VALUES ('Disco Externo D14', 110.00, 'NEGRO', 25, 1);
INSERT INTO Producto VALUES ('Pendrive P15', 12.00, 'AZUL', 80, 1);
INSERT INTO Producto VALUES ('Camara Web C16', 65.00, 'ROJO', 22, 1);
INSERT INTO Producto VALUES ('Webcam Pro C17', 95.00, 'NEGRO', 14, 1);
INSERT INTO Producto VALUES ('Pantalla P18', 680.00, 'ROJO', 7, 1);
INSERT INTO Producto VALUES ('Jean J19', 48.00, 'AZUL', 35, 2);
INSERT INTO Producto VALUES ('Remera R20', 15.00, 'BLANCO', 70, 2);
INSERT INTO Producto VALUES ('Buzo B21', 32.00, 'GRIS', 28, 2);
INSERT INTO Producto VALUES ('Gorra G22', 12.00, 'NEGRO', 45, 2);
INSERT INTO Producto VALUES ('Campera Inv C23', 120.00, 'ROJO', 16, 2);
INSERT INTO Producto VALUES ('Pantalon P24', 55.00, 'MARRON', 20, 2);
INSERT INTO Producto VALUES ('Bufanda B25', 20.00, 'ROJO', 33, 2);
INSERT INTO Producto VALUES ('Medias M26', 8.00, 'NEGRO', 90, 2);
INSERT INTO Producto VALUES ('Cinturon C27', 18.00, 'MARRON', 40, 2);
INSERT INTO Producto VALUES ('Camisa C28', 38.00, 'AZUL', 27, 2);
INSERT INTO Producto VALUES ('Silla S29', 75.00, 'NEGRO', 19, 3);
INSERT INTO Producto VALUES ('Lampara L30', 42.00, 'BLANCO', 24, 3);
INSERT INTO Producto VALUES ('Alfombra A31', 95.00, 'ROJO', 9, 3);
INSERT INTO Producto VALUES ('Cortina C32', 30.00, 'AZUL', 16, 3);
INSERT INTO Producto VALUES ('Espejo E33', 60.00, 'GRIS', 11, 3);
INSERT INTO Producto VALUES ('Florero F34', 22.00, 'ROJO', 30, 3);
INSERT INTO Producto VALUES ('Cofre C35', 48.00, 'MARRON', 13, 3);
INSERT INTO Producto VALUES ('Reloj Pared R36', 35.00, 'NEGRO', 21, 3);
INSERT INTO Producto VALUES ('Almohada A37', 18.00, 'BLANCO', 55, 3);
INSERT INTO Producto VALUES ('Mantel M38', 25.00, 'ROJO', 38, 3);
INSERT INTO Producto VALUES ('Juego Vajilla J39', 140.00, 'BLANCO', 10, 3);
INSERT INTO Producto VALUES ('Set Cubiertos S40', 65.00, 'GRIS', 17, 3);
GO

SELECT P.Nombre, P.Precio
FROM Producto P
INNER JOIN Categoria C ON P.CategoriaID = C.CategoriaID
WHERE C.Nombre = 'Electronica';
GO

DECLARE @VarCategoriaElectronica TABLE (CategoriaID INT, Nombre VARCHAR(50));
INSERT INTO @VarCategoriaElectronica
SELECT CategoriaID, Nombre FROM Categoria WHERE Nombre = 'Electronica';

SELECT P.Nombre, P.Precio
FROM Producto P
INNER JOIN @VarCategoriaElectronica C ON P.CategoriaID = C.CategoriaID;
GO

(
    SELECT P.Nombre, P.Precio
    FROM Producto P
    INNER JOIN Categoria C ON P.CategoriaID = C.CategoriaID
    WHERE C.Nombre = 'Electronica'
)
EXCEPT
(
    SELECT P.Nombre, P.Precio
    FROM Producto P
    INNER JOIN (SELECT CategoriaID, Nombre FROM Categoria WHERE Nombre = 'Electronica') C
        ON P.CategoriaID = C.CategoriaID
);
GO
