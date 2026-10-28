# BBDD 006: conectar un gestor de bases de datos al lenguaje C

Resumen del PPT "006 - BBDD - CONECTAR GESTOR CON C" del Prof. Pablo Linares
(4° 1ra, Ciclo Lectivo 2026) y de sus ejemplos. Los archivos de ejemplo están
en [`ejemplos-conexion-c-mysql/`](ejemplos-conexion-c-mysql/) (la contraseña
del laboratorio se reemplazó por `TU_CLAVE`).

## Parte 01: preparar Ubuntu

- Instalar la librería de desarrollo del cliente de MySQL, que trae la
  cabecera `mysql.h`, y verificar que el servidor MySQL esté funcionando.

## Parte 02: usar MySQL desde un cliente (Workbench o DBeaver)

1. Conectarse al gestor (usuario y contraseña del laboratorio) y crear la base
   con `CREATE DATABASE IF NOT EXISTS ...` (`IF NOT EXISTS` evita el error si
   ya existe).
2. Un **stored procedure** se crea con `DELIMITER //` ... `END //` y se vuelve
   al delimitador normal con `DELIMITER ;`. Se ejecuta con `CALL`.
3. **Manejo de errores** dentro del SP (`script04.sql` y `script07.sql`):
   - `DECLARE EXIT HANDLER FOR SQLEXCEPTION`: atrapa cualquier error de SQL,
     ejecuta su bloque y **sale del SP** sin seguir con el resto.
   - Dentro del handler, `GET DIAGNOSTICS CONDITION 1` carga en variables el
     número (`MYSQL_ERRNO`) y el mensaje (`MESSAGE_TEXT`) del error.
   - El SP devuelve entonces una fila `'ERROR'`, el código y la descripción.
4. **Parámetros**: `CREATE PROCEDURE sp_obtener_alumnos_Fecha(fechaInicio DATE, fechaFin DATE)`
   con un `WHERE fechaNacimiento BETWEEN fechaInicio AND fechaFin`
   (`BETWEEN` también sirve para números).

## Parte 03: conectar C/C++ con MySQL

Compilación: `g++ ejemplobd01.cpp -o ejemplobd01 -lmysqlclient`.

| Función | Para qué sirve |
|---|---|
| `mysql_init()` | Inicializa el puntero y crea la instancia de conexión. |
| `mysql_real_connect()` | Abre la sesión de red con el servidor (host, usuario, contraseña, base, puerto). |
| `mysql_query()` | Envía una instrucción SQL (en texto) al servidor: `SELECT`, `INSERT` o `CALL`. Devuelve 0 si salió bien. |
| `mysql_store_result()` | Baja a la memoria del programa todo el resultado de un `SELECT` o `CALL`. |
| `mysql_fetch_row()` | Saca la fila siguiente del resultado. |
| `mysql_free_result()` | Libera la memoria que reservó la librería. |
| `mysql_close()` | Cierra la conexión. |

Ejemplos:

- `ejemplobd01.cpp`: conecta y recorre un `SELECT`.
- `ejemplobd02.cpp`: `INSERT` con datos escritos a mano (ojo con las comillas).
- `ejemplobd03.cpp`: ejecuta un SP con `CALL`.
- `ejemplobd04.cpp`: SP con parámetros (rango de fechas armado en el `CALL`).

## Notas para el proyecto

- **El proyecto usa esta forma de conectarse** (`mysql.h`), no `QSqlDatabase`.
  La implementación está en `frontend/comun/basedatos.{h,cpp}`; ver
  [`../conexion-base.md`](../conexion-base.md).
- Los ejemplos ponen host, usuario y contraseña dentro del código. En el
  proyecto salen de variables de entorno o de `dermalia.ini` para poder
  cambiar entre el MySQL local y Aiven sin recompilar, y sin subir la
  contraseña al repositorio.
- Los ejemplos arman el `CALL` pegando texto. Con datos escritos por una
  persona eso es inseguro (una comilla rompe la consulta o permite
  inyección SQL), por eso `BaseDatos::llamar` escapa cada parámetro.
- El formato de error del PPT (`'ERROR'`, código, descripción) es el que
  usan todos los SP del proyecto y el que `BaseDatos` reconoce.
- `script04.sql` tiene un error de tipeo del original: dice
  `USE Cuarto_Anio_2026;` y la base se creó como `CuartoAnio_2026`.
