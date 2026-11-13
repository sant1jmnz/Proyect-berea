# Pitch de venta / Demo Day (Semanas 5 y 6)

Formato del 4° bimestre (`plan-4to-bimestre.md`): **5 a 7 minutos por grupo**,
dicho como **venta a inversores**, con **demo en vivo** del programa conectado
a la base y defensa de las objeciones. Este documento es el **guion** (lo que se
dice y se hace); las diapositivas son el apoyo visual. La versión del bimestre
anterior (9,5 minutos, sin demo) quedó en el historial de git.

Reparto: **Santiago** (problema, solución, números) y **Bautista** (demo,
competencia). Si se suman Nicolás y Clovis, se reparte el tiempo de la demo.

## Guion: 6 minutos y medio

| Bloque | Tiempo | Habla | Qué se dice | Diapositiva |
|---|---|---|---|---|
| 1. Gancho | 0:30 | Santiago | "Dermalia es un instituto de estética médica. Cada semana **pierde 6 turnos** por inasistencia —unos **$900.000 por semana**— y su recepción dedica **95 minutos por día** a contestar lo mismo por WhatsApp. Hoy la agenda está en papel y se superpone 5 veces por mes." Sin presentarse antes: arranca con el dato. | El problema (Árbol de Problemas, `01`) |
| 2. Solución | 0:40 | Santiago | "Construimos **un solo sistema, con tres puertas y una misma base**: una terminal táctil en el instituto para que la paciente reserve sola, la PC de recepción para las que llaman por teléfono, y un sitio web. La base cobra la seña, hace cumplir las reglas del negocio y avisa por Telegram o WhatsApp." | Arquitectura (`arquitectura.md`) |
| 3. Demo en vivo | 2:30 | Bautista | Ver "Guion de la demo" abajo. | — (programa en pantalla) |
| 4. Competencia | 0:50 | Bautista | "Las alternativas —AgendaPro, Fresha, Booksy, Doctoralia— cobran **por profesional**: con 20 profesionales son entre **USD 3.600 y 4.900 por año**, más comisión por paciente nueva en Fresha. Y son genéricos. Ninguna documentación pública que revisamos describe nuestra regla de **cirugías con consulta previa**. Además, **los datos son del instituto**." | Matriz comparativa (`07-competencia.md`) |
| 5. Números | 1:00 | Santiago | "Desarrollo: 847 horas, **$16,9 millones**. Precio de implantación **$22 millones** más un abono de **$400.000 por mes**. El instituto recupera **156 turnos al año ($23,4 millones)** y **296 horas** de recepción: **se paga en unos 13 meses**. Si el ticket fuera la mitad, en 2,6 años." | Costos, precio, retorno (`08-presupuesto.md`) |
| 6. Cierre | 0:30 | Santiago | "Buscamos que un instituto lo use cuatro semanas y medir los cuatro indicadores. La pregunta para ustedes: ¿qué necesitarían ver para pilotear esto?" | Gracias / pedido |

Total: 6:00 más 0:30 de margen. **Ensayar con cronómetro** (Semana 6): si pasa de
7 minutos, se recorta la competencia, nunca la demo.

## Guion de la demo (2:30)

La demo muestra **una tarea de punta a punta**, no pantallas sueltas. Datos de
ejemplo de la base (`backend/02_datos.sql`): paciente **Carla Gómez, DNI
33222111**; profesional **Dra. Marino** (limpieza, peeling, mesoterapia).

| # | Tiempo | Dónde | Qué se hace | Qué se cuenta |
|---|---|---|---|---|
| 1 | 0:35 | Terminal (Cliente) | La paciente elige **Peeling químico + Mesoterapia**, el sistema ofrece solo los horarios libres de profesionales que hacen **los dos**, confirma | "Solo muestra lo realmente disponible (RF-04): cero superposiciones" |
| 2 | 0:25 | Terminal | Paga la seña **simulada**: mostrar monto (30%) y el código de operación | "No mueve dinero real (RNF-05); calcula el 30%, 40% en cirugías" |
| 3 | 0:30 | Gestión (recepción) | Buscar a Carla por DNI, ver el turno **confirmado**, intentar cargar otro turno en el mismo horario → mensaje de error | "La regla vive en la base: ni la recepción puede pisar un horario" |
| 4 | 0:25 | Gestión | **Cancelar** el turno con más de 24 h → seña **reembolsada**; mostrar que con menos de 24 h queda retenida | "Reglas de seña y reembolso (RF-10), automáticas" |
| 5 | 0:35 | Gestión → Auditoría | Abrir el reporte de **auditoría** del día: aparecen el alta, el pago y la cancelación con usuario, hora y origen | "Cada acción queda registrada solo por los stored procedures (RF-20)" |

