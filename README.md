# Dermalia

Sistema de gestión de turnos de escritorio para **Dermalia, Instituto de
Estética Médica** (barrio de Flores, CABA). Repositorio oficial de la
**Carpeta de Proyecto V1** para la materia *Proyecto Informático I* (Prof.
Cynthia Berea), 4to año, especialidad Computación, Escuela Técnica de
CABA. Marco pedagógico: **Buenos Aires Aprende**. Bimestre de 7 semanas
(desde el 4 de agosto).

## Desafío integrador

> ¿De qué manera podemos identificar y analizar una problemática real de
> nuestra comunidad o escuela para diseñar una propuesta de solución de
> software viable, justificada y bien estructurada?

Este bimestre **no se programa el sistema**: se lo formula y se lo diseña.
El desarrollo técnico arranca el bimestre siguiente.

## Propuesta elegida

La gestión de turnos y consultas del instituto depende hoy de la atención
manual de la recepción por WhatsApp: 95 minutos diarios respondiendo
consultas repetidas, 6 turnos perdidos por semana por inasistencia (≈
$120.000) y 5 superposiciones de agenda por mes. El sistema propuesto
ataca esas cuatro causas con:

| Módulo | Función |
|---|---|
| Cargar turno en 3 pasos | Protocolo → horario disponible → confirmación, con agenda propia de los profesionales en el sistema |
| Buscador de precios y protocolos | Búsqueda por palabra clave; deriva a WhatsApp si no encuentra coincidencia |
| Registro de seña | Simulado (mock): la recepción marca el estado de pago, sin procesar dinero real |
| Recordatorio de turno | Generado dentro del sistema, visible al buscar el turno |
| Buscar turnos | Por nombre, DNI o teléfono de la paciente, sin enlace ni cuenta |

Dos apartados: una **terminal táctil** en el instituto, que usa la
paciente para cargar su propio turno, y la **PC de recepción**, para los
turnos que llegan por teléfono. Detalle completo en
[`docs/04-requerimientos.md`](docs/04-requerimientos.md).

**Stack técnico**: backend en **C** con **SQL Server**, frontend en
**Qt de escritorio**, sin APIs externas.

El equipo relevó diez propuestas en `docs/propuestas.md`. Esta quedó como
principal frente a otras cuatro (POS de kiosco, adopción de mascotas,
reserva de laboratorios, reclamos de mantenimiento) porque tenía más
evidencia disponible y era viable de terminar en el bimestre.

## Cadena lógica

```
Causas del Árbol de Problemas  →  Medios del Árbol de Objetivos
                               →  Componentes y Actividades de la MML
                               →  Requerimientos funcionales
                               →  Pantallas del maquetado
```

Ejemplo de un camino completo, de principio a fin: *C1.1 (WhatsApp no
integrado a agenda digital) → M1 (integrar WhatsApp con agenda digital) →
R1 (módulo de reserva con agenda propia) → RF-01/RF-02/RF-03 → Pantallas 1
y 2 del maquetado ("Elegir protocolo", "Elegir horario")*.

## Entregable final: estado de cada pieza

| # | Pieza | Documento | Estado |
|---|---|---|---|
| 1 | Diagnóstico, Árbol de Problemas | [`docs/01-arbol-de-problemas.md`](docs/01-arbol-de-problemas.md) | Hecho |
| 2 | Propuesta estratégica, Árbol de Objetivos | [`docs/02-arbol-de-objetivos.md`](docs/02-arbol-de-objetivos.md) | Hecho |
| 3 | Matriz de Marco Lógico (MML) | [`docs/03-matriz-marco-logico.md`](docs/03-matriz-marco-logico.md) | Hecho |
| 4 | Requerimientos funcionales y no funcionales | [`docs/04-requerimientos.md`](docs/04-requerimientos.md) | Hecho (RF-01 a RF-13, dos apartados; RNF-01 a RNF-11) |
| 5 | Maquetado (wireframes) | [`docs/05-maquetado.md`](docs/05-maquetado.md) | 5+5 pantallas de escritorio en Qt, apartado Cliente y Gestión |
| 6 | Pitch (7 a 10 min) | [`docs/06-pitch.md`](docs/06-pitch.md) | Guion armado, falta ensayar y cronometrar con los 4 integrantes |

Documentos de apoyo: [`docs/propuestas.md`](docs/propuestas.md) (las diez
propuestas relevadas y por qué se eligió esta), [`docs/foda.md`](docs/foda.md)
(FODA del equipo), [`docs/plan-de-aprendizaje.md`](docs/plan-de-aprendizaje.md)
(cronograma) y [`docs/material-catedra.md`](docs/material-catedra.md)
(resumen de los videos de cátedra, alojados como [release `material-catedra`](https://github.com/sant1jmnz/Proyect-berea/releases/tag/material-catedra)).

## Indicadores principales (MML: Propósito)

Todos medidos a las 4 semanas de uso del sistema:

- Reducción del 60% en el tiempo diario de atención manual (de 95 a 38 min/día).
- Reducción del 50% en turnos perdidos por inasistencia (de 6 a 3/semana).
- 0 superposiciones de agenda por mes (de 5 actuales).
- ≥ 70% de consultas resueltas con el buscador interno, sin buscar a mano.

El riesgo más alto: que la recepción no use el sistema como herramienta
principal y siga anotando turnos a mano en paralelo. Para evitarlo, la
transición es gradual, con una capacitación breve al iniciar.

## Estructura del repositorio

```
docs/
  01-arbol-de-problemas.md
  02-arbol-de-objetivos.md
  03-matriz-marco-logico.md
  04-requerimientos.md
  05-maquetado.md
  06-pitch.md
  foda.md
  plan-de-aprendizaje.md
  material-catedra.md
  propuestas.md
README.md                # este archivo, portada de la Carpeta de Proyecto V1
```

Todo se escribe en **Markdown**, en español. Los diagramas (árboles, flujos)
van en Mermaid dentro del propio `.md` para que se vean en GitHub. El
maquetado vigente es una página interactiva enlazada desde
`docs/05-maquetado.md`; el maquetado móvil original sigue en
[Figma](https://www.figma.com/design/qEWMXwg68LQOtj9PzRnh1A/Untitled).

## Equipo y roles

Formalizados como issues del repo (#1 a #4), asignados el 1° de
septiembre:

| Integrante | Rol | Issue |
|---|---|---|
| Santiago Jiménez | Marco Lógico y coordinación (árboles, MML, trazabilidad) | [#1](../../issues/1) |
| Bautista | Requerimientos y viabilidad (RF/RNF, FODA) | [#2](../../issues/2) |
| Nicolás | Diseño y maquetado (Figma histórico, mockup Qt vigente) | [#3](../../issues/3) |
| Clovis | Pitch y comunicación (guion, defensa oral) | [#4](../../issues/4) |

## Herramientas

Miro / FigJam (árboles y MML) · Figma (maquetado original, reemplazado) ·
Trello o GitHub Projects (backlog) · GitHub con documentación Markdown ·
Google Workspace / Classroom · Canva (presentación final).

## Qué falta

- Revisión cruzada (peer review) del maquetado y de los árboles con otro
  equipo: sigue pendiente. Sin fecha concreta por ahora; se retoma si
  aparece otro equipo con quien coordinarla.
- Armar la presentación de Canva ("Proyecto Informático 1"): recorrido
  semana a semana de lo que se fue haciendo, más los problemas que se
  encontraron. Es lo último que se arma, una vez que el resto de la
  Carpeta de Proyecto esté cerrado.
- Ensayar y cronometrar el pitch con los 4 integrantes.
