# Proyecto Berea — Bella Piel, Centro de Estética Integral

Repositorio oficial de la **Carpeta de Proyecto V1** para la materia
*Proyecto Informático I* (Prof. Cynthia Berea), 4to año, especialidad
Computación, Escuela Técnica de CABA. Marco pedagógico: **Buenos Aires
Aprende**. Bimestre de 8 semanas.

## Desafío integrador

> ¿De qué manera podemos identificar y analizar una problemática real de
> nuestra comunidad o escuela para diseñar una propuesta de solución de
> software viable, justificada y bien estructurada?

Este bimestre **no se programa el sistema**: se lo formula y se lo diseña.
El desarrollo técnico arranca el bimestre siguiente.

## Propuesta elegida

**Aplicación web para Bella Piel — Centro de Estética Integral** (barrio de
Flores, CABA, a 2026), caso imaginario armado por el equipo para ejercitar
la metodología completa sin depender de un relevamiento real.

La gestión de turnos y consultas del centro depende hoy de la atención
manual del dueño por WhatsApp: 95 minutos diarios respondiendo consultas
repetidas, 6 turnos perdidos por semana por inasistencia y 5 superposiciones
de agenda por mes. El sistema propuesto ataca esas cuatro causas con:

| Módulo | Función |
|---|---|
| Reserva en 3 pasos | Servicio → horario disponible → confirmación, con agenda propia del dueño en el sistema |
| Buscador de preguntas frecuentes | Búsqueda por palabra clave sobre precios y protocolos; deriva a WhatsApp si no encuentra coincidencia |
| Cobro de seña | Simulado (mock): el sistema registra el estado de pago, sin procesar dinero real |
| Recordatorio de turno | Generado dentro del sistema, visible en "Mis Turnos" |
| Mis Turnos | Acceso por enlace mágico, sin registro ni contraseña |

**Stack técnico**: backend en **C** con **SQL Server**, frontend en
**HTML**. Sin integraciones por API externa — donde una versión real usaría
un tercero (pasarela de pago, calendario, un modelo de lenguaje), el
sistema implementa un mock propio. Detalle completo en
[`docs/04-requerimientos.md`](docs/04-requerimientos.md).

De diez propuestas relevadas en `docs/propuestas.md`, esta quedó como
principal frente a otras cuatro en carrera (POS de kiosco, adopción de
mascotas, reserva de laboratorios, reclamos de mantenimiento) por evidencia
disponible y viabilidad para el bimestre.

**Aclaración metodológica**: Bella Piel es un caso imaginario, no un
comercio real relevado. Los datos de partida se inventaron a propósito
para recorrer toda la metodología con la misma disciplina que exigiría un
caso real, sin depender de un relevamiento que no era posible hacer en el
tiempo del bimestre.

## Cadena lógica — la regla que ordena todo

Cada pieza se deriva de la anterior. Nada aparece de la nada:

```
Causas del Árbol de Problemas  →  Medios del Árbol de Objetivos
                               →  Componentes y Actividades de la MML
                               →  Requerimientos funcionales
                               →  Pantallas del maquetado
```

Ejemplo de un camino completo, de punta a punta: *C1.1 (WhatsApp no
integrado a agenda digital) → M1 (integrar WhatsApp con agenda digital) →
R1 (módulo de reserva con agenda propia) → RF-01/RF-02/RF-03 → Pantallas 1
y 2 del maquetado ("Elegir servicio", "Elegir horario")*.

## Entregable final — estado de cada pieza

