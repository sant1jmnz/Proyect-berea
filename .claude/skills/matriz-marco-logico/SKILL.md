---
name: matriz-marco-logico
description: Construir o completar la Matriz de Marco Lógico (MML) — Fin, Propósito, Componentes y Actividades, con indicadores, medios de verificación y supuestos. Usar al planificar el proyecto, definir métricas de éxito, o identificar riesgos y supuestos.
---

# Matriz de Marco Lógico (MML)

El enfoque de marco lógico (EML, 1969) sintetiza el proyecto en una matriz de
4×4. Se llena en dos pasadas: primero la columna de objetivos (lógica vertical),
después las tres columnas restantes (lógica horizontal).

## La matriz

| Nivel | Resumen narrativo | Indicadores (IOV) | Medios de verificación | Supuestos |
|---|---|---|---|---|
| **Fin** | Impacto de largo plazo al que contribuye el proyecto (el fin del Árbol de Objetivos) | | | |
| **Propósito** | El objetivo general: el cambio directo que produce el sistema. Uno solo | | | |
| **Componentes** | Los entregables / módulos del sistema. `R1, R2…` | | | |
| **Actividades** | Las tareas para producir cada componente. `A.1.1, A.1.2…` | | | |

## Lógica vertical (semana 4)

Se lee de abajo hacia arriba con un **"si… entonces"**:

> Si ejecuto las Actividades, entonces produzco los Componentes.
> Si entrego los Componentes, entonces logro el Propósito.
> Si se logra el Propósito, entonces se contribuye al Fin.

- El **Fin** y el **Propósito** vienen directo del Árbol de Objetivos, no se
  reinventan.
- Los **Componentes** son los módulos del sistema, redactados como productos ya
  terminados: "Módulo de carga de asistencia implementado y en uso", no
  "Desarrollar el módulo".
- Las **Actividades** sí van en infinitivo, y cada una se numera bajo su
  componente: `A.1.1` es la primera actividad del componente `R1`.

## Lógica horizontal (semana 5)

Para cada fila, de izquierda a derecha:

- **Indicador (IOV)** — qué se mide, cuánto y para cuándo. Necesita línea de
  base. Ejemplos válidos: "Tiempo de respuesta menor a 2 segundos",
  "Reducción del 50% en el tiempo de gestión respecto de los 40 min actuales",
  "30 usuarios activos al cierre del bimestre". Si no tiene número, no es
  indicador.
- **Medio de verificación (MoV)** — de dónde sale el dato: logs del sistema,
  encuesta de satisfacción, planilla de tiempos, acta de entrega. Tiene que
  existir de verdad y ser accesible al equipo.
- **Supuesto** — la condición externa que tiene que cumplirse y que el equipo
  **no controla**: "La escuela habilita el acceso a la red", "Los docentes
  aceptan usar el sistema". Para cada uno, estimar el riesgo de que no se
  cumpla (bajo / medio / alto) y qué se hace si pasa.

## Chequeos antes de dar la MML por cerrada

- ¿El Propósito es uno solo? Si hay dos, son dos proyectos.
- ¿Cada Componente se desprende de un medio del Árbol de Objetivos?
- ¿Cada Actividad tiene recursos identificados (quién del equipo, qué tiempo,
  qué herramienta)?
- ¿Cada indicador se puede medir con el medio de verificación declarado?
- ¿Los supuestos son externos y no tareas propias disfrazadas? "Terminar el
  módulo a tiempo" no es un supuesto, es una actividad.
- ¿Hay algún riesgo alto sin plan de mitigación?

## Formato de salida

`docs/03-matriz-marco-logico.md`: la matriz completa como tabla Markdown, más
una sección de **riesgos** (técnicos, de infraestructura, de adopción de
usuarios) con su mitigación.
