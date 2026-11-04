# Análisis de competencia y ventaja competitiva (Semana 4)

Informe de la Semana 4 del plan de la cátedra (`plan-4to-bimestre.md`):
benchmarking, matriz comparativa de funcionalidades y costos, y la propuesta
única de valor (PUV) de Dermalia. Lo consulté el **3 de noviembre de 2026**.

**Regla de este informe:** cada precio o función de un competidor lleva su
fuente. Lo que no se pudo confirmar dice **"a verificar"** y no se supone. Los
precios cambian y varían por país: antes del Demo Day hay que mirar de nuevo la
web oficial de cada uno (o pedir cotización). Las cuentas con precios están
hechas con **precio de lista, en dólares y sin impuestos**; son una referencia,
no un presupuesto.

## 1. Competidores indirectos: lo que el instituto usa hoy

Son las alternativas que la recepción tiene a mano sin comprar nada. Sirven
para entender por qué el problema existe (datos del Árbol de Problemas y de la
MML, `docs/01-arbol-de-problemas.md` y `docs/03-matriz-marco-logico.md`).

| Alternativa actual | Qué resuelve | Por qué no alcanza (dato del equipo) |
|---|---|---|
| **WhatsApp** para pedir y cambiar turnos | Es gratis y las pacientes ya lo usan | La recepción dedica **95 min/día** a contestar y repetir consultas; no se integra a la agenda |
| **Agenda en papel** | No requiere nada técnico | Hay **5 superposiciones de turno por mes**; no avisa ni recuerda nada |
| **Planilla de cálculo** | Ordena precios y turnos | Se actualiza a mano, la editan varias personas, no tiene seña ni recordatorios |
| **Memoria de la recepción** | Respuesta inmediata a precios | Se contesta distinto según quién atienda; **6 turnos por semana** se pierden por inasistencia (≈ $900.000/semana con un ticket de $150.000, supuesto del equipo) |

## 2. Competidores directos

Cuatro sistemas de turnos que hoy ofrecen servicios parecidos a centros de
estética o de salud. Todos son **abonos mensuales** que se pagan mientras se use
el servicio.

