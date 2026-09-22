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

Reparto de tiempo por integrante (sobre los 9 min): Santiago 4 min, Bautista
2 min, Nicolás 2 min, Clovis 1 min. Santiago habla más porque cierra la
mayoría de los bloques (Problema, la transición, Viabilidad y Cierre);
Bautista y Nicolás quedan nivelados entre sí.

Cada línea del "Contenido" está escrita para calzar con lo que se ve en
pantalla en ese momento (columna "Diapositiva"): si algo no está en el
Canva, no se dice en este bloque, se deja para las Preguntas anticipadas.

| Bloque | Tiempo | Habla | Contenido | Diapositiva / fuente |
|---|---|---|---|---|
| Gancho | 1 min | Clovis | "Dermalia pierde 312 turnos al año por inasistencia, $6.240.000 anuales, y su recepción dedica casi 500 horas al año, más de 60 jornadas laborales completas, a responder las mismas consultas repetidas por WhatsApp." Sin "nuestro proyecto se llama…": arranca directo con el dato, con los mismos números que van a estar en pantalla. | Página "El problema", Canva; tabla de causas, `docs/01-arbol-de-problemas.md` |
| Problema | 1.5 min | Santiago | El problema central: la gestión de turnos depende de la atención manual de la recepción por WhatsApp, y sus tres causas directas: sin disponibilidad visible en tiempo real (C1), consultas repetidas respondidas a mano (C2), sin seña ni recordatorio (C3, C4). | Páginas "El problema" y "Causas de ineficiencia", Canva; diagrama del Árbol de Problemas, `docs/01-arbol-de-problemas.md` |
| Propuesta | 2 min | Bautista | Objetivo general: facilitar la gestión de turnos y consultas automatizando la carga de turnos, el registro de seña y las respuestas frecuentes. Qué hace el sistema, en criollo: cargar un turno en 3 pasos, un buscador que contesta precios y protocolos por palabra clave, seña simulada, recordatorio dentro del sistema, los RF Must de `docs/04-requerimientos.md`, sin nombrarlos por ID. Dos apartados: una terminal táctil en el instituto para que la paciente cargue su propio turno, y la PC de recepción para los turnos que llegan por teléfono. | Página "La propuesta: Dermalia", Canva; tabla de RF, `docs/04-requerimientos.md` |
| Demostración | 2 min | Nicolás | Recorrer los dos apartados en el maquetado: la terminal (paciente elige protocolo → horario → confirma y paga la seña) y la PC de recepción con el mismo flujo para un turno por teléfono, más la búsqueda de turnos por nombre, DNI o teléfono. Se recorre como una tarea de punta a punta, no pantalla por pantalla suelta. | Página "Cómo funciona", Canva; user flow y mockup, `docs/05-maquetado.md` |
| Transición | 0.5 min | Santiago | "Recorrimos los dos apartados, terminal y recepción, compartiendo la misma base. Ahora, los números: cómo sabemos que esto funciona." | Puente hablado entre "Cómo funciona" y "Éxito", sin diapositiva propia |
| Viabilidad | 1.5 min | Santiago | Los cuatro indicadores de éxito, medidos a las 4 semanas de uso: 296 horas liberadas por año en la recepción, 156 turnos recuperados por año, 18 de las 25 consultas diarias resueltas por el buscador sin intervención humana, y 60 superposiciones de agenda evitadas por año. | Página "Éxito", Canva; matriz completa, `docs/03-matriz-marco-logico.md` |
| Cierre | 0.5 min | Santiago | Este bimestre se formuló y se diseñó; el próximo arranca el desarrollo técnico sobre esta base ya trazada. Se pide al auditorio feedback sobre la propuesta de valor y la seña, antes de empezar a programar. | Página "Gracias", Canva |

## Preguntas anticipadas

Responde Santiago en la ronda de preguntas (coordina el Marco Lógico, es
quien mejor conoce cómo se conecta todo). Igual, **los 4 tienen que
conocer estas respuestas de memoria**: si a la cátedra le da por preguntarle
a otro integrante, no puede quedar en blanco.

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

