# Reparto de tareas del 4° bimestre

Quién hace qué cada semana, entre **Santiago** y **Bautista**. Las semanas y
entregables salen de la transcripción del plan de cátedra en
[`plan-4to-bimestre.md`](plan-4to-bimestre.md).

La **Semana 1 arranca el martes 6 de octubre de 2026**; cada semana corre de
martes a lunes.

**Cambio de la cátedra:** las semanas 2 y 3 se intercambiaron. Del 13 al 19
de octubre se hacen las tareas de los martes de la Semana 3 (validaciones,
lógica y pruebas, sobre datos de prueba) y del 20 al 26 las de la Semana 2
(conexión a la base). Las tareas de Bases de Datos siguen en su orden.

## Cómo está organizada cada semana

| Día | Horario | De qué es |
|---|---|---|
| **Martes** | (según clase) | **C y frontend** (Qt), siguiendo el plan de la cátedra |
| **Miércoles** | 13:30 a 16:20 | **Backend y Bases de Datos** |
| **Jueves** | 15:00 a 16:20 | **Backend y Bases de Datos** |

Son unas 4 horas de Bases de Datos por semana (12 jornadas en total). La
consigna está en [`consigna-bbdd.md`](consigna-bbdd.md); las entidades, en
[`modelo-entidades.md`](modelo-entidades.md); la arquitectura, en
[`arquitectura.md`](arquitectura.md). Las fechas de los hitos que pide el
docente en Classroom no están acá: si difieren, se ajusta.

**Cómo se trabaja la base:** el diseño se piensa **entre los dos** (primero por
escrito) y recién cuando está cerrado se hace el diagrama de Peter Chen en draw.io. Cada uno es
**responsable** de un bloque, pero los dos tienen que conocer todo el modelo
(en la defensa se evalúa el conocimiento global).

- **Santiago: turnos, pagos y auditoría.** Entidades: Paciente, Turno, Pago de
  seña, Evaluación previa, Resultado de evaluación, Estado del turno, Estado
  del pago, Medio de pago, Origen, Usuario, Rol, Log, Tipo de
  evento. Se encarga de la base en Aiven.
- **Bautista: catálogo, profesionales, cupones y avisos.** Entidades:
  Profesional, Protocolo, Categoría de protocolo, Disponibilidad, Cupón, Regla
  de beneficio, Tipo de regla, Tarjeta de regalo, Movimiento de tarjeta,
  Notificación, Canal, Estado y Tipo de notificación, Consulta al asistente.
  Se encarga de n8n
  y del bot de Telegram.

**Dependencia entre martes y miércoles-jueves:** el martes de cada semana
usa lo que la base ya tiene. La base completa recién está lista en la
Semana 3; antes, el frontend trabaja con tablas de prueba.


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

## Semana 1 (martes 6 al lunes 12 de octubre): GUI en Qt y diseño conceptual (los DER)

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 1.

### Martes: C y frontend

| Santiago | Bautista |
|---|---|
| [x] Instalar Qt Creator y dejar el proyecto Qt (`frontend/`) compilando con CMake | [x] Instalar Qt Creator y clonar el repo; verificar que compila el proyecto Qt |
| [x] Ventana principal de **Gestión** (960×600 mín.) con menú lateral | [x] Ventana principal de **Cliente** (terminal vertical, 768×1024 mín.) |
| [x] Pantallas Gestión 1-3: cargar turno, elegir horario, confirmar y registrar seña (RF-02, RF-04, RF-09, RF-10) | [x] Pantallas Cliente 1-3: elegir protocolo, elegir horario, confirmar y pagar seña (RF-01, RF-04, RF-08, RF-10) |
| [x] Pantalla Gestión 5: buscar turnos por nombre, DNI o teléfono (RF-13) | [x] Pantalla Cliente 5: buscar mi turno por DNI o teléfono (RF-12) |
| [x] Señales y slots: navegación entre pasos 1-2-3 en Gestión | [x] Señales y slots: navegación entre pasos 1-2-3 en Cliente, con botones grandes |

Compartido: el buscador de precios (Gestión 4 y Cliente 4) es un solo widget, `frontend/comun/buscadorprecios`, que usan los dos apartados. Hecho: [x].

### Miércoles: backend y Bases de Datos

Entregable de la consigna: punto 1, Diseño Conceptual (Peter Chen). **Hoy (7 de octubre): se cierran por escrito los atributos y las cardinalidades.**

