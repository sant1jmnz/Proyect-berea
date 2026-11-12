# TP9 – SQL Server: tablas temporales, variables tipo tabla y tablas derivadas

Autor: Jimenez, Santiago. Un par de scripts por ejercicio (cada ejercicio crea su propia base `TP9_EjN`).

| Ejercicio | Prod (crea la base, tablas, datos y opciones A/B/C) | QA (50 filas aprox., comparacion con `EXCEPT`) |
|---|---|---|
| 2 – Producto + Categoria | `Jimenez_Santiago_TP9_Prod_Ej2.sql` | `Jimenez_Santiago_TP9_QA_Ej2.sql` |
| 3 – Producto + Modelo | `Jimenez_Santiago_TP9_Prod_Ej3.sql` | `Jimenez_Santiago_TP9_QA_Ej3.sql` |
| 4 – Producto + Modelo + Categoria | `Jimenez_Santiago_TP9_Prod_Ej4.sql` | `Jimenez_Santiago_TP9_QA_Ej4.sql` |
| 5 – + Proveedor (3 filtros) | `Jimenez_Santiago_TP9_Prod_Ej5.sql` | `Jimenez_Santiago_TP9_QA_Ej5.sql` |

Orden de ejecucion: primero el Prod (crea `TP9_EjN`), despues el QA (`USE TP9_EjN`).
Las tres opciones de cada Prod: **A** tabla temporal `#`, **B** variable tipo tabla `@`, **C** tabla derivada (subquery en `FROM`).
En QA, `EXCEPT` entre la consulta directa y la version con tabla derivada debe devolver 0 filas.

Nota: los Prod de Ej2, Ej3 y Ej4 se armaron con el mismo esquema que infieren los INSERT de los QA (la 4ta columna de Ej2/Ej3 se modelo como `Stock`).
No se pudieron ejecutar contra un SQL Server en esta sesion: conviene correrlos una vez antes de entregar.