**¿Por qué una terminal y no que la paciente reserve desde su celular?**
Porque el stack real del equipo es C + SQL Server + Qt de escritorio, sin
web y sin API externa: un self-service remoto necesita un canal web que
el equipo no tiene. Una terminal táctil dentro del instituto sí es Qt
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
catálogo de protocolos, el modelo de los dos apartados) se cerraron como
decisión de equipo en vez de quedar abiertas esperando un relevamiento
que nunca iba a llegar, justamente para no perder tiempo del bimestre
corto.

**¿Por qué está todo simulado en vez de conectado a un servicio real?**
Restricción del equipo: el backend se hace en C con SQL Server, el
frontend en Qt de escritorio, sin integraciones por API externa. El
buscador de precios y protocolos funciona por palabra clave contra una
tabla propia, la agenda vive en el sistema, y la seña se registra como un
estado (pagada/no pagada) que marca la recepción. La lógica de negocio
(30% de seña, derivación a WhatsApp sin coincidencia, recordatorio antes
del turno) queda igual, solo cambia la implementación.

### Preguntas técnicas y de proceso

**¿Qué pasa si dos personas reservan el mismo horario al mismo tiempo?**
El sistema solo muestra horarios que siguen disponibles al momento de
cargar el turno (RF-04); si dos pantallas leen la grilla en el mismo
instante, gana quien confirma primero y a la otra se le actualiza la
disponibilidad al instante. No es un escenario de alta concurrencia
distribuida: los dos apartados corren contra una sola base local del
instituto (RNF-09), no hay servidores en paralelo.

**¿Por qué SQL Server específicamente, y no otra base de datos?**
Es la tecnología que exige la restricción técnica del proyecto (RNF-11):
backend en C sobre SQL Server, sin excepción. No fue una comparación
contra otras bases (MySQL, PostgreSQL); es un dato de la consigna, no una
elección de diseño libre del equipo.

**¿Cómo protegen los datos de las pacientes?**
Nombre, DNI, teléfono y protocolo se guardan solo en la base local del
instituto, sin sincronizarse con ningún servicio externo (RNF-06). El
sistema tampoco maneja pagos reales ni datos de tarjeta: la seña es un
mock que solo cambia un estado (pagada/no pagada) en la base (RNF-05).

**¿Qué pasa si se corta internet o falla el sistema a mitad de un turno?**
Los dos apartados corren en local contra la base del instituto, sin
depender de internet (RNF-09), así que un corte de internet no los tira
abajo. Una caída del propio SQL Server sí frena el sistema: no hay un plan
de contingencia (backup, segundo servidor) definido todavía, queda fuera
del alcance de este bimestre.

**¿El sistema se podría usar en otro instituto, o está armado solo para Dermalia?**
La lógica (turnos, buscador, seña, recordatorio) es genérica; lo que está
a medida de Dermalia es el catálogo de protocolos, los precios y el monto
de seña. Adaptarlo a otro instituto implicaría recargar esos datos, no
reescribir el sistema.

**¿Qué pasa si un profesional cancela su disponibilidad después de que ya hay turnos cargados en ese horario?**
No está resuelto todavía: la disponibilidad (RF-03) se carga y edita en
el sistema, pero no hay una regla definida de qué pasa con los turnos ya
confirmados si el profesional bloquea ese horario después. Es un caso
borde que queda para la etapa de desarrollo del bimestre siguiente.

**¿Cómo se organizó el equipo para tener todo listo (documentos y Canva) a tiempo?**
Con roles fijos desde el 1 de septiembre (ver arriba) y las 6 piezas de la
Carpeta cerrándose en el orden que exige el Marco Lógico: no se puede
definir un requerimiento sin tener antes cerrada la MML, por ejemplo, así
que el orden de trabajo fue el mismo orden de los documentos.

## Qué falta

- Ensayar y cronometrar el guion completo, con los 4 integrantes.
- Ajustar los tiempos de cada bloque según el ensayo, la tabla de arriba es
  el reparto inicial, no una medición real todavía.
- Armar la presentación de Canva ("Proyecto Informático 1"), que es lo
  último que se arma en la Semana 7 real (ver
  `docs/plan-de-aprendizaje.md`): recorrido semana a semana de lo que se
  fue haciendo y los problemas que se encontraron, para usar como apoyo
  visual durante este guion.
