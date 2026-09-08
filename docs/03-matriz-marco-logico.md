# Matriz de Marco Lógico (MML)

Propuesta 1, aplicación web para Bella Piel — Centro de Estética Integral.
El Fin y el Propósito vienen directo de `docs/02-arbol-de-objetivos.md`
(Fines y Objetivo central); los Componentes vienen de los objetivos
específicos OE1-OE4; las Actividades, de los medios M1-M4. Es la misma
cadena, pasada a formato de matriz.

## La matriz

| Nivel | Resumen narrativo | Indicadores (IOV) | Medios de verificación | Supuestos |
|---|---|---|---|---|
| Fin | Contribuir al crecimiento y sostenibilidad del negocio de Bella Piel, mejorando su capacidad de atender y retener clientas frente a la competencia de la zona. | Aumento de la facturación mensual de Bella Piel. Sin meta numérica para este bimestre: es impacto de largo plazo, no se logra apenas el sistema entra en uso. | Comparación de facturación mensual del centro, a evaluar en bimestres posteriores. | El sector de estética de la zona mantiene condiciones de demanda estables. Riesgo medio: el rubro es sensible al consumo. |
| Propósito | El uso del sistema de reserva, cobro de seña, recordatorios y respuestas automatizadas reduce la carga operativa del dueño y la pérdida de turnos de Bella Piel. Redactado como hipótesis: que esto ocurra depende también de que las clientas adopten el canal, no solo de que el equipo entregue el sistema. | Reducción del 60% en el tiempo diario de atención manual (de 95 a 38 min/día). Reducción del 50% en turnos perdidos por inasistencia (de 6 a 3/semana). 0 superposiciones de agenda por mes (de 5 actuales). ≥ 70% de consultas resueltas sin intervención humana. Todos medidos a las 4 semanas de uso del sistema. | Panel de reportes del sistema (turnos, consultas resueltas por el asistente) y encuesta breve al dueño antes/después. | El dueño adopta el sistema como canal principal de reservas y deja de gestionar turnos por WhatsApp en paralelo. Riesgo alto: es la condición de la que depende todo lo demás. |
| Componentes | R1. Módulo de reserva con disponibilidad en tiempo real implementado y en uso. | 0 superposiciones de turno por mes, medido las 4 semanas posteriores al lanzamiento (línea de base: 5/mes). | Registro de reservas del sistema (logs de agenda). | El dueño mantiene su disponibilidad real actualizada en el sistema. Riesgo medio. |
| | R2. Asistente virtual de respuestas frecuentes (RAG sobre precios y protocolos) implementado y en uso. | Reducción del tiempo diario de atención manual de 95 a 38 minutos (-60%) a las 4 semanas de uso. | Encuesta breve al dueño, antes/después, sobre minutos dedicados a WhatsApp. | Las clientas usan el asistente en vez de escribir directo al dueño. Riesgo alto; mitigación: responder desde WhatsApp con el enlace al asistente. |
| | R3. Cobro de seña integrado con Mercado Pago implementado y en uso. | Reducción de turnos perdidos por inasistencia de 6 a 3 por semana (-50%) a las 4 semanas de uso. | Registro de asistencias/inasistencias del sistema. | Las clientas aceptan pagar la seña al reservar. Riesgo medio: ≈10% de clientas nuevas podría dudar. |
| | R4. Recordatorio automático de turno implementado y en uso. | ≥ 70% de los turnos con recordatorio enviado y confirmado antes de la fecha, a las 4 semanas de uso. | Logs de envío y confirmación del sistema. | El canal de envío (WhatsApp/email) está disponible de forma estable. Riesgo bajo. |
| Actividades | Ver detalle por componente abajo. No se listan las 40 tareas acá: la MML se queda con las principales. | — | — | — |

## Detalle de actividades por componente

R1, módulo de reserva con disponibilidad en tiempo real:
- A.1.1 Diseñar la grilla de disponibilidad en tiempo real.
- A.1.2 Integrar el calendario del sistema con el Google Calendar del dueño.

R2, asistente virtual de respuestas frecuentes:
- A.2.1 Armar la base de precios y protocolos que usa el asistente.
- A.2.2 Configurar el asistente con Gemini 2.5 Flash restringido por RAG a esa base.
- A.2.3 Definir el punto de derivación a WhatsApp del dueño cuando el asistente no puede responder.

R3, cobro de seña integrado con Mercado Pago:
- A.3.1 Integrar Mercado Pago al flujo de reserva.
- A.3.2 Seña del 30% del valor del servicio (mínimo $5.000); reembolsable
  100% si se cancela con más de 24 h de anticipación, no reembolsable por
  debajo de ese plazo o por inasistencia. Decisión de equipo, no dato
  relevado: no hay un dueño real de Bella Piel a quien consultarle.

R4, recordatorio automático de turno:
- A.4.1 Configurar el envío automático de recordatorio antes del turno.
- A.4.2 Definir el canal de envío (WhatsApp o el propio sistema) y el tiempo de anticipación.

## Chequeo de cierre

Propósito único: sí, uno solo (reducir carga operativa y pérdida de turnos).

Cada Componente se desprende de un medio del Árbol de Objetivos: sí, R1←M1,
R2←M2, R3←M3, R4←M4 (ver tabla de conversión en `docs/02-arbol-de-objetivos.md`).

Riesgo alto sin mitigación: el supuesto del Propósito (adopción del sistema
como canal principal) es alto y es el que más pesa; es el mismo riesgo de
"Adopción" ya anotado en `docs/propuestas.md`. Mitigación: no reemplazar
WhatsApp de un día para el otro, sino responder desde ahí con el enlace al
sistema hasta que el hábito cambie.

## Qué falta

- Con la MML cerrada, pasar a `docs/04-requerimientos.md`: cada Componente
  (R1-R4) se abre en requerimientos funcionales (RF-01...), y cada
  supuesto/riesgo con mitigación técnica en requerimientos no funcionales
  (RNF-01...).
