# Bitácora personal — Santiago Jiménez

**Autor:** Santiago Jiménez — bitácora individual, de autoría exclusiva.
Los demás integrantes del equipo llevan la suya por separado; este archivo
no se edita por terceros (ver `.github/CODEOWNERS`).

**Materia:** Proyecto Informático I — Prof. Cynthia Berea
**Año y especialidad:** 4to año, Computación — Escuela Técnica de CABA
**Marco pedagógico:** Buenos Aires Aprende
**Cursada:** 8 semanas — Carpeta de Proyecto V1
**Repositorio:** https://github.com/sant1jmnz/Proyect-berea

> Nota: los datos de encuadre de arriba están tomados del plan de aprendizaje
> de la cátedra. Santiago los corrige a mano cuando corresponda.

Registro personal del avance en el proyecto, tal como pide el plan de
aprendizaje del bimestre (autoseguimiento semanal como instrumento de
evaluación formativa). **Se cierra una entrada al final de cada jornada de
trabajo**; las entradas se agregan al final, sin modificar las anteriores.

---

## Jornada 1 — 18 de agosto de 2026

### Creación del repositorio del proyecto

Creé el repositorio **sant1jmnz/Proyect-berea** en GitHub (privado), que va a ser
el repositorio oficial del proyecto y donde se arma toda la Carpeta de Proyecto
V1 en formato Markdown. Esto adelanta una de las tareas previstas para la
semana 7 del plan ("Creación del repositorio oficial del proyecto en Git/GitHub
con el archivo README.md estructurado").

### Incorporación de la herramienta de brainstorming

Descargué e instalé en el repositorio la herramienta **brainstorming** del
proyecto Superpowers (repositorio público `obra/superpowers`, licencia MIT).
Sirve para ordenar la etapa de generación y refinamiento de ideas: obliga a
entender el contexto y a validar la propuesta antes de pasar a implementar, que
es exactamente el enfoque del bimestre. Quedó en `.claude/skills/brainstorming/`
junto con un `ORIGIN.md` que documenta la fuente, la versión exacta y la
licencia.

### Lectura y sistematización del material de cátedra

Revisé el material de la carpeta de Drive *"proyecto berea 1 segundo
cuatrimestre"*:

- **Plan de aprendizaje – Proyecto Informático I:** desafío integrador,
  capacidades a desarrollar, entregable final, secuencia semanal de 8 semanas y
  criterios de evaluación.
- **PROY1 – C11 Teoría (Prof. Cynthia Berea):** enfoque de Marco Lógico (EML),
  objetivo general y específicos, resultados esperados, actividades, indicadores
  objetivamente verificables, fuentes de verificación e hipótesis externas, con
  el ejemplo del Programa ZUMAR de Guayaquil.
- **¿Qué es la Matriz FODA?:** las cuatro variables, el corte entre factores
  internos y externos, y la formulación de estrategias a partir del cruce.
- **Documento de usabilidad:** las 10 heurísticas de Jakob Nielsen y material de
  referencia sobre historias de usuario.

Quedan pendientes de ver los **10 videos** de la carpeta (árbol de problemas,
árbol de objetivos, metodología y ejemplos de Matriz de Marco Lógico).

### Configuración del repositorio con el marco teórico de la materia

A partir de ese material armé la configuración del repositorio, para que toda la
documentación se escriba siguiendo la metodología de la cátedra.

`CLAUDE.md` deja asentado el desafío integrador, las seis piezas del entregable
final, la estructura de carpetas, las convenciones de redacción (problemas en
negativo, objetivos en infinitivo, un solo problema central, indicadores con
línea de base, numeración estable `C1`/`E1`/`OE1`/`R1`/`RF-01`) y, sobre todo,
la **cadena de trazabilidad** que ordena todo el trabajo:

```
Causas del Árbol de Problemas → Medios del Árbol de Objetivos
                              → Componentes y Actividades de la MML
                              → Requerimientos funcionales
                              → Pantallas del maquetado
```

Esa cadena es la clave: la rúbrica evalúa la *integración* entre diagnóstico,
planificación, requerimientos y maquetado, no cada pieza suelta.

Además quedaron ocho guías metodológicas en `.claude/skills/`, una por etapa:

| Guía | Semana | Contenido |
|---|---|---|
| `arbol-de-problemas` | 2 | Problema central, causas raíz y efectos |
| `arbol-de-objetivos` | 3 | Conversión a medios y fines; alternativa de intervención |
| `matriz-marco-logico` | 4 y 5 | Lógica vertical y horizontal (IOV, MoV, supuestos) |
| `analisis-foda` | apoyo | Las cuatro variables y las estrategias del cruce |
| `requerimientos` | 6 | RF, RNF, historias de usuario y backlog |
| `maquetado-ux` | 7 | Wireframes, user flow y heurísticas de Nielsen |
| `pitch` | 8 | Guion de 7 a 10 minutos y preguntas anticipadas |
| `carpeta-proyecto` | cierre | Auditoría de trazabilidad y checklist de rúbrica |

### Gestión de accesos del repositorio

Sumé como colaboradores a **bautistacasero265-maker** y **Nicolas041209**, ambos
con permiso de escritura sobre `Proyect-berea`. Verifiqué que el acceso de
colaborador en GitHub es **por repositorio**: no ven el resto de mis repos
privados. Lo que sí es visible para cualquiera son mis repositorios públicos
(`Apolo-11`, `Owen-Robot-Controller`, `html-apolo-11`), que ya lo eran de antes.

También renombré la rama de trabajo a `main` y la dejé como rama por defecto.

### Relevamiento y desarrollo de las propuestas de proyecto

Quedaron consolidadas **diez propuestas** en `docs/propuestas.md`, cada una con
el mismo esquema: problema central redactado en negativo, evidencia, alcance
delimitado, indicadores preliminares, riesgos y viabilidad.

Para la evidencia se separaron dos cosas distintas: los **datos públicos con
fuente citada**, que contextualizan la problemática, y las marcas `[RELEVAR]`,
que señalan lo que solo puede salir de nuestras propias entrevistas y
observaciones. Ninguna cifra de línea de base se completa sin medirla.

Del análisis salieron tres conclusiones: la propuesta del **centro de estética**
sigue siendo la principal porque tiene un cliente real identificado; la de
**laboratorios y equipamiento** es la alternativa más firme porque el
relevamiento se hace dentro de la institución; y las de **comparador de
hardware** y **gastos compartidos** conviene descartarlas, porque ya existen
soluciones gratuitas instaladas (HardGamers y Splitwise) y no aparece un ángulo
diferencial defendible en el pitch.

### Pendientes que quedaron abiertos

- Corregir a mano los datos de encuadre de la cabecera de esta bitácora.
- Ver los 10 videos del material de cátedra.
- Definir el equipo y los roles.
- Cerrar la elección de la propuesta.

---

_Las diez propuestas, desarrolladas con evidencia y análisis de viabilidad,
están en [`docs/propuestas.md`](propuestas.md)._
