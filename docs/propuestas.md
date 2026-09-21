# Propuestas de proyecto: desarrollo y evidencia

Documento de trabajo de la etapa de detección de necesidades (semana 1). Cada
propuesta sigue el mismo esquema para poder compararlas y elegir una con
criterio.

El problema central va redactado como pide la cátedra: en negativo, en
presente, describiendo la necesidad y nunca la solución faltante. Es el
candidato a tronco del Árbol de Problemas.

La evidencia distingue dos cosas. Los datos públicos, con fuente citada,
sirven para dar contexto al problema. Lo marcado `[RELEVAR]` solo puede
salir del relevamiento propio del equipo: entrevistas, encuestas,
observación. Un dato nacional no reemplaza medir el caso concreto, y
ninguna cifra `[RELEVAR]` se completa a ojo, porque un indicador inventado
invalida toda la Matriz de Marco Lógico que se apoye en él.

---

## Criterio de selección aplicado

De las diez propuestas relevadas quedan cinco en carrera. Se descartaron las
que caían en alguno de estos dos casos:

1. Sin evidencia disponible: no hay datos públicos citables y tampoco un
   camino claro para relevarlos.
2. Solución ya existente y masiva: hay productos gratuitos y consolidados que
   resuelven lo mismo, sin un ángulo diferencial defendible.

Las descartadas quedan al final del documento con el motivo del descarte, en
vez de borrarse, porque mostrar qué se evaluó y por qué se dejó de lado es
parte de la justificación de la alternativa elegida.

---

## Propuesta 1 (PRINCIPAL): Sistema de turnos para instituto de estética médica

Usuario / cliente: recepción de Dermalia, Instituto de Estética Médica, y
sus pacientes actuales y potenciales.

### Problema central (borrador)

*La gestión de turnos y consultas del instituto de estética depende de la
atención manual de la recepción por WhatsApp, lo que consume horas de
trabajo, produce superposiciones y turnos perdidos, y demora las
respuestas a quienes consultan.*

El problema no es "no hay una app": es la carga operativa y la pérdida de
turnos que hoy existen.

### Evidencia

Datos públicos:

