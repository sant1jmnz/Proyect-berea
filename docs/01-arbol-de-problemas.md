# Árbol de Problemas

Diagnóstico de la problemática elegida: **Propuesta 1 — Aplicación web para
centro de estética integral** (ver `docs/propuestas.md`, comparación de las
cinco propuestas en carrera).

> ⚠️ **Aviso metodológico.** Las líneas de base numéricas de este documento
> están marcadas `[ESTIMADO]`: son cifras **inventadas por el equipo**, a
> falta todavía de la entrevista real con el dueño, para poder avanzar con el
> Árbol de Objetivos, la MML y el maquetado sin quedar bloqueados. **No son
> relevamiento propio y no se deben presentar como tal.** En cuanto se haga la
> entrevista, cada `[ESTIMADO]` se reemplaza por el dato real y se borra este
> aviso. Mientras tanto, cualquier indicador de la MML que dependa de estos
> números hereda la misma advertencia.

## Contexto y actores relevados

- **Problemática:** la gestión de turnos y consultas de un centro de estética
  integral, `[ESTIMADO]` **"Bella Piel — Centro de Estética Integral"**,
  barrio de Flores, CABA, a 2026.
- **Involucrados consultados hasta ahora:** ninguno todavía de forma directa.
  `[ESTIMADO — pendiente de reemplazar por la entrevista real]` — falta la
  primera entrevista con el dueño (ver "Qué falta" en `docs/bitacora.md`).
- **Grupos a considerar cuando se releve** (según la cátedra, no alcanza con
  el equipo solo):
  - **Beneficiarios directos:** el dueño del centro (menos carga operativa).
  - **Beneficiarios indirectos:** clientas y clientes actuales y potenciales
    (respuestas más rápidas, menos superposición de turnos).
  - **Posibles detractores:** clientas que hoy prefieren el trato directo por
    WhatsApp y podrían resistirse a un sistema con seña obligatoria (riesgo ya
    anotado en `propuestas.md`).
  - **Ejecutores:** el equipo del proyecto.

## Problema central

> **La gestión de turnos y consultas del centro de estética depende de la
> atención manual del dueño por WhatsApp, lo que consume horas de trabajo,
> produce superposiciones y turnos perdidos, y demora las respuestas a quienes
> consultan** (Bella Piel, barrio de Flores, CABA `[ESTIMADO]`, a 2026).

No es "no hay una app de turnos" (columna izquierda de la tabla mal/bien
formulado) — es la carga operativa y la pérdida de turnos que ya existen hoy,
con o sin sistema.

## Diagrama

```mermaid
flowchart TB
    E4[E4: Menor rentabilidad y<br/>crecimiento limitado del negocio]
    E5[E5: Clientes potenciales eligen<br/>competidores con atención más ágil]
    E1[E1: El dueño dedica horas del día<br/>a responder consultas repetidas]
    E2[E2: Se pierden turnos e ingresos<br/>por superposición e inasistencia]
    E3[E3: Las consultas tardan en<br/>resolverse y se desiste de reservar]

    P["PROBLEMA CENTRAL<br/>La gestión de turnos y consultas depende<br/>de la atención manual del dueño por WhatsApp"]

    C1[C1: No hay disponibilidad de<br/>horarios visible en tiempo real]
    C2[C2: Las consultas repetitivas se<br/>responden una por una, a mano]
    C3[C3: No se cobra ni confirma<br/>seña al reservar]
    C4[C4: No hay recordatorio<br/>automático de turno]

    C1_1[C1.1: WhatsApp no está integrado<br/>con ninguna agenda digital]
    C2_1[C2.1: No existe una base de<br/>respuestas para precios/protocolos]
    C3_1[C3.1: Cobrar seña hoy exige gestión<br/>manual de transferencias]
    C4_1[C4.1: El dueño no tiene tiempo de<br/>avisar turno a cada clienta a mano]

    E1 --> E4
    E2 --> E4
    E3 --> E5
    P --> E1
    P --> E2
    P --> E3
    C1 --> P
    C2 --> P
    C3 --> P
    C4 --> P
    C1_1 --> C1
    C2_1 --> C2
    C3_1 --> C3
    C4_1 --> C4
```

## Tabla de causas

