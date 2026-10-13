# Casos de prueba funcional del apartado Cliente (Semana 3)

Planilla con un caso por requerimiento funcional (RF-01 a RF-25, ver
[`04-requerimientos.md`](04-requerimientos.md)) y el resultado de cada uno.
Responsable: Bautista (apartado Cliente).

**Cómo se ejecutaron:** los casos marcados con una prueba automática corren
con `QT_QPA_PLATFORM=offscreen ./dermalia_tests` (ver
`frontend/tests/test_cliente.cpp`). Resultado de la última corrida:
**27 pruebas, 27 aprobadas, 0 fallidas**. Todo se probó sin base de datos: los
datos son los de ejemplo que están dentro de la aplicación.

**Estados:** *Aprobado* · *Parcial* (lo que existe anda, pero falta una parte
del RF) · *Falla* (no cumple lo que pide el RF) · *No ejecutado* (todavía no
hay nada que probar en Cliente: depende de la base, de Gestión o del apartado
Web).

## Casos por requerimiento

| Caso | RF | Apartado | Pasos | Resultado esperado | Resultado obtenido | Estado |
|---|---|---|---|---|---|---|
| CP-01 | RF-01 | Cliente | Cargar nombre, DNI y teléfono válidos; elegir un protocolo; elegir fecha y horario; confirmar | Se completan los 3 pasos y se confirma el turno | Los 3 pasos funcionan y el turno queda confirmado (`rf01_rf04_rf08_rf10_flujo_completo`). **No se puede elegir más de un protocolo en el mismo turno** (el RF lo pide) | Parcial |
| CP-02 | RF-02 | Gestión | — | Recepción carga un turno en 3 pasos | Es del apartado Gestión (Santiago); no se probó acá | No ejecutado |
| CP-03 | RF-03 | Gestión | — | Cargar y editar disponibilidad horaria | La pantalla de profesionales y disponibilidad todavía no existe | No ejecutado |
| CP-04 | RF-04 | Cliente | Reservar un horario y volver a abrir la grilla para la misma fecha y profesional | El horario reservado aparece como "Ocupado" y no se puede elegir | Aparece "Ocupado" y el botón queda deshabilitado. Funciona solo en memoria de esta terminal: no hay "tiempo real" entre apartados | Parcial |
| CP-05 | RF-05 | Cliente | Escribir "peeling" en el buscador | Se ve solo el protocolo que coincide, con precio y duración; "Seleccionar" lo pasa al turno | Muestra 1 resultado (Peeling Químico Médico, $18.000, 40 min) y "Seleccionar" envía los datos (`rf05_buscador_filtra_por_palabra_clave`) | Aprobado |
| CP-06 | RF-06 | Gestión | — | Recepción busca precios y protocolos | Es del apartado Gestión (Santiago); no se probó acá | No ejecutado |
| CP-07 | RF-07 | Cliente | Buscar un texto sin coincidencias ("zzzzzz") | Se ofrece derivar la consulta al WhatsApp del instituto y se deja registrada | Se muestra el botón de WhatsApp (`rf07_sin_coincidencias_deriva_a_whatsapp`). **La consulta no queda registrada** (necesita la base) | Parcial |
| CP-08 | RF-08 | Cliente | Confirmar el turno en el paso 3 | Se muestra el monto de la seña y el turno queda registrado con la seña "Pagada" (mock) | Muestra el monto y registra el turno con seña "Pagada" en memoria. No guarda el estado en la base | Parcial |
| CP-09 | RF-09 | Gestión | — | Recepción registra la seña | Es del apartado Gestión (Santiago); no se probó acá | No ejecutado |
| CP-10 | RF-10 | Cliente | Ver la seña de un protocolo de $22.000; cancelar un turno a más de 24 hs y otro a menos de 24 hs | Seña del 30% con **mínimo $20.000** (40% en cirugías); reembolso del 100% con más de 24 hs y sin reembolso con menos | El reembolso con más y con menos de 24 hs es correcto (`rf10_cancelar_con_mas_de_24hs_reembolsa`, `rf10_cancelar_con_menos_de_24hs_no_reembolsa`). **La seña usa mínimo $5.000** (el RF dice $20.000) y **no existe el 40% en cirugías**; ver BUG-01 | Falla |
| CP-11 | RF-11 | Cliente | Buscar un turno y mirar el recordatorio | Se envía un recordatorio y se registra cada aviso (canal, estado, fecha programada) | Se muestra el texto del recordatorio en pantalla. No se envía ni se registra ningún aviso (necesita la base y n8n) | No ejecutado |
| CP-12 | RF-12 | Cliente | Buscar con un DNI y con un teléfono que tienen turno; cancelar el turno | Aparece el turno de esa paciente y se puede cancelar sin cuenta | Encuentra el turno por DNI (38123456) y por teléfono (1144332211) y lo puede cancelar (`rf12_buscar_por_dni_y_telefono`) | Aprobado |
| CP-13 | RF-13 | Gestión | — | Recepción busca y cancela por nombre, DNI o teléfono | Es del apartado Gestión (Santiago); no se probó acá | No ejecutado |
| CP-14 | RF-14 | Cliente | — | Preguntar al asistente de IA | No existe la pantalla del asistente | No ejecutado |
| CP-15 | RF-15 | Cliente | — | Crear una cuenta opcional | No existe; necesita la base | No ejecutado |
| CP-16 | RF-16 | Cliente | Buscar el historial por DNI | Aparecen todos los turnos de ese DNI | Aparecen los turnos de esa sesión, que están en memoria; el historial real necesita la base | Parcial |
| CP-17 | RF-17 | Todos | — | Ingresar un cupón por código y ver el precio actualizado | No existe; necesita la base | No ejecutado |
| CP-18 | RF-18 | Gestión | — | Ofrecer solo los profesionales habilitados para el protocolo | Hoy el combo de profesionales muestra los mismos dos para todos los protocolos | No ejecutado |
| CP-19 | RF-19 | Web + Gestión | — | Agregar el turno a Google Calendar | No existe | No ejecutado |
| CP-20 | RF-20 | Gestión | — | Ingreso con cuenta propia y log de auditoría | Es de Gestión y de la base (Santiago) | No ejecutado |
| CP-21 | RF-21 | Web | — | Sitio web completo | El apartado Web no se empezó | No ejecutado |
| CP-22 | RF-22 | Gestión | — | Cupón con QR rotativo cada 5 minutos | No existe; necesita la base | No ejecutado |
| CP-23 | RF-23 | Todos | — | Vender y canjear tarjetas de regalo | No existe; necesita la base | No ejecutado |
| CP-24 | RF-24 | Todos | — | Cupones automáticos por fidelidad | No existe; necesita la base | No ejecutado |
| CP-25 | RF-25 | Todos | — | Cirugía solo con consulta previa y evaluación "apta" | No existe; necesita la base | No ejecutado |

