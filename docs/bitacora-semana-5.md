# Bitácora de la Semana 5 (martes 3 al lunes 9 de noviembre de 2026)

> **Cómo se armó.** Esta bitácora se reconstruyó a partir del historial de commits de `main` y de las casillas
> marcadas en [`reparto-4to-bimestre.md`](reparto-4to-bimestre.md). Cada integrante tiene
> que **revisarla,
> corregirla con lo que realmente hizo y completar "Qué aprendí"** antes de entregarla como propia.

**Qué pedía la semana** (`plan-4to-bimestre.md`, Semana 5): presupuesto y modelo de negocio, y preparar el pitch
de venta. En Bases de Datos (`consigna-bbdd.md`, punto 5): al menos 8 reportes con funciones de agrupamiento,
reuniones y fechas, y el reporte de auditoría. Entregable: presentación ejecutiva (pitch) y documento de
presupuesto final.

## Día por día

### Martes 3 de noviembre

**Presupuesto, monetización y pitch**
- `docs/08-presupuesto.md`: **847 horas** de desarrollo × $20.000 = **$16.940.000**. Con 30% de margen, el
  precio de implantación es **$22.020.000**; con el hardware de la terminal ($660.000), la inversión inicial del
  instituto es **$22.680.000**.
- Modelo de monetización: se comparó licencia, SaaS y llave en mano. Se **eligió llave en mano + abono fijo de
  soporte** ($400.000 por mes), porque el abono no crece con la cantidad de profesionales y eso sostiene la
  propuesta única de valor.
- Retorno de la inversión: beneficio neto de **$20.376.000 por año** (156 turnos recuperados y 296 horas de
  recepción liberadas, menos el abono). Se recupera en unos **13 meses**. Los supuestos del equipo están marcados
  con 🔶 para que se cambien por los que decidan.
- `docs/06-pitch.md` pasó al formato nuevo de **5 a 7 minutos**, de venta a inversores, con demo en vivo.

**Base de datos (backend)**
- Backend completo en una primera versión: datos de ejemplo, stored procedures, **los 8 reportes y la auditoría
  por rango de fechas** (`backend/05_reportes.sql`), tuning y pruebas.
- Pruebas de los stored procedures: **198 casos, todos OK**.
- Medición del tuning con **300.000 turnos** y actividad de ejemplo generada **solo con stored procedures**
  (`backend/07_actividad_con_sps.sql`), para que el log tenga movimiento real.
- Stored procedures de listado para las pantallas (turnos del período, pacientes, profesionales, disponibilidad,
  avisos) y 24 casos de prueba más.
- `backend/08_usuarios.sql`: usuarios de las aplicaciones que **solo pueden ejecutar** stored procedures.

**Frontend y sitio**
- Capa `Repositorio`: un solo lugar que llama a los stored procedures, con el estilo simple de la cátedra.
- **Gestión conectada a la base** (ingreso del personal y datos reales) y pantalla **Reportes** con los 8 reportes
  y la auditoría.
- **Terminal (Cliente) conectada a la base**: catálogo, horarios libres, reserva con seña y cancelación.
- **Modo contingencia**: los turnos guardados sin conexión se envían a la base cuando vuelve (probado).
- **Sitio web conectado**: API propia que llama a los stored procedures, reserva y "Mi turno" con datos reales,
  con prueba de integración y recorrido verificado en el navegador.
- Plantillas de **n8n** para avisos y tareas diarias (todavía sin probar en una instancia real).

**Documentación**
- Pruebas de la base, contrato de stored procedures, manuales técnico y de usuario, guía por semana, resumen del
  material de la cátedra y README con el estado del trabajo.
- Bitácora de la investigación de competencia de la Semana 4 (`bitacora-semana-4-investigacion.md`).

### Miércoles 4 de noviembre

- Se trajeron a `main` las semanas 3 y 4 y el sitio conectado, por pull request (#58, #59 y #60).
- **Decisión de equipo sobre contraseñas:** se dejaron **sin hash ni encriptación** (se guardan tal cual), los
  códigos pasaron a generarse con UUID y el token del cupón con CRC32. Queda anotado como pendiente de seguridad.
- Los schemas se crean **sin charset explícito**: se usa el que trae MySQL 8 por defecto.

### Jueves 5 al lunes 9 de noviembre

- **No hay commits** en el repositorio en esos días. Si el equipo trabajó en las diapositivas o en el guion fuera
  del repositorio, hay que anotarlo acá.

## Qué se entregó (según el reparto)

| Tarea | Estado |
|---|---|
| Presupuesto, precio de venta y retorno (`08-presupuesto.md`) | Hecho |
| Modelo de monetización y pitch de 5 a 7 minutos (`06-pitch.md`) | Hecho |
| Reportes 1 a 8 y reporte de auditoría, con sus 4 casos de prueba | Hecho |
| Pantalla Reportes en Gestión | Hecho |
| Diapositivas del pitch (problema, competencia, solución, costos, precio y retorno) | **Pendiente** |
| Guion de la demo en vivo, paso a paso | **Pendiente** |
| Revisión cruzada de los reportes (cada uno revisa los del otro) | **Pendiente** (Bautista, reportes de Santiago) |

## Problemas y cómo se resolvieron

| Problema | Solución |
|---|---|
| Las pruebas de la base fallaban en el log, en los cupones y con mayúsculas | Se corrigieron los stored procedures y se volvió a correr todo: 198 casos OK |
| El log quedaba vacío y la consigna pide actividad real | Se generó actividad de ejemplo usando solo stored procedures (script 07) |
| Las aplicaciones no tienen que poder tocar las tablas | Usuarios de la base que solo ejecutan stored procedures (script 08) |
| Sin internet la terminal no podía cargar turnos | Modo contingencia: se guardan en el equipo y se envían al volver la conexión |
| Los flujos de n8n no se podían probar en este trabajo | Se escribieron con el formato de n8n y se dejaron marcados "sin probar" |

## Qué aprendí

*(Completar con tus palabras. Algunas ideas que salen del trabajo de la semana:)*
- Que el precio de venta sale del costo (horas por valor de la hora más margen) y que el retorno se defiende con
  los números que ya midió el proyecto (turnos perdidos y horas de recepción).
- Que conviene que las aplicaciones solo llamen a stored procedures: las reglas viven en un solo lugar.
- Que un reporte se prueba con casos propios (éxito, rechazo, nulos y límites, consistencia).

## Pendiente al cerrar la semana

- Diapositivas del pitch y guion de la demo en vivo.
- Revisión cruzada de los reportes entre Santiago y Bautista.
- Probar los flujos de n8n en una instancia real y poner las credenciales.
- Proteger las contraseñas (hoy se guardan tal cual, decisión del equipo).
- Confirmar con la docente el criterio de las tablas maestras con menos de 20 filas.
