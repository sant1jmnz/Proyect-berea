# Revisión del script de tablas

Revisión de `codigobasededatossolotablas.sql` (la versión que subió Bautista)
contra la consigna (`docs/consigna-bbdd.md`) y el modelo
(`docs/modelo-entidades.md`). El script ya estaba muy bien encaminado: las 27
entidades más las 2 tablas N:M, los teléfonos como tabla aparte (multivaluado,
punto 1b), las FK con nombre, los CHECK de precios y porcentajes, y la relación
circular Turno ↔ Evaluación previa cerrada con un `ALTER TABLE`. Se mantuvieron
los nombres de tablas, columnas y constraints.

## Cómo probarlo

```
mysql -u root -p < backend/codigobasededatossolotablas.sql
mysql -u root -p < backend/pruebas_estructura.sql
```

El segundo script prueba 44 casos (26 que tienen que entrar, incluida la lectura de tildes, y
18 inválidos que tienen que rebotar) y al final deshace todo: las tablas quedan
vacías. Resultado en MySQL 8.0.46: **44 de 44 OK**, y el script de tablas se
puede correr dos veces seguidas sin errores.

## Qué se cambió

| # | Cambio | Por qué |
|---|---|---|
| 1 | **9 schemas reales** (`seguridad`, `personas`, `clinica`, `agenda`, `pagos`, `beneficios`, `notificaciones`, `auditoria`, `asistente`) en vez de una base `Proyecto1` con prefijos. Las tablas pasan de `agenda_Turno` a `agenda.Turno`. | La consigna (3c) pide el modelo dividido en schemas. En MySQL un schema es una base: `CREATE SCHEMA` y `CREATE DATABASE` son lo mismo, y las FK cruzan schemas sin problema. |
| 2 | El borrado inicial pasó a `DROP DATABASE` con `FOREIGN_KEY_CHECKS = 0`. | La segunda vez que se corría fallaba (error 3730): por la FK circular no hay orden de `DROP TABLE` que funcione. |
| 3 | `SET NAMES utf8mb4` y schemas en `utf8mb4`. | Para que tildes y eñes se guarden y se lean bien desde cualquier cliente. |
| 4 | `UNIQUE` en `pagos.PagoSena.id_turno`. | El modelo dice un pago de seña por turno. |
| 5 | `UNIQUE` en `beneficios.Cupon.id_turno`. | Cupón (0,1) — Turno (0,1): un turno no puede usar dos cupones. |
| 6 | `UNIQUE` en `clinica.EvaluacionPrevia.id_turno`. | Un turno de consulta genera a lo sumo una evaluación. |
| 7 | `UNIQUE` en `id_usuario` de `Paciente` y de `Profesional`. | Si no, dos personas podían compartir la misma cuenta. |
| 8 | CHECK `CK_Notificacion_Destinatario`. | El modelo pide "paciente o profesional, exactamente uno". |
| 9 | `MovimientoTarjeta.monto <> 0` (antes `> 0`). | El modelo dice que el monto negativo es una devolución de saldo. |
| 10 | `vigencia_semanas BETWEEN 2 AND 8` (antes `> 0`) y `ventana_dias > 0`. | El modelo fija la vigencia de los cupones entre 2 y 8 semanas. |
| 11 | `fecha_nacimiento` pasó a `DATE`. | No hace falta la hora. |
| 12 | `Disponibilidad`: `fecha DATE`, `hora_inicio` y `hora_fin` `TIME`, con CHECK de que termine después de empezar. | Antes eran tres `DATETIME` y la fecha se repetía tres veces. |
| 13 | `CHECK (x IN (0, 1))` en todos los sí/no (`activo`, `activa`, `derivada`, `exitoso`, `requiere_evaluacion`). | `TINYINT` acepta de -128 a 127. |
| 14 | `UNIQUE (id_paciente, telefono)` y lo mismo para profesional. | No repetir el mismo número dos veces. |
| 15 | CHECK de fechas en `TarjetaRegalo` y `Cupon` (vence después de comprarse o emitirse) y `monto_reembolsado <= monto` en `PagoSena`. | Datos imposibles que conviene frenar en la base. |

## Lo que queda para los stored procedures

No se pueden (o no conviene) resolver con restricciones de tabla; van en los SP
y en sus pruebas:

- Un turno tiene **al menos un protocolo** (`TurnoProtocolo`).
- **No superponer turnos** del mismo profesional ni salir de su
  `Disponibilidad` (RF-04).
- **Cupón y tarjeta de regalo no van juntos** en el mismo turno.
- Una cuenta es de una paciente **o** de un profesional, no de los dos.
- Sin evaluación "apta" vigente (6 meses) no se agenda una cirugía.
- El log se llena solo desde los SP (consigna 4c).

Los **índices** para los reportes (por ejemplo `agenda.Turno(fecha_hora_inicio)`
o `(id_profesional, fecha_hora_inicio)`) conviene dejarlos para el punto 5e
(tuning), así se puede mostrar la diferencia entre el SP original y el
`_tuneado`.

## Ojo con la versión de MySQL

Los `CHECK` se respetan desde **MySQL 8.0.16**. En MySQL 5.7 se aceptan pero se
ignoran, así que en una PC de laboratorio vieja las pruebas inválidas
"pasarían". Aiven usa MySQL 8, así que ahí funcionan.