## Casos de validación de datos (Semana 3)

Módulo `frontend/comun/validaciones.*`, usado en la carga de turno (paso 1) y
en "Buscar mi turno". Además, los campos de DNI y teléfono solo dejan tipear
dígitos (máscara de entrada).

| Caso | Campo | Entrada | Resultado esperado | Resultado obtenido | Estado |
|---|---|---|---|---|---|
| CV-01 | DNI | `36123456` | Válido | Válido | Aprobado |
| CV-02 | DNI | `9123456` (7 dígitos) | Válido | Válido | Aprobado |
| CV-03 | DNI | `36.123.456` | Válido (se limpian los puntos) | Válido | Aprobado |
| CV-04 | DNI | vacío | Rechazado: "Ingresá tu DNI." | Rechazado | Aprobado |
| CV-05 | DNI | `123456` (6 dígitos) | Rechazado: 7 u 8 dígitos | Rechazado | Aprobado |
| CV-06 | DNI | `123456789` (9 dígitos) | Rechazado | Rechazado | Aprobado |
| CV-07 | DNI | `36A23456` | Rechazado: solo números | Rechazado | Aprobado |
| CV-08 | Teléfono | `1144332211` | Válido | Válido | Aprobado |
| CV-09 | Teléfono | `+5491144332211` | Válido | Válido | Aprobado |
| CV-10 | Teléfono | `11 4433-2211` | Válido (se limpian espacios y guion) | Válido | Aprobado |
| CV-11 | Teléfono | vacío | Rechazado | Rechazado | Aprobado |
| CV-12 | Teléfono | `114433221` (9 dígitos) | Rechazado: 10 a 13 dígitos | Rechazado | Aprobado |
| CV-13 | Teléfono | `54911443322110` (14 dígitos) | Rechazado | Rechazado | Aprobado |
| CV-14 | Teléfono | `11443322ab` | Rechazado: solo números | Rechazado | Aprobado |
| CV-15 | Nombre | `María José O'Brien-Pérez` | Válido | Válido | Aprobado |
| CV-16 | Nombre | vacío, `A` o `Carolina123` | Rechazado | Rechazado | Aprobado |
| CV-17 | Protocolo (ABM) | precio `0` y `22000` | Válido (precio ≥ 0) | Válido | Aprobado |
| CV-18 | Protocolo (ABM) | precio `-1` | Rechazado | Rechazado | Aprobado |
| CV-19 | Protocolo (ABM) | duración `1` y `45` | Válido (duración > 0) | Válido | Aprobado |
| CV-20 | Protocolo (ABM) | duración `0` y `-10` | Rechazado | Rechazado | Aprobado |
| CV-21 | Carga de turno, paso 1 | Tipear `36ab12.3456789` en DNI | Queda `36123456` (solo dígitos, máx. 8) | Queda `36123456` (`rf01_mascara_de_entrada`) | Aprobado |
| CV-22 | Carga de turno, paso 1 | Campos vacíos, DNI de 3 dígitos o teléfono de 3 dígitos | Cartel de error y no avanza al paso 2 | Cartel de error y se queda en el paso 1 (`rf01_paso1_datos_invalidos_no_avanza`) | Aprobado |
| CV-23 | Buscar mi turno | Buscar `123` | Cartel de error | Cartel de error (`rf12_busqueda_invalida_muestra_aviso`) | Aprobado |
| CV-24 | Buscar mi turno | Tipear `38abc123456` | Queda `38123456` | Queda `38123456` | Aprobado |

## Reporte de fallos

| Id | RF | Descripción | Gravedad | Estado |
|---|---|---|---|---|
| BUG-01 | RF-10 | La seña se calcula como 30% con mínimo **$5.000** (`pasoscargaturnowidget.cpp`, `buscadorwidget.cpp`), pero `04-requerimientos.md` pide mínimo **$20.000** y 40% en cirugías. Además, un mínimo de $20.000 superaría el precio de protocolos baratos (por ejemplo Limpieza Profunda, $16.000): hay que acordar la regla con Santiago antes de corregirla | Media | Abierto |
| BUG-02 | RF-01 | Solo se puede elegir un protocolo por turno; el RF pide poder elegir varios en el mismo turno | Media | Abierto |
| BUG-03 | RF-18 | El combo de profesionales es el mismo para todos los protocolos | Baja | Abierto (depende de la base) |

## Cambio de comportamiento en esta semana

"Buscar mi turno" (RF-12) ahora busca solo por DNI o teléfono, con coincidencia
exacta, como pide el requerimiento. Antes también aceptaba parte del nombre y
coincidencias parciales de números; la búsqueda por nombre queda para Gestión
(RF-13).
