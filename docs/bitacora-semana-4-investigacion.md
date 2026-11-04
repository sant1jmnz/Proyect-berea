# Bitácora de la investigación de la Semana 4 (competencia)

Registro de **cómo se hizo la investigación** del análisis de competencia, no del informe en sí (el
resultado está en [`07-competencia.md`](07-competencia.md)). Sirve para saber qué se buscó, qué se
encontró, qué no, y qué hay que volver a verificar.

- **Fecha de la investigación:** martes 3 de noviembre de 2026.
- **Quién la hizo:** el asistente Claude, a pedido del equipo, con un buscador web. **No la hicieron
  Santiago ni Bautista ni se probó ningún producto**: si la bitácora se entrega como propia, hay que
  repetir la verificación (ver "Pendiente") y firmarla con lo que cada uno compruebe.
- **Qué pide el plan:** Semana 4, *Análisis de mercado, competencia y ventaja competitiva*: relevar
  software existente (competidores directos e indirectos), armar una matriz comparativa de funcionalidades
  y costos, e identificar la propuesta única de valor (`plan-4to-bimestre.md`).
- **Reparto del equipo:** Santiago, competidores indirectos, PUV e informe; Bautista, competidores
  directos y matriz (`reparto-4to-bimestre.md`). Se juntó todo en un solo informe.
- **Regla fijada antes de empezar:** cada precio o función de un competidor lleva su fuente; lo que no se
  pueda confirmar se marca **"a verificar"** y no se supone.

## 1. Qué se hizo, paso a paso

1. **Competidores indirectos.** No hizo falta buscar afuera: salen de lo que ya está medido en el
   proyecto (Árbol de Problemas y MML). WhatsApp, agenda en papel, planilla y memoria de la recepción,
   con sus números: 95 min/día, 5 superposiciones por mes, 6 turnos perdidos por semana.
2. **Elegir qué competidores directos buscar.** Se partió de lo que usa un centro de estética o de salud
   para turnos: AgendaPro (tiene versión argentina), Fresha y Booksy (belleza), Doctoralia (agenda médica).
3. **Cuatro búsquedas** (tabla de abajo). De la última salió un quinto competidor, **XIAgenda**, que
   no se buscó por separado.
4. **Lectura de los resultados** y anotación de la fuente de cada dato.
5. **Cuentas** para el tamaño del instituto (20 profesionales) con los precios de lista.
6. **Matriz de funcionalidades** y redacción de la propuesta única de valor con lo que Dermalia ya tiene
   hecho (cirugías con consulta previa, seña por categoría, cupones con token, tarjetas de regalo, etc.).

## 2. Registro de búsquedas

| N.º | Consulta | Qué devolvió | Qué se usó |
|---|---|---|---|
| 1 | `AgendaPro precios planes software agenda centros de estética Argentina` | La página argentina de AgendaPro (agenda, clientes, finanzas, inventario; "más de 135.000 profesionales") **sin montos**; planes de México en pesos mexicanos; una nota de una ronda de inversión que menciona expansión en Argentina | Solo la descripción de AgendaPro. **El precio argentino no apareció** |
| 2 | `Fresha pricing salon software subscription fees per month` | Varias páginas de comparación (Capterra, Costbench, reseñas): desde USD 19,95 por mes para un profesional o USD 14,95 por profesional en el plan de equipo; comisión del 20% (mínimo USD 6) por pacientes nuevas del marketplace; programa de fidelidad USD 59,95/mes; cambio de precios en febrero de 2026 | Precios de lista y comisión (ver fuentes en `07`) |
| 3 | `Booksy pricing plans per month beauty business software` | La página oficial de Booksy EE. UU. (USD 29,99/mes + USD 20 por integrante adicional), guías de terceros, tarifas por país, procesamiento de tarjetas 2,49% + USD 0,10, "Boost" desde USD 49,99/mes | Los datos de la página oficial; las guías de terceros solo para confirmar |
| 4 | `Doctoralia Agenda software turnos médicos Argentina precio plan` | Doctoralia Pro: EUR 69/mes por especialista y EUR 129/mes para clínicas (precios de **España**, en Capterra); reserva online 24 h y varias consultas; apareció **XIAgenda** (Argentina): desde USD 15 por profesional por mes; una reseña de terceros dice que AgendaPro empieza en USD 19 | Precios de Doctoralia (con la salvedad del país), XIAgenda, y el dato de terceros de AgendaPro marcado "a verificar" |

## 3. Qué se encontró

| Competidor | Dato confirmado | Lo que **no** se pudo confirmar |
|---|---|---|
| AgendaPro | Existe versión para Argentina; agenda, clientes, finanzas e inventario | Precio en Argentina (una reseña de terceros dice "desde USD 19", sin confirmar); si tiene seña por categoría, tarjetas de regalo, consulta previa |
| Fresha | USD 19,95 o USD 14,95 por profesional; comisión 20% (mín. USD 6) por paciente nueva; fidelidad como complemento pago | Si tiene seña por categoría, consulta previa o terminal en el local |
| Booksy | USD 29,99/mes + USD 20 por integrante adicional; tarjetas 2,49% + USD 0,10; marketing aparte | Lo mismo |
| Doctoralia | EUR 69 por especialista, EUR 129 para clínicas (España); reserva 24 h, varias consultas | Precio en Argentina; el resto de las funciones |
| XIAgenda | Desde USD 15 por profesional por mes (plan Esencial) | Funciones (solo se vio el precio) |

