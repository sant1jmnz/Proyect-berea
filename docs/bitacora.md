# Bitácora personal — Santiago Jiménez

**Materia:** Proyecto Informático I — Prof. Cynthia Berea
**Año y especialidad:** 4to año, Computación — Escuela Técnica de CABA
**Marco pedagógico:** Buenos Aires Aprende
**Cursada:** 8 semanas — Carpeta de Proyecto V1
**Repositorio:** https://github.com/sant1jmnz/Proyect-berea

> Nota: los datos de encuadre de arriba están tomados del plan de aprendizaje
> de la cátedra. Santiago los corrige a mano cuando corresponda.

Registro personal del avance en el proyecto, tal como pide el plan de
aprendizaje del bimestre (autoseguimiento semanal como instrumento de
evaluación formativa). **Se cierra una entrada al final de cada jornada de
trabajo**; las entradas se agregan al final, sin modificar las anteriores.

---

## Jornada 1 — 18 de agosto de 2026

### Creación del repositorio del proyecto

Creé el repositorio **sant1jmnz/Proyect-berea** en GitHub (privado), que va a ser
el repositorio oficial del proyecto y donde se arma toda la Carpeta de Proyecto
V1 en formato Markdown. Esto adelanta una de las tareas previstas para la
semana 7 del plan ("Creación del repositorio oficial del proyecto en Git/GitHub
con el archivo README.md estructurado").

### Incorporación de la herramienta de brainstorming

Descargué e instalé en el repositorio la herramienta **brainstorming** del
proyecto Superpowers (repositorio público `obra/superpowers`, licencia MIT).
Sirve para ordenar la etapa de generación y refinamiento de ideas: obliga a
entender el contexto y a validar la propuesta antes de pasar a implementar, que
es exactamente el enfoque del bimestre. Quedó en `.claude/skills/brainstorming/`
junto con un `ORIGIN.md` que documenta la fuente, la versión exacta y la
licencia.

### Lectura y sistematización del material de cátedra

Revisé el material de la carpeta de Drive *"proyecto berea 1 segundo
cuatrimestre"*:

- **Plan de aprendizaje – Proyecto Informático I:** desafío integrador,
  capacidades a desarrollar, entregable final, secuencia semanal de 8 semanas y
  criterios de evaluación.
- **PROY1 – C11 Teoría (Prof. Cynthia Berea):** enfoque de Marco Lógico (EML),
  objetivo general y específicos, resultados esperados, actividades, indicadores
  objetivamente verificables, fuentes de verificación e hipótesis externas, con
  el ejemplo del Programa ZUMAR de Guayaquil.
- **¿Qué es la Matriz FODA?:** las cuatro variables, el corte entre factores
  internos y externos, y la formulación de estrategias a partir del cruce.
- **Documento de usabilidad:** las 10 heurísticas de Jakob Nielsen y material de
  referencia sobre historias de usuario.

Quedan pendientes de ver los **10 videos** de la carpeta (árbol de problemas,
árbol de objetivos, metodología y ejemplos de Matriz de Marco Lógico).

### Configuración del repositorio con el marco teórico de la materia

A partir de ese material armé la configuración del repositorio, para que toda la
documentación se escriba siguiendo la metodología de la cátedra.

`CLAUDE.md` deja asentado el desafío integrador, las seis piezas del entregable
final, la estructura de carpetas, las convenciones de redacción (problemas en
negativo, objetivos en infinitivo, un solo problema central, indicadores con
línea de base, numeración estable `C1`/`E1`/`OE1`/`R1`/`RF-01`) y, sobre todo,
la **cadena de trazabilidad** que ordena todo el trabajo:

```
Causas del Árbol de Problemas → Medios del Árbol de Objetivos
                              → Componentes y Actividades de la MML
                              → Requerimientos funcionales
                              → Pantallas del maquetado
```

Esa cadena es la clave: la rúbrica evalúa la *integración* entre diagnóstico,
planificación, requerimientos y maquetado, no cada pieza suelta.

Además quedaron ocho guías metodológicas en `.claude/skills/`, una por etapa:

| Guía | Semana | Contenido |
|---|---|---|
| `arbol-de-problemas` | 2 | Problema central, causas raíz y efectos |
| `arbol-de-objetivos` | 3 | Conversión a medios y fines; alternativa de intervención |
| `matriz-marco-logico` | 4 y 5 | Lógica vertical y horizontal (IOV, MoV, supuestos) |
| `analisis-foda` | apoyo | Las cuatro variables y las estrategias del cruce |
| `requerimientos` | 6 | RF, RNF, historias de usuario y backlog |
| `maquetado-ux` | 7 | Wireframes, user flow y heurísticas de Nielsen |
| `pitch` | 8 | Guion de 7 a 10 minutos y preguntas anticipadas |
| `carpeta-proyecto` | cierre | Auditoría de trazabilidad y checklist de rúbrica |

### Gestión de accesos del repositorio

Sumé como colaboradores a **bautistacasero265-maker** y **Nicolas041209**, ambos
con permiso de escritura sobre `Proyect-berea`. Verifiqué que el acceso de
colaborador en GitHub es **por repositorio**: no ven el resto de mis repos
privados. Lo que sí es visible para cualquiera son mis repositorios públicos
(`Apolo-11`, `Owen-Robot-Controller`, `html-apolo-11`), que ya lo eran de antes.

También renombré la rama de trabajo a `main` y la dejé como rama por defecto.

### Relevamiento de las propuestas de proyecto

Quedaron consolidadas diez propuestas (ver anexo). La del centro de estética
integral es la principal.

### Pendientes que quedaron abiertos

- Corregir a mano los datos de encuadre de la cabecera de esta bitácora.
- Ver los 10 videos del material de cátedra.
- Definir el equipo y los roles.
- Cerrar la elección de la propuesta.

---

# Anexo — Propuestas de proyecto en evaluación

Diez ideas relevadas en la etapa de tormenta de ideas (semana 1). La primera es
la **propuesta principal**; las demás quedan como alternativas.

## Propuesta 1 (PRINCIPAL) — Aplicación web para centro de estética integral

### Idea del proyecto

Desarrollar una aplicación web para un centro de estética integral centrada en
la experiencia del usuario, la automatización operativa y la seguridad de los
datos. La plataforma ofrece un entorno interactivo con comparativas de "antes y
después", un carrusel de valoraciones en tiempo real integrando la Google Maps
API, y un quiz de diagnóstico de piel para recomendar tratamientos
personalizados.

El sistema cuenta con un backend centralizado diseñado para gestionar las
integraciones externas de forma segura:

- **Google Calendar API:** al completar el flujo de reserva de 3 pasos, el turno
  se sincroniza automáticamente en el calendario personal del dueño.
- **API de Gemini 2.5 Flash con base de datos (RAG):** el asistente virtual
  consulta exclusivamente una base de datos local predefinida con la información
  del negocio (precios, protocolos, políticas). Esto restringe sus respuestas
  únicamente a temas del centro de estética, evitando respuestas incorrectas,
  fuga de datos o el uso indebido de la IA.
- **Pasarela de pagos (Mercado Pago / tarjetas de crédito y débito):** permite
  procesar el cobro de la seña ($20.000) de forma directa mediante la API de la
  pasarela de pagos. El backend no almacena datos sensibles de tarjetas ni
  información financiera, garantizando la privacidad del cliente y el
  cumplimiento de normativas de seguridad.
- **Google Maps API:** extrae las reseñas y calificaciones del negocio.

El módulo "Mis Turnos" opera mediante cookies del navegador y "enlaces mágicos"
para migrar la información a otros dispositivos sin requerir registros ni
contraseñas.

### Problema que soluciona

1. **Saturación en la atención al cliente y riesgos de alucinación de la IA.**
   Las consultas repetitivas consumen tiempo administrativo. Integrar el
   asistente con la API de Gemini 2.5 Flash conectada a la base de datos interna
   automatiza la atención las 24 horas y garantiza que la IA solo brinde
   información oficial y precisa del negocio, eliminando vulnerabilidades de
   seguridad. En el caso de que se le pregunte algo que la IA no pueda responder
   debido a las restricciones, se le envía un mensaje al usuario diciendo que se
   comunique con el dueño, generándole un link de WhatsApp.
2. **Desorganización en la agenda y ausentismo.** Sincroniza las reservas
   automáticamente mediante la Google Calendar API para evitar choques de
   horarios, mientras que el cobro seguro de la seña ($20.000) compromete al
   cliente y reduce los turnos perdidos.
3. **Desconfianza del usuario respecto a sus datos personales y financieros.**
   Procesa los pagos a través de Mercado Pago sin guardar credenciales ni datos
   bancarios en el backend del sistema.
4. **Fricción en el proceso de registro e indecisión en los tratamientos.**
   Elimina la barrera de recordar contraseñas gracias al acceso por cookies y
   "link mágico". Además, orienta al usuario mediante el quiz de piel, las fotos
   de "antes y después" y las reseñas de la Google Maps API.

## Propuesta 2 — Gestión de inventario y punto de venta (POS simplificado)

### Idea del proyecto

Desarrollar una aplicación web de gestión de inventario y punto de venta para
restaurantes y kioscos, orientada a optimizar el control de caja y la atención
en el local. La plataforma permite registrar y consultar en tiempo real el
catálogo de productos con su respectivo precio, categoría y stock disponible.

El sistema cuenta con una interfaz ágil para que el personal de atención pueda
registrar cada venta diaria en pocos clics, actualizando el inventario de manera
automática sin necesidad de verificar el stock físico manualmente. Además,
incluye un panel de control con una sección de "Movimientos del Día" que
desglosa los ingresos, el historial de ventas concretadas y las alertas de
productos con bajo stock.

### Problema que soluciona

- **Control manual e ineficiente del stock:** evita que el personal tenga que
  revisar físicamente las góndolas o depósitos para saber si hay disponibilidad
  de un producto, reduciendo errores humanos y demoras en la atención.
- **Falta de visibilidad sobre las ventas diarias:** reemplaza los registros en
  papel o los cálculos manuales de fin de jornada por un panel de movimientos en
  tiempo real que detalla el total vendido, la caja actual y los productos de
  mayor rotación.
- **Demoras en la atención en caja:** simplifica el proceso de cobro y registro
  de productos al centralizar los precios y el inventario en una sola pantalla
  intuitiva.

## Propuesta 3 — Organizador de tareas e intercambio de turnos de trabajo

Aplicación web para empleados a tiempo parcial donde pueden visualizar sus
horarios semanales, registrar horas trabajadas para estimar cobros y solicitar
cambios de turno con compañeros.

## Propuesta 4 — Comparador de hardware

Búsqueda y comparación de precios de componentes de PC entre proveedores.

## Propuesta 5 — Buscador de adopción y registro de mascotas

Plataforma web que conecta refugios con adoptantes, permitiendo filtrar animales
por tamaño, edad o compatibilidad, y gestionar las solicitudes de adopción.

## Propuesta 6 — Gestor de gastos compartidos para viajes o eventos

Aplicación web sencilla para ingresar gastos grupales, calcular automáticamente
cuánto debe o recibe cada integrante y simplificar las rendiciones de cuentas.

## Propuesta 7 — Menú digital para comedores

Publicación del plato del día, votación de favoritos y sugerencias.

## Propuesta 8 — Entradas con código QR

Creación de eventos, mapa de capacidad y emisión de pases digitales.

## Propuesta 9 (NUEVA) — Reserva y control de uso de laboratorios y equipamiento

*Derivada del cruce de la propuesta 1 (reserva de turnos con agenda
sincronizada), la propuesta 2 (control de stock y alertas) y la propuesta 8
(pases digitales con QR).*

### Idea del proyecto

Aplicación web para que los docentes reserven el laboratorio de informática, el
aula taller o el equipamiento portátil de la institución (netbooks, proyectores,
kits de robótica), y para que el encargado lleve el control de qué se prestó, a
quién y en qué estado volvió.

El flujo de reserva es de tres pasos: se elige el recurso, se elige el bloque
horario disponible de una grilla semanal y se confirma. La grilla muestra en
vivo qué está libre, evitando la doble reserva. Cada equipo prestable lleva una
etiqueta con un código QR: escanearlo desde el celular abre directamente la
ficha del equipo para registrar el retiro o la devolución en un toque.

El panel del encargado muestra los movimientos del día, qué hay prestado en este
momento, qué está vencido sin devolver y qué equipos quedaron marcados como
fallados o fuera de servicio. El acceso es por enlace, sin crear usuarios ni
contraseñas nuevas.

### Problema que soluciona

- **Superposición de reservas y pérdida de horas de clase:** hoy la reserva se
  hace verbalmente o en un cuaderno y es habitual que dos cursos lleguen al
  mismo laboratorio en la misma hora.
- **Falta de trazabilidad del equipamiento:** cuando falta un proyector o una
  netbook nadie puede reconstruir quién fue el último que lo usó.
- **Demora en detectar equipos fuera de servicio:** los desperfectos se
  descubren recién cuando alguien los necesita en el medio de una clase.
- **Carga administrativa del encargado:** reemplaza la planilla en papel y el
  recuento manual de fin de jornada.

## Propuesta 10 (NUEVA) — Registro y seguimiento de reclamos de mantenimiento

*Derivada del cruce de la propuesta 5 (gestión de solicitudes con estados y
seguimiento), la propuesta 8 (identificación por QR) y el panel de movimientos
de la propuesta 2.*

### Idea del proyecto

Aplicación web para que cualquier integrante de la comunidad educativa reporte
un desperfecto edilicio y pueda seguir en qué estado quedó el reclamo, en lugar
de que el aviso se pierda en un pasillo.

Cada aula, baño y espacio común tiene un código QR pegado en la puerta. Al
escanearlo, el formulario ya viene con el lugar cargado: solo hay que elegir el
tipo de problema (eléctrico, sanitario, mobiliario, conectividad, limpieza),
describirlo en una línea y adjuntar una foto. El reclamo entra con estado
*Recibido* y avanza por *En revisión*, *En reparación* y *Resuelto*, y quien lo
reportó recibe el seguimiento por un enlace, sin registrarse.

El panel de mantenimiento ordena los reclamos por antigüedad y por cantidad de
reportes repetidos del mismo problema, marca los que llevan más de una semana
sin moverse, y muestra un histórico por espacio: qué aula concentra más fallas y
cuánto se tarda en promedio en resolver cada tipo de reclamo.

### Problema que soluciona

- **Los reclamos se pierden en el circuito informal:** el aviso es de boca en
  boca y no queda constancia de quién lo recibió ni de si alguien lo tomó.
- **Nadie sabe en qué estado está su reclamo:** quien reportó el problema no
  tiene forma de averiguar si se está resolviendo, y termina volviendo a
  reclamar.
- **Reportes duplicados del mismo desperfecto:** varias personas informan la
  misma falla por canales distintos y se atiende dos veces.
- **Falta de información para priorizar:** sin datos, la reparación depende de
  quién insiste más.

---

## Estado de la elección

La **propuesta 1 (centro de estética integral)** es hoy la candidata principal:
es la más desarrollada, tiene un cliente real identificado, un alcance claro y
varias integraciones que permiten mostrar decisiones técnicas fundamentadas en
el pitch. Antes de cerrarla hay que verificar que el alcance sea realizable en
el tiempo disponible y relevar al dueño del negocio con entrevistas para
sostener el diagnóstico con datos y no con supuestos.

Las propuestas 9 y 10 tienen la ventaja de que los usuarios están dentro de la
institución, lo que facilita el relevamiento, las entrevistas y la validación
del maquetado con usuarios reales.

## Próximos pasos

1. Ver los videos del material de cátedra sobre árbol de problemas, árbol de
   objetivos y Matriz de Marco Lógico.
2. Definir el equipo (3 a 4 integrantes) y los roles.
3. Cerrar la elección de la propuesta y delimitar el problema central, uno solo,
   redactado en negativo.
4. Relevar con entrevistas y observación para respaldar el diagnóstico.
5. Construir el Árbol de Problemas y someterlo a revisión cruzada con otro
   equipo.
