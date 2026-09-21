# Árbol de Problemas

Diagnóstico de la problemática elegida: Propuesta 1, sistema de escritorio
para un instituto de estética médica (ver `docs/propuestas.md`,
comparación de las cinco propuestas en carrera).

Dermalia es un caso imaginario. No hay relevamiento real ni entrevista
posible; los datos de partida los inventa el equipo a propósito. El
ejercicio es armar la Carpeta de Proyecto completa igual, con la misma
disciplina metodológica que si el caso fuera real.

## Contexto y actores

La problemática es la gestión de turnos y consultas de Dermalia, Instituto
de Estética Médica, barrio de Flores, CABA, a 2026.

Grupos a considerar (según la cátedra, no alcanza con pensar solo desde el
equipo, aunque acá se imaginan en vez de relevarse):

- Beneficiarios directos: el instituto y su equipo de recepción (menos
  carga operativa, menos horas perdidas en WhatsApp).
- Beneficiarios indirectos: pacientes actuales y potenciales (turnos
  confirmados sin demoras, menos reprogramaciones por superposición).
- Posibles detractores: pacientes habituales acostumbradas al trato
  directo por WhatsApp, que podrían resistirse a que se les pida una seña
  formal al reservar (riesgo ya anotado en `propuestas.md`).
- Ejecutores: el equipo del proyecto.

## Problema central

La gestión de turnos y consultas de Dermalia depende de la atención manual
de la recepción por WhatsApp, lo que consume horas de trabajo, produce
superposiciones y turnos perdidos, y demora las respuestas a quienes
consultan (Dermalia, barrio de Flores, CABA, a 2026).

No es "no hay una app de turnos" (el error más común al formular esta
etapa): es la carga de trabajo y la pérdida de turnos que ya existen hoy,
con o sin sistema.

## Diagrama