- El 97% de los argentinos usa WhatsApp a diario y el 58% lo usa para
  consultas comerciales; el 28% ya compra por ese canal: es el mismo canal
  donde hoy se satura la atención
  ([estudio sobre WhatsApp y compras](https://dialecto.com/blog/whatsapp-marketing/estudio-impacto-de-whatsapp-en-compras/)).
- El ausentismo a turnos reservados es un problema reconocido del rubro: en
  España los centros de estética y peluquerías empezaron a cobrar por
  adelantado para frenar las "reservas fantasma", y reportan menos
  inasistencias
  ([Cuatro](https://www.cuatro.com/noticias/economia/20250116/reservas-fantasma-centros-estetica-peluquerias_18_014508640.html)).
- Un caso documentado de red de clínicas con recordatorios automáticos de
  turno reporta una reducción del 50% en las inasistencias
  ([WhatsApp Business API](https://developargentina.com/blog/whatsapp-business-api-argentina-automatizacion-ventas-2025)),
  y sirve de referencia para fijar la meta del indicador.

Datos del instituto:

- 25 consultas por WhatsApp por día, de las cuales ≈70% (18) son repetidas
  (precios, horarios, "¿qué incluye el protocolo?").
- 95 minutos por día dedicados a responderlas. Es la línea de base del
  indicador principal.
- 6 turnos por semana perdidos por inasistencia, ≈ $120.000/semana (precio
  promedio de protocolo, $20.000).
- 5 superposiciones de turno por mes.

### Qué hace el sistema

Dos apartados, los dos en Qt de escritorio: una terminal táctil en el
instituto para que la paciente cargue su propio turno, y la PC de
recepción para los turnos que llegan por teléfono.

| Módulo | Función |
|---|---|
| Cargar turno en 3 pasos | Protocolo → horario disponible → confirmación, con agenda propia de los profesionales en el sistema; lo hace la paciente en la terminal o la recepción cuando llama por teléfono |
| Registro de seña | Simulado (mock): se marca el estado de pago, sin pasarela real ni datos de tarjeta |
| Buscador de precios y protocolos | Búsqueda por palabra clave contra una base local con precios, protocolos y políticas; si no encuentra coincidencia, marca la derivación a WhatsApp del instituto |
| Buscar turnos | Por nombre, DNI o teléfono de la paciente, sin enlace ni cuenta |

**Restricción técnica del equipo** (definida después de este relevamiento
inicial): backend en C con SQL Server, frontend en Qt de escritorio, sin
integraciones por API externa ni canal web. Por eso el registro de seña y
el buscador quedaron descriptos arriba como simulados/locales, sin
Mercado Pago, Google Calendar ni un modelo de lenguaje real detrás. El
detalle completo, actualizado, está en `docs/03-matriz-marco-logico.md` y
`docs/04-requerimientos.md`.

### Fuera de alcance

Historia clínica de tratamientos, gestión de stock de insumos, liquidación
de comisiones, app nativa, y una vitrina de fotos y reseñas (dependía de
la API de Google Maps). Este bimestre no se programa nada: se formula y
se diseña.

### Indicadores preliminares

| Indicador | Meta | Línea de base |
|---|---|---|
| Tiempo diario de atención manual de consultas | Reducción del 60% | 95 min/día |
| Turnos perdidos por inasistencia | Reducción del 50% | 6 turnos/semana |
| Superposiciones de agenda | 0 por mes | 5 casos/mes |
| Consultas resueltas con el buscador interno, sin buscar a mano o de memoria | ≥ 70% | 0% (hoy todo es manual) |

### Riesgos

- Adopción: que la recepción siga anotando turnos a mano o respondiendo de
  memoria en vez de usar el sistema. Mitigación: capacitación breve al
  iniciar y transición gradual.
- Resistencia a la seña: puede espantar pacientes nuevas. Se estima que ≈10%
  de pacientes nuevas podría dudar; falta relevar qué hacen los competidores
  de la zona.
- Datos personales: los datos de contacto y protocolo de la paciente son
  sensibles y se guardan solo en la base local del instituto.
- Fidelidad del mock: no hay pasarela de pago ni modelo de lenguaje real,
  así que el pitch tiene que dejar claro qué es simulado y qué sería una
  integración real en una versión productiva, sin esconder la diferencia.

### Viabilidad para el bimestre

Alta. Alcance delimitado, decisiones técnicas defendibles en el pitch. El
riesgo de armar demasiadas integraciones externas quedó resuelto de raíz
por la restricción técnica del equipo (C + SQL Server, sin APIs): no hay
cuatro integraciones que gestionar, hay cuatro mocks propios. Conviene
igual marcar cuáles son núcleo (reserva + seña) y cuáles deseables (quiz,
reseñas).

## Propuesta 2: Gestión de inventario y punto de venta (POS simplificado)

Usuario / cliente: dueño y personal de atención de un kiosco o restaurante
chico.

### Problema central (borrador)

*El control de stock y el registro de ventas de los comercios minoristas
chicos se lleva de memoria o en papel, por lo que el personal no sabe qué hay
disponible sin ir a mirar y el dueño no conoce el resultado del día hasta
cerrar la caja a mano.*

### Evidencia

Datos públicos:

- El sector atraviesa una crisis severa: cerraron 41.000 kioscos desde
  diciembre de 2023, pasando de unos 100.000 a 59.000, alrededor de 50
  cierres por día según UKRA
  ([Infobae](https://www.infobae.com/economia/2026/08/03/cerraron-41000-kioscos-desde-diciembre-de-2023-y-en-el-sector-ven-una-crisis-similar-a-la-de-2001/)).
- Un relevamiento de ARCA registró una caída de 112.000 a 96.000 kioscos
  activos en un año
  ([Infobae](https://www.infobae.com/economia/2025/08/12/crisis-en-los-kioscos-cerraron-16000-locales-en-el-ultimo-ano-y-el-sector-cae-a-minimos-historicos/)),
  con más de 72.000 puestos de trabajo perdidos en dos años
  ([BAE Negocios](https://www.baenegocios.com/negocios/cerraron-mas-de-36-000-kioscos-y-se-perdieron-72-000-puestos-de-trabajo-en-los-ultimos-dos-anos/)).

Estos números prueban que el sector está bajo presión, no que la causa sea
la falta de un sistema de gestión. Las fuentes atribuyen los cierres a la
caída del consumo, los alquileres y los servicios. Presentarlo como
"cierran kioscos porque no tienen software" sería el error metodológico
que la cátedra penaliza. El encuadre correcto es otro: con un margen tan
ajustado, el descontrol de stock y la falta de visibilidad de la caja
dejan de ser molestias y pasan a ser pérdidas que el comercio ya no puede
absorber.

A relevar en el comercio elegido:

- `[RELEVAR]` Cuántas veces por semana se pierde una venta por faltante no detectado.
- `[RELEVAR]` Cuánto tarda el cierre de caja diario hoy.
- `[RELEVAR]` Cuántos productos maneja y cuántos rotan de verdad.
- `[RELEVAR]` Qué diferencia aparece entre la caja contada y lo que se esperaba.

### Qué hace el sistema

Catálogo con precio, categoría y stock; registro de venta en pocos clics con
descuento automático de inventario; panel de "Movimientos del Día" con
ingresos, historial y alertas de bajo stock.

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

Que el personal siga sin cargar las ventas en momentos de mucha gente: si el
registro no es más rápido que el cuaderno, no se usa. La carga inicial del
catálogo es trabajo real y hay que preverla como actividad.

### Viabilidad para el bimestre

Alta. Alcance chico y claro. Es la alternativa más segura si la de estética
resulta demasiado ambiciosa.

## Propuesta 5: Buscador de adopción y registro de mascotas

Usuario / cliente: refugios y proteccionistas independientes, y personas que
quieren adoptar.

### Problema central (borrador)

*Los refugios gestionan las solicitudes de adopción por redes sociales y
mensajes privados, sin un registro de los animales disponibles ni
seguimiento de cada solicitud, por lo que se pierden contactos de posibles
adoptantes y se repite el trabajo de responder lo mismo.*

### Evidencia

Datos públicos:

- Una ONG estima más de 20 millones de animales en la calle en Argentina
  ([Infobae](https://www.infobae.com/sociedad/2024/07/27/dia-del-perro-callejero-una-ong-estima-que-en-la-argentina-hay-mas-de-20-millones-de-animales-que-viven-en-las-calles/));
  un estudio del Colegio de Veterinarios de Buenos Aires de 2018 calculaba
  6 millones de perros sin hogar.
- En CABA se estiman 100.000 perros y gatos en situación de abandono, uno
  cada 30 habitantes
  ([La Nación](https://www.lanacion.com.ar/lifestyle/dia-mundial-del-perro-callejero-cual-es-la-cifra-local-de-animales-que-no-tienen-hogar-nid27072021/)).
- Las fuentes coinciden en que los refugios no dan abasto y sostienen la
  situación sin política pública detrás
  ([Ámbito](https://www.ambito.com/maltrato-animal/sos-refugios-tres-historias-lucha-contra-el-abandono-y-el-n5623609)).
- Activistas de rescate describen un ritmo de reproducción que la castración
  no alcanza a compensar (una entrevistada estima 3.000 cachorros nacidos en
  un solo día), lo que sostiene el volumen de solicitudes que un refugio
  recibe sin infraestructura para procesarlas
  ([Infobae](https://www.infobae.com/perros-y-gatos/2025/09/06/rescate-animal-y-abandono-en-argentina-el-rol-del-activismo-y-el-trabajo-de-las-ong/)).

Las cifras de animales en calle son estimaciones de ONG con metodologías
distintas: hay que citarlas como estimación, no como dato oficial.

A relevar en un refugio concreto:

- `[RELEVAR]` Cuántas solicitudes de adopción recibe por mes y por qué canal.
- `[RELEVAR]` Cuántas se pierden sin respuesta y por qué.
- `[RELEVAR]` Cuánto tarda una adopción desde el primer contacto.
- `[RELEVAR]` Qué datos necesitan del adoptante para aprobar una adopción.

### Fuera de alcance

Historia clínica veterinaria, gestión de donaciones y cobros, geolocalización
de animales perdidos.

### Viabilidad para el bimestre

Media-alta. Problemática con impacto social claro y usuarios accesibles si un
refugio de la zona acepta participar. Sin refugio que acepte, no hay
relevamiento y la propuesta se cae.

## Propuesta 9 (NUEVA): Reserva y control de laboratorios y equipamiento

Derivada del cruce de la propuesta 1 (reserva con agenda), la 2 (stock y
alertas) y la 8 (identificación por QR).

Usuario / cliente: docentes, encargado de laboratorio y quien administra el
equipamiento de la institución.

### Problema central (borrador)

*La reserva de laboratorios y el préstamo de equipamiento se registran de
palabra o en un cuaderno, por lo que se superponen reservas, no se puede
reconstruir quién usó cada equipo por última vez y los desperfectos se
descubren recién en el momento de usarlos.*

### Evidencia

La ventaja de esta propuesta es que el relevamiento está a mano: se puede
entrevistar al encargado y a los docentes en la misma institución, y observar
directamente cómo se reserva hoy.

- `[RELEVAR]` Cuántas superposiciones de reserva ocurren por mes.
- `[RELEVAR]` Cuántos equipos hay y cuántos figuran como no localizados.
- `[RELEVAR]` Cuánto tiempo de clase se pierde por equipo fallado no informado.

### Qué hace el sistema

Grilla semanal de disponibilidad en vivo; reserva en tres pasos; etiqueta QR
por equipo que abre la ficha para registrar retiro y devolución; panel con
préstamos activos, vencidos y equipos fuera de servicio; acceso por enlace
sin contraseñas.

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

Alta. Es la propuesta con relevamiento más barato y validación de maquetado
más fácil: los usuarios están en el edificio.

## Propuesta 10 (NUEVA): Registro y seguimiento de reclamos de mantenimiento

Derivada del cruce de la propuesta 5 (solicitudes con estados), la 8 (QR) y
el panel de la 2.

Usuario / cliente: toda la comunidad educativa como reportantes; el
encargado de mantenimiento y la dirección como gestores.

### Problema central (borrador)

*Los desperfectos edilicios se avisan por canales informales y sin registro,
por lo que no queda constancia de quién recibió el reclamo, quien lo reportó
no sabe si se está resolviendo, y no hay información para priorizar las
reparaciones.*

### Evidencia

Datos públicos:

- Un relevamiento de UTE encontró que el 20% de las escuelas de CABA tiene
  problemas edilicios y el 10% no tiene calefacción
  ([UTE](https://ute.org.ar/escuelas-de-caba-20-con-problemas-edilicios-y-10-sin-calefaccion/)).
- Se documentaron más de 200 escuelas de CABA con problemas de
  infraestructura
  ([ANCCOM](https://anccom.sociales.uba.ar/2022/09/14/caba-mas-de-200-escuelas-con-problemas-de-infraestructura/)).
- Las fuentes señalan la falta de transparencia y la inexistencia de
  estadísticas oficiales sobre el estado edilicio
  ([El Destape](https://www.eldestapeweb.com/opinion/ciudad-de-buenos-aires/infraestructura-escolar-en-caba-subejecucion-falta-de-vacantes-y-abandono-202253114310)):
  el problema de registro que el sistema resuelve está documentado como
  problema real del sector, no solo del edificio propio.

A relevar:

- `[RELEVAR]` Cuántos reclamos se reportan por mes y por qué canal.
- `[RELEVAR]` Cuántos se resuelven, en cuánto tiempo, y cuántos se pierden.
- `[RELEVAR]` Cuántas veces se reporta dos veces el mismo desperfecto.

### Sensibilidad a tener en cuenta

Un registro de fallas edilicias con fotos es información políticamente
sensible para cualquier institución. Hay que acordar con la dirección desde
el principio quién ve qué y si los datos son internos. Presentarlo como
herramienta de gestión y priorización, no como sistema de denuncia, es lo que
lo vuelve viable.

### Viabilidad para el bimestre

Alta en lo técnico y en el relevamiento; media en lo político, por lo
anterior. Requiere aval de la institución antes de arrancar.

---

## Comparación de las cinco propuestas en carrera

| # | Propuesta | Usuario accesible | Evidencia pública | Competencia | Viabilidad |
|---|---|---|---|---|---|
| 1 | Instituto de estética médica | Dermalia | Buena | Media | Alta |
| 2 | POS / inventario | A conseguir | Buena | Alta | Alta |
| 5 | Adopción de mascotas | A conseguir | Buena | Baja | Media-alta |
| 9 | Laboratorios y equipamiento | Sí, acá mismo | A relevar | Baja | Alta |
| 10 | Reclamos de mantenimiento | Sí, acá mismo | Buena | Baja | Alta |

La 2 es la única que sobrevive con competencia alta. Se sostiene porque la
evidencia del sector es contundente, y el segmento al que apunta (el kiosco
chico que hoy no paga ningún sistema) está desatendido por precio. Ese
argumento hay que poder defenderlo en el pitch.

Recomendación: sostener la 1 (estética médica) como principal, por la
evidencia y la viabilidad ya expuestas arriba. La 9 queda anotada como
alternativa con relevamiento real disponible, por si en algún momento se
decide cambiar de enfoque.

Lo que sigue, en orden:

1. Datos de partida de la propuesta elegida (hecho, ver "Datos del centro"
   arriba).
2. Árbol de Problemas e indicadores de la MML sobre esos números (hecho, ver
   `docs/01-arbol-de-problemas.md` y `docs/03-matriz-marco-logico.md`).
3. Roles del equipo y el resto de la Carpeta de Proyecto.

---

# Anexo: Propuestas descartadas y motivo

Se mantienen registradas como evidencia del proceso de selección.

| # | Propuesta | Motivo del descarte |
|---|---|---|
| 3 | Organizador de turnos de trabajo | La evidencia juega en contra: el 45,1% de los jóvenes ocupados es informal, y sin empleo formal no hay grilla ni liquidación que gestionar. Además depende por completo de conseguir un comercio que acepte usarlo, y compite con soluciones de gestión de personal ya instaladas |
| 4 | Comparador de precios de hardware | Ya existe idéntico y gratuito: HardGamers, con historial de precios y funcionando hoy. Además exige scraping de terceros, que es frágil y de legalidad dudosa |
| 6 | Gestor de gastos compartidos | Sin ningún dato público citable, y Splitwise resuelve exactamente lo mismo desde hace años. El alcance además es demasiado chico para sostener un bimestre |
| 7 | Menú digital para comedores | Sin datos públicos aplicables. En su versión básica es una cartelera digital; el único ángulo con sustancia (reducir desperdicio ajustando producción a demanda) exigía reformular el problema entero |
| 8 | Entradas con código QR | Tiene buena evidencia, pero el mercado está muy cubierto por plataformas comerciales y gratuitas. El nicho defendible, evento chico autogestionado, es demasiado estrecho para justificar el desarrollo frente a las alternativas existentes |

La más discutible de las cinco es la 8: la evidencia de fraude es sólida y la
solución es demostrable. Si el equipo consigue un evento concreto donde
relevar (una fiesta escolar, un torneo de club), puede reabrirse. Se descarta
por competencia, no por falta de problema.
