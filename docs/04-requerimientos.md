# Requerimientos

Se derivan de los Componentes de la MML (`docs/03-matriz-marco-logico.md`).
Cada RF referencia el componente del que sale; no hay ningún requerimiento
acá que no venga de R1-R4.

**Restricción técnica**: backend en C con SQL Server, frontend en Qt, sin
integraciones por API externa ni canal web. La restricción es sobre la
tecnología (Qt, no HTML/web), no sobre quién puede usar el sistema: por
eso el sistema tiene **dos apartados**, ambos nativos en Qt, sin depender
de ningún navegador ni servidor web:

- **Apartado Cliente**: pantalla táctil (kiosco) instalada en el instituto,
  para que la paciente cargue su propio turno mientras está en el local.
  No es self-service remoto desde el celular de la paciente (eso sí
  necesitaría web), es self-service presencial.
- **Apartado Gestión**: lo usa la recepción desde la PC del mostrador,
  para cargar turnos que la paciente pide por teléfono, administrar la
  disponibilidad y resolver consultas.

Los dos apartados comparten los mismos Componentes (R1-R4) y la misma base
en SQL Server, solo cambia quién entra por cada pantalla. Donde antes
había un tercero (Mercado Pago, Google Calendar, un modelo de lenguaje),
el requerimiento describe una versión mockeada dentro del propio sistema.

## Requerimientos funcionales

| ID | Apartado | El sistema debe permitir... | Componente MML | Prioridad |
|---|---|---|---|---|
| RF-01 | Cliente | ...a la paciente cargar su propio turno en 3 pasos (protocolo → horario disponible → confirmación) desde el kiosco del instituto, sin tener que pedírselo a la recepción. | R1 | Must |
| RF-02 | Gestión | ...a la recepción cargar un turno en 3 pasos cuando la paciente lo pide por teléfono, sin anotarlo a mano. | R1 | Must |
| RF-03 | Gestión | ...a los profesionales o a la recepción cargar y editar la disponibilidad horaria directo en el sistema (agenda propia en SQL Server, sin integración externa), para evitar superposiciones. | R1 | Must |
| RF-04 | Cliente + Gestión | ...mostrar únicamente los horarios realmente disponibles, actualizados en tiempo real, sin importar si carga el turno la paciente o la recepción. | R1 | Must |
| RF-05 | Cliente | ...a la paciente consultar precios, duración y protocolos en un buscador por palabra clave desde el kiosco, mientras espera o antes de decidirse. | R2 | Must |
| RF-06 | Gestión | ...a la recepción buscar lo mismo en el buscador, para responder consultas por teléfono sin buscar a mano o de memoria. | R2 | Must |
| RF-07 | Cliente + Gestión | ...marcar la consulta para derivar a WhatsApp del instituto (enlace `wa.me`, no envío automático) cuando el buscador no encuentra coincidencia en la base, para no perderla. | R2 | Must |
| RF-08 | Cliente | ...a la paciente simular el pago de la seña al confirmar su turno desde el kiosco (mock: el sistema registra el estado como pagado, sin procesar dinero real ni conectarse a una pasarela). | R3 | Must |
| RF-09 | Gestión | ...a la recepción registrar el pago de la seña cuando confirma un turno cargado por teléfono (mismo mock que RF-08). | R3 | Must |
| RF-10 | Cliente + Gestión | ...calcular (de forma simulada) una seña del 30% del valor del protocolo (mínimo $5.000), reembolsable 100% si se cancela con más de 24 h de anticipación y no reembolsable por debajo de ese plazo o por inasistencia. | R3 | Should |
| RF-11 | Cliente + Gestión | ...generar un recordatorio de turno antes de la fecha reservada, visible tanto para la paciente (en el kiosco, buscando su turno) como para la recepción, sin envío real por WhatsApp o email. | R4 | Must |
| RF-12 | Cliente | ...a la paciente buscar y cancelar su propio turno desde el kiosco, escribiendo su DNI o teléfono (sin enlace ni contraseña: está físicamente en el instituto). | R1 | Should |
| RF-13 | Gestión | ...a la recepción buscar y cancelar el turno de cualquier paciente por nombre, DNI o teléfono. | R1 | Should |

Los Must son los que atacan directamente las cuatro causas del Árbol de
Problemas (C1-C4) en cualquiera de los dos apartados. RF-10, RF-12 y RF-13
son Should: mejoran la experiencia pero el sistema funciona sin ellos.

Se sacó del alcance la "vitrina" (fotos antes/después + reseñas de Google
Maps) que estaba anotada como Could en una versión anterior: dependía de
la API de Google Maps, que no es viable con la restricción técnica actual
(Qt, sin web ni API). Queda anotada en `docs/propuestas.md` como posible
iteración futura si el proyecto suma en algún momento un componente web.

## Requerimientos no funcionales