| # | Pieza | Documento | Estado |
|---|---|---|---|
| 1 | Diagnóstico — Árbol de Problemas | [`docs/01-arbol-de-problemas.md`](docs/01-arbol-de-problemas.md) | Hecho — falta la revisión cruzada con otro equipo |
| 2 | Propuesta estratégica — Árbol de Objetivos | [`docs/02-arbol-de-objetivos.md`](docs/02-arbol-de-objetivos.md) | Hecho — falta la revisión cruzada con otro equipo |
| 3 | Matriz de Marco Lógico (MML) | [`docs/03-matriz-marco-logico.md`](docs/03-matriz-marco-logico.md) | Hecho |
| 4 | Requerimientos funcionales y no funcionales | [`docs/04-requerimientos.md`](docs/04-requerimientos.md) | Hecho (RF-01 a RF-10, RNF-01 a RNF-10) |
| 5 | Maquetado (wireframes) | [`docs/05-maquetado.md`](docs/05-maquetado.md) | 5 pantallas armadas en Figma; falta aplicar ahí los cambios de esta semana (stack sin APIs, enlace de ayuda) y la revisión cruzada |
| 6 | Pitch (7 a 10 min) | [`docs/06-pitch.md`](docs/06-pitch.md) | Guion armado — falta ensayar y cronometrar con los 4 integrantes |

Documentos de apoyo: [`docs/propuestas.md`](docs/propuestas.md) (las diez
propuestas relevadas y por qué se eligió esta), [`docs/foda.md`](docs/foda.md)
(FODA del equipo, no del negocio imaginario), [`docs/bitacora.md`](docs/bitacora.md)
(bitácora individual de avance), [`docs/plan-de-aprendizaje.md`](docs/plan-de-aprendizaje.md)
(cronograma oficial de la cátedra) y [`docs/material-catedra.md`](docs/material-catedra.md)
(resumen de los videos de cátedra, alojados como [release `material-catedra`](https://github.com/sant1jmnz/Proyect-berea/releases/tag/material-catedra)).

## Indicadores principales (MML — Propósito)

Todos medidos a las 4 semanas de uso del sistema:

- Reducción del 60% en el tiempo diario de atención manual (de 95 a 38 min/día).
- Reducción del 50% en turnos perdidos por inasistencia (de 6 a 3/semana).
- 0 superposiciones de agenda por mes (de 5 actuales).
- ≥ 70% de consultas resueltas sin intervención humana.

Riesgo más alto: que el dueño no adopte el sistema como canal principal y
siga gestionando turnos por WhatsApp en paralelo. Mitigación: no reemplazar
WhatsApp de un día para el otro, sino responder desde ahí con el enlace al
sistema hasta que el hábito cambie.

## Estructura del repositorio

```
docs/
  01-arbol-de-problemas.md
  02-arbol-de-objetivos.md
  03-matriz-marco-logico.md
  04-requerimientos.md
  05-maquetado.md
  06-pitch.md
  bitacora.md
  foda.md
  plan-de-aprendizaje.md
  material-catedra.md
  propuestas.md
.claude/skills/          # guías metodológicas por etapa (árboles, MML, requerimientos, maquetado, pitch, FODA)
README.md                # este archivo, portada de la Carpeta de Proyecto V1
```

Todo se escribe en **Markdown**, en español. Los diagramas (árboles, flujos)
van en Mermaid dentro del propio `.md` para que se vean en GitHub; los
wireframes están en [Figma](https://www.figma.com/design/qEWMXwg68LQOtj9PzRnh1A/Untitled)
y se enlazan pantalla por pantalla desde `docs/05-maquetado.md`.

## Equipo y roles

| Integrante | Rol |
|---|---|
| Santiago Jiménez | Marco Lógico y coordinación |
| Bautista | Requerimientos |
| Nicolás | Diseño y maquetado |
| Clovis | Pitch |

## Herramientas

Miro / FigJam (árboles y MML) · Figma (maquetado) · Trello o GitHub Projects
(backlog) · GitHub con documentación Markdown · Google Workspace / Classroom.

## Qué falta

- Revisión cruzada (peer review) del maquetado y de los árboles con otro
  equipo — todavía no se hizo ninguna de las dos.
- Aplicar en Figma los cambios de esta semana: agenda propia y buscador de
  FAQ en vez de Google Calendar/asistente con IA, seña simulada en vez de
  Mercado Pago, RF-10 fuera de alcance, enlace de ayuda en el header.
- Ensayar y cronometrar el pitch con los 4 integrantes.

El detalle semana a semana está en `docs/bitacora.md`.