| # | Causa | Tipo | Evidencia que la respalda |
|---|---|---|---|
| C1 | No hay disponibilidad de horarios visible en tiempo real | Directa | `[ESTIMADO]` 5 superposiciones de turno por mes |
| C1.1 | WhatsApp no está integrado con ninguna agenda digital | Indirecta (raíz) | El 97% usa WhatsApp a diario y el 58% para consultas comerciales — el canal satura porque no está conectado a nada más ([estudio WhatsApp](https://dialecto.com/blog/whatsapp-marketing/estudio-impacto-de-whatsapp-en-compras/)) |
| C2 | Las consultas repetitivas se responden una por una, a mano | Directa | `[ESTIMADO]` 95 minutos diarios dedicados a responder consultas — línea de base del indicador principal |
| C2.1 | No existe una base de respuestas para precios/protocolos | Indirecta (raíz) | `[ESTIMADO]` de 25 consultas por WhatsApp por día, un 70% (≈18) son repetidas (precio, horario, "¿qué incluye?") |
| C3 | No se cobra ni confirma seña al reservar | Directa | Centros en España redujeron inasistencias cobrando por adelantado ([Cuatro](https://www.cuatro.com/noticias/economia/20250116/reservas-fantasma-centros-estetica-peluquerias_18_014508640.html)) — `[ESTIMADO]` hoy Bella Piel no cobra seña |
| C3.1 | Cobrar seña hoy exige gestión manual de transferencias | Indirecta (raíz) | `[ESTIMADO]` el dueño estima que un 10% de clientas nuevas podría dudar frente a una seña obligatoria; las habituales no la resistirían |
| C4 | No hay recordatorio automático de turno | Directa | Recordatorios automáticos redujeron inasistencias 50% en un caso documentado ([WhatsApp Business API](https://developargentina.com/blog/whatsapp-business-api-argentina-automatizacion-ventas-2025)) |
| C4.1 | El dueño no tiene tiempo de avisar turno a cada clienta a mano | Indirecta (raíz) | `[ESTIMADO]` 6 turnos/semana perdidos por inasistencia, ≈ $48.000/semana |

## Tabla de efectos

| # | Efecto | Tipo |
|---|---|---|
| E1 | El dueño dedica horas del día a responder consultas repetidas en vez de atender clientas | Directo |
| E2 | Se pierden turnos e ingresos por superposición e inasistencia | Directo |
| E3 | Las consultas tardan en resolverse y se desiste de reservar | Directo |
| E4 | Menor rentabilidad y crecimiento limitado del negocio | Indirecto (final) |
| E5 | Clientes potenciales eligen competidores con atención más ágil | Indirecto (final) |

## Verificación de la lógica causal

Leído de corrido: *"Como WhatsApp no está integrado con ninguna agenda (C1.1),
no hay disponibilidad visible en tiempo real (C1); eso hace que la gestión de
turnos dependa de la atención manual del dueño (problema central); y por eso
el dueño pierde horas respondiendo y se pierden turnos por superposición
(E1, E2), lo que reduce la rentabilidad del negocio (E4)."* Se sostiene leída
en voz alta — cumple la regla de la cátedra.

## Qué causas se atacan con software y cuáles quedan fuera

**Se atacan con el sistema (justifican la propuesta):**
- C1 / C1.1 → módulo de reserva con disponibilidad en vivo + sincronización a
  Google Calendar.
- C2 / C2.1 → asistente virtual restringido por RAG a precios y protocolos.
- C3 / C3.1 → cobro de seña integrado con Mercado Pago.
- C4 / C4.1 → recordatorio automático (a definir si por WhatsApp o el propio
  sistema).

**Quedan fuera de alcance de este bimestre** (ya anotado en `propuestas.md`):
historia clínica de tratamientos, gestión de stock de insumos, liquidación de
comisiones, app nativa. No se programa nada: se formula y se diseña.

## Qué falta para cerrar este documento

- Confirmar la entrevista con el dueño del centro de estética.
- Reemplazar cada `[ESTIMADO]` de la tabla de causas por el dato real relevado
  en la entrevista — son las que después arman los indicadores de la MML, y
  hoy son inventados por el equipo, no medidos.
- Una vez relevado: releer el árbol completo con el dueño y ajustar causas si
  aparece algo que el equipo no consideró (la cátedra pide que el problema se
  registre como lo perciben los involucrados, no como lo interpreta el
  equipo). Si algún `[ESTIMADO]` resulta muy distinto del dato real, revisar
  también si la causa correspondiente sigue siendo válida.
