# Guía por semana: cómo sacar de esta rama lo que toca cada semana

Esta rama (`claude/awesome-hopper-20z4z2`) tiene **todo el trabajo del 4° bimestre ya
hecho y probado**. No se mergea entera: **cada semana se trae solo lo que corresponde**
a la rama de cada uno (`santiago`, `bautista`) y se abre el PR a `main` como pide
`reparto-4to-bimestre.md`. Así el repositorio muestra el avance semana a semana y cada uno
puede **leer, entender y defender** lo que trae (en la defensa se evalúa el conocimiento de todo
el modelo, no solo del bloque propio).

> **Regla de oro:** no traer un archivo sin leerlo. Cada SQL tiene comentarios que explican qué
> hace cada cosa; si algo no se entiende, se pregunta antes de subirlo.

## Cómo traer archivos de esta rama

Desde tu rama de trabajo:

```bash
git fetch origin claude/awesome-hopper-20z4z2
git checkout santiago                    # o bautista
git checkout origin/claude/awesome-hopper-20z4z2 -- backend/03_sp_semana3.sql docs/12-contrato-sp.md
git status                                # revisar qué entró
git commit -m "Semana 3: stored procedures de login, ABM, horarios y alta de turno"
git push -u origin santiago
```

Para traer **una carpeta entera** (por ejemplo las pruebas): `git checkout origin/claude/awesome-hopper-20z4z2 -- backend/pruebas`.
Para **ver** un archivo sin traerlo: `git show origin/claude/awesome-hopper-20z4z2:docs/07-competencia.md`.

Antes de cada semana, **probar en limpio**: cargar los scripts en orden (ver `13-manual-tecnico.md`)
y, para la base, `python3 backend/pruebas/correr_pruebas.py --recargar` (necesita `pymysql`).

## Dónde estamos (martes 3 de noviembre de 2026, Semana 5)

Las semanas 1 y 2 (los DER y el diseño lógico) ya existen en `docs/diagramas/`. Las **semanas 3 y 4
están atrasadas** según el reparto: conviene traerlas **primero** (esta semana), porque los
reportes de la Semana 5 dependen de ellas.

## Semana 3 (martes 20 al lunes 26 de octubre): datos y primeros stored procedures; lógica y QA

| Cuándo | Qué es | Traer de esta rama | Para entender |
|---|---|---|---|
| Miércoles | **Poblar el modelo**: 50+ turnos y 20+ filas por tabla; el log queda vacío | `backend/02_datos.sql` | `docs/11-pruebas-bbdd.md` (tabla de datos), `backend/REVISION.md` |
| Jueves | **SP de login y logs, alta de turno, ABM de protocolos y profesionales, horarios libres** | `backend/03_sp_semana3.sql` | `docs/12-contrato-sp.md` (columnas y códigos de error) |
| Jueves | **Pruebas (4 casos por SP)** de lo anterior | `backend/05_pruebas_sp.sql` (casos de las secciones C a I) y `backend/pruebas/correr_pruebas.py` | `docs/consigna-bbdd.md` punto 6 |
| Martes | Validaciones y casos de prueba funcional de la app | Ya están en `frontend/` y `docs/09`, `docs/10` | — |

## Semana 4 (martes 27 de octubre al lunes 2 de noviembre): funcionalidades en SP; análisis de competencia

| Cuándo | Qué es | Traer de esta rama | Para entender |
|---|---|---|---|
| Martes | **Informe de competencia, matriz comparativa y PUV** | `docs/07-competencia.md` | Completar las celdas "a verificar" probando las demos de cada competidor |
| Miércoles | SP de **cancelación, seña y reembolso**; regla de **cirugías** | `backend/04_sp_semana4.sql` (seña, cancelación, evaluaciones) | `docs/modelo-entidades.md` (sección Cirugías) |
| Miércoles | SP de **cupones** (token de 5 minutos) y **tarjetas de regalo** | `backend/04_sp_semana4.sql` (cupones, tarjetas) | `docs/modelo-entidades.md` (grupo 3, "Qué hace el token") |
| Jueves | SP de **notificaciones** y **consultas al asistente** | `backend/04_sp_semana4.sql` (avisos, asistente) | `docs/arquitectura.md` (n8n) |
| Jueves | Pruebas de cada SP | `backend/05_pruebas_sp.sql` (secciones J a O) | — |

El archivo `04_sp_semana4.sql` es uno solo; se puede subir de una vez o por partes.

## Semana 5 (martes 3 al lunes 9 de noviembre): reportes y auditoría; presupuesto y pitch — **esta semana**

