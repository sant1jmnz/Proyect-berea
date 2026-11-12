# Presupuesto, modelo de negocio y retorno (Semana 5)

Documento de la Semana 5 del plan de la cátedra: costos de desarrollo,
modelo de monetización, precio de venta y retorno de la inversión. Alimenta
las diapositivas "costos, precio y retorno" del pitch (`06-pitch.md`).

**Todo lo que no es un dato del repositorio es un supuesto del equipo** y está
marcado con 🔶. Los supuestos están juntos en la sección 1 para cambiarlos en
un solo lugar: si cambian, hay que rehacer las cuentas de las secciones 2 a 5
(las fórmulas están escritas). Moneda: pesos argentinos de 2026, sin impuestos.

## 1. Supuestos y datos de partida

| Dato | Valor | Origen |
|---|---|---|
| Tiempo diario de atención manual de la recepción | 95 min/día, bajan a 38 (−57 min/día) | MML (`03-matriz-marco-logico.md`) |
| Días de atención por año | 312 (lunes a sábado) | Cálculo del equipo: 57 min × 312 días ≈ **296 horas/año** liberadas |
| Turnos perdidos por inasistencia | 6/semana, bajan a 3 → **156 turnos/año** recuperados | MML |
| Ticket promedio por turno | $150.000 | 🔶 Supuesto del equipo (`04-requerimientos.md`) |
| Valor de la hora de recepción | $6.000 | 🔶 Supuesto del equipo |
| Valor de la hora de desarrollo | $20.000 | 🔶 Supuesto del equipo (programador semi-senior) |
| Margen sobre el costo de desarrollo | 30% | 🔶 Supuesto del equipo |
| Gestión de proyecto | 10% de las horas de desarrollo | 🔶 Supuesto del equipo |
| Profesionales del instituto | 20 | Datos de ejemplo del proyecto |

## 2. Costo de desarrollo

Horas por módulo (estimación del equipo 🔶, para un equipo profesional que
construya el sistema completo; el trabajo real del bimestre es un subconjunto):

| Módulo | Horas |
|---|---|
| Relevamiento, análisis y diseño (árboles, MML, requerimientos, maquetado) | 80 |
| Base de datos: 27 entidades, 9 schemas, stored procedures, 8 reportes + auditoría, pruebas | 160 |
| Apartado Gestión (Qt, recepción) | 120 |
| Apartado Cliente (Qt, terminal táctil) | 100 |
| Sitio web para la paciente | 140 |
| Integraciones: n8n, Telegram/WhatsApp, Google Calendar, asistente de IA | 60 |
| Pruebas y control de calidad | 70 |
| Manuales y capacitación | 40 |
| **Subtotal** | **770** |
| Gestión de proyecto (10%) | 77 |
| **Total** | **847 h** |

**Costo de desarrollo = 847 h × $20.000 = $16.940.000.**

## 3. Licencias, infraestructura y mantenimiento

| Concepto | Tipo | Monto | Nota |
|---|---|---|---|
| Base MySQL en Aiven | Año | $0 | Plan gratuito (límites de almacenamiento; si crece, hay planes pagos: **a verificar** en aiven.io) |
| VM para n8n en Google Cloud (e2-micro) | Año | $0 | Nivel gratuito de la nube; **a verificar** las condiciones vigentes |
| Dominio del sitio web | Año | $25.000 🔶 | |
| Asistente de IA (consumo de la API) | Mes | $30.000 🔶 | Depende del uso real; se estima poco |
| WhatsApp (API oficial de Meta) | Mes | **a verificar** | Se cobra por conversación; en desarrollo se usa Telegram, gratis |
| Terminal táctil de 768×1024 | Una vez | $450.000 🔶 | Tablet o pantalla táctil con soporte |
| No-break y router 4G de respaldo (RNF-09) | Una vez | $210.000 🔶 | $120.000 + $90.000 |
| **Hardware inicial** | Una vez | **$660.000** | |
| **Infraestructura anual** | Año | **$385.000** | Dominio $25.000 + IA 12 × $30.000 |
| Mantenimiento correctivo y evolutivo | Año | $2.541.000 | 15% del costo de desarrollo (regla práctica, 🔶) |

