# Propuestas de proyecto — desarrollo y evidencia

Documento de trabajo de la etapa de detección de necesidades (semana 1). Cada
propuesta está desarrollada con el mismo esquema para poder **compararlas y
elegir una** con criterio, no por simpatía.

## Cómo leer este documento

- **Problema central (borrador):** redactado como pide la cátedra — en negativo,
  en presente, describiendo la necesidad y **nunca la solución faltante**. Es el
  candidato a tronco del Árbol de Problemas.
- **Evidencia:** se distinguen dos cosas que no son lo mismo.
  - **Datos públicos** con fuente citada. Sirven para **contextualizar** la
    problemática y mostrar que no es un invento.
  - **`[RELEVAR]`** marca lo que **solo puede salir de nuestro propio
    relevamiento** (entrevistas, encuestas, observación). El plan de aprendizaje
    pide relevamiento propio y la rúbrica evalúa el diagnóstico: un dato
    nacional no reemplaza medir el caso concreto.

> **Regla que no se negocia:** ninguna cifra `[RELEVAR]` se completa a ojo. Si no
> la medimos, no va. Un indicador inventado invalida toda la Matriz de Marco
> Lógico que se apoye en él.

---

## Propuesta 1 (PRINCIPAL) — Aplicación web para centro de estética integral

**Usuario / cliente:** dueño de un centro de estética integral (cliente real ya
identificado) y sus clientas y clientes actuales y potenciales.

### Problema central (borrador)

*La gestión de turnos y consultas del centro de estética depende de la atención
manual del dueño por WhatsApp, lo que consume horas de trabajo, produce
superposiciones y turnos perdidos, y demora las respuestas a quienes consultan.*

Nótese que el problema **no** es "no hay una app": es la carga operativa y la
pérdida de turnos que hoy existen.

### Evidencia

**Datos públicos**

