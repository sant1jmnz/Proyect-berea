# Cómo se trabaja en SQL (metodología de Bases de Datos)

Resumen de la carpeta de la materia **Bases de Datos 2026** (docente Pablo Linares, 4° 1ª CT) y
de los scripts de **profundización 02** de Santiago Jiménez (dataset BradFit). Sirve de guía
para escribir y defender el backend de Dermalia. Los archivos originales están en el release
[`material-catedra`](https://github.com/sant1jmnz/Proyect-berea/releases/tag/material-catedra);
los scripts de profundización 02 están en [`catedra/profundizacion-02/`](catedra/profundizacion-02/).

> La cátedra enseña **SQL Server (T-SQL)**. Solo el PPT 006 usa MySQL. El proyecto es **MySQL 8**:
> la tabla de equivalencias está al final.

## 1. Orden de trabajo

1. Diseño conceptual (Peter Chen) y lógico (Edgar Codd), normalizado en 3FN.
2. Implementación dividida en **schemas** (en MySQL, cada schema es una base de datos).
3. Datos de ejemplo con `INSERT`.
4. Consultas y stored procedures.
5. Pruebas documentadas con la plantilla `Template_Test_Case_BD.xlsx`.

Regla de la rúbrica: sin claves primarias no se corrige la fase de implementación. Sin diseño
previo (solo SQL) el ítem de coherencia global se evalúa en 0.

## 2. Normalización y modelado

- **1FN:** valores atómicos, sin grupos repetitivos ni listas separadas por comas.
- **2FN:** todo atributo no clave depende de la clave completa.
- **3FN:** sin dependencias transitivas (un atributo no clave no depende de otro no clave).
- Un dato categorizable o multivaluado es una **tabla**, no una columna (los rangos de
  refrigeración de una morgue son información, no estructura).
- Las relaciones N:M se resuelven con tabla intermedia. Una relación no conecta con otra relación.
- Total de venta, edad y similares **se calculan en una consulta**, no se guardan.
- Se usan autoincrementales (`AUTO_INCREMENT`), no ids insertados a mano.

## 3. Estilo del código SQL (lo que penaliza la rúbrica)

| Regla | Penalización |
|---|---|
| Comentar qué hace cada consulta | −0,5 |
| Nombres claros (nada de `tabla1` o `columnaA`) | −1,0 |
| El script corre "de un tirón", sin arreglar comas ni nombres | −1,5 |
| No usar `SELECT *`; listar las columnas | observación del docente |
| Nombrar las tablas con su schema (`personas.Paciente`) | observación del docente |

Convenciones de los ejemplos: alias siempre con `AS`; columnas calculadas con alias; palabras
clave en mayúscula; una cláusula por línea; encabezado con la pregunta de negocio.

## 4. Consultas: el orden en que se ejecutan

```
FROM (JOIN) -> WHERE -> GROUP BY -> HAVING -> SELECT -> ORDER BY
```

- `WHERE` filtra **filas** antes de agrupar y no admite funciones de agregación.
- `HAVING` filtra **grupos** después de agrupar.
- `COUNT(*)` cuenta filas; `COUNT(columna)` no cuenta los `NULL`. La resta de ambos mide datos
  incompletos (ejemplo: planes sin suscripción tras un `LEFT JOIN`).
- `LEFT JOIN` + comprobar `NULL` sirve para la **auditoría de registros huérfanos**.
- Subconsultas: escalar (`> (SELECT AVG(...))`), de lista (`IN`, `ANY`, `ALL`) y correlacionadas
  con `EXISTS` (devuelve verdadero o falso, y es la forma más eficiente de verificar existencia).
- Conjuntos: `UNION` (quita duplicados, ordena), `UNION ALL` (más rápido), `INTERSECT`, `EXCEPT`.
  Las dos consultas deben tener el mismo número y tipo de columnas.
- Vistas: no llevan `ORDER BY` (salvo `TOP`); las columnas agregadas llevan alias; para
  protegerlas de cambios de tabla se usa `WITH SCHEMABINDING` (SQL Server).
- No usar `*` en consultas de producción.

## 5. Optimización: del Caracol al Cheetah

La profundización 02 compara la misma consulta de cinco maneras. Es la técnica del PPT 004
(álgebra relacional y árboles de ejecución):

1. **Caracol:** consulta directa; junta todas las tablas completas y filtra al final.
2. **Cheetah A, tablas temporales (`#N1`, `#N2`…):** primero se filtra (σ, selección) y se
   proyecta (π, solo las columnas necesarias) cada tabla; después se hacen los JOIN de a dos
   (`#J1`, `#J2`…); al final se agrupa (`#G`) y se aplica el filtro de grupo.
3. **Cheetah B, variables de tipo tabla (`@N1`…):** igual que A, pero sin tocar `tempdb`.
   Son la opción ideal dentro de un stored procedure.
4. **Cheetah C, subconsultas anidadas (tablas derivadas en línea):** el mismo árbol escrito
   en una sola sentencia.
5. **Producción:** la consulta limpia, con comentarios y `ORDER BY`.

Pasos que se repiten en todos los casos:

- **Selección conmutativa:** los filtros `WHERE` van lo más cerca posible de la tabla de origen,
  así llegan menos filas al JOIN.
- **Proyección conmutativa:** cada tabla aporta solo las columnas que se van a usar.
- **Reunión conmutativa:** se unen primero las relaciones que se emparejan entre sí.
- Cada paso informa su cantidad de filas (`PRINT ... @@ROWCOUNT`) para comparar los tamaños.

Por qué las temporales no son lo ideal: se crean en `tempdb` y generan bloqueos en todo el
servidor, hay que borrarlas, y dentro de un procedimiento hacen perder el plan compilado.

Otras vías de performance (se ven más adelante en la materia): índices, vistas materializadas,
planes de ejecución, configuración del servidor y hardware.

## 6. Manejo de errores y auditoría

**SQL Server (PPT 003):** `BEGIN TRY ... END TRY BEGIN CATCH ... END CATCH`, con
`ERROR_NUMBER()` y `ERROR_MESSAGE()`. `@@ROWCOUNT` informa cuántas filas afectó la última
sentencia (valida que un `UPDATE` encontró datos). `SYSTEM_USER`, `GETDATE()` y `DB_NAME()`
estampan quién, cuándo y dónde. `ISNULL` y `COALESCE` reemplazan los `NULL`. `RAISERROR` crea
errores propios (número 50000 por defecto).

**MySQL (PPT 006)**, patrón de todo stored procedure:

```sql
DROP PROCEDURE IF EXISTS sp_nombre;
DELIMITER //
CREATE PROCEDURE sp_nombre(parametros)
BEGIN
    DECLARE codigo_error INT DEFAULT 0;
    DECLARE mensaje_error VARCHAR(255) DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            codigo_error = MYSQL_ERRNO, mensaje_error = MESSAGE_TEXT;
        SELECT 'ERROR' AS estado, codigo_error AS codigo_sql, mensaje_error AS descripcion_error;
    END;

    -- código principal
END //
DELIMITER ;
```

`EXIT` corta el procedimiento al primer error; `SQLEXCEPTION` atrapa cualquier error SQL.

## 7. Pruebas

Plantilla de la cátedra (`Template_Test_Case_BD.xlsx`): ID de escenario, escenario de prueba,
ID de caso, caso, precondición, pasos, datos de prueba, resultado esperado, postcondición,
resultado real, estado (aprobado o falló) y severidad. La consigna pide cuatro casos por SP:
éxito, sin coincidencias, parámetros nulos o límite, y equivalencia con un `SELECT` directo.

## 8. Equivalencias SQL Server → MySQL

| SQL Server (material) | MySQL 8 (proyecto) |
|---|---|
| `TRY ... CATCH` | `DECLARE EXIT HANDLER FOR SQLEXCEPTION` + `GET DIAGNOSTICS` |
| `RAISERROR` | `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = ...` |
| `@@ROWCOUNT` | `ROW_COUNT()` |
| `GETDATE()` | `NOW()` |
| `SYSTEM_USER` | `CURRENT_USER()` o `USER()` |
| `ISNULL(a, b)` | `IFNULL(a, b)` (`COALESCE` es igual) |
| `SELECT TOP 10` | `LIMIT 10` |
| `#tabla` (temporal) | `CREATE TEMPORARY TABLE` |
| `DECLARE @t TABLE (...)` | **no existe**: usar tabla temporal o tabla derivada |
| `PRINT` | `SELECT` |
| `EXCEPT` | no existe en MySQL 5.7; en 8.0.31 o posterior sí |
| `schema.tabla` | `base.tabla` (cada schema es una base de datos) |

## 9. Qué puede usar el backend de Dermalia

Regla del equipo: solo lo que está en las clases (presentaciones con sus imágenes, scripts de la cátedra
y los scripts propios de profundización 02) y lo que pide la consigna. El libro *Fundamentos de SQL* de la
carpeta no se usó en clase, así que **no cuenta**. Se aceptan además:

- **`CHECK`, `UNIQUE` y `DATE`**, que el equipo ya usó en sus trabajos.
- **El equivalente en MySQL de algo que está en las clases** (que son de SQL Server): `SIGNAL` por
  `RAISERROR`, `CONCAT` por unir textos con `+`, `LIMIT` por `TOP`, `NOW()` por `GETDATE()`,
  `CHAR_LENGTH` por `LEN`, `IFNULL` por `ISNULL`, `ROW_COUNT()` por `@@ROWCOUNT`, `CREATE TEMPORARY TABLE`
  por `#tabla`, `DIV` por la división entera de SQL Server, `START TRANSACTION`/`COMMIT`/`ROLLBACK`.
- **Funciones de fecha** (`INTERVAL`, `EXTRACT`, `DATE_FORMAT`): la consigna pide "gestión de fechas".

Por eso el backend **no usa** `IF`, `CASE`, `WHILE`, `LOOP`, cursores, `LEAVE`, `FOR UPDATE`,
`CREATE FUNCTION` ni funciones de texto (salvo `CHAR_LENGTH`). Cómo se reemplazó cada cosa está en
[`12-contrato-sp.md`](12-contrato-sp.md): las validaciones se escriben con `COALESCE` y subconsultas, los
cambios llevan `WHERE ... AND v_codigo IS NULL` y la respuesta se arma con `UNION ALL`.

### Estilo de los reportes (scripts 05 y 06)

Los reportes y sus versiones `_tuneado` se escriben como los scripts de la cátedra (TP9 y profundización 02):
una pregunta de negocio por consulta, `INNER JOIN` / `LEFT JOIN`, alias siempre con `AS`, una cláusula por
línea, tablas derivadas en el `FROM` y `CASE WHEN` dentro de `SUM(...)` para contar por estado (en lugar de
sumar comparaciones o simular el `CASE` con `SELECT ... FROM DUAL`). Los cuatro scripts de TP9 en SQL Server
(Prod y QA, ejercicios 2 a 5) están en [`catedra/tp9-sql-server/`](catedra/tp9-sql-server/).
