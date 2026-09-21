# Pitch

**Qué es "el pitch"**: la exposición oral de 7 a 10 minutos frente a la
clase, defendiendo la propuesta (por qué este problema, por qué esta
solución, por qué es viable). Este documento es el **guion**, lo que se
dice; el Canva ("Proyecto Informático 1") es el **apoyo visual** que se
proyecta mientras se habla, con lo que se fue haciendo semana a semana.
Son dos piezas distintas: el guion ya está, el Canva es lo último que
falta armar.

Guion de presentación oral, 9 minutos, Propuesta 1 (Dermalia, Instituto de
Estética Médica). Cada bloque se apoya en un documento ya cerrado de la
Carpeta de Proyecto: no hay nada acá que no salga de `01` a `05`.

Roles del equipo (definidos el 1 de septiembre): Santiago en Marco Lógico
y coordinación, Bautista en requerimientos, Nicolás en diseño y maquetado,
Clovis en el pitch.

## Guion por bloques

| Bloque | Tiempo | Habla | Contenido | Diapositiva / fuente |
|---|---|---|---|---|
| Gancho | 1 min | Clovis | "Dermalia pierde 6 turnos por semana por inasistencia, casi $120.000 semanales, y su recepción gasta 95 minutos por día contestando las mismas 18 preguntas por WhatsApp." Sin "nuestro proyecto se llama…": arranca directo con el dato. | Tabla de causas, `docs/01-arbol-de-problemas.md` |
| Problema | 1.5 min | Santiago | El problema central: la gestión de turnos depende de la atención manual de la recepción por WhatsApp, y sus tres causas directas: sin disponibilidad visible en tiempo real (C1), consultas repetidas respondidas a mano (C2), sin seña ni recordatorio (C3, C4). | Diagrama del Árbol de Problemas, `docs/01-arbol-de-problemas.md` |
| Propuesta | 2 min | Bautista | Objetivo general: facilitar la gestión de turnos y consultas automatizando la carga de turnos, el registro de seña y las respuestas frecuentes. Qué hace el sistema, en criollo: cargar un turno en 3 pasos, un buscador que contesta precios y protocolos por palabra clave, seña simulada, recordatorio dentro del sistema, los RF Must de `docs/04-requerimientos.md`, sin nombrarlos por ID. Dos apartados: un kiosco táctil en el instituto para que la paciente cargue su propio turno, y la PC de recepción para los turnos que llegan por teléfono. | Tabla de RF, `docs/04-requerimientos.md` |
| Demostración | 2.5 min | Nicolás | Recorrer los dos apartados en el maquetado: primero el kiosco (paciente elige protocolo → horario → confirma y paga la seña), después la PC de recepción con el mismo flujo para un turno por teléfono, y la búsqueda de turnos por nombre/DNI/teléfono. Mostrar también el buscador de precios y protocolos cuando la consulta es solo informativa. Pantalla por pantalla suelta, no: se recorre como una tarea de punta a punta. | User flow y mockup, `docs/05-maquetado.md` |
| Viabilidad | 1.5 min | Santiago | Los cuatro indicadores de la MML (-60% tiempo de atención, -50% turnos perdidos, 0 superposiciones, ≥70% consultas resueltas por el buscador, a las 4 semanas de uso) y el riesgo más alto: que la recepción no adopte el sistema como herramienta principal y siga anotando turnos aparte. Mitigación: capacitación breve al iniciar y transición gradual, sin cortar el hábito de un día para otro. | Matriz completa, `docs/03-matriz-marco-logico.md` |
| Cierre | 0.5 min | Clovis | Este bimestre se formuló y se diseñó; el próximo arranca el desarrollo técnico sobre esta base ya trazada. Se pide al auditorio feedback sobre la propuesta de valor y la seña, antes de empezar a programar. |, |

## Preguntas anticipadas

**¿Por qué este problema y no otro? ¿Cómo lo verificaron?**
Se compararon 10 propuestas (`docs/propuestas.md`); se descartaron 5 por
falta de evidencia o por tener ya una solución gratuita instalada.
Dermalia quedó porque toda la cadena causal se sostiene con evidencia
externa real (estudios de uso de WhatsApp, casos de cobro de seña y
recordatorios automáticos citados en el Árbol de Problemas) en vez de una
intuición.

**¿Por qué es un instituto de estética médica y no un centro de estética simple?**
Decisión de equipo tomada esta semana, no un dato relevado. Un instituto
de estética médica (protocolos con tecnología: láser, radiofrecuencia,
peeling químico) sostiene mejor la seña obligatoria y el ticket promedio
que usan los indicadores ($20.000 en vez de precios de manicura), y da un
posicionamiento más defendible en el pitch que un centro de tratamientos
simples. El rubro y la lógica del problema (turnos, consultas repetidas,
inasistencia) no cambian, cambia el catálogo y el nivel de la marca.

