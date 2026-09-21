# Matriz de Marco Lógico (MML)

Propuesta 1, sistema de escritorio para Dermalia, Instituto de Estética
Médica. El Fin y el Propósito vienen directo de
`docs/02-arbol-de-objetivos.md` (Fines y Objetivo central); los
Componentes vienen de los objetivos específicos OE1-OE4; las Actividades,
de los medios M1-M4. Es la misma cadena, pasada a formato de matriz.

**Restricción técnica**: backend en C con SQL Server, frontend en Qt, sin
integraciones por API externa ni canal web. Cada Componente que antes
dependía de un tercero (pasarela de pago, calendario, IA) queda mockeado
dentro del propio sistema, se explica en el detalle de cada uno. El
sistema tiene dos apartados, los dos nativos en Qt: una terminal táctil en
el instituto que opera la paciente (self-service presencial, no remoto) y
la PC de recepción que opera el instituto (`docs/04-requerimientos.md`
tiene el detalle por apartado). Los cuatro Componentes son los mismos
para los dos, solo cambia quién entra por cada pantalla.

## La matriz

| Nivel | Resumen narrativo | Indicadores (IOV) | Medios de verificación | Supuestos |
|---|---|---|---|---|
| Fin | Contribuir al crecimiento y sostenibilidad de Dermalia, mejorando su capacidad de atender y retener pacientes frente a la competencia de la zona. | Aumento de la facturación mensual del instituto. Sin meta numérica para este bimestre: es impacto de largo plazo, no se logra apenas el sistema entra en uso. | Comparación de facturación mensual del instituto, a evaluar en bimestres posteriores. | El sector de estética médica de la zona mantiene condiciones de demanda estables. Riesgo medio: el rubro es sensible al consumo. |
| Propósito | El uso del sistema de reserva, registro de seña, recordatorios y respuestas ágiles reduce la carga operativa de la recepción y la pérdida de turnos de Dermalia. Redactado como hipótesis: que esto ocurra depende también de que la recepción adopte el sistema como herramienta principal, no solo de que el equipo lo entregue. | Reducción del 60% en el tiempo diario de atención manual (de 95 a 38 min/día). Reducción del 50% en turnos perdidos por inasistencia (de 6 a 3/semana). 0 superposiciones de agenda por mes (de 5 actuales). ≥ 70% de consultas resueltas con el buscador interno, sin buscar a mano o de memoria. Todos medidos a las 4 semanas de uso del sistema. | Panel de reportes del sistema (turnos, consultas resueltas por el buscador) y encuesta breve a la recepción antes/después. | La recepción adopta el sistema como herramienta principal de gestión y deja de anotar turnos a mano en paralelo. Riesgo alto: es la condición de la que depende todo lo demás. |
| Componentes | R1. Módulo de reserva con agenda propia (SQL Server), sin sincronización externa: la paciente lo usa desde la terminal y la recepción desde su PC. | 0 superposiciones de turno por mes, medido las 4 semanas posteriores al lanzamiento (línea de base: 5/mes). | Registro de reservas del sistema (logs de agenda). | La recepción mantiene la disponibilidad real actualizada en el sistema. Riesgo medio. |
| | R2. Buscador de preguntas frecuentes por palabra clave (precios y protocolos, contra una base propia), disponible en la terminal para la paciente y en la PC para que la recepción responda por teléfono. | Reducción del tiempo diario de atención manual de 95 a 38 minutos (-60%) a las 4 semanas de uso. | Encuesta breve a la recepción, antes/después, sobre minutos dedicados a WhatsApp. | La paciente usa el buscador de la terminal y la recepción el propio, en vez de responder todo de memoria. Riesgo medio; mitigación: capacitación breve al iniciar y base de precios cargada desde el primer día. |
| | R3. Registro de seña simulado (mock, sin pasarela de pago real): lo marca la paciente en la terminal o la recepción al confirmar el turno por teléfono. | Reducción de turnos perdidos por inasistencia de 6 a 3 por semana (-50%) a las 4 semanas de uso. | Registro de asistencias/inasistencias del sistema. | Las pacientes aceptan pagar la seña al reservar. Riesgo medio: ≈10% de pacientes nuevas podría dudar. |
| | R4. Recordatorio de turno simulado (visible en el sistema, sin envío real por WhatsApp/email): la paciente lo ve al buscar su turno en la terminal, la recepción lo usa para avisar por teléfono si hace falta. | ≥ 70% de los turnos con recordatorio generado y confirmado antes de la fecha, a las 4 semanas de uso. | Logs de recordatorios del sistema. | La paciente revisa la terminal o la recepción avisa a tiempo. Riesgo medio. |
| Actividades | Ver detalle por componente abajo. No se listan las 40 tareas acá: la MML se queda con las principales. |, |, |, |

