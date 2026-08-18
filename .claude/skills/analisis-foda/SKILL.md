---
name: analisis-foda
description: Realizar el análisis FODA (Fortalezas, Oportunidades, Debilidades, Amenazas) del proyecto o del equipo y derivar estrategias. Usar al evaluar viabilidad, contexto o posición del proyecto antes de decidir la alternativa de intervención.
---

# Análisis FODA

Radiografía de una situación puntual. Sirve para pasar del análisis del contexto
a la formulación de estrategias — apoya la elección de la alternativa de
intervención en el Árbol de Objetivos.

## Las cuatro variables

|  | Positivo | Negativo |
|---|---|---|
| **Interno** (se puede actuar directo) | **Fortalezas** — capacidades, recursos y habilidades que el equipo controla | **Debilidades** — carencias y falencias propias |
| **Externo** (solo influible indirectamente) | **Oportunidades** — factores del entorno aprovechables | **Amenazas** — situaciones del entorno que pueden obstaculizar el proyecto |

El corte interno/externo es lo que más se confunde. La pregunta que lo resuelve:
**¿el equipo puede modificarlo por decisión propia?** Si sí, es interno.

Aplicado a un proyecto escolar de software: fortalezas y debilidades son del
equipo y del propio proyecto (conocimiento técnico, tiempo disponible,
experiencia con la herramienta, cohesión del grupo); oportunidades y amenazas
son del contexto (apoyo de la dirección, infraestructura de la escuela,
disponibilidad de los usuarios a entrevistar, calendario escolar).

## Procedimiento

1. Listar las variables de cada cuadrante, numeradas `F1…`, `D1…`, `O1…`, `A1…`.
2. Separar las amenazas **permanentes** (no asociadas a debilidades propias) de
   las **circunstanciales** (asociadas a debilidades propias) — sobre estas
   últimas sí se puede actuar corrigiendo hacia adentro.
3. **Derivar estrategias** cruzando cuadrantes, y referenciar siempre las
   variables de origen:
   - **Ofensivas** (F+O): usar una fortaleza para tomar una oportunidad.
   - **Defensivas** (F+A): usar una fortaleza para blindarse de una amenaza.
   - **Reordenamiento** (D+O): corregir una debilidad para poder aprovechar una
     oportunidad.
   - **Supervivencia** (D+A): reducir una debilidad expuesta a una amenaza.

Ejemplo del formato: `E1 (para D1): preparar un plan de capacitación del equipo
en Figma antes de la semana 7`.

**Listar los cuatro cuadrantes no es hacer un FODA.** Lo que se evalúa es la
conclusión y las estrategias que salen del cruce.

## Formato de salida

`docs/foda.md`: la matriz 2×2 con variables numeradas y, debajo, la lista de
estrategias `E1, E2…` con la referencia a las variables que atienden.