## 4. Modelo de monetización

Tres formas de cobrar un sistema como este (opciones de la cátedra):

| Modelo | Cómo se cobra | A favor | En contra |
|---|---|---|---|
| **Licencia** (pago único) | Una vez, por instalación | Ingreso grande de entrada | El cliente se queda sin soporte; no cubre los costos que siguen (nube, IA) |
| **SaaS** (abono por uso) | Mensual, por profesional | Ingreso recurrente | Es el modelo de los competidores (`07-competencia.md`): con 20 profesionales cuesta USD 3.600 a 4.900 por año; no nos diferencia |
| **Llave en mano + abono de soporte** | Implantación única + abono mensual fijo | Cubre el desarrollo y los costos que siguen; el abono no crece con la cantidad de profesionales | Exige que el cliente confíe en un proveedor chico |

**Elegido: llave en mano + abono de soporte.** Es lo que sostiene la PUV
(sin abono por profesional, datos del instituto): el instituto paga una vez la
puesta en marcha y un abono fijo que incluye soporte, hosting, respaldos y la
cuota del asistente de IA.

## 5. Precio de venta

| Concepto | Cuenta | Monto |
|---|---|---|
| Costo de desarrollo | 847 h × $20.000 | $16.940.000 |
| Margen | 30% | $5.082.000 |
| **Precio de implantación** (redondeado) | | **$22.020.000** |
| Hardware inicial (se factura aparte) | | $660.000 |
| **Inversión inicial del instituto** | | **$22.680.000** |
| **Abono mensual de soporte** | Soporte, hosting, respaldos, IA | **$400.000/mes ($4.800.000/año)** 🔶 |

El abono cubre con holgura los costos de infraestructura ($385.000/año) más unas
5 horas mensuales de soporte (12 × 5 × $20.000 = $1.200.000/año), 🔶.

## 6. Retorno de la inversión

Beneficio anual para el instituto, a las 4 semanas de uso del sistema (los
mismos indicadores de la MML):

| Beneficio | Cuenta | Por año |
|---|---|---|
| Turnos recuperados | 156 × $150.000 | $23.400.000 |
| Horas de recepción liberadas | 296 h × $6.000 | $1.776.000 |
| **Beneficio bruto** | | **$25.176.000** |
| Abono de soporte | | −$4.800.000 |
| **Beneficio neto anual** | | **$20.376.000** |

- **Retorno de la inversión (primer año):** $20.376.000 ÷ $22.680.000 ≈ **90%**.
- **Se recupera en:** $22.680.000 ÷ $20.376.000 ≈ **1,11 años, unos 13 meses**.
- A partir del segundo año el instituto solo paga el abono ($4.800.000) contra
  un beneficio de $25.176.000.

### Qué tiene que ser cierto para que esto funcione

1. **Que la recepción use el sistema** y deje de anotar turnos a mano (el
   riesgo más alto de la MML). Sin eso, ningún beneficio se materializa.
2. **Que el ticket y los turnos perdidos sean los supuestos.** Si el ticket
   fuera la mitad ($75.000), los turnos recuperados valdrían $11.700.000 y el
   beneficio neto sería $11.700.000 + $1.776.000 − $4.800.000 = $8.676.000: el
   retorno del primer año bajaría a ≈ 38% y se recuperaría en ~2,6 años. Conviene mostrar esta
   sensibilidad en el pitch.
3. **Que la seña simulada se vuelva real** en una etapa posterior (integración
   con una pasarela de pagos): hoy el sistema no mueve dinero (RNF-05).

## 7. Cómo repartir este documento en el pitch

- Diapositiva "Costos": tabla de la sección 2 y el total $16.940.000.
- Diapositiva "Precio": secciones 4 y 5.
- Diapositiva "Retorno": tabla de la sección 6 y los 13 meses.
- Si preguntan "¿por qué no cobrar por profesional como los demás?": sección 4.