| Santiago | Bautista |
|---|---|
| [x] Grupo 1 (Paciente, Profesional, Protocolo, Turno): atributos, decisiones y cardinalidades cerrados | [x] Revisar el grupo 1 y las reglas de cirugía |
| [x] Grupo 2 (pago de seña, evaluación previa): propuesto y aprobado | [x] Grupo 3 (cupones, reglas, tarjetas de regalo): propuesto, con códigos rotativos solo en cupones |
| [ ] **Grupo 4, modelo de logs**: Log, Tipo de evento, Usuario y Rol (qué datos se guardan para auditoría) | [ ] **Grupo 4**: Notificación, Canal y Consulta al asistente |
| [ ] Revisar contra la consigna: mínimo 13 entidades, cardinalidades y todo lo categorizable como tabla maestra | [ ] Revisar contra la consigna y cerrar las dos preguntas abiertas del grupo 3 |

### Jueves: backend y Bases de Datos

Entregable de la consigna: punto 1. **Jueves 8: los DER en draw.io.**

| Santiago | Bautista |
|---|---|
| [ ] **Hacer el diagrama de Peter Chen** del bloque de Santiago | [ ] **Hacer el diagrama de Peter Chen** del bloque de Bautista |
| [ ] Acomodar los diagramas del bloque de Santiago | [ ] Revisar cardinalidades `(mín,máx)` y que cada atributo esté en su entidad |
| [ ] Juntar los dos bloques en **un solo DER conceptual** y revisar la coherencia | [ ] Exportar el DER (imagen y `.drawio`) y subirlo a `docs/diagramas/` |
| [ ] Entregar el **hito del DER conceptual** en Classroom | [ ] Si sobra tiempo: instalar MySQL local (portable, sin permisos de administrador) |

## Semana 2 (martes 13 al lunes 19 de octubre): Persistencia (conexión) y diseño lógico con la implementación

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 2.

### Martes: C y frontend

| Santiago | Bautista |
|---|---|
| [ ] Capa de conexión Qt a MySQL (`QSqlDatabase`) con la base local y manejo de errores de conexión | [ ] Mensaje claro en pantalla cuando la base no responde (RNF-09) y modo contingencia: avisar y guardar localmente |
| [ ] Probar la conexión de punta a punta contra una tabla de prueba | [ ] Armar la pantalla de **administración de protocolos** (RF-05/06) sobre datos de prueba |
| [ ] Preparar el formulario de **pacientes** (alta y búsqueda) sobre datos de prueba | [ ] Preparar la pantalla de **profesionales y disponibilidad** (RF-03) sobre datos de prueba |

Las pantallas se conectan a la base real en la Semana 3, cuando ya hay tablas y stored procedures.

### Miércoles: backend y Bases de Datos

Entregable de la consigna: punto 2, Diseño Lógico (Edgar Codd), en 3FN.

| Santiago | Bautista |
|---|---|
| [ ] Pasar su bloque a tablas: claves primarias y foráneas, tablas intermedias de las N:M | [ ] Pasar su bloque a tablas: claves primarias y foráneas, tablas intermedias de las N:M |
| [ ] Normalizar en 3FN y justificar cada decisión | [ ] Normalizar en 3FN y justificar cada decisión |
| [ ] Definir los **schemas** (por ejemplo gestión, catálogo, auditoría) | [ ] Revisar los conectores según cardinalidades y que sea coherente con el DER conceptual |
| [ ] Armar el **DER lógico** (Codd) de su bloque en draw.io | [ ] Armar el **DER lógico** de su bloque y entregar el hito |

### Jueves: backend y Bases de Datos

Entregable de la consigna: punto 3, Implementación del modelo.

| Santiago | Bautista |
|---|---|
| [ ] Instalar MySQL local y crear los schemas | [ ] Script `CREATE TABLE` de su bloque con todas las restricciones referenciales |
| [ ] Script `CREATE TABLE` de su bloque con todas las restricciones referenciales | [ ] Poblar las **tablas maestras** (estados, categorías, canales, resultados) |
| [ ] Probar que el modelo implementado refleja el diseño | [ ] Correr el script completo en limpio, de punta a punta |
| [ ] Entregar el **hito de la implementación** | [ ] Crear la base en Aiven y verificar que acepte stored procedures y eventos |

## Semana 3 (martes 20 al lunes 26 de octubre): Datos y primeros stored procedures; lógica y QA

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 3.

### Martes: C y frontend

