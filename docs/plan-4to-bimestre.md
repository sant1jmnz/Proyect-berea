# Plan de Aprendizaje – 4° Bimestre: Proyecto Informático I

Transcripción del PDF de cátedra. El reparto de tareas entre el equipo está en
[`reparto-4to-bimestre.md`](reparto-4to-bimestre.md).

**Enfoque**: Buenos Aires Aprende / Escuela Técnica CABA

**Especialidad**: Computación

**Producto Final**: Software de Gestión/Escritorio desarrollado en C con
framework Qt, vinculado a una Base de Datos relacional, presentado en formato
Pitch de Ventas / Demo Day ante inversores, respaldado por un Análisis de
Competencia.

## Contexto Curricular y Pedagógico

- **Trayecto previo (3er Bimestre)**: Los estudiantes fundamentaron la
  problemática abordada a través de las herramientas de planificación
  estratégica: Árbol de Problemas, Árbol de Objetivos y la Matriz de Marco
  Lógico (MML).
- **Objetivo del 4° Bimestre**: Traducir los requerimientos y la planificación
  construida en el 3er bimestre en un producto de software funcional en C / Qt
  con persistencia de datos relacional, validando su viabilidad comercial
  mediante una propuesta de valor frente al mercado y la competencia.
- **Metodología de Trabajo**: Desarrollo ágil (sprints semanales), aprendizaje
  basado en proyectos integradores (ABP), trabajo colaborativo en repositorio y
  presentación ejecutiva final.

## Semana 1: Arquitectura del Sistema y Prototipado de GUI en Qt Designer

- **Propósito de Aprendizaje**: Maquetar la interfaz gráfica de usuario en Qt
  Creator basándose en la Matriz de Marco Lógico y los requerimientos
  funcionales definidos en el bimestre anterior.
- **Actividades**:
  1. Configuración de entorno de trabajo C/ Qt (Qt Creator) y vinculación con
     el repositorio Git institucional.
  2. Diseño de pantallas e interfaz de usuario (ventanas principales,
     formularios, menús y cuadros de diálogo) utilizando Qt Designer y widgets
     estándar (QLineEdit, QPushButton, QTableView, etc.).
  3. Implementación de eventos básicos mediante la arquitectura de Señales y
     Slots de Qt.
- **Entregable**: Prototipo navegable de la interfaz gráfica (GUI) en C/ Qt sin
  persistencia activa, sincronizado en el repositorio.

## Semana 2: Persistencia e Integración C++ / Qt con Base de Datos

- **Propósito de Aprendizaje**: Vincular la aplicación desarrollada en C con la
  base de datos relacional para garantizar las operaciones de ABM (Altas, Bajas
  y Modificaciones).
- **Actividades**:
  1. Configuración del módulo de base de datos en Qt (QSqlDatabase, QSqlQuery,
     QSqlQueryModel / QSqlTableModel).
  2. Implementación de controladores C para la apertura de conexión, ejecución
     de sentencias SQL y manejo de excepciones de conexión.
  3. Mapeo e integración de formularios GUI con operaciones CRUD sobre las
     tablas de la base de datos relacional.
- **Entregable**: Módulo ABM funcional integrado a la base de datos a través de
  la interfaz de Qt.

## Semana 3: Lógica de Negocio, Validaciones y Calidad de Software (QA)

- **Propósito de Aprendizaje**: Asegurar el correcto funcionamiento de la
  aplicación, implementando validaciones de entrada de datos y ejecutando
  pruebas funcionales.
- **Actividades**:
  1. Implementación de validaciones en campos de la interfaz (máscaras de
     entrada, expresiones regulares para correos, CUIT, etc.) y tratamiento de
     mensajes de error al usuario.
  2. Implementación de la lógica interna de negocio en C (cálculos, filtrados,
     reportes o reglas específicas del dominio abordado).
  3. Diseño de casos de prueba funcional (Testing de aplicación) y reporte de
     fallos/bugs para la refactorización de código.
- **Entregable**: Release candidato (Beta) de la aplicación C/Qt estable,
  testeada y sin fallos críticos.

## Semana 4: Análisis de Mercado, Competencia y Ventaja Competitiva

- **Propósito de Aprendizaje**: Evaluar el panorama competitivo de la solución
  de software desarrollada para identificar la propuesta única de valor (PUV).
- **Actividades**:
  1. Relevamiento y benchmarking de software existente en el mercado
     (competidores directos e indirectos, alternativas de código abierto o
     comerciales).
  2. Confección de una Matriz Comparativa de Funcionalidades y Costos frente a
     la competencia.
  3. Identificación de la propuesta de valor diferencial de la solución propia
     (¿Por qué un cliente/inversor elegiría nuestro desarrollo sobre lo
     existente?).
- **Entregable**: Informe analítico de competencia e identificación de la
  Ventaja Competitiva del proyecto.

## Semana 5: Presupuesto, Modelo de Negocio y Preparación del Pitch Deck

