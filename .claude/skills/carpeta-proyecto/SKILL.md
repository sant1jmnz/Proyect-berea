---
name: carpeta-proyecto
description: Ensamblar y auditar la Carpeta de Proyecto V1 completa contra la rúbrica de evaluación, verificando la trazabilidad entre árboles, MML, requerimientos y maquetado. Usar al cierre del bimestre, antes de entregar, o al revisar si falta algo.
---

# Carpeta de Proyecto V1 — Ensamblado y Auditoría

Documento técnico final del bimestre. Se evalúa la **integración** entre las
piezas, no cada pieza por separado.

## Contenido obligatorio

1. Diagnóstico — Árbol de Problemas
2. Propuesta estratégica — Árbol de Objetivos
3. Matriz de Marco Lógico completa (IOV, MoV, supuestos)
4. Requerimientos funcionales y no funcionales
5. Maquetado funcional e interfaz propuesta
6. Pitch de presentación

## Auditoría de trazabilidad

Recorrer la cadena en los dos sentidos y anotar cada hueco:

**Hacia adelante** — ¿todo lo que entró, salió?
- Cada causa del Árbol de Problemas → ¿tiene su medio en el Árbol de Objetivos?
- Cada medio seleccionado → ¿aparece como Componente o Actividad en la MML?
- Cada Componente de la MML → ¿tiene requerimientos funcionales que lo realicen?
- Cada RF → ¿está cubierto por alguna pantalla del maquetado?

**Hacia atrás** — ¿todo lo que hay, se justifica?
- Cada pantalla → ¿qué RF implementa?
- Cada RF → ¿de qué Componente sale?
- Cada Componente → ¿qué causa del problema ataca?

Un elemento que no cierra en ninguno de los dos sentidos es un hallazgo:
o sobra, o falta algo aguas arriba. **Reportarlos todos, no arreglarlos en
silencio** — la decisión de qué recortar es del equipo.

## Checklist contra la rúbrica

- [ ] Un solo problema central y un solo objetivo general
- [ ] Objetivos redactados en infinitivo
- [ ] Ningún problema formulado como "falta de solución"
- [ ] Todos los indicadores de la MML tienen número y línea de base
- [ ] Todos los supuestos son externos al equipo y tienen riesgo estimado
- [ ] Los RNF tienen criterio medible
- [ ] Cada pantalla del maquetado está rotulada con sus RF
- [ ] Revisión heurística de Nielsen hecha
- [ ] Repositorio en GitHub con `README.md` estructurado
- [ ] Bitácora de equipo con el seguimiento semanal
- [ ] Registro de la devolución de los otros equipos (*peer review*) y qué se
      cambió a partir de ella

## Niveles de logro

- **Destacado** — integración sinérgica entre diagnóstico, planificación,
  requerimientos y maquetado. La cadena cierra completa en ambos sentidos.
- **Esperado** — metodologías correctamente aplicadas y presentación formal
  completa.
- **En proceso** — metodologías incompletas o desconexión entre la problemática
  identificada y el diseño propuesto.

## README.md del repositorio

La portada de la carpeta: nombre del proyecto, problema que resuelve en dos
frases, equipo y roles, índice enlazado a los documentos de `docs/`, estado de
avance y herramientas usadas.