```mermaid
flowchart TB
    E4[E4: Menor rentabilidad y<br/>crecimiento limitado del instituto]
    E5[E5: Pacientes potenciales eligen<br/>competidores con atención más ágil]
    E1[E1: La recepción dedica horas del día<br/>a responder consultas repetidas]
    E2[E2: Se pierden turnos e ingresos<br/>por superposición e inasistencia]
    E3[E3: Las consultas tardan en<br/>resolverse y se desiste de reservar]

    P["PROBLEMA CENTRAL<br/>La gestión de turnos y consultas depende<br/>de la atención manual de la recepción por WhatsApp"]

    C1[C1: No hay disponibilidad de<br/>horarios visible en tiempo real]
    C2[C2: Las consultas repetitivas se<br/>responden una por una, a mano]
    C3[C3: No se cobra ni confirma<br/>seña al reservar]
    C4[C4: No hay recordatorio<br/>automático de turno]

    C1_1[C1.1: WhatsApp no está integrado<br/>con ninguna agenda digital]
    C2_1[C2.1: No existe una base de<br/>respuestas para precios/protocolos]
    C3_1[C3.1: Cobrar seña hoy exige gestión<br/>manual de transferencias]
    C4_1[C4.1: La recepción no tiene tiempo de<br/>avisar turno a cada paciente a mano]

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
| C1 | No hay disponibilidad de horarios visible en tiempo real | Directa | 5 superposiciones de turno por mes |
| C1.1 | WhatsApp no está integrado con ninguna agenda digital | Indirecta (raíz) | El 97% usa WhatsApp a diario y el 58% para consultas comerciales, el canal satura porque no está conectado a nada más ([estudio WhatsApp](https://dialecto.com/blog/whatsapp-marketing/estudio-impacto-de-whatsapp-en-compras/)) |
| C2 | Las consultas repetitivas se responden una por una, a mano | Directa | 95 minutos diarios dedicados a responder consultas, línea de base del indicador principal |
| C2.1 | No existe una base de respuestas para precios/protocolos | Indirecta (raíz) | De 25 consultas por WhatsApp por día, un 70% (≈18) son repetidas (precio, duración, "¿qué incluye el protocolo?") |
| C3 | No se cobra ni confirma seña al reservar | Directa | Centros en España redujeron inasistencias cobrando por adelantado ([Cuatro](https://www.cuatro.com/noticias/economia/20250116/reservas-fantasma-centros-estetica-peluquerias_18_014508640.html)); hoy Dermalia no cobra seña |
| C3.1 | Cobrar seña hoy exige gestión manual de transferencias | Indirecta (raíz) | La recepción estima que un 10% de pacientes nuevas podría dudar frente a una seña obligatoria; las habituales no la resistirían |
| C4 | No hay recordatorio automático de turno | Directa | Recordatorios automáticos redujeron inasistencias 50% en un caso documentado ([WhatsApp Business API](https://developargentina.com/blog/whatsapp-business-api-argentina-automatizacion-ventas-2025)) |
| C4.1 | La recepción no tiene tiempo de avisar turno a cada paciente a mano | Indirecta (raíz) | 6 turnos/semana perdidos por inasistencia, ≈ $120.000/semana (precio promedio de protocolo, $20.000) |

## Tabla de efectos

| # | Efecto | Tipo |
|---|---|---|
| E1 | La recepción dedica horas del día a responder consultas repetidas en vez de atender pacientes | Directo |
| E2 | Se pierden turnos e ingresos por superposición e inasistencia | Directo |
| E3 | Las consultas tardan en resolverse y se desiste de reservar | Directo |
| E4 | Menor rentabilidad y crecimiento limitado del instituto | Indirecto (final) |
| E5 | Pacientes potenciales eligen competidores con atención más ágil | Indirecto (final) |

## Verificación de la lógica causal

Leído de corrido: WhatsApp no está integrado con ninguna agenda (C1.1), así
que no hay disponibilidad visible en tiempo real (C1). Eso hace que la
gestión de turnos dependa de la atención manual de la recepción (problema
central). Por eso la recepción pierde horas respondiendo, se pierden turnos
por superposición (E1, E2), y baja la rentabilidad del instituto (E4). La
cadena se sostiene leída en voz alta, que es la regla de la cátedra.

## Qué causas se atacan con software y cuáles quedan fuera

Se atacan con el sistema, y justifican la propuesta:

- C1 / C1.1 → módulo de reserva con agenda propia, cargada por la
  recepción directo en el sistema (sin sincronizar con ningún calendario
  externo).
- C2 / C2.1 → buscador interno de precios y protocolos por palabra clave,
  que la recepción usa para responder consultas rápido, contra una base
  propia, en vez de buscarlas de memoria o en papel.
- C3 / C3.1 → registro de seña simulado (mock): la recepción marca el
  estado de pago al confirmar el turno, sin procesar dinero real.
- C4 / C4.1 → recordatorio de turno simulado, visible para la recepción
  dentro del sistema.

**Restricción técnica del equipo**: backend en C con SQL Server, frontend
en Qt (aplicación de escritorio, sin web y sin API externa). Por eso el
sistema no es un self-service que la paciente usa desde su celular: lo
opera la recepción en la PC del instituto, que carga los turnos que la
paciente pide por teléfono o en persona. Todo lo que en una versión con
más libertad técnica sería una conexión con un tercero (pasarela de pago,
calendario, inteligencia artificial) queda simulado dentro del propio
sistema: no hay Mercado Pago, Google Calendar ni un modelo de lenguaje
conectado.

Quedan fuera de alcance de este bimestre (ya anotado en `propuestas.md`):
historia clínica de tratamientos, gestión de stock de insumos, liquidación
de comisiones, app nativa, y un portal o app para que la paciente reserve
por su cuenta (self-service) — no es viable con la restricción técnica
actual (Qt de escritorio, sin web ni API), queda anotado como posible
iteración futura si el equipo suma un componente web. No se programa
nada: se formula y se diseña.

## Preguntas para la coevaluación cruzada

1. Leído de corrido (causas → problema central → efectos), ¿la secuencia se
   sostiene, o hay algún salto lógico que no se explica solo?
2. C1.1 y C2.1 nombran una solución ausente ("WhatsApp no está integrado",
   "no existe una base de respuestas") en vez de un estado negativo, ¿es
   un problema real, o para una causa raíz (no un problema central) da
   igual?
3. ¿El problema central sigue leyéndose como un problema y no como "falta
   una app"? Es la trampa más común de la metodología.

## Qué falta

- Nada pendiente propio de esta pieza. La revisión cruzada con otro equipo
  (Semana 2 del cronograma oficial) no se hizo y el equipo decidió no
  perseguirla: no hay otro equipo con quien intercambiarla en el tiempo
  que queda. Queda como limitación documentada, no como pendiente abierto.
  Los roles del equipo ya están formalizados como issues del repo
  (#1-#4), asignados el 1/9.