- El 97% de los argentinos usa WhatsApp a diario y el 58% lo usa para
  **consultas comerciales**; el 28% ya compra por ese canal. Es decir: el canal
  por el que hoy se satura la atención es exactamente donde está el cliente
  ([estudio sobre WhatsApp y compras](https://dialecto.com/blog/whatsapp-marketing/estudio-impacto-de-whatsapp-en-compras/)).
- El ausentismo a turnos reservados es un problema reconocido del rubro: en
  España los centros de estética y peluquerías empezaron a **cobrar por
  adelantado** para frenar las "reservas fantasma", y reportan que las
  inasistencias bajaron
  ([Cuatro](https://www.cuatro.com/noticias/economia/20250116/reservas-fantasma-centros-estetica-peluquerias_18_014508640.html)).
  Esto respalda directamente la decisión de cobrar la seña.
- Un caso documentado de red de clínicas con recordatorios automáticos de turno
  reporta una **reducción del 50% en las inasistencias**
  ([WhatsApp Business API](https://developargentina.com/blog/whatsapp-business-api-argentina-automatizacion-ventas-2025)).
  Sirve como referencia para fijar la meta del indicador, no como resultado
  propio.

**A relevar con el dueño**

- `[RELEVAR]` Cuántas consultas por WhatsApp recibe por día y qué proporción son
  repetidas (precios, horarios, "¿qué incluye el tratamiento?").
- `[RELEVAR]` Cuántos minutos por día dedica a responderlas. **Es la línea de
  base del indicador principal.**
- `[RELEVAR]` Cuántos turnos por semana se pierden por inasistencia y cuánto
  representa en dinero.
- `[RELEVAR]` Cuántas veces por mes se superponen dos turnos.
- `[RELEVAR]` Cuántas personas consultan y no reservan, y por qué.

### Qué hace el sistema

| Módulo | Función |
|---|---|
| Reserva en 3 pasos | Servicio → horario disponible → confirmación, con sincronización automática al Google Calendar del dueño |
| Cobro de seña | Mercado Pago; el backend **no** almacena datos de tarjeta |
| Asistente virtual | Gemini 2.5 Flash restringido por RAG a una base local con precios, protocolos y políticas; si no puede responder, deriva a WhatsApp del dueño |
| Mis Turnos | Acceso por cookies y enlace mágico, sin registro ni contraseña |
| Vitrina | Antes y después, quiz de diagnóstico de piel, reseñas vía Google Maps API |

### Fuera de alcance

Historia clínica de tratamientos, gestión de stock de insumos, liquidación de
comisiones, app nativa. **Este bimestre no se programa nada:** se formula y se
diseña.

### Indicadores preliminares

| Indicador | Meta | Línea de base |
|---|---|---|
| Tiempo diario de atención manual de consultas | Reducción del 60% | `[RELEVAR]` min/día actuales |
| Turnos perdidos por inasistencia | Reducción del 50% | `[RELEVAR]` turnos/semana |
| Superposiciones de agenda | 0 por mes | `[RELEVAR]` casos/mes |
| Consultas resueltas sin intervención humana | ≥ 70% | 0% (hoy todo es manual) |

### Riesgos

- **Adopción:** que las clientas sigan escribiendo por WhatsApp igual. Mitigación:
  responder desde WhatsApp con el enlace de reserva.
- **Resistencia a la seña:** puede espantar clientes nuevos. `[RELEVAR]` qué opina
  el dueño y qué hacen los competidores de la zona.
- **Dependencia de terceros:** si cambian las condiciones de las APIs de Google o
  de Gemini, se cae una parte del sistema.
- **Datos personales:** fotos de "antes y después" son dato sensible; requieren
  consentimiento explícito.

### Viabilidad para el bimestre

**Alta.** Cliente real, alcance delimitado, decisiones técnicas defendibles en el
pitch. El riesgo es de sobredimensionamiento: son cuatro integraciones externas
y conviene marcar cuáles son núcleo (reserva + calendario) y cuáles son
deseables (quiz, reseñas).

---

## Propuesta 2 — Gestión de inventario y punto de venta (POS simplificado)

**Usuario / cliente:** dueño y personal de atención de un kiosco o restaurante
chico.

### Problema central (borrador)

*El control de stock y el registro de ventas de los comercios minoristas chicos
se lleva de memoria o en papel, por lo que el personal no sabe qué hay
disponible sin ir a mirar y el dueño no conoce el resultado del día hasta
cerrar la caja a mano.*

### Evidencia

**Datos públicos**

- El sector atraviesa una crisis severa: cerraron **41.000 kioscos desde
  diciembre de 2023**, pasando de unos 100.000 a 59.000 — alrededor de **50
  cierres por día** según UKRA
  ([Infobae](https://www.infobae.com/economia/2026/08/03/cerraron-41000-kioscos-desde-diciembre-de-2023-y-en-el-sector-ven-una-crisis-similar-a-la-de-2001/)).
- Un relevamiento de ARCA registró una caída de **112.000 a 96.000 kioscos
  activos** en un año
  ([Infobae](https://www.infobae.com/economia/2025/08/12/crisis-en-los-kioscos-cerraron-16000-locales-en-el-ultimo-ano-y-el-sector-cae-a-minimos-historicos/)),
  con **más de 72.000 puestos de trabajo perdidos** en dos años
  ([BAE Negocios](https://www.baenegocios.com/negocios/cerraron-mas-de-36-000-kioscos-y-se-perdieron-72-000-puestos-de-trabajo-en-los-ultimos-dos-anos/)).

**Cómo se usa esta evidencia — y cómo no**

Estos números prueban que el sector está bajo presión, **no** que la causa sea la
falta de un sistema de gestión. Las fuentes atribuyen los cierres a la caída del
consumo, los alquileres y los servicios. Presentarlo como "cierran kioscos porque
no tienen software" sería exactamente el error metodológico que la cátedra
penaliza. El encuadre honesto: en un margen así de ajustado, **el descontrol de
stock y la falta de visibilidad de la caja dejan de ser molestias y pasan a ser
pérdidas que el comercio ya no puede absorber**.

**A relevar en el comercio elegido**

- `[RELEVAR]` Cuántas veces por semana se pierde una venta por faltante no detectado.
- `[RELEVAR]` Cuánto tarda el cierre de caja diario hoy.
- `[RELEVAR]` Cuántos productos maneja y cuántos rotan de verdad.
- `[RELEVAR]` Qué diferencia aparece entre la caja contada y lo que se esperaba.

### Qué hace el sistema

Catálogo con precio, categoría y stock; registro de venta en pocos clics con
descuento automático de inventario; panel de "Movimientos del Día" con ingresos,
historial y alertas de bajo stock.

### Fuera de alcance

Facturación electrónica ante ARCA, medios de pago electrónicos, control de
proveedores y compras, balance contable.

### Indicadores preliminares

| Indicador | Meta | Línea de base |
|---|---|---|
| Tiempo de cierre de caja | Menos de 5 minutos | `[RELEVAR]` minutos actuales |
| Ventas perdidas por faltante | Reducción del 70% | `[RELEVAR]` casos/semana |
| Tiempo de registro de una venta | Menos de 15 segundos | `[RELEVAR]` |

### Riesgos

Que el personal siga sin cargar las ventas en momentos de mucha gente — si el
registro no es más rápido que el cuaderno, no se usa. La carga inicial del
catálogo es trabajo real y hay que preverla como actividad.

### Viabilidad para el bimestre

**Alta.** Alcance chico y muy claro. Es la alternativa más segura si la de
estética resulta demasiado ambiciosa.

---

## Propuesta 3 — Organizador de tareas e intercambio de turnos de trabajo

**Usuario / cliente:** empleados a tiempo parcial, típicamente jóvenes que
estudian y trabajan, y el encargado que arma la grilla.

### Problema central (borrador)

*Los empleados a tiempo parcial no tienen un lugar único donde ver su horario
actualizado ni estimar lo que van a cobrar, y los cambios de turno se arreglan
por mensajes sueltos, lo que genera confusiones y ausencias no cubiertas.*

### Evidencia

**Datos públicos**

- En Argentina, **13% de los jóvenes de 19 a 25 años trabaja y estudia**, mientras
  que el **52%** de los alumnos del último año de secundaria planea hacerlo — una
  brecha grande entre expectativa y realidad
  ([Argentinos por la Educación](https://argentinosporlaeducacion.org/informe/educacion-y-trabajo-expectativa-y-realidad-de-jovenes-en-argentina/)).
- La desocupación de 18 a 24 años ronda el **19%, casi el triple** que la de los
  adultos ([IDESA](https://idesa.org/por-que-el-desempleo-de-los-jovenes-triplica-al-de-los-adultos/)).
- El **45,1%** de los jóvenes ocupados son asalariados informales, contra 22,2%
  en adultos ([Infobae](https://www.infobae.com/sociedad/2026/05/01/radar-del-empleo-joven-en-argentina-la-informalidad-la-precariedad-las-expectativas-rotas-y-el-rol-de-la-formacion-laboral/)).

**Advertencia sobre este dato:** la alta informalidad juega **en contra** de la
propuesta. En un empleo informal no hay grilla formal ni liquidación que
verificar, y el sistema pierde sentido. Conviene acotar el usuario a un comercio
o cadena concreta con turnos formalizados.

**A relevar**

- `[RELEVAR]` En el local elegido: cuántos cambios de turno se piden por mes y
  por qué canal.
- `[RELEVAR]` Cuántas veces al mes alguien se presenta en un horario equivocado.
- `[RELEVAR]` Si el encargado aceptaría delegar la aprobación de los cambios.

### Fuera de alcance

Liquidación de sueldos real, integración con el sistema de RR.HH. de la empresa,
control de presentismo por fichaje biométrico.

### Riesgos

El sistema necesita al encargado del lado de adentro: si él no aprueba los
cambios en la app, todo vuelve al grupo de WhatsApp. **Sin un local concreto que
acepte usarlo, la propuesta no tiene usuario.**

### Viabilidad para el bimestre

**Media.** Depende por completo de conseguir un comercio con turnos formales que
acepte participar del relevamiento.

---

## Propuesta 4 — Comparador de precios de hardware

**Usuario / cliente:** persona que quiere armar o actualizar una PC.

### Problema central (borrador)

*Quien quiere comprar componentes de PC debe consultar los precios comercio por
comercio, porque el mismo producto tiene valores muy distintos según el canal, y
no tiene forma de saber si el precio que le ofrecen es razonable.*

### Evidencia

**Datos públicos**

- La dispersión de precios es real y creciente: para un mismo producto, la
  diferencia según el canal de venta lleva a que el consumidor "pierda la noción"
  de lo que valen las cosas; una brecha que era del 7% en promedio hoy llega al
  **20%** ([iProUP](https://www.iproup.com/economia-digital/30520-inflacion-en-la-argentina-diferencia-de-precios-segun-comercios)).
- El mercado de componentes se reactivó y la brecha contra Estados Unidos pasó
  de **100–150% a cerca del 15%**
  ([El Cronista](https://www.cronista.com/infotechnology/actualidad/pc-y-gaming-las-ventas-se-reaniman-y-los-precios-en-argentina-ya-se-acercan-al-nivel-internacional/)).

### Problema serio de esta propuesta: ya existe

**[HardGamers](https://www.hardgamers.com.ar/) es exactamente esto**: comparador
de precios de hardware en Argentina, con historial de precios, funcionando hoy.
No es un detalle menor — la cátedra evalúa la justificación de la solución, y
"ya existe y es gratis" es la primera objeción que va a aparecer en el pitch.

Para sostenerla habría que encontrar un ángulo que el existente no cubra
(por ejemplo: armado de configuraciones completas con control de compatibilidad
y presupuesto tope), y eso hay que **verificar que efectivamente no esté
resuelto**, no suponerlo.

Además, alimentar el comparador exige scraping de sitios de terceros: es frágil,
puede violar términos de servicio y es una dependencia externa fuerte.

### Viabilidad para el bimestre

**Baja.** Competidor consolidado, problema de obtención de datos y usuario
difuso. **Recomendación: descartarla**, salvo que aparezca un ángulo diferencial
comprobado.

---

## Propuesta 5 — Buscador de adopción y registro de mascotas

**Usuario / cliente:** refugios y proteccionistas independientes, y personas que
quieren adoptar.

### Problema central (borrador)

*Los refugios gestionan las solicitudes de adopción por redes sociales y
mensajes privados, sin un registro de los animales disponibles ni seguimiento de
cada solicitud, por lo que se pierden contactos de posibles adoptantes y se
repite el trabajo de responder lo mismo.*

### Evidencia

**Datos públicos**

- Una ONG estima **más de 20 millones de animales en la calle** en Argentina
  ([Infobae](https://www.infobae.com/sociedad/2024/07/27/dia-del-perro-callejero-una-ong-estima-que-en-la-argentina-hay-mas-de-20-millones-de-animales-que-viven-en-las-calles/));
  un estudio del Colegio de Veterinarios de Buenos Aires de 2018 calculaba
  6 millones de perros sin hogar.
- En CABA se estiman **100.000 perros y gatos en situación de abandono**: uno
  cada 30 habitantes
  ([La Nación](https://www.lanacion.com.ar/lifestyle/dia-mundial-del-perro-callejero-cual-es-la-cifra-local-de-animales-que-no-tienen-hogar-nid27072021/)).
- Las fuentes coinciden en que **los refugios no dan abasto** y que sostienen la
  situación sin política pública detrás
  ([Ámbito](https://www.ambito.com/maltrato-animal/sos-refugios-tres-historias-lucha-contra-el-abandono-y-el-n5623609)).

Las cifras de animales en calle son estimaciones de ONG con metodologías
distintas: hay que citarlas **como estimación**, no como dato oficial.

**A relevar en un refugio concreto**

- `[RELEVAR]` Cuántas solicitudes de adopción recibe por mes y por qué canal.
- `[RELEVAR]` Cuántas se pierden sin respuesta y por qué.
- `[RELEVAR]` Cuánto tarda una adopción desde el primer contacto.
- `[RELEVAR]` Qué datos necesitan del adoptante para aprobar una adopción.

### Fuera de alcance

Historia clínica veterinaria, gestión de donaciones y cobros, geolocalización de
animales perdidos.

### Viabilidad para el bimestre

**Media-alta.** Problemática con impacto social claro y usuarios accesibles si un
refugio de la zona acepta participar. **Sin refugio que acepte, no hay
relevamiento y la propuesta se cae.**

---

## Propuesta 6 — Gestor de gastos compartidos para viajes o eventos

**Usuario / cliente:** grupos que comparten gastos: un viaje de egresados, un
equipo, un grupo de convivientes.

### Problema central (borrador)

*Los grupos que comparten gastos llevan las cuentas en papel o en una planilla
improvisada, por lo que al momento de saldar nadie coincide en cuánto debe cada
uno y las rendiciones se demoran o quedan sin cerrar.*

### Evidencia

- `[RELEVAR]` **No hay datos públicos citables** para esta problemática, y eso es
  en sí un dato: es un problema cotidiano pero poco medido. Todo el diagnóstico
  tendría que salir de una encuesta propia a grupos que hayan compartido gastos.

**Problema de la propuesta:** existen soluciones muy instaladas (Splitwise y
similares) y la funcionalidad es acotada — es esencialmente una calculadora de
deudas cruzadas. Cuesta sostener un bimestre de formulación sobre esto y cuesta
más defenderla en el pitch.

### Viabilidad para el bimestre

**Baja.** Alcance demasiado chico y competencia gratuita instalada.
**Recomendación: descartarla.**

---

## Propuesta 7 — Menú digital para comedores

**Usuario / cliente:** responsable del comedor y sus comensales.

### Problema central (borrador)

*Los comensales del comedor no saben qué se sirve cada día hasta llegar, y quien
planifica el menú no tiene forma de conocer qué platos se aceptan y cuáles se
desperdician.*

### Evidencia

- `[RELEVAR]` **Sin datos públicos aplicables** al caso concreto. Habría que
  relevar en el comedor elegido: raciones preparadas contra raciones servidas,
  cantidad de comensales por día, y una encuesta de preferencias.

El ángulo con más sustancia no es publicar el menú (eso es un cartel) sino
**reducir el desperdicio ajustando la producción a la demanda real** medida con
las votaciones y la asistencia. Con ese encuadre, la propuesta tiene un problema
medible; sin él, es una cartelera digital.

### Viabilidad para el bimestre

**Media.** Viable y con usuarios a mano si hay un comedor accesible, pero exige
reformular el problema hacia el desperdicio para que valga la pena.

---

## Propuesta 8 — Entradas con código QR

**Usuario / cliente:** organizador de eventos y personas que asisten.

### Problema central (borrador)

*Los organizadores de eventos chicos controlan el ingreso con listas en papel y
comprobantes enviados por mensajería, que se duplican y reenvían con facilidad,
por lo que no pueden verificar si una entrada ya fue usada ni saber cuánta gente
ingresó.*

### Evidencia

**Datos públicos**

- El fraude documentado en el circuito argentino de fiestas y recitales es
  exactamente el descrito: **la misma captura de pantalla reenviada a varias
  personas, copias impresas del mismo PDF y entradas vendidas por redes**
  ([Passcore](https://passcore.net/como-evitar-entradas-falsas)).
- En plataformas reguladas con validación, los casos de entradas falsificadas
  **no superan el 0,02%** de las transacciones
  ([Veridas](https://veridas.com/es/fraude-compra-entradas/)) — sirve como
  referencia de a dónde se puede llegar con validación única.
- Hay un proyecto legislativo para que las entradas se entreguen en un formato
  que permita **validación y trazabilidad**
  ([iProfesional](https://www.iprofesional.com/economia/425203-buscan-regular-reventa-entradas-tras-mega-estafa-en-partido-argentina-versus-brasil)),
  lo que empuja al sector en esta dirección.

**A relevar**

- `[RELEVAR]` En un evento concreto (fiesta escolar, torneo, peña): cuántos
  ingresos se controlan, cuánto tarda la fila, cuántos casos de entrada
  duplicada aparecieron.

### Riesgo principal

El mercado está muy cubierto por plataformas comerciales. El nicho defendible es
el **evento chico y autogestionado** que no puede pagar una plataforma: fiesta
de egresados, torneo de club, evento escolar.

### Viabilidad para el bimestre

**Media-alta.** Problema concreto, solución acotada y demostrable. Pierde puntos
por competencia, los recupera si se acota bien al evento autogestionado.

---

## Propuesta 9 (NUEVA) — Reserva y control de laboratorios y equipamiento

*Derivada del cruce de la propuesta 1 (reserva con agenda), la 2 (stock y
alertas) y la 8 (identificación por QR).*

**Usuario / cliente:** docentes, encargado de laboratorio y quien administra el
equipamiento de la institución.

### Problema central (borrador)

*La reserva de laboratorios y el préstamo de equipamiento se registran de
palabra o en un cuaderno, por lo que se superponen reservas, no se puede
reconstruir quién usó cada equipo por última vez y los desperfectos se descubren
recién en el momento de usarlos.*

### Evidencia

- `[RELEVAR]` **Ventaja decisiva de esta propuesta: el relevamiento está a mano.**
  Se puede entrevistar al encargado y a los docentes en la misma institución, y
  observar directamente cómo se reserva hoy.
- `[RELEVAR]` Cuántas superposiciones de reserva ocurren por mes.
- `[RELEVAR]` Cuántos equipos hay y cuántos figuran como no localizados.
- `[RELEVAR]` Cuánto tiempo de clase se pierde por equipo fallado no informado.

### Qué hace el sistema

Grilla semanal de disponibilidad en vivo; reserva en tres pasos; etiqueta QR por
equipo que abre la ficha para registrar retiro y devolución; panel con préstamos
activos, vencidos y equipos fuera de servicio; acceso por enlace sin contraseñas.

### Fuera de alcance

Inventario patrimonial contable, compras y bajas de equipamiento, reserva de
aulas comunes.

### Indicadores preliminares

| Indicador | Meta | Línea de base |
|---|---|---|
| Superposiciones de reserva | 0 por mes | `[RELEVAR]` casos/mes |
| Equipos sin trazabilidad de último uso | 0% | `[RELEVAR]` % actual |
| Tiempo de registro de un préstamo | Menos de 20 segundos | `[RELEVAR]` |

### Viabilidad para el bimestre

**Alta.** Es la propuesta con relevamiento más barato y validación de maquetado
más fácil: los usuarios están en el edificio.

---

## Propuesta 10 (NUEVA) — Registro y seguimiento de reclamos de mantenimiento

*Derivada del cruce de la propuesta 5 (solicitudes con estados), la 8 (QR) y el
panel de la 2.*

**Usuario / cliente:** toda la comunidad educativa como reportantes; el
encargado de mantenimiento y la dirección como gestores.

### Problema central (borrador)

*Los desperfectos edilicios se avisan por canales informales y sin registro, por
lo que no queda constancia de quién recibió el reclamo, quien lo reportó no sabe
si se está resolviendo, y no hay información para priorizar las reparaciones.*

### Evidencia

**Datos públicos**

- Un relevamiento de UTE encontró que el **20% de las escuelas de CABA tiene
  problemas edilicios y el 10% no tiene calefacción**
  ([UTE](https://ute.org.ar/escuelas-de-caba-20-con-problemas-edilicios-y-10-sin-calefaccion/)).
- Se documentaron **más de 200 escuelas** de CABA con problemas de
  infraestructura ([ANCCOM](https://anccom.sociales.uba.ar/2022/09/14/caba-mas-de-200-escuelas-con-problemas-de-infraestructura/)).
- Un dato que respalda directamente esta propuesta: las fuentes señalan la
  **falta de transparencia y la inexistencia de estadísticas oficiales** sobre el
  estado edilicio ([El Destape](https://www.eldestapeweb.com/opinion/ciudad-de-buenos-aires/infraestructura-escolar-en-caba-subejecucion-falta-de-vacantes-y-abandono-202253114310)).
  Es decir: **el problema de registro que el sistema resuelve está documentado
  como problema real del sector**, no solo del edificio propio.

**A relevar**

- `[RELEVAR]` Cuántos reclamos se reportan por mes y por qué canal.
- `[RELEVAR]` Cuántos se resuelven, en cuánto tiempo, y cuántos se pierden.
- `[RELEVAR]` Cuántas veces se reporta dos veces el mismo desperfecto.

### Sensibilidad a tener en cuenta

Un registro de fallas edilicias con fotos es información políticamente sensible
para cualquier institución. **Hay que acordar con la dirección desde el
principio** quién ve qué y si los datos son internos. Presentarlo como
herramienta de gestión y priorización —no como sistema de denuncia— es lo que
lo vuelve viable.

### Viabilidad para el bimestre

**Alta** en lo técnico y en el relevamiento; **media** en lo político, por lo
anterior. Requiere aval de la institución antes de arrancar.

---

## Comparación y recomendación

| # | Propuesta | Usuario accesible | Evidencia pública | Competencia | Viabilidad |
|---|---|---|---|---|---|
| 1 | Centro de estética | Sí, cliente real | Buena | Media | **Alta** |
| 2 | POS / inventario | A conseguir | Buena | Alta | **Alta** |
| 3 | Turnos de trabajo | A conseguir | Contradictoria | Media | Media |
| 4 | Comparador hardware | Difuso | Buena | **Ya existe** | Baja |
| 5 | Adopción de mascotas | A conseguir | Buena | Baja | Media-alta |
| 6 | Gastos compartidos | Fácil | Nula | **Ya existe** | Baja |
| 7 | Menú de comedor | Sí | Nula | Baja | Media |
| 8 | Entradas QR | A conseguir | Buena | Alta | Media-alta |
| 9 | Laboratorios y equipamiento | **Sí, acá mismo** | A relevar | Baja | **Alta** |
| 10 | Reclamos de mantenimiento | **Sí, acá mismo** | Buena | Baja | Alta |

**Recomendación:** sostener la **1 (estética)** como principal — tiene cliente
real, que es lo más difícil de conseguir — y mantener la **9** como alternativa
firme, porque el relevamiento y la validación del maquetado se hacen sin salir
del edificio. Descartar la **4** y la **6**: ambas tienen competidores gratuitos
instalados y no aparece un ángulo diferencial que se pueda defender.

**Lo que hay que hacer ahora, en este orden:**

1. Confirmar con el dueño del centro de estética que acepta ser entrevistado.
   **De esto depende toda la propuesta 1.**
2. Armar el cuestionario de entrevista a partir de los `[RELEVAR]` de la
   propuesta elegida.
3. Relevar y **completar las líneas de base**. Recién con esos números se puede
   escribir el Árbol de Problemas y, después, los indicadores de la MML.
