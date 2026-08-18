# Proyecto Berea — Proyecto Informático I

Repositorio de la **Carpeta de Proyecto V1** para la materia *Proyecto Informático I*
(Prof. Cynthia Berea), 4to año, especialidad Computación, Escuela Técnica de CABA.
Marco pedagógico: **Buenos Aires Aprende**. Bimestre de 8 semanas.

## Desafío integrador

> ¿De qué manera podemos identificar y analizar una problemática real de nuestra
> comunidad o escuela para diseñar una propuesta de solución de software viable,
> justificada y bien estructurada?

Este bimestre **no se programa el sistema**: se lo formula y se lo diseña. El
desarrollo técnico arranca el bimestre siguiente. Si se pide "codear la app",
avisar que está fuera del alcance de esta entrega y volver al documento.

## Entregable final

**Carpeta de Proyecto V1**, con estas seis piezas:

1. Diagnóstico de la problemática — **Árbol de Problemas**
2. Propuesta estratégica — **Árbol de Objetivos**
3. **Matriz de Marco Lógico (MML)** completa: indicadores, medios de verificación y supuestos
4. **Requerimientos** funcionales y no funcionales
5. **Maquetado** funcional (wireframes) e interfaz propuesta
6. **Pitch** de presentación (7 a 10 minutos)

## Estructura del repositorio

```
docs/
  01-arbol-de-problemas.md
  02-arbol-de-objetivos.md
  03-matriz-marco-logico.md
  04-requerimientos.md
  05-maquetado.md
  06-pitch.md
  foda.md              # opcional, apoya el diagnóstico
README.md              # portada de la Carpeta de Proyecto V1
```

Todo se escribe en **Markdown**, en español, dentro de `docs/`. Los diagramas
(árboles, flujos) van en Mermaid dentro del propio `.md` para que se vean en
GitHub; los wireframes hechos en Figma se enlazan y se adjunta captura en
`docs/assets/`.

## Cadena lógica — la regla que ordena todo

Cada pieza se deriva de la anterior. Nada aparece de la nada:

```
Causas del Árbol de Problemas  →  Medios del Árbol de Objetivos
                               →  Componentes y Actividades de la MML
                               →  Requerimientos funcionales
                               →  Pantallas del maquetado
```

Antes de agregar cualquier elemento a un documento, verificar de qué elemento
del documento anterior se desprende. Si no se desprende de ninguno, o sobra o
falta algo aguas arriba. **Esta trazabilidad es el criterio de "nivel de logro
destacado" de la rúbrica**: el docente evalúa la integración sinérgica entre
diagnóstico, planificación, requerimientos y maquetado, no cada pieza aislada.

## Convenciones de redacción

- **Problemas** (Árbol de Problemas): en negativo, como estado presente.
  "Los alumnos no reciben las notas a tiempo", no "falta un sistema de notas".
- **Un problema central, uno solo.** Si hay dos, son dos proyectos.
- **Objetivos**: en infinitivo. "Reducir el tiempo de carga de notas a menos de
  5 minutos". Un solo objetivo general.
- **Nunca escribir la solución como problema.** "No hay una app" no es un
  problema, es una solución faltante. El problema es la necesidad que la app
  atendería.
- **Indicadores**: medibles y con línea de base. "Reducción del 50% respecto de
  los 40 min actuales", no "mejor rendimiento".
- Numeración estable: `C1, C2…` causas, `E1, E2…` efectos, `OE1, OE2…` objetivos
  específicos, `R1, R2…` resultados/componentes, `A.1.1…` actividades,
  `RF-01…` requerimientos funcionales, `RNF-01…` no funcionales.

## Herramientas del curso

Miro / FigJam (árboles y MML) · Figma (maquetado) · Trello o GitHub Projects
(backlog) · GitHub con documentación Markdown · Google Workspace / Classroom.

## Trabajo en equipo

Equipos de 3 a 4 integrantes con roles definidos. Hay bitácora semanal de avance
y revisión cruzada entre equipos (*peer review*) sobre los árboles y el maquetado.

## Fuentes

El material de cátedra está en la carpeta de Drive
*"proyecto berea 1 segundo cuatrimestre"*: el Plan de aprendizaje del bimestre,
la teoría de Marco Lógico (Clase 11), el apunte de Matriz FODA, un documento con
las heurísticas de Nielsen, y videos sobre árbol de problemas, árbol de
objetivos y MML.