| Santiago | Bautista |
|---|---|
| [ ] Conectar Gestión 1-3 y 5 con la base real (alta de turno, búsqueda y cancelación) | [ ] Conectar Cliente 1-3, 5 y el buscador con la base real |
| [x] Validaciones de DNI y teléfono (formato, largo, solo dígitos) en los formularios de Gestión | [ ] Validaciones en Cliente (DNI/teléfono) y en el ABM de protocolos (precio ≥ 0, duración > 0) |
| [ ] Integrar seña y reembolso (RF-10) al flujo de confirmar y cancelar | [ ] Recordatorio de turno (RF-11): registro de cada aviso |
| [ ] Registro de seña como mock que imita un pago real (RF-08/09, RNF-05) | [ ] **Casos de prueba funcional**: planilla con un caso por RF y resultado de cada uno |

Criterio de "Beta": los RF Must (RF-01 a RF-09, RF-11, RF-20 y RF-21) funcionando de punta a punta y sin errores críticos.

Los casos de prueba siguen el formato de la cátedra: [`catedra/semana-3-casos-de-prueba-funcional.pdf`](catedra/semana-3-casos-de-prueba-funcional.pdf) (identificador, descripción, precondiciones, pasos, resultado esperado y real, criterio de aprobación).

### Miércoles: backend y Bases de Datos

Entregable de la consigna: punto 4, poblar el modelo (50+ registros en la tabla principal, 20+ en las demás).

| Santiago | Bautista |
|---|---|
| [ ] Poblar Paciente, Turno, Pago y demás de su bloque, con **50+ turnos** | [ ] Poblar Profesional, Protocolo (con cirugías y precios realistas), Cupones, Tarjetas y demás de su bloque, con 20+ cada una |
| [ ] Revisar que no haya datos que rompan las restricciones | [ ] Revisar los datos de la base en Aiven |

### Jueves: backend y Bases de Datos

Primeros stored procedures. Los logs se llenan **solo** vía stored procedures, nunca a mano.

| Santiago | Bautista |
|---|---|
| [ ] SPs de **login y logs** | [ ] SPs de ABM de protocolos y profesionales |
| [ ] SP de alta de turno | [ ] SP de horarios libres y disponibilidad |
| [ ] Pruebas (4 casos) de cada SP terminado | [ ] Pruebas (4 casos) de cada SP terminado |

## Semana 4 (martes 27 de octubre al lunes 2 de noviembre): Funcionalidades en stored procedures; análisis de competencia

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 4.

### Martes: C y frontend

| Santiago | Bautista |
|---|---|
| [ ] Relevar **competidores indirectos**: lo que hoy usa el instituto (WhatsApp, agenda en papel, planillas) y por qué no alcanza | [ ] Relevar **competidores directos**: al menos 3 sistemas de turnos para centros de estética o salud, con precio y funciones |
| [ ] Definir la **PUV**: terminal + recepción + web sobre una misma base, con cupones, tarjetas de regalo y asistente de IA | [ ] Armar la **matriz comparativa** de funcionalidades y costos |
| [ ] Redactar el informe `docs/07-competencia.md` | [ ] Aportar datos y matriz; revisar que cada afirmación tenga fuente |
| [ ] Corregir los bugs de la Beta que queden abiertos | [ ] Pulido de la GUI con la heurística de Nielsen de `docs/05-maquetado.md` |

Cuidar en el informe: no comparar contra productos con datos inventados; cada precio o función de un competidor va con su fuente.

### Miércoles: backend y Bases de Datos

Entregable de la consigna: punto 5, funcionalidades.

| Santiago | Bautista |
|---|---|
| [ ] SPs de cancelación, seña y reembolso | [ ] SPs de cupones: emisión por reglas, token rotativo de 5 minutos y validación |
| [ ] SP de la regla de cirugías (consulta previa, 40%, vigencia de 6 meses, retención) | [ ] SPs de tarjetas de regalo: compra, saldo y movimientos |

### Jueves: backend y Bases de Datos

Entregable de la consigna: punto 5, funcionalidades.

| Santiago | Bautista |
|---|---|
| [ ] SPs de evaluación previa y de reclamo | [ ] SPs de notificaciones pendientes y de consultas al asistente |
| [ ] Pruebas (4 casos) de cada SP terminado | [ ] Pruebas (4 casos) de cada SP terminado |

## Semana 5 (martes 3 al lunes 9 de noviembre): Reportes y auditoría; presupuesto y pitch

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 5.

### Martes: C y frontend

