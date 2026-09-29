# Plan de aprendizaje, 4° bimestre: Proyecto Informático I

Transcripción del PDF de cátedra `Plan de Aprendizaje – 4° Bimestre: Proyecto
Informático I`, más el reparto de tareas semana a semana entre **Santiago** y
**Bautista**. Continúa a `docs/plan-de-aprendizaje.md` (3er bimestre, ya
terminado).

- Enfoque: Buenos Aires Aprende · Escuela Técnica CABA · Especialidad Computación
- Metodología: desarrollo ágil (sprints semanales), aprendizaje basado en
  proyectos (ABP), trabajo colaborativo en repositorio y presentación final.
- **Producto final**: software de gestión de escritorio en C con Qt, vinculado a
  una base de datos relacional, presentado como Pitch de ventas / Demo Day ante
  inversores, respaldado por un análisis de competencia.
- **Objetivo del bimestre**: pasar los requerimientos y la planificación del 3er
  bimestre a un producto funcional con persistencia de datos, y validar su
  viabilidad comercial frente al mercado.

## Cómo se reparte

| Persona | Foco general | Rama |
|---|---|---|
| **Santiago** | Apartado **Gestión** (recepción), ABM de turnos y pacientes, reglas de negocio, presupuesto | `santiago` |
| **Bautista** | Apartado **Cliente** (terminal táctil), protocolos, profesionales y disponibilidad, buscador, competencia y manuales | `bautista` |

Cada uno trabaja en su rama y se junta a `main` con un PR al cerrar cada semana
(guía de Git: la del equipo). El reparto es un punto de partida: si una semana
uno se traba, el otro lo ayuda y se anota acá.

Nicolás y Clovis (diseño y pitch en el 3er bimestre) no figuran en este reparto
porque este reparto es de a dos; si se suman, se agregan como una tercera columna.

Lo que ya existe en `main` y no hay que rehacer: `db/schema.sql` y `db/seed.sql`
(SQL Server), reglas de negocio en C con tests (`backend/src/dermalia.c`) y la
capa ODBC (`backend/src/db.c`: conexión, buscar protocolos, crear turno).

**Diferencia con el PDF**: la cátedra habla de "C / Qt" y menciona `QSqlDatabase`
y `QSqlTableModel` (que son C++). Nuestra decisión de arquitectura sigue
siendo backend en C con ODBC contra SQL Server, y Qt para la interfaz. Conviene
confirmar con la profesora que esto cumple lo pedido.

## Semana 1: Arquitectura del sistema y prototipado de GUI en Qt Designer

**Propósito**: maquetar la interfaz en Qt Creator a partir de la MML y los
requerimientos del bimestre anterior.

**Actividades de la cátedra**
1. Configurar el entorno de trabajo C / Qt (Qt Creator) y vincularlo con el
   repositorio Git institucional.
2. Diseñar pantallas (ventanas principales, formularios, menús, diálogos) con
   Qt Designer y widgets estándar (`QLineEdit`, `QPushButton`, `QTableView`...).
3. Implementar eventos básicos con señales y slots.

**Entregable**: prototipo navegable de la GUI en Qt, sin persistencia,
sincronizado en el repositorio.

| Santiago | Bautista |
|---|---|
| [ ] Instalar Qt Creator y dejar el proyecto Qt (`frontend/`) compilando con CMake | [ ] Instalar Qt Creator y clonar el repo; verificar que compila el proyecto Qt |
| [ ] Ventana principal de **Gestión** (960×600 mín.) con menú lateral | [ ] Ventana principal de **Cliente** (terminal vertical, 768×1024 mín.) |
| [ ] Pantallas Gestión 1-3: cargar turno, elegir horario, confirmar y registrar seña (RF-02, RF-04, RF-09, RF-10) | [ ] Pantallas Cliente 1-3: elegir protocolo, elegir horario, confirmar y pagar seña (RF-01, RF-04, RF-08, RF-10) |
| [ ] Pantalla Gestión 5: buscar turnos por nombre, DNI o teléfono (RF-13) | [ ] Pantalla Cliente 5: buscar mi turno por DNI o teléfono (RF-12) |
| [ ] Señales y slots: navegación entre pasos 1-2-3 en Gestión | [ ] Señales y slots: navegación entre pasos 1-2-3 en Cliente, con botones grandes |

Compartido: las pantallas de buscador (Gestión 4 y Cliente 4) las hace **Bautista**
para las dos y Santiago las reutiliza como widget.

## Semana 2: Persistencia e integración Qt con base de datos

**Propósito**: vincular la aplicación con la base relacional para las
operaciones de ABM (altas, bajas y modificaciones).

**Actividades de la cátedra**
1. Configurar el módulo de base de datos.
2. Controladores para abrir la conexión, ejecutar SQL y manejar errores de conexión.
3. Integrar los formularios de la GUI con operaciones CRUD sobre las tablas.

