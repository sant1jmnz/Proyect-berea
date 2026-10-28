# Conexión de la aplicación a la base de datos

Cómo se conecta el frontend (C++/Qt) a MySQL, al estilo de la cátedra
([`catedra/bbdd-006-conectar-c-con-mysql.md`](catedra/bbdd-006-conectar-c-con-mysql.md)).
La base y los stored procedures todavía no existen (Bases de Datos arranca
después): hoy la aplicación trabaja con **datos de prueba** y esta capa deja
resuelto el resto.

## Dónde está el código

| Archivo (`frontend/comun/`) | Qué hace |
|---|---|
| `basedatos.h/.cpp` | Conexión con `mysql.h` (`mysql_init`, `mysql_real_connect`, `mysql_query`, `mysql_store_result`). `llamar("sp", {params})` arma el `CALL`, escapa cada dato y devuelve las filas por nombre de columna. |
| `contingencia.h/.cpp` | Turnos guardados en este equipo cuando no hay base (archivo `pendientes.json` en la carpeta de datos de la aplicación). |
| `avisoconexion.h/.cpp` | Franja amarilla "sin conexión con la base de datos" con botón *Reintentar*. |
| `conexionapp.h/.cpp` | Junta las tres cosas; lo usan Gestión y Cliente. |

## Qué ve el usuario (RNF-09)

- Si la app no llega a la base, aparece una **franja arriba de la ventana**
  con el motivo en español (servidor apagado, sin internet, usuario o
  contraseña incorrectos, SSL, etc.) y avisa que se trabaja en **modo
  contingencia**.
- En ese modo, cada turno confirmado se guarda en el equipo como *pendiente
  de sincronizar* y la franja cuenta cuántos hay.
- Con *Reintentar* se vuelve a conectar. Si hay pendientes, avisa que faltan
  enviarlos.
- **Pendiente:** el envío de los turnos guardados a la base se hace cuando
  existan los stored procedures de alta de turno; hoy solo se guardan y se
  cuentan.

## Configuración

Los datos de conexión no van en el código ni en el repositorio. Se leen de
**variables de entorno** o de un archivo `dermalia.ini` junto al ejecutable
(se copia de [`frontend/dermalia.ini.ejemplo`](../frontend/dermalia.ini.ejemplo);
`dermalia.ini` está en `.gitignore`). Las variables tienen prioridad.

| Variable | Ini (`[base]`) | Valor |
|---|---|---|
| `DERMALIA_DB_HOST` | `host` | `127.0.0.1` (local) o el host que da Aiven |
| `DERMALIA_DB_PORT` | `puerto` | `3306` (local) o el puerto de Aiven |
| `DERMALIA_DB_USER` | `usuario` | `root` (local) o `avnadmin` (Aiven) |
| `DERMALIA_DB_PASS` | `clave` | la contraseña |
| `DERMALIA_DB_NAME` | `base` | opcional: los SP pueden llevar el schema (`gestion.sp_...`) |
| `DERMALIA_DB_SSL` | `ssl` | `1` en Aiven (exige conexión cifrada), vacío en local |

Sin usuario configurado no se intenta conectar: la franja avisa que falta
configurar.

## Compilar con el cliente de MySQL

```bash
sudo apt install libmysqlclient-dev   # en Ubuntu también sirve libmariadb-dev
cd frontend && cmake -B build && cmake --build build
```

Si CMake no encuentra la librería, la aplicación igual compila y corre con
datos de prueba, avisando que se compiló sin el cliente de MySQL.

## Convención de los stored procedures

La misma de la cátedra (PPT 006): ante un error, un `EXIT HANDLER` devuelve
una fila `estado = 'ERROR'`, `codigo_sql`, `descripcion_error`. `BaseDatos`
la reconoce y devuelve `Resultado.ok = false` con el mensaje listo para
mostrar. Los SP que modifican datos devuelven `estado = 'OK'`.

## Pruebas

```bash
cd frontend/build
QT_QPA_PLATFORM=offscreen ctest --output-on-failure
```

`prueba_gestion` cubre el escape de datos, los mensajes de error, la lectura
de la configuración, el modo contingencia y la franja de aviso, sin necesidad
de una base real.