- **Propósito de Aprendizaje**: Estructurar el modelo económico-financiero del
  proyecto y diseñar una presentación ejecutiva orientada a la
  comercialización/inversión.
- **Actividades**:
  1. Cálculo de costos de desarrollo: estimación de horas hombre de
     programación, licencias, infraestructura y mantenimiento.
  2. Definición del modelo de monetización (venta de licencias, modelo SaaS,
     llave en mano, abono de soporte técnico).
  3. Estructuración del Pitch Deck (Presentación de ventas) siguiendo la
     estructura:
     - Problema detectado (referenciando el Árbol de Problemas del 3er
       bimestre).
     - Solución / Demo en vivo del software C/Qt + BD.
     - Análisis de Competencia y Diferencial.
     - Modelo de Costos, Precio de Venta y Retorno de Inversión.
- **Entregable**: Presentación ejecutiva (Pitch Deck) y documento de
  presupuesto final.

## Semana 6: "Demo Day" – Presentación del Proyecto en Formato de Venta

- **Propósito de Aprendizaje**: Defender el proyecto informático mediante una
  exposición oral y demostración técnica en vivo ante un jurado simulado de
  inversores y evaluadores.
- **Actividades**:
  1. Ensayo de la exposición (Pitch) con límite de tiempo (5 a 7 minutos por
     grupo).
  2. Ejecución del Demo Day / Ronda de Inversión:
     - Exposición oral del Pitch Deck.
     - Demostración funcional en vivo (Live Demo) de la aplicación C/Qt
       conectada a la base de datos.
     - Argumentación frente a objeciones, preguntas del panel sobre viabilidad,
       competencia y arquitectura técnica.
  3. Coevaluación y retroalimentación final entre pares e instructores bajo el
     marco de BA Aprende.
- **Entregable**: Demostración del software final + Defensa pública en formato
  Pitch + Manual técnico y de usuario del producto.

## Rúbrica de Evaluación de Formato BA Aprende

**RÚBRICA DE EVALUACIÓN SOCIOFORMATIVA Y TÉCNICA**

Unidad Curricular Proyecto informático 1

Ciclo: Segundo Ciclo - Modalidad Técnico Profesional (Especialidad Computación
/ Técnica)

Estudiante: _______________________ Fecha: _______________

| Criterio de Evaluación | Nivel 1: En Inicio | Nivel 2: En Proceso | Nivel 3: Satisfactorio | Nivel 4: Avanzado / Destacado |
|---|---|---|---|---|
| 1. Trabajo en Equipo y Colaboración | Muestra dificultad para integrarse en el equipo. Trabaja de manera aislada o genera conflictos que impiden el avance técnico del proyecto. No asume los roles asignados. | Participa de manera esporádica en el equipo. Cumple con sus tareas individuales pero le cuesta coordinar con sus compañeros o comunicar avances y bloques de código/diagramas. | Trabaja de forma colaborativa, asume el rol asignado (Scrum/roles de taller), respeta la diversidad de opiniones y contribuye activamente al logro de los objetivos grupales. | Lidera de forma constructiva, fomenta la cohesión del equipo, ayuda a resolver bloqueos técnicos o de convivencia y optimiza la dinámica de trabajo colaborativo. |
| 2. Asistencia y Compromiso con el Entorno de Aprendizaje | Registra inasistencias reiteradas no justificadas o faltas de puntualidad que interfieren significativamente con el desarrollo de los laboratorios/talleres y el trabajo grupal. | Asiste con discontinuidad o llega con impuntualidad de manera recurrente, afectando parcialmente el ritmo de las actividades y entregas planificadas. | Cumple de manera regular con la asistencia y puntualidad establecidas para las clases/laboratorios. Justifica con responsabilidad las eventuales faltas. | Muestra un nivel de asistencia y puntualidad ejemplar. Aprovecha al máximo el tiempo de taller/laboratorio y demuestra un compromiso constante con el espacio. |
| 3. Desempeño Técnico y Aplicación de Contenidos (Referencial) | Muestra dificultades para aplicar los conceptos teóricos y prácticos de la especialidad. Requiere guía constante para resolver tareas de baja complejidad. | Aplica conceptos técnicos básicos con asistencia del docente. Realiza pruebas o procedimientos técnicos de forma parcial o con errores frecuentes. | Resuelve situaciones problemáticas y tareas técnicas según las especificaciones requeridas, demostrando autonomía en la ejecución de los procedimientos. | Aplica los saberes de manera autónoma, creativa y rigurosa. Propone soluciones eficientes y optimizadas ante problemáticas del área técnica. |
| 4. Responsabilidad y Entrega en Tiempo y Forma | Rara vez entrega los avances, informes o proyectos en las fechas acordadas. Muestra falta de seguimiento de las pautas institucionales. | Entrega con demoras frecuentes o de manera incompleta los trabajos requeridos, necesitando recordatorios del docente. | Entrega las tareas, informes y producciones en los plazos estipulados y cumpliendo con las pautas y formatos acordados. | |