**¿Por qué software resuelve esta causa y no otra intervención?**
Las cuatro causas raíz (C1.1-C4.1) son fricciones de proceso: un canal no
integrado a nada, respuestas repetidas sin base centralizada, cobro y
aviso manuales. No es falta de capacitación ni de infraestructura física.
Automatizarlas ataca la fricción directamente, sin que el instituto tenga
que cambiar de rubro ni invertir en algo distinto de lo que ya usa
(WhatsApp).

**¿Por qué un kiosco y no que la paciente reserve desde su celular?**
Porque el stack real del equipo es C + SQL Server + Qt de escritorio, sin
web y sin API externa: un self-service remoto necesita un canal web que
el equipo no tiene. Un kiosco táctil dentro del instituto sí es Qt
nativo, así que la paciente sigue cargando su propio turno, solo que
presencial en vez de desde su casa. Para cuando llama por teléfono está
el apartado de recepción, con el mismo flujo.

**¿Qué pasa si el supuesto de mayor riesgo no se cumple?**
El riesgo más alto es que la recepción no adopte el sistema como
herramienta principal (supuesto del Propósito en la MML). Si no se
cumple, el sistema queda subutilizado y ningún indicador de Propósito se
mueve, aunque los Componentes (R1-R4) estén técnicamente terminados.
Mitigación ya definida: capacitación breve al iniciar y transición
gradual, en vez de cortar el hábito anterior de un día para otro.

**¿Cómo van a medir que el sistema funcionó?**
Con los cuatro indicadores de la MML, medidos a las 4 semanas de uso: -60%
en tiempo diario de atención manual, -50% en turnos perdidos por
inasistencia, 0 superposiciones de agenda por mes, ≥70% de consultas
resueltas con el buscador interno sin buscar a mano. Medios de
verificación: panel de reportes del sistema y una encuesta breve a la
recepción antes/después.

**¿Qué queda afuera del alcance y por qué?**
Historia clínica de tratamientos, gestión de stock de insumos, liquidación
de comisiones y app nativa quedaron fuera desde el Árbol de Problemas: no
atacan ninguna de las cuatro causas raíz identificadas. También queda
fuera cualquier portal self-service para la paciente (lo que antes era la
"vitrina" con fotos y reseñas): dependía de la API de Google Maps y de un
canal web que el stack actual no tiene. Y en general: este bimestre no se
programa nada, se formula y se diseña: el desarrollo técnico es alcance
del bimestre siguiente.

**¿Es realizable en el tiempo que tienen, con el equipo que son?**
Para este bimestre (formulación y diseño), sí: el equipo cuenta 7 semanas
reales de trabajo (desde el 4 de agosto), y las 6 piezas de la Carpeta de
Proyecto están cerradas o en cierre en la Semana 7, la última. Las
decisiones de diseño que no dependían de datos reales (monto de seña,
catálogo de protocolos, el pivot a herramienta interna) se cerraron como
decisión de equipo en vez de quedar abiertas esperando un relevamiento
que nunca iba a llegar, justamente para no perder tiempo del bimestre
corto.

**¿Por qué está todo mockeado, sin Mercado Pago, sin Google Calendar, sin IA real?**
Restricción del equipo: el backend se hace en C con SQL Server, el
frontend en Qt de escritorio, sin integraciones por API externa. En vez de
dejar esas piezas sin resolver, cada una se diseñó igual pero simulada
dentro del propio sistema: el buscador de precios/protocolos funciona por
palabra clave contra una tabla propia en vez de un modelo de lenguaje, la
agenda vive en el sistema en vez de sincronizarse con Google Calendar, y
la seña se registra como un estado (pagada/no pagada) que marca la
recepción en vez de procesarse por una pasarela real. La lógica de negocio
(30% de seña, derivación a WhatsApp sin coincidencia, recordatorio antes
del turno) es la misma que si hubiera integraciones reales, cambia la
implementación, no el diseño.

## Qué falta

- Ensayar y cronometrar el guion completo, con los 4 integrantes.
- Ajustar los tiempos de cada bloque según el ensayo, la tabla de arriba es
  el reparto inicial, no una medición real todavía.
- Armar la presentación de Canva ("Proyecto Informático 1"), que es lo
  último que se arma en la Semana 7 real (ver
  `docs/plan-de-aprendizaje.md`): recorrido semana a semana de lo que se
  fue haciendo y los problemas que se encontraron, para usar como apoyo
  visual durante este guion.
