# EstéticaFlow

Sistema de gestión de turnos para **Dermalia, Instituto de Estética
Médica**. Repositorio oficial de la **Carpeta de Proyecto V1** para la
materia *Proyecto Informático I* (Prof. Cynthia Berea), 4to año,
especialidad Computación, Escuela Técnica de CABA. Marco pedagógico:
**Buenos Aires Aprende**. Bimestre de 7 semanas reales de trabajo (desde
el 4 de agosto).

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
| Supuesto | Una condición externa de la que depende el proyecto, pero que el equipo no controla (ej: que la recepción adopte el sistema). |
| FODA | Fortalezas, Oportunidades, Debilidades y Amenazas: análisis de la situación del equipo, no del negocio imaginario. |
| Mock | Una parte del sistema que simula una función real (por ejemplo, un pago) sin conectarse a un servicio externo de verdad. |
| `[RELEVAR]` | Un dato que falta conseguir con trabajo de campo propio (entrevista, encuesta), no algo que se pueda inventar o buscar en internet. |

## Propuesta elegida

**Sistema de turnos de escritorio para Dermalia, Instituto de Estética
Médica** (barrio de Flores, CABA, a 2026). Es un caso imaginario que el
equipo armó para practicar toda la metodología, sin necesitar un
relevamiento real.

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

**No es un self-service para la paciente**: lo opera la recepción desde la
PC del instituto, cuando la paciente pide el turno por teléfono o en
persona. Es así por la restricción técnica del equipo, no por elección de
producto — ver más abajo.

**Stack técnico**: backend en **C** con **SQL Server**, frontend en
**Qt de escritorio**. No usa ninguna API externa ni tiene canal web. Donde
una versión con más libertad técnica usaría un servicio de terceros
(pasarela de pago, calendario, un modelo de lenguaje), este sistema lo
simula por dentro. Detalle completo en
[`docs/04-requerimientos.md`](docs/04-requerimientos.md).

El equipo relevó diez propuestas en `docs/propuestas.md`. Esta quedó como
principal frente a otras cuatro (POS de kiosco, adopción de mascotas,
reserva de laboratorios, reclamos de mantenimiento) porque tenía más
evidencia disponible y era viable de terminar en el bimestre.

**Aclaraciones**: Dermalia es un caso imaginario, no un comercio real. El
equipo inventó los datos de partida a propósito, para recorrer toda la
metodología con la misma disciplina que exigiría un caso real, ya que un
relevamiento real no era posible en el tiempo del bimestre. El negocio y
el modelo de uso se ajustaron en la última semana (de "Bella Piel",
centro de estética simple con self-service móvil, a Dermalia, instituto
de estética médica con herramienta interna de recepción) al confirmar que
el stack real es Qt de escritorio sin web: el problema central y la
cadena causal no cambiaron, cambió el catálogo y quién usa el sistema.

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
y 2 del maquetado ("Elegir protocolo", "Elegir horario")*.

## Entregable final: estado de cada pieza

| # | Pieza | Documento | Estado |
|---|---|---|---|
| 1 | Diagnóstico, Árbol de Problemas | [`docs/01-arbol-de-problemas.md`](docs/01-arbol-de-problemas.md) | Hecho. Sin revisión cruzada: el equipo decidió no perseguirla, no hay otro equipo disponible |
| 2 | Propuesta estratégica, Árbol de Objetivos | [`docs/02-arbol-de-objetivos.md`](docs/02-arbol-de-objetivos.md) | Hecho. Misma nota sobre la revisión cruzada |
| 3 | Matriz de Marco Lógico (MML) | [`docs/03-matriz-marco-logico.md`](docs/03-matriz-marco-logico.md) | Hecho |
| 4 | Requerimientos funcionales y no funcionales | [`docs/04-requerimientos.md`](docs/04-requerimientos.md) | Hecho (RF-01 a RF-13, dos apartados; RNF-01 a RNF-11) |
| 5 | Maquetado (wireframes) | [`docs/05-maquetado.md`](docs/05-maquetado.md) | 5+5 pantallas de escritorio en Qt, apartado Cliente y Gestión (vigente); el maquetado móvil original en Figma queda como historial, reemplazado. Sin revisión cruzada, misma nota |
| 6 | Pitch (7 a 10 min) | [`docs/06-pitch.md`](docs/06-pitch.md) | Guion armado, falta ensayar y cronometrar con los 4 integrantes |

Documentos de apoyo: [`docs/propuestas.md`](docs/propuestas.md) (las diez
propuestas relevadas y por qué se eligió esta), [`docs/foda.md`](docs/foda.md)
(FODA del equipo, no del negocio imaginario), [`docs/plan-de-aprendizaje.md`](docs/plan-de-aprendizaje.md)
(cronograma oficial de la cátedra y el cronograma real de 7 semanas del
equipo) y [`docs/material-catedra.md`](docs/material-catedra.md)
(resumen de los videos de cátedra, alojados como [release `material-catedra`](https://github.com/sant1jmnz/Proyect-berea/releases/tag/material-catedra)).

## Indicadores principales (MML: Propósito)

Todos medidos a las 4 semanas de uso del sistema:

- Reducción del 60% en el tiempo diario de atención manual (de 95 a 38 min/día).
- Reducción del 50% en turnos perdidos por inasistencia (de 6 a 3/semana).
- 0 superposiciones de agenda por mes (de 5 actuales).
- ≥ 70% de consultas resueltas con el buscador interno, sin buscar a mano.

El riesgo más alto: que la recepción no use el sistema como herramienta
principal y siga anotando turnos a mano en paralelo. Para evitarlo, la
transición es gradual, con una capacitación breve al iniciar, en vez de
cortar el hábito anterior de un día para otro.

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
maquetado vigente (5 pantallas de escritorio en Qt) es una página
interactiva enlazada desde `docs/05-maquetado.md`; el maquetado móvil
original, reemplazado, sigue en [Figma](https://www.figma.com/design/qEWMXwg68LQOtj9PzRnh1A/Untitled)
como historial.

## Equipo y roles

No son roles de Scrum (Product Owner, Scrum Master, etc.): este bimestre
no se programa nada, se formula y se diseña, así que los roles siguen las
piezas de la metodología de Marco Lógico, no un sprint de desarrollo.
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

- Armar la presentación de Canva ("Proyecto Informático 1"): recorrido
  semana a semana de lo que se fue haciendo, más los problemas que se
  encontraron (incluido el pivot de esta semana). Es lo último que se
  arma, una vez que el resto de la Carpeta de Proyecto esté cerrado.
- Ensayar y cronometrar el pitch con los 4 integrantes.