| Sistema | Qué es | Precio de lista consultado | Fuente |
|---|---|---|---|
| **AgendaPro** | Software de agenda y gestión (clientes, finanzas, inventario), con versión para Argentina. Lo usan más de 135.000 profesionales según su web | **No publicado en la página argentina** consultada. Una reseña de terceros dice "desde USD 19 por mes" en el plan básico (dato de terceros, **a verificar**) | [agendapro.com/ar](https://agendapro.com/ar/negocios/software-para-negocios), [reseña de Medesk](https://www.medesk.net/es/blog/agenda-pro-review/) |
| **Fresha** | Agenda y marketplace para salones y estética | Desde **USD 19,95/mes** (un profesional) o **USD 14,95/mes por profesional** en el plan de equipo. Además **20% de comisión (mínimo USD 6)** por cada paciente nueva que llega por su marketplace, costo de procesar tarjetas y complementos: programa de fidelidad USD 59,95/mes, reportes USD 9,95/mes | [Capterra](https://www.capterra.com/p/142138/Shedul-com/pricing/), [Costbench](https://www.costbench.com/software/salon-spa/fresha/) |
| **Booksy** | Agenda para belleza y bienestar | **USD 29,99/mes + USD 20/mes por cada integrante adicional**; procesar tarjetas 2,49% + USD 0,10; marketing ("Boost") desde USD 49,99/mes | [Booksy (EE. UU.)](https://biz.booksy.com/en-us/pricing), [Koalendar](https://koalendar.com/blog/booksy-pricing) |
| **Doctoralia (plan profesional)** | Agenda médica con reserva online 24 h y varias consultas | **EUR 69/mes por especialista** y **EUR 129/mes para clínicas** (precios de España en Capterra; **el de Argentina, a verificar**) | [Capterra](https://www.capterra.com/p/253301/Doctoralia-Pro/pricing/) |
| **XIAgenda** (Argentina) | Agenda para consultorios | Desde **USD 15 por profesional por mes** (plan Esencial) | [Comparasoftware](https://www.comparasoftware.com/xiagenda) |

### Lo que cuesta para el tamaño de Dermalia

El instituto del proyecto tiene **20 profesionales** (los de los datos de
ejemplo). Con los precios de lista de arriba, **sin impuestos ni complementos**:

| Sistema | Cuenta | Por mes | Por año |
|---|---|---|---|
| Fresha (plan de equipo) | 20 × USD 14,95 | USD 299 | USD 3.588 |
| Booksy | USD 29,99 + 19 × USD 20 | USD 410 | USD 4.919 |
| XIAgenda (Esencial) | 20 × USD 15 | USD 300 | USD 3.600 |
| Doctoralia (clínicas) | EUR 129 (precio de España) | EUR 129 | EUR 1.548 |
| AgendaPro | a verificar | a verificar | a verificar |

Dos aclaraciones para no engañarse: (1) Doctoralia para clínicas parece más
barato, pero está en euros, es el precio de otro país y no sabemos qué incluye;
(2) en todos los casos el abono **no incluye** lo que Dermalia necesita y
resuelve por sí mismo (ver 3).

## 3. Matriz comparativa de funcionalidades

Se marca **Sí** solo cuando la fuente consultada lo dice; **a verificar** cuando
la información pública que encontré no alcanza para afirmarlo ni negarlo. Las
columnas de competidores resumen lo que pude confirmar de cada uno.

| Función que necesita el instituto | Dermalia | AgendaPro | Fresha | Booksy | Doctoralia |
|---|---|---|---|---|---|
| Agenda con horarios disponibles en tiempo real | Sí (RF-04) | Sí (agenda, según su web) | a verificar | a verificar | Sí (reserva online 24 h) |
| Varios profesionales y varios protocolos en un turno | Sí (RF-01, RF-18) | a verificar | a verificar | a verificar | Sí (varias consultas) |
| Terminal táctil en el local para que la paciente cargue su turno | **Sí** (apartado Cliente) | a verificar | a verificar | a verificar | a verificar |
| Seña con porcentaje por categoría y reembolso según el plazo | **Sí**, 30% / 40% en cirugías, 100% con más de 24 h (RF-10) | a verificar | a verificar | a verificar | a verificar |
| **Consulta previa obligatoria para cirugías**, con evaluación apta que vale 6 meses y retención del 10% / 50% (RF-25) | **Sí** | a verificar | a verificar | a verificar | a verificar |
| Cupones por fidelidad (visitas o gasto) con **código y QR que cambian cada 5 minutos** | **Sí** (RF-22, RF-24) | a verificar | Programa de fidelidad (complemento de USD 59,95/mes) | a verificar | a verificar |
| Tarjetas de regalo por monto, con saldo, que se gastan en varios turnos | **Sí** (RF-23) | a verificar | a verificar | a verificar | a verificar |
| Asistente de IA que no recibe datos personales y deriva a una persona | **Sí** (RF-14, RNF-06, RNF-10) | a verificar | a verificar | a verificar | a verificar |
| Registro de auditoría (quién, qué, cuándo) consultable por fechas | **Sí** (RF-20) | a verificar | a verificar | a verificar | a verificar |
| Modo contingencia sin internet | **Sí** (RNF-09) | a verificar | a verificar | a verificar | a verificar |
| Los datos del instituto están en una base que controla el instituto | **Sí** (MySQL propia) | no: base del proveedor | no: base del proveedor | no: base del proveedor | no: base del proveedor |
| Comisión por paciente nueva | No | a verificar | **Sí**, 20% (mín. USD 6) | a verificar | a verificar |
| Costo | Pago único + soporte (ver `08-presupuesto.md`) | abono | abono + comisión | abono por integrante | abono por especialista |

**Cómo se llena lo que falta.** La mayoría de las celdas "a verificar" se
resuelven en media hora con la demo gratuita de cada producto o con su ayuda
online. Es una tarea concreta antes del Demo Day: abrir cada demo, probar si
tienen consulta previa, seña por categoría, tarjetas de regalo y terminal, y
completar esta tabla con captura de pantalla como fuente. Hasta entonces la
diferencia real que sostenemos es la de las filas donde Dermalia tiene "Sí" y
la información pública de los otros no menciona la función.

## 4. Propuesta única de valor (PUV)

> **Un solo sistema para un instituto de estética médica: la paciente reserva
> sola (terminal del local o web), la recepción atiende por teléfono desde la
> misma agenda, y las reglas del negocio —seña, cirugías con consulta previa,
> cupones y tarjetas de regalo— las hace cumplir la base de datos, que es del
> instituto.**

Por qué un inversor o el instituto lo elegiría:

1. **Está hecho para este negocio.** Las plataformas de agenda son genéricas
   (peluquerías, consultorios). La regla de las cirugías —consulta previa paga,
   evaluación apta que vale 6 meses, devolución al pasar a la cirugía, retención
   del 10% si no es apta— es un proceso real del instituto que no encontramos
   descrito en la documentación pública de los competidores.
2. **Resuelve los cuatro problemas medidos.** Cada función sale de una causa del
   Árbol de Problemas: agenda propia (superposiciones), buscador y asistente
   (95 min/día de consultas), seña simulada (turnos perdidos) y recordatorios.
3. **Sin abono por profesional ni comisiones por paciente.** Con 20
   profesionales los competidores cuestan entre USD 3.600 y USD 4.900 por año
   solo de abono (sección 2); Dermalia es un pago único más un soporte
   opcional.
4. **Los datos son del instituto.** Reglas, auditoría y respaldos viven en una
   base MySQL propia (Aiven), no en la de un tercero.
5. **Seguridad de las reglas.** Cupón y tarjeta no se mezclan, un cupón se usa
   una vez, el código del cupón cambia cada 5 minutos, y todo queda en un log
   que solo escriben los stored procedures.

## 5. Limitaciones del informe

- Los precios salen de páginas oficiales y de sitios de comparación (Capterra,
  Costbench, Comparasoftware) vistos a través de un buscador, no de una demo.
  Los de Doctoralia son de España. Los de AgendaPro no se publican en la página
  argentina.
- No probamos ninguno de los productos: las filas marcadas "a verificar"
  pueden resultar "Sí" en algún competidor.
- El ticket promedio ($150.000), el costo de los turnos perdidos y los 95
  minutos diarios son supuestos y mediciones del equipo (`docs/01-arbol-de-problemas.md`).
- Dermalia todavía no tiene usuarios reales: las ventajas son de diseño y de
  costo, no de resultados medidos.
