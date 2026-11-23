# Pitch de venta / Demo Day (Semanas 5 y 6)

Formato del 4° bimestre (`plan-4to-bimestre.md`): **5 a 7 minutos por grupo**,
dicho como **venta a inversores**, con **demo en vivo** del programa conectado
a la base y defensa de las objeciones. Este documento es el **guion** (lo que se
dice y se hace); las diapositivas son el apoyo visual. La versión del bimestre
anterior (9,5 minutos, sin demo) quedó en el historial de git.

Reparto: **Santiago** y **Bautista** se turnan **de a 2 diapositivas** (columna
"Láminas"). La demo la maneja Bautista y la cuenta Santiago. Si se suman Nicolás y
Clovis, se reparte el tiempo de la demo.

## Guion: 6 minutos y medio

| Bloque | Tiempo | Láminas (quién habla) | Qué se dice |
|---|---|---|---|
| 1. Gancho | 0:30 | 1-2 Santiago · 3-4 Bautista · 5-6 Santiago | **S (1-2):** "Dermalia es un instituto de estética médica. Cada semana **pierde 6 turnos** por inasistencia." **B (3-4):** "Son unos **$900.000 por semana**, y su recepción dedica **95 minutos por día** a contestar lo mismo por WhatsApp." **S (5-6):** "Hoy la agenda está en papel y se superpone 5 veces por mes. Seguir igual cuesta **156 turnos al año ($23,4 millones)**." Sin presentarse antes: arranca con el dato. |
| 2. Solución | 0:40 | 7-8 Bautista · 9-10 Santiago · 11-12 Bautista | **B (7-8):** "Construimos **un solo sistema con una misma base y tres puertas**. La primera, una terminal táctil en el instituto: la paciente reserva sola y ve solo horarios libres." **S (9-10):** "La segunda, la PC de recepción para las que llaman por teléfono: si un horario está tomado, nadie más lo puede dar. La tercera, un sitio web con un asistente que responde con el catálogo y deriva si no sabe." **B (11-12):** "La base cobra la seña, hace cumplir las reglas del negocio y devuelve o retiene la seña según el plazo de cancelación. Avisa por Telegram; WhatsApp oficial queda para una etapa posterior." |
| 3. Demo en vivo | 2:30 | 13 · Bautista maneja, Santiago cuenta | Ver "Guion de la demo" abajo. Programa en pantalla. |
| 4. Competencia | 0:50 | 14-15 Bautista | "Las alternativas —AgendaPro, Fresha, Booksy, Doctoralia— cobran **por profesional**: con 20 profesionales son entre **USD 3.600 y 4.900 por año**, más comisión por paciente nueva en Fresha. Y son genéricos. En la documentación pública que revisamos no encontramos nuestra regla de **cirugías con consulta previa**. Además, **los datos son del instituto**." |
| 5. Números | 1:00 | 16-17 Santiago · 18-19 Bautista | **S (16-17):** "Desarrollo: 847 horas, **$16,9 millones**. Precio de implantación **$22 millones** más un abono de **$400.000 por mes**." **B (18-19):** "El instituto recupera **156 turnos al año ($23,4 millones)** y **296 horas** de recepción: **se paga en unos 13 meses**. Si el ticket fuera la mitad, en 2,6 años." |
| 6. Cierre | 0:30 | 20-21 Santiago · 22-23 Bautista · 24 Santiago | **S (20-21):** "Para que funcione tienen que cumplirse dos condiciones. Lo ya construido está probado: **259 casos de la base aprobados** (255 con el script y 4 del aviso de turno perdido, corridos a mano en la base real), 61 de la API y se instala con un comando." **B (22-23):** "Lo que todavía no hay: WhatsApp oficial y resultados medidos. Proponemos un piloto de cuatro semanas." **S (24):** "¿Qué necesitarían ver para pilotear esto?" |

Total: 6:00 más 0:30 de margen. Los pases cambian cada 2 láminas: cada uno tiene que saber
qué lámina cierra su turno. **Ensayar con cronómetro** (Semana 6): ideal 7 minutos y
máximo 10: si pasa de 7, se recorta la competencia, nunca la demo.

## Guion de la demo (2:30)

La demo muestra **una tarea de punta a punta**, no pantallas sueltas (Bautista maneja,
Santiago cuenta lo que se ve). Datos de
ejemplo de la base (`backend/02_datos.sql`): paciente **Carla Gómez, DNI
33222111**; profesional **Dra. Marino** (limpieza, peeling, mesoterapia).

| # | Tiempo | Dónde | Qué se hace | Qué se cuenta |
|---|---|---|---|---|
| 1 | 0:35 | Terminal (Cliente) | La paciente elige **Peeling químico + Mesoterapia**, el sistema ofrece solo los horarios libres de profesionales que hacen **los dos**, confirma | "Solo muestra lo realmente disponible (RF-04): cero superposiciones" |
| 2 | 0:25 | Terminal | Paga la seña: mostrar monto (30%) y el código de operación | "Calcula el 30%, 40% en cirugías" |
| 2b | 0:20 | Terminal o sitio | **Asistente**: preguntar "¿cuánto sale el botox?" y "me quiero operar la nariz"; después "quiero un turno para peeling el jueves a la mañana" y tocar un horario (reserva dentro del chat, solo horarios de la mañana) | "Responde solo con el catálogo y las reglas del instituto, y también reserva: el mismo flujo anda en la web, la terminal y Telegram" |
| 3 | 0:30 | Gestión (recepción) | Buscar a Carla por DNI, ver el turno **confirmado**, intentar cargar otro turno en el mismo horario → mensaje de error | "La regla vive en la base: ni la recepción puede pisar un horario" |
| 4 | 0:25 | Gestión | **Cancelar** el turno con más de 24 h → seña **reembolsada**; mostrar que con menos de 24 h queda retenida | "Reglas de seña y reembolso (RF-10), automáticas" |
| 5 | 0:35 | Gestión → Auditoría | Abrir el reporte de **auditoría** del día: aparecen el alta, el pago y la cancelación con usuario, hora y origen | "Cada acción queda registrada solo por los stored procedures (RF-20)" |

