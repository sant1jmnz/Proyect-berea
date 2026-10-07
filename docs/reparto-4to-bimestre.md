# Reparto de tareas del 4° bimestre

Quién hace qué cada semana, entre **Santiago** y **Bautista**. Las semanas y
entregables salen de la transcripción del plan de cátedra en
[`plan-4to-bimestre.md`](plan-4to-bimestre.md).

La **Semana 1 arranca el martes 6 de octubre de 2026**; cada semana corre de
martes a lunes.

| Persona | Foco general | Rama |
|---|---|---|
| **Santiago** | Apartado **Gestión** (recepción), ABM de turnos y pacientes, reglas de negocio, presupuesto | `santiago` |
| **Bautista** | Apartado **Cliente** (terminal táctil), protocolos, profesionales y disponibilidad, buscador, competencia y manuales | `bautista` |

Cada uno trabaja en su rama y se junta a `main` con un PR al cerrar cada
semana. El reparto es un punto de partida: si una semana uno se traba, el otro
lo ayuda y se anota acá. Nicolás y Clovis no figuran porque este reparto es de
a dos; si se suman, se agrega una tercera columna.

Lo que ya existe y no hay que rehacer: los prototipos Qt de `frontend/`
(Cliente y Gestión). La carpeta `backend/` se vació a propósito: el
backend y la base MySQL se rehacen desde cero (ver "Sección Bases de
Datos" más abajo). El apartado Web todavía no se empezó.

## Semana 1 (martes 6 al lunes 12 de octubre): GUI en Qt

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 1.

| Santiago | Bautista |
|---|---|
| [x] Instalar Qt Creator y dejar el proyecto Qt (`frontend/`) compilando con CMake | [ ] Instalar Qt Creator y clonar el repo; verificar que compila el proyecto Qt |
| [x] Ventana principal de **Gestión** (960×600 mín.) con menú lateral | [x] Ventana principal de **Cliente** (terminal vertical, 768×1024 mín.) |
| [x] Pantallas Gestión 1-3: cargar turno, elegir horario, confirmar y registrar seña (RF-02, RF-04, RF-09, RF-10) | [x] Pantallas Cliente 1-3: elegir protocolo, elegir horario, confirmar y pagar seña (RF-01, RF-04, RF-08, RF-10) |
| [x] Pantalla Gestión 5: buscar turnos por nombre, DNI o teléfono (RF-13) | [x] Pantalla Cliente 5: buscar mi turno por DNI o teléfono (RF-12) |
| [x] Señales y slots: navegación entre pasos 1-2-3 en Gestión | [x] Señales y slots: navegación entre pasos 1-2-3 en Cliente, con botones grandes |

Compartido: el buscador de precios (Gestión 4 y Cliente 4) es un solo widget,
`frontend/comun/buscadorprecios`, que usan los dos apartados. Hecho: [x].

## Semana 2 (martes 13 al lunes 19 de octubre): Persistencia con base de datos

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 2.

| Santiago | Bautista |
|---|---|
| [ ] Levantar MySQL local, correr el esquema y los datos de ejemplo, y probar la conexión de punta a punta | [ ] Manejo de errores de conexión (base caída, cadena mal armada) con mensaje claro en pantalla |
| [ ] ABM de **pacientes** (alta, búsqueda por nombre/DNI/teléfono, modificación) con pantalla, sobre stored procedures | [ ] ABM de **protocolos** (RF-05/06; la recepción lo edita sin ayuda técnica, RNF-08) |
| [ ] Alta de **turno** desde Gestión con un stored procedure (RF-02) | [ ] ABM de **profesionales y disponibilidad** (RF-03): pantalla de administración |
| [ ] Cancelar turno (RF-13) | [ ] Consulta de **horarios libres** en tiempo real (RF-04) para las dos pantallas de horario |
| [ ] Conectar Gestión 1-3 y 5 con la base | [ ] Conectar Cliente 1-3, 5 y el buscador con la base |

## Semana 3 (martes 20 al lunes 26 de octubre): Lógica de negocio, validaciones y QA

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 3.

| Santiago | Bautista |
|---|---|
| [ ] Validaciones de DNI y teléfono (formato, largo, solo dígitos) en los formularios de Gestión | [ ] Validaciones en Cliente (DNI/teléfono) y en el ABM de protocolos (precio ≥ 0, duración > 0) |
| [ ] Integrar seña y reembolso (RF-10) al flujo de confirmar y cancelar; agregar sus pruebas | [ ] Recordatorio de turno (RF-11): registro de cada aviso; el envío por WhatsApp se define aparte |
| [ ] Registro de seña como mock que imita un pago real (RF-08/09, RNF-05) | [ ] Buscador/asistente sin respuesta: derivar a WhatsApp (RF-07) y registrar la consulta |
| [ ] Reporte simple para recepción: turnos del día (opcional, si alcanza el tiempo) | [ ] **Casos de prueba funcional**: planilla con un caso por RF (Must primero) y resultado de cada uno |
| [ ] Corregir los bugs que salgan de la planilla en Gestión | [ ] Registrar los bugs encontrados y corregir los de Cliente |

Criterio de "Beta": los RF Must (RF-01 a RF-09, RF-11, RF-20 y RF-21) funcionando de punta a punta y sin errores
críticos al hacer el flujo completo en los dos apartados.

## Semana 4 (martes 27 de octubre al lunes 2 de noviembre): Análisis de competencia

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 4.

| Santiago | Bautista |
|---|---|
| [ ] Relevar **competidores indirectos**: lo que hoy usa el instituto (WhatsApp, agenda en papel, planillas) y por qué no alcanza, con datos de `docs/01-arbol-de-problemas.md` | [ ] Relevar **competidores directos**: al menos 3 sistemas de turnos para centros de estética o salud (comerciales y gratuitos), con precio y funciones |
| [ ] Definir la **PUV** (¿por qué elegir Dermalia?): terminal + recepción + web sobre una misma base, con cupones, tarjetas de regalo y asistente de IA | [ ] Armar la **matriz comparativa** de funcionalidades y costos contra la competencia |
| [ ] Redactar el informe `docs/07-competencia.md` (estructura y conclusiones) | [ ] Aportar al informe los datos y la matriz; revisar que cada afirmación tenga fuente |
| [ ] Corregir los bugs de la Beta que queden abiertos | [ ] Pulido de la GUI: revisión con la heurística de Nielsen de `docs/05-maquetado.md` |

Cuidar en el informe: no comparar contra productos con datos inventados; cada
precio o función de un competidor va con su fuente.

## Semana 5 (martes 3 al lunes 9 de noviembre): Presupuesto, modelo de negocio y Pitch Deck

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 5.

| Santiago | Bautista |
|---|---|
| [ ] **Presupuesto**: horas hombre por módulo (del backlog real), licencias (Qt, APIs externas), infraestructura de la terminal y mantenimiento | [ ] **Modelo de monetización**: comparar licencia, abono de soporte y llave en mano; elegir uno y justificarlo |
| [ ] Calcular **precio de venta y retorno de inversión** con los datos del instituto (95 min/día, ≈ $900.000 de turnos perdidos por semana) | [ ] Diapositivas: problema (Árbol de Problemas), competencia y diferencial |
| [ ] Diapositivas: solución, costos, precio y retorno | [ ] Armar el guion de la **demo en vivo** paso a paso (qué se muestra y en qué orden) |
| [ ] Documento `docs/08-presupuesto.md` | [ ] Actualizar `docs/06-pitch.md` al formato nuevo (5-7 min) |

**Cambio de formato**: el pitch de este bimestre dura **5 a 7 minutos** (el del
bimestre anterior era de 7 a 10) y es de **venta a inversores**, con demo en
vivo. El guion de `docs/06-pitch.md` hay que recortarlo.

## Semana 6 (martes 10 al lunes 16 de noviembre): Demo Day

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 6.

| Santiago | Bautista |
|---|---|
| [ ] **Manual técnico**: arquitectura (MySQL + Qt + sitio web), cómo instalar, compilar y crear la base | [ ] **Manual de usuario**: uso de la terminal (paciente) y de Gestión (recepción), con capturas |
| [ ] Preparar la **demo en vivo**: base con datos de ejemplo, orden de pasos y plan B si falla la conexión | [ ] Preparar respuestas a **objeciones** (competencia, seña simulada, seguridad de datos, costo) |
| [ ] Ensayar y cronometrar el pitch completo con el equipo (≤ 7 min) | [ ] Ensayar y cronometrar; ajustar el reparto de tiempo |
| [ ] Congelar `main`: tag de la versión final | [ ] Congelar la documentación y revisar que el README esté actualizado |
| [ ] Coevaluación al resto de los equipos | [ ] Coevaluación al resto de los equipos |

## Sección Bases de Datos: plan semanal

**Días de trabajo:** los **martes** son de C y frontend (las tablas de
arriba, Semanas 1 a 6 de la cátedra); los **miércoles y jueves** son de
backend y Bases de Datos. Las semanas son las mismas (de martes a lunes), así
que cada semana tiene su tabla de arriba para el martes y su bloque de abajo
para el miércoles y el jueves.

La consigna completa está en [`consigna-bbdd.md`](consigna-bbdd.md); las
entidades, en [`modelo-entidades.md`](modelo-entidades.md); la arquitectura,
en [`arquitectura.md`](arquitectura.md). Las fechas de los hitos que pide el
docente en Classroom no están en esta tabla: si difieren, se ajusta.

**Cómo se trabaja:** el diseño se piensa **entre los dos** (primero por
escrito, entidad por entidad) y recién cuando está cerrado se pasa a XML
para draw.io. Cada uno es **responsable** de un bloque, pero los dos tienen
que conocer todo el modelo: en la defensa se evalúa el conocimiento global.

### Bloques de cada uno
- **Santiago: turnos, pagos y auditoría.** Entidades: Paciente, Turno, Pago
  de seña, Evaluación previa, Resultado de evaluación, Estado del turno,
  Estado del pago, Usuario, Rol, Log, Tipo de evento. Se encarga de la base
  en Aiven.
- **Bautista: catálogo, profesionales, cupones y avisos.** Entidades:
  Profesional, Protocolo, Categoría de protocolo, Disponibilidad, Cupón,
  Regla de beneficio, Tarjeta de regalo, Movimiento de tarjeta, Notificación,
  Canal de notificación, Consulta al asistente. Se encarga de n8n y el bot de
  Telegram.

### Semana 1 (miércoles 7 y jueves 8 de octubre): diseño conceptual, los DER

Entregable de la consigna: punto 1, Diseño Conceptual (Peter Chen).

| Santiago | Bautista |
|---|---|
| [ ] **Miércoles (hoy)**: cerrar por escrito, entre los dos, atributos y cardinalidades de las entidades de su bloque | [ ] **Miércoles (hoy)**: cerrar por escrito, entre los dos, atributos y cardinalidades de las entidades de su bloque |
| [ ] Cardinalidades y regla de cirugías (consulta previa, 40%, 6 meses) | [ ] Cardinalidades de cupones, tarjetas de regalo y notificaciones |
| [ ] **Modelo de logs** (Log + Tipo de evento): qué datos se guardan para auditoría | [ ] Revisar que las 13 entidades mínimas se cumplan y que lo categorizable sea tabla maestra |
| [ ] **Jueves**: pasar lo cerrado a XML y armar el DER de su bloque en draw.io | [ ] **Jueves**: pasar lo cerrado a XML y armar el DER de su bloque en draw.io |
| [ ] Juntar los dos diagramas en uno solo y revisar coherencia | [ ] Revisar el diagrama completo y entregar el hito |

### Semana 2 (miércoles 14 y jueves 15 de octubre): diseño lógico

Entregable de la consigna: punto 2, Diseño Lógico (Edgar Codd), en 3FN.

| Santiago | Bautista |
|---|---|
| [ ] Pasar su bloque a tablas: claves primarias y foráneas, tablas intermedias de las N:M | [ ] Pasar su bloque a tablas: claves primarias y foráneas, tablas intermedias de las N:M |
| [ ] Normalizar en 3FN y justificar cada decisión | [ ] Normalizar en 3FN y justificar cada decisión |
| [ ] Definir los **schemas** (por ejemplo gestión, catálogo, auditoría) | [ ] Revisar los conectores según cardinalidades y que sea coherente con el DER |
| [ ] Armar el diagrama lógico | [ ] Revisar y entregar el hito |

### Semana 3 (miércoles 21 y jueves 22 de octubre): implementación en MySQL

Entregable de la consigna: punto 3, Implementación del modelo.

| Santiago | Bautista |
|---|---|
| [ ] Instalar MySQL local (portable, sin permisos de administrador) y crear los schemas | [ ] Script `CREATE TABLE` de su bloque con todas las restricciones referenciales |
| [ ] Script `CREATE TABLE` de su bloque con todas las restricciones referenciales | [ ] Poblar las **tablas maestras** (estados, categorías, canales, resultados) |
| [ ] Crear la base en Aiven y verificar que acepte stored procedures y eventos | [ ] Probar que el script corre completo en limpio, de punta a punta |
| [ ] Probar que el modelo implementado refleja el diseño | [ ] Entregar el hito |

### Semana 4 (miércoles 28 y jueves 29 de octubre): datos y primeros stored procedures

Entregable de la consigna: punto 4, poblar el modelo (50+ registros en la tabla principal, 20+ en las demás).

| Santiago | Bautista |
|---|---|
| [ ] Poblar Paciente, Turno, Pago y demás de su bloque, con **50+ turnos** | [ ] Poblar Profesional, Protocolo (con cirugías y precios realistas), Cupones, Tarjetas y demás de su bloque, con 20+ cada una |
| [ ] SPs de **login y logs** (los logs se llenan solo vía SP, nunca a mano) | [ ] SPs de ABM de protocolos y profesionales |
| [ ] SP de alta de turno | [ ] SP de horarios libres y disponibilidad |

### Semana 5 (miércoles 4 y jueves 5 de noviembre): funcionalidades y primeros reportes

Entregable de la consigna: punto 5, funcionalidades y reportes.

| Santiago | Bautista |
|---|---|
| [ ] SPs de cancelación, seña, reembolso y regla de cirugías | [ ] SPs de cupones (código y reglas de fidelidad), tarjetas de regalo y saldo |
| [ ] **2 reportes** con agrupamiento, reuniones y fechas | [ ] SPs de notificaciones pendientes y de consultas al asistente |
| [ ] Pruebas (4 casos) de cada SP terminado | [ ] **2 reportes** con agrupamiento, reuniones y fechas |
| | [ ] Pruebas (4 casos) de cada SP terminado |

### Semana 6 (miércoles 11 y jueves 12 de noviembre): reportes finales, tuning y pruebas

Entregable de la consigna: puntos 5 y 6, y preparación de la defensa.

| Santiago | Bautista |
|---|---|
| [ ] **2 reportes** más (llegar a 4 propios, 8 en total) | [ ] **2 reportes** más (llegar a 4 propios, 8 en total) |
| [ ] SP de **reporte de auditoría** por rango de fechas | [ ] Elegir un reporte y hacer su `_tuneado` |
| [ ] Elegir un reporte y hacer su `_tuneado` | [ ] Documentar las pruebas de sus SP en el documento de la cátedra |
| [ ] Documentar las pruebas de sus SP en el documento de la cátedra | [ ] Ensayar la defensa oral: cada uno explica también los SP del otro |

Es un plan ajustado (12 jornadas para toda la consigna): si una semana no
alcanza, lo pendiente pasa a la siguiente y se anota acá con una línea de
motivo.

## Seguimiento

- Al cerrar cada semana: tildar las tareas hechas en este archivo, en la rama
  de cada uno, y abrir un PR a `main`.
- Si una tarea no se termina, pasa a la semana siguiente y se anota acá con
  una línea de motivo.