**Plan B si falla la conexión** (RNF-09): el programa entra en **modo
contingencia** (franja amarilla), guarda el turno en el equipo y avisa. Si
también falla el programa, mostrar el sitio web (`web/`, `npm run dev`) y los
reportes ya ejecutados en Workbench (`backend/05_reportes_semana5.sql`).
**Antes de empezar:** recargar la base (`01` a `08`), ingresar con `recepcion1` / `dermalia2026` y probar la
conexión. Las pantallas de Gestión y de la terminal ya trabajan con la base (si no hay conexión, usan los datos
de prueba y lo avisan). Para el paso 5 se abre la pantalla **Reportes** (auditoría) del mismo programa.

## Objeciones y respuestas

Responden los dos. Todos tienen que saberlas.

**"¿La seña es de verdad?"** No. Es un **mock** que imita un pago (estado,
monto, código de operación): el sistema no maneja dinero ni datos de tarjeta (RNF-05).
Pasarse a una pasarela real es una etapa posterior y no cambia las reglas.

**"¿Qué pasa con los datos de salud y personales?"** Quedan en una base
MySQL del instituto (Aiven). A servicios externos solo va lo mínimo; **al
asistente de IA no se le envían datos personales**: el sistema tacha emails y
números antes de guardar o enviar la pregunta, y si no sabe responder deriva al
WhatsApp del instituto (RNF-06, RNF-10). Cada acción queda en un log que solo
escriben los stored procedures.

**"¿Y si se corta internet o la luz?"** No-break y conexión 4G de respaldo;
y el **modo contingencia** guarda los turnos en el equipo y los sincroniza al
volver (RNF-09). Hoy el sistema guarda y cuenta los pendientes; el envío
automático al volver está previsto con los SP ya hechos.

**"¿Por qué pagar esto si Fresha o Booksy cuestan menos por mes?"** Con 20
profesionales cuestan USD 3.600–4.900 al año, **por profesional**, y no
tienen (en lo que revisamos) consulta previa para cirugías, tarjetas de
regalo con saldo ni cupones con QR que cambia cada 5 minutos. Y los datos
quedan en su plataforma. Aclaración honesta: varias celdas de la matriz dicen
"a verificar" (`07-competencia.md`).

**"¿Quién lo mantiene?"** El abono de $400.000/mes incluye soporte, hosting,
respaldos y la cuota de IA. El código está documentado (manual técnico) y la
lógica vive en stored procedures probados (222 casos).

**"¿Cómo saben que funciona?"** Cuatro indicadores de la MML, medidos a las 4
semanas de uso: −60% de tiempo de atención manual, −50% de turnos perdidos, 0
superposiciones, ≥70% de consultas resueltas con el buscador. Todavía no hay
usuarios reales: lo que mostramos es el diseño y la prueba de las reglas, no
resultados medidos.

**"¿Es realizable con el equipo que son?"** Para el bimestre sí, y está hecho: la base completa (reglas,
reportes, auditoría), Gestión y la terminal conectadas a ella, el sitio con su API y 222 casos de prueba más las
pruebas de integración contra MySQL real. Lo que queda para una etapa posterior —pasarela de pagos real,
WhatsApp oficial, Google Calendar y las pantallas de cupones por QR, tarjetas y cirugías— está identificado y
presupuestado.

## Para el día

- Diapositivas: una idea por diapositiva y los números grandes (6 turnos, 95
  min, $900.000, 13 meses).
- Cronometrar entero tres veces. Ensayar el plan B.
- Llevar impresa la matriz de competencia y la tabla de presupuesto por si
  piden detalle.
- Coevaluación: completar la rúbrica de BA Aprende de los otros equipos.
