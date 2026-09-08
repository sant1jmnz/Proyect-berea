# Bitácora — Santiago Jiménez

Materia: Proyecto Informático I, Prof. Cynthia Berea.
Bitácora individual. Se agrega una entrada al cierre de cada jornada.

---

## 18 de agosto de 2026

Qué hice hoy:

- Creé el repositorio del proyecto en GitHub (`sant1jmnz/Proyect-berea`, privado)
  y sumé como colaboradores a Bautista y Nicolás.
- Leí el material de cátedra: el plan de aprendizaje del bimestre, la teoría de
  Marco Lógico de la Clase 11, el apunte de Matriz FODA y las heurísticas de
  usabilidad de Nielsen.
- Dejé el repositorio ordenado según esa metodología, con una guía por cada
  etapa del bimestre (árboles, MML, requerimientos, maquetado, pitch) y la
  regla de trazabilidad que las une: cada pieza tiene que desprenderse de la
  anterior.
- Desarrollé las 10 propuestas de proyecto en `docs/propuestas.md`, cada una con
  su problema central, evidencia y viabilidad.
- Busqué datos públicos para respaldar cada problemática y marqué con `[RELEVAR]`
  todo lo que solo puede salir de nuestras propias entrevistas.
- Descarté 5 propuestas por falta de datos o por tener soluciones gratuitas ya
  instaladas. Quedan 5 en carrera.

Dónde quedó la decisión:

La propuesta principal sigue siendo la aplicación web para el centro de
estética integral. Como alternativa firme queda la de reserva de
laboratorios y equipamiento, que tiene la ventaja de que los usuarios están
en la institución y el relevamiento se puede hacer sin depender de nadie de
afuera.

Qué falta:

- Ver los 10 videos del material de cátedra.
- Confirmar con el dueño del centro de estética que acepta la entrevista.
- Definir los roles del equipo.
- Relevar los datos reales que hoy faltan para poder armar el Árbol de Problemas.

---

## 1 de septiembre de 2026

Vimos 4 de los 10 videos de cátedra y sumamos lo que faltaba de ahí a las
guías del repo: la tabla de mal/bien formulado del Árbol de Problemas, la
conversión exacta a Árbol de Objetivos, y cómo se completa la MML paso a
paso.

Con eso terminamos el Árbol de Problemas y el Árbol de Objetivos de la
propuesta de estética, tanto en el repo como en post-its en el Miro del
equipo. Nos dimos cuenta de que veníamos redactando como si Bella Piel fuera
un cliente real con el que había que coordinar una entrevista, cuando en
realidad es un caso imaginario que armamos nosotros. Corregimos eso en
`propuestas.md` y en el árbol.

Seguimos con la Matriz de Marco Lógico, los requerimientos funcionales y no
funcionales, y armamos 5 pantallas del maquetado en Figma. También hicimos
el FODA del equipo.

Por último nos repartimos los roles: yo quedo en Marco Lógico y
coordinación, Bautista en requerimientos, Nicolás en diseño y maquetado, y
Clovis en el pitch.

Dónde quedó la decisión:

Sigue Bella Piel como propuesta principal, ahora ya aclarado en todos los
documentos que es un ejercicio imaginario: los datos de partida los
inventamos nosotros a propósito, no hay relevamiento real posible.

Qué falta:

- El pitch, la última pieza de la Carpeta de Proyecto.
- Pasar el maquetado por la revisión cruzada con otro equipo.
- Ver los 6 videos de cátedra que quedan.

---

## 8 de septiembre de 2026

Semana 6 de 8: quedan dos semanas y la última no es de producción, así que
reordenamos por lo que no podía esperar más.

Cerramos la decisión de la seña que estaba abierta en tres documentos a la
vez (MML A.3.2, RF-07 y la Pantalla 3 del maquetado): 30% del valor del
servicio, mínimo $5.000, reembolsable si se cancela con más de 24 h de
anticipación. Era una decisión de equipo, no un dato para relevar — Bella
Piel no tiene dueño real a quien preguntarle.