| ID | Categoría | Criterio medible |
|---|---|---|
| RNF-01 | Rendimiento | El buscador de precios y protocolos responde en menos de 2 segundos, en cualquiera de los dos apartados. |
| RNF-02 | Rendimiento | La grilla de disponibilidad carga en menos de 2 segundos. |
| RNF-03 | Usabilidad | Una paciente sin instrucción previa completa la carga de su turno en el kiosco en menos de 2 minutos. |
| RNF-04 | Usabilidad | La recepción, con una capacitación breve, completa la carga de un turno en menos de 1 minuto. |
| RNF-05 | Seguridad | El sistema no maneja pagos reales ni datos de tarjeta, la seña es un mock que solo registra un estado (pagada/no pagada) en SQL Server. |
| RNF-06 | Seguridad | Los datos de contacto y de salud de la paciente (nombre, DNI, teléfono, protocolo) se guardan solo en la base local del instituto, sin sincronizarse con ningún servicio externo. |
| RNF-07 | Compatibilidad | El apartado Cliente funciona en una pantalla táctil de al menos 768×1024 px (kiosco vertical); el apartado Gestión, en una ventana de escritorio de 960×600 px como mínimo. |
| RNF-08 | Mantenibilidad | La recepción puede actualizar la base de precios y protocolos del buscador sin intervención técnica del equipo. |
| RNF-09 | Disponibilidad | Los dos apartados están disponibles durante todo el horario de atención del instituto, sin depender de conexión a internet (corren local contra SQL Server). |
| RNF-10 | Seguridad | El buscador (R2) solo responde con coincidencias de la base de precios/protocolos cargada; si no hay coincidencia, marca la derivación al WhatsApp del instituto en vez de dar una respuesta genérica. |
| RNF-11 | Arquitectura | Todo el backend se implementa en C sobre SQL Server; el frontend, en Qt, en los dos apartados. Ninguna funcionalidad depende de una API externa ni de un navegador web. |

## Historias de usuario

```
Como paciente, quiero cargar mi propio turno desde el kiosco del instituto,
para no tener que esperar a que la recepción esté libre para atenderme.

Criterios de aceptación:
- La carga se completa en 3 pasos como máximo, en pantalla táctil.
- Solo se muestran horarios realmente disponibles.
- Al confirmar, veo un resumen del turno antes de guardarlo.
```

```
Como recepción, quiero cargar un turno cuando la paciente llama por teléfono,
para no perder tiempo ni cometer errores al pasarlo después a la agenda.

Criterios de aceptación:
- La carga se completa en 3 pasos como máximo.
- Solo se muestran horarios realmente disponibles.
- Funciona en una ventana de escritorio de 960×600 px como mínimo.
```

```
Como paciente, quiero pagar la seña al confirmar mi turno en el kiosco,
para asegurar mi reserva y saber cuánto se cobra por adelantado.

Criterios de aceptación:
- El pago es simulado (mock): no se conecta a ninguna pasarela real.
- El monto se ve antes de confirmar (30%, mínimo $5.000).
- El sistema no pide ni guarda ningún dato de tarjeta.
```

```
Como recepción o paciente, quiero que el buscador resuelva las consultas de precios y protocolos,
para no tener que memorizarlos ni buscarlos en una planilla aparte.

Criterios de aceptación:
- El buscador responde solo con coincidencias de la base de precios/protocolos.
- Si no encuentra coincidencia, marca la derivación al WhatsApp del instituto.
- Funciona igual desde el kiosco (paciente) y desde la PC de recepción.
```

```
Como paciente, quiero ver un recordatorio antes de mi turno,
para no faltar ni olvidarme la fecha.

Criterios de aceptación:
- El recordatorio se genera con anticipación configurable.
- Lo veo al buscar mi turno en el kiosco con mi DNI o teléfono.
- No es un envío real por WhatsApp ni email.
```

```
Como paciente, quiero buscar y cancelar mi turno desde el kiosco con mi DNI o teléfono,
para no tener que pedirle nada a la recepción ni recordar ninguna contraseña.

Criterios de aceptación:
- Puedo buscar por DNI o teléfono.
- Veo el estado del turno (confirmado, realizado, cancelado) y si la seña está pagada.
- Puedo cancelar el turno desde la misma búsqueda.
```

```
Como recepción, quiero buscar el turno de cualquier paciente por nombre, DNI o teléfono,
para poder confirmarle o cancelarle un turno cuando llama por WhatsApp o teléfono.

Criterios de aceptación:
- Puedo buscar por cualquiera de los tres datos (nombre, DNI, teléfono).
- Veo el estado del turno y si la seña está pagada.
- Puedo cancelar el turno desde la misma búsqueda.
```

```
Como recepción o profesional, quiero cargar y editar la disponibilidad directo en el sistema,
para no depender de ningún calendario externo.

Criterios de aceptación:
- Puedo marcar y desmarcar horarios disponibles desde el sistema.
- Los cambios se reflejan de inmediato en la grilla de reserva, en los dos apartados.
- No hay ningún paso de sincronización con Google Calendar ni otro
  calendario externo.
```

## Backlog inicial

Se pasa a Trello/GitHub Projects con etiquetas Must / Should y el apartado
(Cliente / Gestión) según la tabla de RF de arriba. Orden sugerido para el
maquetado (`docs/05-maquetado.md`): primero las pantallas Must de cada
apartado (carga de turno, buscador, seña), después las búsquedas Should.

## Qué falta

- Pasar a `docs/05-maquetado.md`: cada pantalla del wireframe se justifica
  contra uno o más RF de esta tabla, separadas por apartado.
- Diseñar la pantalla de administración de disponibilidad (RF-03), que
  todavía no tiene wireframe.