## Detalle de actividades por componente

R1, módulo de reserva con agenda propia:
- A.1.1 Diseñar la grilla de disponibilidad en tiempo real, contra la tabla
  de agenda de los profesionales en SQL Server.
- A.1.2 Implementar en el sistema la carga y edición de disponibilidad, que
  hace la recepción; no hay integración con Google Calendar ni ningún
  calendario externo, la agenda vive solo en el sistema.

R2, buscador interno de preguntas frecuentes:
- A.2.1 Armar la base de precios y protocolos que usa el buscador (tabla en
  SQL Server, cargada y editable por la recepción).
- A.2.2 Implementar en C el motor de búsqueda por palabra clave contra esa
  base, no hay modelo de lenguaje ni servicio de IA conectado.
- A.2.3 Definir el punto de derivación a WhatsApp del instituto (un enlace
  `wa.me`, no un envío automático) cuando el buscador no encuentra
  coincidencia, para que la recepción escale la consulta.

R3, registro de seña simulado (mock):
- A.3.1 Implementar en el sistema un flujo de seña simulada, disponible
  en los dos apartados: la paciente lo confirma en la terminal o la
  recepción marca el pago como recibido (efectivo o transferencia ya
  confirmada por fuera del sistema), el sistema registra el estado como
  pagado, sin procesar dinero real ni conectarse a ninguna pasarela.
- A.3.2 Seña del 30% del valor del protocolo (mínimo $5.000); reembolsable
  100% si se cancela con más de 24 h de anticipación, no reembolsable por
  debajo de ese plazo o por inasistencia. Decisión de equipo, no dato
  relevado: no hay una recepción real de Dermalia a quien consultarle. Como
  todo el registro es mock, el "reembolso" también es un cambio de estado
  en el sistema, no una devolución de dinero real.

R4, recordatorio de turno simulado:
- A.4.1 Generar el recordatorio dentro del sistema (visible para la
  recepción en la búsqueda de turnos) con la anticipación configurada, no
  hay envío real por WhatsApp ni email, sería una integración externa.
- A.4.2 Definir el tiempo de anticipación con el que se genera el
  recordatorio.

## Chequeo de cierre

Propósito único: sí, uno solo (reducir carga operativa y pérdida de turnos).

Cada Componente se desprende de un medio del Árbol de Objetivos: sí, R1←M1,
R2←M2, R3←M3, R4←M4 (ver tabla de conversión en `docs/02-arbol-de-objetivos.md`).

Riesgo alto sin mitigación: el supuesto del Propósito (adopción del sistema
como herramienta principal de la recepción) es alto y es el que más pesa; es
el mismo riesgo de "Adopción" ya anotado en `docs/propuestas.md`. Mitigación:
no reemplazar el cuaderno/WhatsApp de un día para el otro, sino acompañar la
transición con capacitación breve hasta que el hábito cambie.

## Qué falta

- Con la MML cerrada, pasar a `docs/04-requerimientos.md`: cada Componente
  (R1-R4) se abre en requerimientos funcionales (RF-01...), y cada
  supuesto/riesgo con mitigación técnica en requerimientos no funcionales
  (RNF-01...).
