# Proyecto Informático I – Base de Datos

**Actividad Cuatrimestral:** "Software de Gestión/Escritorio respaldado por un Análisis de Competencia"
**Sección:** BASES DE DATOS
**Docentes:** Pablo Linares – Cynthia Berea · 4to 1ra · Ciclo Lectivo 2026

## Consigna general

En el marco del trabajo integrador final, en el cual deberán aplicar conocimientos adquiridos en Bases de Datos, como así también en otras asignaturas de la especialidad, a través del espacio dado en Proyecto Informático I, se requieren las siguientes actividades "Backend" para los proyectos de desarrollo:

1. Diseño Conceptual de la BBDD (Peter Chen).
2. Diseño Lógico de la BBDD (Edgar Codd).
3. Implementación del modelo en Base de Datos Relacional (se sugiere MySQL por cuestiones operativas respecto del equipamiento de los laboratorios).
4. Poblar el modelo con datos.
5. Implementación de funcionalidades en lenguaje SQL.
6. Documentación de pruebas.

## 1. Diseño Conceptual de la BBDD (Peter Chen)

a. Se requieren un mínimo de **13 (trece) entidades**. Las relaciones no cuentan como tales.
b. Todo atributo que represente un dato categorizable o que pueda tomar múltiples valores deberá ser modelado según corresponda (ya sea como atributo multivaluado o como una entidad independiente/tabla maestra).
c. Incluir cardinalidades.
d. Anexo a lo que el proyecto requiera, se debe incluir un modelo de **"logs"**. Un log es un evento que se genera por las acciones del usuario. Por ejemplo, en un "inicio de sesión", los datos a guardar son el tipo de evento, la fecha y la hora del suceso, el usuario implicado, y otros datos relevantes para "auditorías".

## 2. Diseño Lógico de la BBDD (Edgar Codd)

a. Debe ser coherente con lo diseñado en el punto anterior.
b. Debe ser normalizado en **3FN**.
c. Las relaciones deben tener los conectores adecuados según cardinalidades.

## 3. Implementación del modelo en Base de Datos Relacional

a. El modelo debe reflejar estrictamente lo diseñado previamente.
b. Realizar todas las restricciones referenciales necesarias.
c. Generar el modelo dividido en **schemas**. La cantidad de schemas dependerá del diseño y requerimientos que cada desarrollo posee.

## 4. Poblar el modelo con datos

a. Incorporar, al menos, **50 (cincuenta) registros** en la tabla principal del sistema.
b. Poblar las restantes tablas con **20 o más registros** en cada caso.
c. El modelo relativo a "Logs" **no** se debe completar "a mano", sino que se poblará dinámicamente mediante la ejecución de los Stored Procedures desarrollados para tal fin a medida que los eventos sucedan.

## 5. Implementación de funcionalidades en lenguaje SQL

a. Realizar las funcionalidades que resuelvan los requerimientos dados en el proyecto.
b. Dichas funcionalidades deberán ser resueltas a través de **Stored Procedures**.
c. Agregar una serie de stored procedures que resuelvan reportes de distinta índole sobre aspectos relevantes del proyecto (realizar al menos **8 reportes**). En todos los casos deben aplicar la utilización de funciones de agrupamiento, reuniones y gestión de fechas.
d. Agregar un stored procedure que permita, mediante distintos parámetros, realizar un **reporte de auditoría** (siempre en rango de fechas, como mínimo).
e. Elegir **2 reportes** que por sus características lo justifiquen y aplicar **tuning** sobre los mismos. Efectuar tales cambios en dos stored procedures que se llamen igual a los originales, agregando al nombre el texto `_tuneado`.

## 6. Documentación de pruebas

a. Efectuar las pruebas de las funcionalidades efectuadas en los stored procedures sobre el documento adjunto a esta tarea (el mismo que vienen utilizando en otras actividades).
b. Deberán realizar por cada SP una prueba funcional completa. Para ello, diseñar un script de prueba que ejecute cada Stored Procedure del siguiente modo:
   1. **Caso de Éxito (Flujo Normal):** ejecutar el SP enviando parámetros válidos y verificar que retorne el conjunto exacto de registros esperado.
   2. **Búsqueda sin Coincidencias (Resultado Vacío):** invocar el SP con valores que no existan en las tablas base. Verificar que no arroje errores de ejecución.
   3. **Validación de Parámetros Nulos / Límite:** probar el comportamiento del SP enviando parámetros `NULL` o cadenas vacías, verificando que no retorne datos erróneos ni ejecute agrupaciones innecesarias.
   4. **Prueba de Consistencia Lógica / Equivalencia de Resultados:** comparar el resultado devuelto por el SP optimizado con una consulta `SELECT` directa. Ambos resultados deben ser 100% idénticos en cantidad de filas y valores.

## Forma de trabajo

El trabajo será realizado en equipos de dos personas, tal y como se ha pautado en la asignatura Proyecto Informático I.

## Entregables y evaluación

La aprobación del Proyecto dependerá del cumplimiento de los hitos de desarrollo establecidos, de la calidad técnica de la solución implementada y del desempeño demostrado durante las pruebas requeridas.

El proyecto será evaluado como una experiencia integral de ingeniería de software, considerando tanto el producto final como el proceso de diseño, construcción, documentación, validación y defensa técnica realizado por cada equipo.

Cada equipo deberá presentar una serie de **HITOS**, de la sección BBDD, que se requerirán a través de Classroom, como tareas.

## Defensa técnica

Cada integrante deberá participar de una instancia de defensa oral ante el docente. Durante dicha defensa se evaluará:

1. Comprensión de la arquitectura general del sistema, su diseño e implementación. Justificación de las decisiones de diseño adoptadas.
2. Conocimiento de los stored procedures desarrollados. Explicación de las funcionalidades realizadas y las pruebas efectuadas.
3. Participación efectiva dentro del proyecto. Este punto se evaluará tanto en la defensa oral como en lo que el docente vea en clase, siendo la asistencia y trabajo en clase un aspecto muy importante.
4. Todos los integrantes deberán demostrar conocimiento suficiente sobre el funcionamiento global de la solución, independientemente del rol principal desempeñado durante el desarrollo.