**Entregable**: módulo ABM funcional integrado a la base a través de la interfaz.

| Santiago | Bautista |
|---|---|
| [ ] Levantar SQL Server local, correr `schema.sql` y `seed.sql`, probar la capa ODBC de punta a punta | [ ] Manejo de errores de conexión (base caída, cadena mal armada) con mensaje claro en pantalla |
| [ ] ABM de **pacientes** (alta, búsqueda por nombre/DNI/teléfono, modificación) en C + pantalla | [ ] ABM de **protocolos** (RF-05/06; la recepción lo edita sin ayuda técnica, RNF-08) |
| [ ] Alta de **turno** desde Gestión con `db_crear_turno` (RF-02) | [ ] ABM de **profesionales y disponibilidad** (RF-03): pantalla de administración |
| [ ] Cancelar turno (RF-13) | [ ] Consulta de **horarios libres** en tiempo real (RF-04) para las dos pantallas de horario |
| [ ] Conectar Gestión 1-3 y 5 con la base | [ ] Conectar Cliente 1-3, 5 y el buscador con la base |

## Semana 3: Lógica de negocio, validaciones y calidad (QA)

**Propósito**: asegurar el funcionamiento con validaciones de entrada y pruebas
funcionales.

**Actividades de la cátedra**
1. Validaciones en la interfaz (máscaras de entrada, expresiones regulares para
   correos, CUIT, etc.) y mensajes de error al usuario.
2. Lógica interna de negocio en C (cálculos, filtrados, reportes, reglas del dominio).
3. Casos de prueba funcional y reporte de fallos para refactorizar.

**Entregable**: release candidato (Beta) estable, testeada y sin fallos críticos.

| Santiago | Bautista |
|---|---|
| [ ] Validaciones de DNI y teléfono (formato, largo, solo dígitos) en los formularios de Gestión | [ ] Validaciones en Cliente (DNI/teléfono) y en el ABM de protocolos (precio ≥ 0, duración > 0) |
| [ ] Integrar seña y reembolso (RF-10) al flujo de confirmar y cancelar; extender `backend/tests` | [ ] Recordatorio de turno (RF-11) visible al buscar el turno, en los dos apartados |
| [ ] Registro de seña como mock (RF-08/09, RNF-05): solo guarda pagada / no pagada | [ ] Buscador sin coincidencia: derivar a WhatsApp (RF-07) y guardar en `ConsultaSinRespuesta` |
| [ ] Reporte simple para recepción: turnos del día (opcional, si alcanza el tiempo) | [ ] **Casos de prueba funcional**: planilla con un caso por RF (Must primero) y resultado de cada uno |
| [ ] Corregir los bugs que salgan de la planilla en Gestión | [ ] Registrar los bugs encontrados y corregir los de Cliente |

Criterio de "Beta": los 10 RF Must (RF-01 a RF-09 y RF-11) funcionando de punta a punta y sin errores
críticos al hacer el flujo completo en los dos apartados.

## Semana 4: Análisis de mercado, competencia y ventaja competitiva

**Propósito**: evaluar el panorama competitivo para identificar la propuesta
única de valor (PUV).

**Actividades de la cátedra**
1. Relevamiento y benchmarking de software existente (competidores directos e
   indirectos, alternativas de código abierto o comerciales).
2. Matriz comparativa de funcionalidades y costos.
3. Identificar la propuesta de valor diferencial.

**Entregable**: informe de competencia y ventaja competitiva.

| Santiago | Bautista |
|---|---|
| [ ] Relevar **competidores indirectos**: lo que hoy usa el instituto (WhatsApp, agenda en papel, planillas) y por qué no alcanza, con datos de `docs/01-arbol-de-problemas.md` | [ ] Relevar **competidores directos**: al menos 3 sistemas de turnos para centros de estética o salud (comerciales y gratuitos), con precio y funciones |
| [ ] Definir la **PUV** (¿por qué elegir Dermalia?): terminal presencial + recepción, sin depender de internet ni de terceros (RNF-09, RNF-11) | [ ] Armar la **matriz comparativa** de funcionalidades y costos contra la competencia |
| [ ] Redactar el informe `docs/07-competencia.md` (estructura y conclusiones) | [ ] Aportar al informe los datos y la matriz; revisar que cada afirmación tenga fuente |
| [ ] Corregir los bugs de la Beta que queden abiertos | [ ] Pulido de la GUI: revisión con la heurística de Nielsen de `docs/05-maquetado.md` |

Cuidar en el informe: no comparar contra productos con datos inventados; cada
precio o función de un competidor va con su fuente.

## Semana 5: Presupuesto, modelo de negocio y preparación del Pitch Deck

