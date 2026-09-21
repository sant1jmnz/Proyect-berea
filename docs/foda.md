# Análisis FODA

FODA del equipo y del proyecto, no del negocio imaginario de Dermalia, que
no tiene FODA propio porque no existe fuera del ejercicio. Sirve para
evaluar la viabilidad del equipo de llegar a la Carpeta de Proyecto V1
completa en las 7 semanas reales del bimestre del equipo, y para derivar estrategias antes de
seguir avanzando.

## Matriz

|  | Positivo | Negativo |
|---|---|---|
| Interno (el equipo lo controla) | Fortalezas | Debilidades |
| | F1. El repositorio, la metodología y las guías por etapa están armadas y ordenadas desde la Jornada 1. | D1. Al ser Dermalia un caso imaginario, no hay relevamiento real que valide las hipótesis del diagnóstico: todo se apoya en datos inventados por el equipo. |
| | F2. Herramientas conectadas (Miro, Figma, GitHub) que aceleran diagramación y maquetado. | D2. Los roles recién se definieron en la semana 3, no desde el arranque. |
| | F3. El equipo avanzó más rápido de lo previsto: árboles, MML, requerimientos y maquetado ya tienen borrador en la semana 3, antes de lo que marca el cronograma. | |
| Externo (solo influible indirectamente) | Oportunidades | Amenazas |
| | O1. La cátedra da una rúbrica clara y material de referencia (videos, teoría de Marco Lógico) que reduce la ambigüedad sobre qué se evalúa. | A1. Bimestre de solo 7 semanas reales de trabajo, poco margen si algo se traba. Permanente: no depende de una debilidad propia. |
| | | A2. Dependencia de herramientas externas (Miro, Figma, GitHub) para tener el proyecto al día; si cambia el acceso, se frena el trabajo. Permanente. |
| | | A3. Si no se deja explícito que Dermalia es un caso imaginario, la devolución del docente puede cuestionar la validez del diagnóstico. Circunstancial: asociada a D1. |
| | | A4. La revisión cruzada entre equipos, prevista en el marco pedagógico como feedback externo antes de la entrega final, no se concretó: no hubo otro equipo disponible para intercambiarla en el tiempo del bimestre. El diagnóstico y el maquetado llegan a la entrega sin ese chequeo externo. |

## Estrategias

- E1 (F1 + O1), ofensiva: usar la organización ya armada del repo para
  responder punto por punto a la rúbrica de Buenos Aires Aprende, mostrando
  trazabilidad explícita (causa → objetivo → componente → requerimiento →
  pantalla) en cada entrega.
- E2 (F1 + A4), defensiva: sin revisión cruzada, el propio equipo asume ese
  chequeo: cada rol (issues #1-#4) revisa el trabajo de otro rol antes de
  cerrar la Carpeta de Proyecto, en vez de esperar un feedback externo que
  no va a llegar.
- E3 (F1 + A1), defensiva: con la metodología y las guías ya listas, el
  equipo absorbe mejor un imprevisto dentro del bimestre corto, sin
  reconstruir el criterio de trabajo si alguien falta una semana.
- E4 (D2 + F1), reordenamiento: los roles ya están formalizados como
  issues del repo (#1 a #4) desde el 1/9; el pendiente real es que se
  reflejen ahí los cambios del pivot de la Semana 7 (nuevo negocio,
  apartados Cliente/Gestión), no la asignación en sí.
- E5 (D1 + A3), supervivencia: dejar explícito en cada documento (ya hecho en
  `docs/propuestas.md` y `docs/01-arbol-de-problemas.md`) y repetirlo en el
  pitch que Dermalia es un caso imaginario, para que la cátedra evalúe el
  proceso metodológico, no la existencia de un relevamiento que nunca fue.

## Qué falta

- Actualizar los issues #6 a #15 (los RF viejos) para que reflejen la
  nueva numeración y los dos apartados de `docs/04-requerimientos.md`, o
  cerrarlos y crear los nuevos: hoy están desactualizados (hablan de
  "clienta" y "dueño", numeración RF-01 a RF-10 vieja).
- Nada más pendiente sobre O2/A4: se aceptó que la revisión cruzada no se
  va a hacer, ver E2.