### Las cuentas para 20 profesionales (precio de lista, USD, sin impuestos)

| Sistema | Cuenta | Por mes | Por año |
|---|---|---|---|
| Fresha (plan de equipo) | 20 × 14,95 | 299 | 3.588 |
| Booksy | 29,99 + 19 × 20 | 410 | 4.919 |
| XIAgenda (Esencial) | 20 × 15 | 300 | 3.600 |
| Doctoralia (clínicas) | EUR 129 (España) | EUR 129 | EUR 1.548 |
| AgendaPro | a verificar | — | — |

## 4. Dificultades y cómo se resolvieron

| Problema | Qué se hizo |
|---|---|
| AgendaPro no publica precios para Argentina | Se dejó "a verificar" y se citó el dato de terceros sin usarlo en las cuentas |
| Los precios de Doctoralia son de España y en euros | Se aclaró en la tabla y no se comparó directamente con los dólares |
| Las fuentes de terceros se contradicen (por ejemplo, un sitio dice que Booksy tiene tres planes y la página oficial uno solo) | Se priorizó la página oficial del producto |
| Los precios cambian y varían por país (Fresha bajó el suyo en febrero de 2026) | Se anotó la fecha de consulta y se avisó que hay que rever antes del Demo Day |
| El buscador solo da páginas y resúmenes: no se pueden ver las pantallas de cada producto | Se evitó afirmar que un competidor **no** tiene una función; se escribió "no encontramos en la documentación pública" |

## 5. Decisiones que se tomaron

1. Comparar con **precio de lista en dólares y sin impuestos**, y mostrarlo para **20 profesionales**
   (el tamaño del instituto de los datos de ejemplo).
2. En la matriz, **Sí** solo si la fuente lo dice; si no, **a verificar**. Las funciones propias de Dermalia
   (consulta previa de cirugías, cupones con token de 5 minutos, tarjetas con saldo, auditoría, contingencia)
   se marcan como **Sí** de Dermalia, y para los competidores como "a verificar", no como "No".
3. La propuesta única de valor se apoya en **tres cosas verificables**: está hecho para este negocio (regla de
   cirugías), no cobra por profesional ni comisión por paciente, y los datos son del instituto.
4. Todas las cifras del instituto (ticket de $150.000, 95 minutos, 6 turnos) se citan como **supuestos o
   mediciones del equipo**, no como datos de mercado.

## 6. Qué se aprendió

- Casi todos cobran **por profesional**: el costo crece con el equipo; el modelo de Dermalia (implantación +
  abono fijo) es la diferencia comercial más clara.
- Fresha suma **comisión por paciente nueva**, algo que no aparece en el precio de lista y cambia la cuenta.
- La información pública de precios es incompleta justo donde más importa (Argentina): conviene pedir
  cotización o probar la demo en vez de depender de comparadores.
- Una matriz honesta tiene celdas vacías: es mejor mostrar "a verificar" que afirmar de más ante el jurado.

## 7. Limitaciones

- La investigación fue **solo con buscador**; no se abrió una cuenta ni una demo de ningún producto.
- El buscador usado devuelve resultados de EE. UU.: puede faltar información local.
- Se consultó una sola vez (3 de noviembre de 2026).
- No se relevó a otros competidores locales de turnos para estética (por ejemplo, plataformas más chicas).

## 8. Pendiente (próximos pasos concretos)

- [ ] Abrir la **demo gratuita** de AgendaPro, Fresha y Booksy y completar las celdas "a verificar" con captura de pantalla como fuente.
- [ ] Pedir **cotización** a AgendaPro Argentina y a Doctoralia Argentina.
- [ ] Verificar **XIAgenda** (funciones, no solo precio) y buscar al menos un competidor local más.
- [ ] Volver a mirar los precios la semana del Demo Day (cambian) y actualizar las cuentas.
- [ ] Revisar con el docente si alcanza con este nivel de fuentes para la matriz.
- [ ] Cuando se verifique, firmar la bitácora con lo que **cada integrante** comprobó.

## 9. Fuentes consultadas

- [AgendaPro Argentina](https://agendapro.com/ar/negocios/software-para-negocios) (descripción, sin precios) y [reseña de Medesk](https://www.medesk.net/es/blog/agenda-pro-review/) (dato de terceros).
- Fresha: [Capterra](https://www.capterra.com/p/142138/Shedul-com/pricing/) y [Costbench](https://www.costbench.com/software/salon-spa/fresha/).
- Booksy: [página oficial EE. UU.](https://biz.booksy.com/en-us/pricing) y [Koalendar](https://koalendar.com/blog/booksy-pricing).
- Doctoralia: [Capterra](https://www.capterra.com/p/253301/Doctoralia-Pro/pricing/).
- XIAgenda: [Comparasoftware](https://www.comparasoftware.com/xiagenda).
