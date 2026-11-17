# Bitácora del equipo — Dermalia

**Integrantes:** Santiago Jiménez y Bautista Casero · Proyecto Informático I · 4° bimestre 2026

## Qué hicimos

| Período | Santiago | Bautista |
|---|---|---|
| Septiembre | Carpeta de Proyecto V1, guion del pitch y resumen del material de cátedra | Viabilidad del pitch y maquetado del apartado Cliente |
| Semana 1 (6/10) | Prototipo de **Gestión** en Qt con el diseño estilo spa | Prototipo de la **terminal táctil** (Cliente) |
| Semana 3 (13/10) | Validaciones de la carga de turnos, seña por categoría y 5 casos de prueba de Gestión | Validaciones, pruebas y casos de prueba de la terminal; quedó un solo módulo de validaciones para los dos |
| Base de datos | Modelo de Chen entre los dos. SP de seña, cancelación, reembolso y cirugías; reportes 1 a 4 y auditoría | SP de cupones, tarjetas de regalo y notificaciones; reportes 5 a 8 |
| Noviembre | Competencia (indirectos y PUV), presupuesto y retorno de inversión, manual técnico y tuning de su reporte | Competencia (directos y matriz), monetización, manual de usuario con capturas y tuning de su reporte |

**Lo último (noviembre):**

- La terminal y Gestión trabajan sobre la misma base y se actualizan solas cada 3 segundos.
- Pantallas nuevas en Gestión: Cupones, Tarjetas de regalo, Consultas previas y Usuarios (la administración crea los usuarios del personal).
- Cuenta opcional de la paciente en la terminal (Ingresar / Crear cuenta).
- "Ver resumen" de cada tratamiento, igual al de la web, y buscador de precios funcional.
- 239 pruebas de los stored procedures y 6 de los programas, todas aprobadas; manuales con capturas.

## Problemas y cómo los resolvimos

| Problema | Solución |
|---|---|
| Las ramas chocaban con `main` | Un PR por semana, resolviendo los conflictos y corriendo las pruebas de los dos |
| Cliente y Gestión validaban distinto | Un solo módulo compartido (`frontend/comun/validaciones`) |
| Las tildes se guardaban rotas en la base | `SET NAMES utf8mb4` al principio de cada script |
| No compilaba con la librería de MySQL (sí con MariaDB) | Guardar la conexión como `void*` y convertirla a `MYSQL*` |
| Gestión seguía sin la base si se cancelaba el ingreso | Una franja amarilla que avisa y un botón para ingresar |
| El buscador de precios mostraba resultados fijos | Ahora busca en el catálogo real de la base |

## Qué aprendimos

- A conectar C++ con MySQL usando la API de C y a llamar a los stored procedures desde Qt.
- A manejar errores en los SP con `EXIT HANDLER` y `GET DIAGNOSTICS`.
- Que un dato debe tener una sola fuente: el catálogo sale de la base, y la web y los programas lo leen de ahí.

## Pendiente

- Subir la base a Aiven para usarla desde cualquier PC.
- Entregas en Classroom, diapositivas, ensayo del Demo Day y coevaluación.