| Cuándo | Qué es | Traer de esta rama | Para entender |
|---|---|---|---|
| Martes (Santiago) | **Presupuesto**, precio de venta y retorno | `docs/08-presupuesto.md` | Cambiar los supuestos 🔶 por los que defina el equipo |
| Martes (Bautista) | **Modelo de monetización**, guion de la demo, pitch de 5 a 7 minutos | `docs/06-pitch.md` (secciones de monetización en `08`) | Ensayar con cronómetro |
| Miércoles | **Reportes 1 a 3 (Santiago) y 5 a 7 (Bautista)** | `backend/05_reportes_semana5.sql` | `docs/12-contrato-sp.md` (columnas) |
| Jueves | **Reporte 4 (Santiago) y 8 (Bautista)** + **SP de auditoría por rango de fechas** | `backend/05_reportes_semana5.sql` | — |
| Jueves | Pruebas de los reportes y la auditoría | `backend/05_pruebas_sp.sql` (secciones A y P) | — |
| Cualquier día | Que la base tenga actividad real en el log | `backend/07_actividad_con_sps.sql` | consigna 4c |

## Semana 6 (martes 10 al lunes 16 de noviembre): tuning, pruebas y Demo Day

| Cuándo | Qué es | Traer de esta rama | Para entender |
|---|---|---|---|
| Martes | **Manual técnico** (Santiago) y **de usuario** (Bautista) | `docs/13-manual-tecnico.md`, `docs/14-manual-usuario.md` | Completar con capturas de pantalla propias |
| Miércoles | **Tuning**: 2 reportes `_tuneado` y medición antes/después | `backend/06_tuning_semana6.sql`, `backend/medir_tuning.sql` | `docs/11-pruebas-bbdd.md` (tabla de tiempos) |
| Miércoles | **Documento de pruebas** de la cátedra | `docs/11-pruebas-bbdd.md` | Pasar a la plantilla que entrega el docente |
| Jueves | **Defensa técnica** | Todo lo anterior | Ver "Preguntas de defensa" abajo |

## Lo que NO está hecho (y hay que hacer a mano)

1. **Conectar las pantallas Qt a la base.** La capa `frontend/comun/repositorio.*` está lista y probada
   contra MySQL real, pero `ventanagestion.cpp` y las pantallas del Cliente todavía leen
   `gestion/datosprueba.cpp`. Es la tarea "Conectar Gestión 1-3 y 5 / Cliente 1-3, 5 con la base real".
   Camino: en cada pantalla, reemplazar la llamada a `DatosPrueba::...` por el método de `Repositorio`
   (`listarProtocolos`, `horariosLibres`, `altaTurno`, `registrarSena`, `cancelarTurno`, `buscarTurnos`) y
   mostrar `Respuesta::mensaje` cuando `ok` sea falso. Probar con `prueba_base`.
2. **Sitio web conectado a la base.** Hoy usa datos fijos. Hace falta una API intermedia que llame a los SP.
3. **Envío real de recordatorios** (flujo de n8n, bot de Telegram, WhatsApp oficial) y **Google Calendar**.
4. **Sincronizar los turnos guardados en contingencia** al volver la conexión (hoy se guardan y se cuentan).
5. **Verificar la competencia**: las celdas "a verificar" de `07-competencia.md`.
6. **Presentación (Canva / diapositivas)** del pitch y **revisión cruzada** con otro equipo.
7. **Pantallas** para cupones, tarjetas de regalo, cirugías y reportes (la base ya las resuelve).
8. Confirmar con el docente el criterio de las tablas maestras con menos de 20 filas.

## Preguntas de defensa (la base)

Cada integrante tiene que poder contestar, de los dos bloques:

1. ¿Por qué son 9 schemas y qué tabla es la principal? (`Turno`, 150 filas.)
2. ¿Por qué el estado y el saldo no se guardan? (3FN: son derivados.) ¿Dónde se calcula la seña?
3. ¿Qué pasa si dos personas reservan el mismo horario a la vez? (`FOR UPDATE` sobre el profesional + transacción.)
4. ¿Cómo evita la base que se pise un turno? ¿Y que se use un cupón dos veces?
5. ¿Qué hace el `EXIT HANDLER` y por qué los SP devuelven siempre 6 columnas?
6. ¿Cómo se llena el log y por qué nunca a mano?
7. Explicar el token del cupón y por qué se acepta el tramo anterior.
8. ¿Qué dos reportes se tunearon, qué se cambió y cuánto mejoró? (`11-pruebas-bbdd.md`.)
9. ¿Qué es el reloj simulado y para qué sirve?
10. Recorrer la regla de cirugías: consulta, evaluación, 6 meses, 10% y 50%.