Con eso resuelto, cerramos también los tres flecos que quedaban en el
maquetado (`docs/05-maquetado.md`): RF-02 se resuelve con un aviso dentro
de la Pantalla 3 en vez de pantalla propia, RF-10 (vitrina) queda fuera de
este bimestre por tiempo, y la heurística 10 de Nielsen se cubre con un
enlace "Ayuda" en el header en vez de una pantalla de FAQ nueva. Faltan
aplicarse en el archivo de Figma, hoy están cerradas en el documento.

Armamos el borrador completo de `docs/06-pitch.md`: guion de 9 minutos por
bloques, quién habla en cada uno según los roles definidos, y las
respuestas a las seis preguntas que anticipa la guía del pitch.

Dónde quedó la decisión:

Con esto, las 6 piezas de la Carpeta de Proyecto V1 existen: falta pulirlas
(aplicar en Figma lo que se cerró hoy, ensayar el pitch), no armarlas de
cero.

Qué falta:

- Revisión cruzada del maquetado con otro equipo — no puede esperar a la
  semana 8.
- Aplicar en Figma las tres decisiones de RF-02/RF-10/ayuda.
- Ensayar y cronometrar el pitch con los 4 integrantes.
- Correr `carpeta-proyecto` (auditoría contra la rúbrica) antes de dar el
  bimestre por cerrado.
- Confirmar roles en los issues del repo (pendiente desde el FODA).

---

## Repaso: Semanas 1 a 6 del cronograma oficial (`docs/plan-de-aprendizaje.md`)

Corrida la auditoría con la skill `carpeta-proyecto`: agregó el `README.md`
que faltaba en la raíz del repo (portada de la Carpeta de Proyecto,
requerida por `CLAUDE.md` y por la Semana 7 del plan) y sumó "Preguntas
para la coevaluación cruzada" a los dos árboles, que no las tenían (el
maquetado sí).

Contenido de las Semanas 1 a 6, uno por uno:

- Semana 1 (equipos, brainstorming, idea inicial): hecho.
- Semana 2 (Árbol de Problemas): el árbol está hecho; **la revisión
  cruzada con otro equipo, que es parte de esta semana en el cronograma
  oficial, todavía no se hizo**. Es el único hueco real de las 6 semanas.
- Semana 3 (Árbol de Objetivos): hecho.
- Semana 4 y 5 (MML, vertical y horizontal): hecho.
- Semana 6 (Requerimientos, RNF, historias de usuario, backlog): hecho el
  documento; no verificado si el backlog llegó a existir como tablero real
  en Trello/GitHub Projects, más allá de estar descrito en
  `docs/04-requerimientos.md`.

Fuera de esas 6 semanas, ya está armado el borrador del maquetado (Semana 7)
y del pitch (Semana 8) también, adelantados.

Qué falta, acotado a cerrar hasta semana 6 en serio:

- Conseguir un equipo para la revisión cruzada de los árboles — no es algo
  que se resuelva en el repo, hay que coordinarlo en persona/Miro con otro
  grupo de la clase.
- Confirmar si el backlog de Semana 6 existe como tablero, o si solo quedó
  como descripción en el documento.

---

## Aporte de Bautista: dos RNF y una historia de usuario nuevas

Bautista mandó por mail su versión de `docs/04-requerimientos.md`, armada
sobre una copia de antes del cierre de la seña de hoy. Se mergeó: se
mantuvo el RF-07 ya cerrado (30%, mínimo $5.000, reembolso con +24h) y se
sumó lo suyo, que sí era nuevo:

- RNF-09: el asistente virtual solo responde con datos de la base cargada,
  nunca inventa una respuesta fuera de esa base.
- RNF-10: si falla la sincronización con Google Calendar, el sistema avisa
  al dueño en vez de mostrar la grilla como actualizada sin estarlo.
- Historia de usuario nueva del dueño, sobre ese mismo RNF-10.

Se reflejó también en `docs/05-maquetado.md`: RNF-09 en la Pantalla 4
(asistente), RNF-10 como parte del mismo aviso de sincronización de la
Pantalla 3.