| Santiago | Bautista |
|---|---|
| [ ] **Presupuesto**: horas hombre por módulo, licencias, infraestructura de la terminal y mantenimiento | [ ] **Modelo de monetización**: comparar licencia, abono de soporte y llave en mano; elegir uno y justificarlo |
| [ ] Calcular **precio de venta y retorno de inversión** (95 min/día, ≈ $900.000 de turnos perdidos por semana) | [ ] Diapositivas: problema, competencia y diferencial |
| [ ] Diapositivas: solución, costos, precio y retorno | [ ] Armar el guion de la **demo en vivo** paso a paso |
| [ ] Documento `docs/08-presupuesto.md` | [ ] Actualizar `docs/06-pitch.md` al formato nuevo (5-7 min) |

**Cambio de formato**: el pitch de este bimestre dura **5 a 7 minutos** y es de **venta a inversores**, con demo en vivo. El guion de `docs/06-pitch.md` hay que recortarlo.

### Miércoles: backend y Bases de Datos

Entregable de la consigna: punto 5, reportes (al menos 8). Todos con funciones de agrupamiento, reuniones y gestión de fechas.

| Santiago | Bautista |
|---|---|
| [ ] **Reporte 1**: turnos por período y profesional | [ ] **Reporte 5**: protocolos más pedidos por período |
| [ ] **Reporte 2**: ingresos por seña, reembolsos y retenciones | [ ] **Reporte 6**: ocupación por profesional |
| [ ] **Reporte 3**: cancelaciones e inasistencias | [ ] **Reporte 7**: uso de cupones y reglas de beneficio |

### Jueves: backend y Bases de Datos

Entregable de la consigna: punto 5, reportes y auditoría.

| Santiago | Bautista |
|---|---|
| [ ] **Reporte 4**: evaluaciones previas y cirugías por resultado | [ ] **Reporte 8**: saldo y uso de tarjetas de regalo |
| [ ] SP de **reporte de auditoría** por rango de fechas (con parámetros) | [ ] Pruebas (4 casos) de los reportes propios |
| [ ] Pruebas (4 casos) de los reportes propios y de la auditoría | [ ] Revisar los reportes de Santiago |

## Semana 6 (martes 10 al lunes 16 de noviembre): Tuning, pruebas y Demo Day

Entregable de la cátedra: ver `plan-4to-bimestre.md`, Semana 6.

### Martes: C y frontend

| Santiago | Bautista |
|---|---|
| [ ] **Manual técnico**: arquitectura (MySQL + Qt + sitio web), cómo instalar, compilar y crear la base | [ ] **Manual de usuario**: uso de la terminal (paciente) y de Gestión (recepción), con capturas |
| [ ] Preparar la **demo en vivo**: base con datos de ejemplo, orden de pasos y plan B si falla la conexión | [ ] Preparar respuestas a **objeciones** (competencia, seña simulada, seguridad de datos, costo) |
| [ ] Ensayar y cronometrar el pitch completo (≤ 7 min) | [ ] Ensayar y cronometrar; ajustar el reparto de tiempo |
| [ ] Congelar `main`: tag de la versión final | [ ] Congelar la documentación y revisar que el README esté actualizado |
| [ ] Coevaluación al resto de los equipos | [ ] Coevaluación al resto de los equipos |

### Miércoles: backend y Bases de Datos

Entregable de la consigna: punto 5e, tuning, y punto 6, pruebas.

| Santiago | Bautista |
|---|---|
| [ ] Elegir un reporte que lo justifique y hacer su `_tuneado` (índices, reescritura de consultas) | [ ] Elegir un reporte y hacer su `_tuneado` |
| [ ] Medir antes y después del tuning (plan de ejecución) | [ ] Medir antes y después del tuning (plan de ejecución) |
| [ ] Documentar las pruebas de sus SP en el documento de la cátedra | [ ] Documentar las pruebas de sus SP en el documento de la cátedra |

### Jueves: backend y Bases de Datos

Entregable de la consigna: preparación de la **defensa técnica**.

| Santiago | Bautista |
|---|---|
| [ ] Ensayar la defensa oral: explicar la arquitectura, el modelo y los SP de los dos bloques | [ ] Ensayar la defensa oral: explicar la arquitectura, el modelo y los SP de los dos bloques |
| [ ] Revisar el documento de pruebas completo | [ ] Revisar el documento de pruebas completo |

Es un plan ajustado (12 jornadas de Bases de Datos para toda la consigna): si
un día no alcanza, lo pendiente pasa al siguiente y se anota acá con una
línea de motivo.

## Seguimiento

- Al cerrar cada semana: tildar las tareas hechas en este archivo, en la rama
  de cada uno, y abrir un PR a `main`.
- Si una tarea no se termina, pasa a la semana siguiente y se anota acá con
  una línea de motivo.
