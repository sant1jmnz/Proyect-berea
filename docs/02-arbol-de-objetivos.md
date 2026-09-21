# Árbol de Objetivos

Espejo en positivo del Árbol de Problemas (`docs/01-arbol-de-problemas.md`),
construido con la tabla de conversión estándar de la metodología: efectos →
fines, problema central → objetivo central, causas directas → objetivos
específicos, causas raíz → medios. También está armado en post-its en el
board de Miro "Proyecto informático 1", al lado del Árbol de Problemas.

## Objetivo central

Facilitar la gestión de turnos y consultas de Dermalia, Instituto de
Estética Médica, mediante un sistema que automatice la reserva, el cobro de
seña y las respuestas frecuentes, liberando el tiempo de la recepción y
reduciendo los turnos perdidos (barrio de Flores, CABA, a 2026).

Es el mismo problema central del árbol anterior, reescrito en infinitivo y en
positivo: no es un objetivo distinto, es su conversión directa.

## Diagrama

```mermaid
flowchart TB
    F4[F4: Aumentar la rentabilidad y<br/>el crecimiento del instituto]
    F5[F5: Atraer pacientes potenciales<br/>con atención más ágil]
    F1[F1: Liberar tiempo de la recepción<br/>para atender pacientes]
    F2[F2: Eliminar la pérdida de turnos<br/>e ingresos por superposición e inasistencia]
    F3[F3: Resolver las consultas rápido<br/>y concretar la reserva]

    O["OBJETIVO CENTRAL<br/>Facilitar la gestión de turnos y consultas<br/>con un sistema que automatice reserva, seña y respuestas"]

    OE1[OE1: Contar con disponibilidad<br/>de horarios visible en tiempo real]
    OE2[OE2: Automatizar las respuestas<br/>a consultas repetitivas]
    OE3[OE3: Cobrar y confirmar<br/>seña al reservar]
    OE4[OE4: Enviar recordatorio<br/>automático de turno]

    M1[M1: Integrar WhatsApp<br/>con una agenda digital]
    M2[M2: Contar con una base de<br/>respuestas para precios/protocolos]
    M3[M3: Registrar el cobro de seña<br/>sin gestión manual de transferencias]
    M4[M4: Automatizar el aviso de turno<br/>sin depender de la recepción]

    F1 --> F4
    F2 --> F4
    F3 --> F5
    O --> F1
    O --> F2
    O --> F3
    OE1 --> O
    OE2 --> O
    OE3 --> O
    OE4 --> O
    M1 --> OE1
    M2 --> OE2
    M3 --> OE3
    M4 --> OE4
```

## Tabla de conversión aplicada

| Árbol de Problemas | Árbol de Objetivos | Fechado (meta a 2026, Dermalia) |
|---|---|---|
| C1: No hay disponibilidad de horarios visible en tiempo real | OE1: Contar con disponibilidad de horarios visible en tiempo real | De 5 a 0 superposiciones de turno por mes |
| C1.1: WhatsApp no integrado a agenda digital | M1: Integrar WhatsApp con una agenda digital |, (actividad, no lleva indicador propio) |
| C2: Consultas repetitivas respondidas una por una, a mano | OE2: Automatizar las respuestas a consultas repetitivas | De 95 a 38 minutos diarios de atención manual (-60%) |
| C2.1: No existe base de respuestas para precios/protocolos | M2: Contar con una base de respuestas para precios/protocolos |, |
| C3: No se cobra ni confirma seña al reservar | OE3: Cobrar y confirmar seña al reservar | De 6 a 3 turnos perdidos por semana (-50%) |
| C3.1: Cobrar seña exige gestión manual de transferencias | M3: Registrar el cobro de seña sin gestión manual de transferencias |, |
| C4: No hay recordatorio automático de turno | OE4: Enviar recordatorio automático de turno | Contribuye a la misma meta de OE3 (turnos perdidos) |
| C4.1: La recepción no tiene tiempo de avisar turno a mano | M4: Automatizar el aviso de turno sin depender de la recepción |, |
| E1: La recepción pierde horas respondiendo consultas | F1: Liberar tiempo de la recepción para atender pacientes |, (fin, no se mide en el bimestre) |
| E2: Se pierden turnos e ingresos | F2: Eliminar la pérdida de turnos e ingresos |, |
| E3: Las consultas tardan y se desiste de reservar | F3: Resolver las consultas rápido y concretar la reserva |, |
| E4: Menor rentabilidad y crecimiento limitado | F4: Aumentar la rentabilidad y el crecimiento del instituto |, |
| E5: Pacientes eligen la competencia | F5: Atraer pacientes potenciales con atención más ágil |, |

## Adónde va cada nodo en la MML

Según la tabla de conversión estándar: los objetivos específicos (OE1-OE4)
son los candidatos a Componentes, los medios (M1-M4) son las Actividades
que producen cada componente, y los fines directos (F1-F3) son el Fin de
la matriz. El objetivo central es el Propósito.

## Verificación de la lógica

Leído de corrido: si se integra WhatsApp con una agenda digital (M1), hay
disponibilidad de horarios en tiempo real (OE1). Eso facilita la gestión de
turnos y consultas (objetivo central), libera tiempo de la recepción y
elimina la pérdida de turnos (F1, F2), y en conjunto aumenta la rentabilidad
del instituto (F4). La cadena se sostiene leída en voz alta.

## Preguntas para la coevaluación cruzada

1. Cada medio (M1-M4) es una acción concreta, no un estado, ¿alguno
   describe en realidad un resultado en vez de la actividad que lo produce?
2. El objetivo central es la conversión directa del problema central,
   reescrito en infinitivo, ¿esa reescritura mantiene el mismo alcance, o
   se coló una ambición nueva que el problema no planteaba?
3. ¿Los cuatro objetivos específicos alcanzan para sostener el objetivo
   central, o falta alguno que el Árbol de Problemas sí tenía como causa
   directa?

## Qué falta

- Pasar por la revisión cruzada con otro equipo, junto con
  `docs/01-arbol-de-problemas.md` (Semana 2 del cronograma oficial,
  Semana 7 real — `docs/plan-de-aprendizaje.md`): todavía no se hizo.