**Propósito**: estructurar el modelo económico del proyecto y diseñar una
presentación orientada a la comercialización o inversión.

**Actividades de la cátedra**
1. Cálculo de costos de desarrollo: horas hombre, licencias, infraestructura,
   mantenimiento.
2. Modelo de monetización (licencias, SaaS, llave en mano, abono de soporte).
3. Pitch Deck con esta estructura: problema detectado (Árbol de Problemas),
   solución y demo en vivo, análisis de competencia y diferencial, costos, precio
   de venta y retorno de inversión.

**Entregable**: Pitch Deck y documento de presupuesto final.

| Santiago | Bautista |
|---|---|
| [ ] **Presupuesto**: horas hombre por módulo (del backlog real), licencias (SQL Server, Qt), infraestructura de la terminal y mantenimiento | [ ] **Modelo de monetización**: comparar licencia, abono de soporte y llave en mano; elegir uno y justificarlo |
| [ ] Calcular **precio de venta y retorno de inversión** con los datos del instituto (95 min/día, ≈ $120.000 de turnos perdidos por semana) | [ ] Diapositivas: problema (Árbol de Problemas), competencia y diferencial |
| [ ] Diapositivas: solución, costos, precio y retorno | [ ] Armar el guion de la **demo en vivo** paso a paso (qué se muestra y en qué orden) |
| [ ] Documento `docs/08-presupuesto.md` | [ ] Actualizar `docs/06-pitch.md` al formato nuevo (5-7 min) |

**Cambio de formato**: el pitch de este bimestre dura **5 a 7 minutos** (el del
bimestre anterior era de 7 a 10) y es de **venta a inversores**, con demo en
vivo. El guion de `docs/06-pitch.md` hay que recortarlo.

## Semana 6: Demo Day, presentación del proyecto en formato de venta

**Propósito**: defender el proyecto con una exposición oral y una demostración
técnica en vivo ante un jurado simulado.

**Actividades de la cátedra**
1. Ensayo del pitch con límite de tiempo (5 a 7 min por grupo).
2. Demo Day: exposición oral, demo en vivo de la aplicación conectada a la base,
   y respuesta a objeciones sobre viabilidad, competencia y arquitectura.
3. Coevaluación y retroalimentación final entre pares e instructores.

**Entregable**: software final funcionando + defensa pública en formato Pitch +
**manual técnico y de usuario**.

| Santiago | Bautista |
|---|---|
| [ ] **Manual técnico**: arquitectura (C + ODBC + SQL Server + Qt), cómo instalar, compilar y crear la base | [ ] **Manual de usuario**: uso de la terminal (paciente) y de Gestión (recepción), con capturas |
| [ ] Preparar la **demo en vivo**: base con datos de ejemplo, orden de pasos y plan B si falla la conexión | [ ] Preparar respuestas a **objeciones** (competencia, seña simulada, seguridad de datos, costo) |
| [ ] Ensayar y cronometrar el pitch completo con el equipo (≤ 7 min) | [ ] Ensayar y cronometrar; ajustar el reparto de tiempo |
| [ ] Congelar `main`: tag de la versión final | [ ] Congelar la documentación y revisar que el README esté actualizado |
| [ ] Coevaluación al resto de los equipos | [ ] Coevaluación al resto de los equipos |

## Rúbrica de evaluación (BA Aprende)

Es una rúbrica socioformativa y técnica de cuatro niveles (1 En inicio, 2 En
proceso, 3 Satisfactorio, 4 Avanzado / Destacado), individual por estudiante.
Criterios:

1. **Trabajo en equipo y colaboración**: asumir el rol asignado, coordinar
   avances con los compañeros, ayudar a resolver bloqueos. Por eso conviene que
   cada semana quede registrado en el repo quién hizo qué (ramas y PRs).
2. **Asistencia y compromiso con el entorno de aprendizaje**: asistencia y
   puntualidad, aprovechar el tiempo de taller.
3. **Desempeño técnico y aplicación de contenidos** (referencial): resolver las
   tareas técnicas con autonomía y según las especificaciones.
4. **Responsabilidad y entrega en tiempo y forma**: entregar tareas, informes y
   producciones en los plazos y con el formato acordado.

Nota: la copia del PDF que se subió trae la rúbrica cortada en el criterio 4
(el texto extraído trae solo los niveles 1 a 3 de ese criterio; falta el nivel 4).
Si hace falta el detalle completo, hay que consultarlo en el original.

## Seguimiento

- Al cerrar cada semana: tildar las tareas hechas en este archivo, en la rama
  de cada uno, y abrir un PR a `main`.
- Si una tarea no se termina, pasa a la semana siguiente y se anota acá con una
  línea de motivo.
- Los entregables de la cátedra (prototipo, ABM, Beta, informe, presupuesto,
  manuales) se enlazan desde el README a medida que existan.