**Plan B si falla la conexión** (RNF-09): el programa entra en **modo
contingencia** (franja amarilla), guarda el turno en el equipo y avisa. Si
también falla el programa, mostrar el sitio web (`web/`, `npm run dev`) y los
reportes ya ejecutados en Workbench (`backend/05_reportes_semana5.sql`).
**Antes de empezar:** `./dermalia.sh recargar-base` y `./dermalia.sh iniciar` (deja la base con los datos de
ejemplo y abre el sitio, Gestión y la terminal); ingresar con `recepcion1` / `dermalia2026`; `./dermalia.sh estado`
tiene que decir que la API llega a la base. Para recortar los 20 segundos del asistente, se saca del paso 4. Las pantallas de Gestión y de la terminal ya trabajan con la base (si no hay conexión, usan los datos
de prueba y lo avisan). Para el paso 5 se abre la pantalla **Reportes** (auditoría) del mismo programa.

## Objeciones y respuestas

Responden los dos. Todos tienen que saberlas.

**"¿Qué pasa con los datos de salud y personales?"** Quedan en una base
MySQL del instituto (Aiven). A servicios externos solo va lo mínimo; **al
asistente de IA no se le envían datos personales**: antes de mandar la pregunta
a Gemini y antes de guardarla, la API borra los emails y los números largos (DNI,
teléfonos, tarjetas). Si el asistente no sabe responder, deriva al WhatsApp del
instituto en vez de inventar (RNF-06, RNF-10). Cada acción queda en un log que
solo escriben los stored procedures.

**"¿Y si se corta internet o la luz?"** No-break y conexión 4G de respaldo;
y el **modo contingencia** guarda los turnos en el equipo y, cuando vuelve la
conexión, los manda solos a la base y avisa cuántos sincronizó (RNF-09). Si
lo que se corta es solo la IA, el asistente sigue respondiendo con el catálogo
y las reglas del instituto. Si un turno se sacó sin conexión y mientras tanto otra
paciente tomó ese horario, al volver la conexión la base lo rechaza y la paciente recibe
un aviso por el bot de Telegram con los horarios libres de esa semana para que reagende
(si no tiene Telegram vinculado, queda en Avisos de recepción). Está escrito y tiene 4
casos de prueba, pero todavía no lo corrimos contra una base real.

**"¿La IA puede inventar precios?"** No: se le pasa el catálogo de la base y
las reglas, con la orden de responder solo con eso; si no está ahí, deriva a
una persona. Y si Gemini no responde, contesta el asistente local, que solo
busca en el catálogo.

**"¿Por qué pagar esto si Fresha o Booksy cuestan menos por mes?"** Con 20
profesionales cuestan USD 3.600–4.900 al año, **por profesional**, y no
tienen (en lo que revisamos) consulta previa para cirugías, tarjetas de
regalo con saldo ni cupones con QR que cambia cada 5 minutos. Y los datos
quedan en su plataforma. Aclaración honesta: varias celdas de la matriz dicen
"a verificar" (`07-competencia.md`).

**"¿Quién lo mantiene?"** El abono de $400.000/mes incluye soporte, hosting,
respaldos y la cuota de IA. El código está documentado (manual técnico) y la
lógica vive en stored procedures probados (259 casos aprobados: 255 con el script y 4 corridos a mano en la base real).

**"¿Cómo saben que funciona?"** Cuatro indicadores de la MML, medidos a las 4
semanas de uso: −60% de tiempo de atención manual, −50% de turnos perdidos, 0
superposiciones, ≥70% de consultas resueltas con el buscador. Lo que mostramos es
el diseño y la prueba de las reglas, no resultados medidos.

**"¿Es realizable con el equipo que son?"** Para el bimestre sí, y está hecho: la base completa (reglas,
reportes, auditoría), Gestión con 13 pantallas, la terminal y el sitio conectados a ella, el asistente de IA,
cupones con QR, tarjetas de regalo y cirugías con consulta previa; 259 casos de prueba de la base aprobados (255 con el script, 4 a mano en la base real), 44 de la
estructura, 6 programas de prueba de las apps y 61 de la API, y se instala con un solo comando
(`./dermalia.sh instalar`). Lo que queda para una etapa posterior —pasarela de pagos real y WhatsApp con la
API oficial de Meta— está identificado y presupuestado.

## Para el día

- Diapositivas: una idea por diapositiva y los números grandes (6 turnos, 95
  min, $900.000, 13 meses).
- Cronometrar entero tres veces. Ensayar el plan B.
- Llevar impresa la matriz de competencia y la tabla de presupuesto por si
  piden detalle.
- Coevaluación: completar la rúbrica de BA Aprende de los otros equipos.
