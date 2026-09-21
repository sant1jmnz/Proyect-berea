# EstéticaFlow

Sistema de gestión de turnos para **Bella Piel, Centro de Estética
Integral**. Repositorio oficial de la **Carpeta de Proyecto V1** para la
materia *Proyecto Informático I* (Prof. Cynthia Berea), 4to año,
especialidad Computación, Escuela Técnica de CABA. Marco pedagógico:
**Buenos Aires Aprende**. Bimestre de 8 semanas.

## Desafío integrador

> ¿De qué manera podemos identificar y analizar una problemática real de
> nuestra comunidad o escuela para diseñar una propuesta de solución de
> software viable, justificada y bien estructurada?

Este bimestre **no se programa el sistema**: se lo formula y se lo diseña.
El desarrollo técnico arranca el bimestre siguiente.

## Glosario rápido

Para quien no cursó la materia y quiere entender los documentos sin buscar
cada sigla por su cuenta:

| Sigla | Qué significa |
|---|---|
| MML | Matriz de Marco Lógico: la tabla que resume todo el proyecto en Fin, Propósito, Componentes y Actividades. |
| RF / RNF | Requerimiento Funcional (qué debe *hacer* el sistema) / Requerimiento No Funcional (qué tan bien debe hacerlo: velocidad, seguridad, etc.). |
| IOV | Indicador Objetivamente Verificable: cómo se mide si algo se cumplió (un número, un porcentaje). |
| MoV | Medio de Verificación: de dónde sale el dato que confirma el indicador (una encuesta, un registro del sistema). |
| Supuesto | Una condición externa de la que depende el proyecto, pero que el equipo no controla (ej: que la clienta acepte pagar una seña). |
| FODA | Fortalezas, Oportunidades, Debilidades y Amenazas: análisis de la situación del equipo, no del negocio imaginario. |
| Mock | Una parte del sistema que simula una función real (por ejemplo, un pago) sin conectarse a un servicio externo de verdad. |
| `[RELEVAR]` | Un dato que falta conseguir con trabajo de campo propio (entrevista, encuesta), no algo que se pueda inventar o buscar en internet. |

## Propuesta elegida

**Aplicación web para Bella Piel, Centro de Estética Integral** (barrio de
Flores, CABA, a 2026). Es un caso imaginario que el equipo armó para
practicar toda la metodología, sin necesitar un relevamiento real.

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
**HTML**. No usa ninguna API externa. Donde una versión real usaría un
servicio de terceros (pasarela de pago, calendario, un modelo de lenguaje),
este sistema lo simula por dentro. Detalle completo en
[`docs/04-requerimientos.md`](docs/04-requerimientos.md).

El equipo relevó diez propuestas en `docs/propuestas.md`. Esta quedó como
principal frente a otras cuatro (POS de kiosco, adopción de mascotas,
reserva de laboratorios, reclamos de mantenimiento) porque tenía más
evidencia disponible y era viable de terminar en el bimestre.

**Aclaración**: Bella Piel es un caso imaginario, no un comercio real. El
equipo inventó los datos de partida a propósito, para recorrer toda la
metodología con la misma disciplina que exigiría un caso real, ya que un
relevamiento real no era posible en el tiempo del bimestre.

## Cadena lógica: la regla que ordena todo

Cada pieza se deriva de la anterior. Nada aparece de la nada:

```
Causas del Árbol de Problemas  →  Medios del Árbol de Objetivos
                               →  Componentes y Actividades de la MML
                               →  Requerimientos funcionales
                               →  Pantallas del maquetado
```

Ejemplo de un camino completo, de principio a fin: *C1.1 (WhatsApp no
integrado a agenda digital) → M1 (integrar WhatsApp con agenda digital) →
R1 (módulo de reserva con agenda propia) → RF-01/RF-02/RF-03 → Pantallas 1
y 2 del maquetado ("Elegir servicio", "Elegir horario")*.

## Entregable final: estado de cada pieza

| # | Pieza | Documento | Estado |
|---|---|---|---|
| 1 | Diagnóstico, Árbol de Problemas | [`docs/01-arbol-de-problemas.md`](docs/01-arbol-de-problemas.md) | Hecho, falta la revisión cruzada con otro equipo |
| 2 | Propuesta estratégica, Árbol de Objetivos | [`docs/02-arbol-de-objetivos.md`](docs/02-arbol-de-objetivos.md) | Hecho, falta la revisión cruzada con otro equipo |
| 3 | Matriz de Marco Lógico (MML) | [`docs/03-matriz-marco-logico.md`](docs/03-matriz-marco-logico.md) | Hecho |
| 4 | Requerimientos funcionales y no funcionales | [`docs/04-requerimientos.md`](docs/04-requerimientos.md) | Hecho (RF-01 a RF-10, RNF-01 a RNF-10) |
| 5 | Maquetado (wireframes) | [`docs/05-maquetado.md`](docs/05-maquetado.md) | 5 pantallas armadas en Figma; falta aplicar ahí los cambios de esta semana (stack sin APIs, enlace de ayuda) y la revisión cruzada |
| 6 | Pitch (7 a 10 min) | [`docs/06-pitch.md`](docs/06-pitch.md) | Guion armado, falta ensayar y cronometrar con los 4 integrantes |

Documentos de apoyo: [`docs/propuestas.md`](docs/propuestas.md) (las diez
propuestas relevadas y por qué se eligió esta), [`docs/foda.md`](docs/foda.md)
(FODA del equipo, no del negocio imaginario), [`docs/plan-de-aprendizaje.md`](docs/plan-de-aprendizaje.md)
(cronograma oficial de la cátedra) y [`docs/material-catedra.md`](docs/material-catedra.md)
(resumen de los videos de cátedra, alojados como [release `material-catedra`](https://github.com/sant1jmnz/Proyect-berea/releases/tag/material-catedra)).

## Indicadores principales (MML: Propósito)

Todos medidos a las 4 semanas de uso del sistema:

- Reducción del 60% en el tiempo diario de atención manual (de 95 a 38 min/día).
- Reducción del 50% en turnos perdidos por inasistencia (de 6 a 3/semana).
- 0 superposiciones de agenda por mes (de 5 actuales).
- ≥ 70% de consultas resueltas sin intervención humana.

El riesgo más alto: que el dueño no use el sistema como canal principal y
siga manejando los turnos por WhatsApp al mismo tiempo. Para evitarlo, no
se reemplaza WhatsApp de un día para el otro: se responde desde ahí con el
enlace al sistema, hasta que el hábito cambie.

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
  equipo, todavía no se hizo ninguna de las dos.
- Aplicar en Figma los cambios de esta semana: agenda propia y buscador de
  FAQ en vez de Google Calendar/asistente con IA, seña simulada en vez de
  Mercado Pago, RF-10 fuera de alcance, enlace de ayuda en el header.
- Ensayar y cronometrar el pitch con los 4 integrantes.
