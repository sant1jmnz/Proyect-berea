# Casos de prueba funcional del apartado Gestión (Semana 3)

Cinco casos, uno por validación de la carga de un turno (RF-02 y RF-04), con la
plantilla de [`catedra/semana-3-casos-de-prueba-funcional.md`](catedra/semana-3-casos-de-prueba-funcional.md).
Responsable: Santiago. Se probó sin base de datos, con los datos de ejemplo de
`frontend/gestion/datosprueba.cpp`. Nombre, DNI y teléfono también tienen
pruebas automáticas (`frontend/pruebas/prueba_validaciones.cpp`).

| Característica | Descripción del caso de prueba | Precondiciones | Pasos de la prueba | Resultados esperados | Criterios de aprobación/reprobación |
|---|---|---|---|---|---|
| **CP-01 Nombre y apellido** | Verificar que se rechaza un nombre vacío o con números | Gestión abierta en "Cargar turno"; DNI, teléfono y protocolo válidos | 1. Dejar el nombre vacío.<br>2. Clic en **Continuar**.<br>3. Escribir `Carolina123`.<br>4. Clic en **Continuar**. | No avanza. El campo se marca en rojo y un cartel explica el error. | Aprobado si no avanza en los dos intentos y el cartel nombra el error. |
| **CP-02 DNI** | Verificar que el DNI solo acepta números y tiene 7 u 8 dígitos | Gestión abierta en "Cargar turno"; nombre, teléfono y protocolo válidos | 1. Escribir `36ab12.3456789`.<br>2. Clic en **Continuar**.<br>3. Cambiar el DNI por `123456`.<br>4. Clic en **Continuar**. | Queda `36123456` y avanza. Con `123456` no avanza y avisa que deben ser 7 u 8 dígitos. | Aprobado si no deja escribir letras y rechaza el DNI de 6 dígitos. |
| **CP-03 Teléfono** | Verificar que el teléfono tiene de 10 a 13 dígitos y acepta `+54` | Gestión abierta en "Cargar turno"; nombre, DNI y protocolo válidos | 1. Escribir `11 55`.<br>2. Clic en **Continuar**.<br>3. Cambiar el teléfono por `+54 9 11 4444-3322`.<br>4. Clic en **Continuar**. | Con `11 55` no avanza y avisa. Con `+54 9 11 4444-3322` avanza y se guarda solo con números. | Aprobado si rechaza el teléfono corto y acepta el que lleva prefijo. |
| **CP-04 Protocolo** | Verificar que no se avanza sin elegir un protocolo | Gestión abierta en "Cargar turno"; nombre, DNI y teléfono válidos | 1. No elegir ningún protocolo.<br>2. Clic en **Continuar**. | No avanza. Un cartel pide elegir el protocolo. | Aprobado si no avanza al paso 2 sin protocolo. |
| **CP-05 Horario** | Verificar que no se avanza sin horario y que solo se ofrecen horarios libres | Paso 2 abierto con datos válidos; hay un turno el jueves 15/10 a las 09:00 | 1. Clic en **Continuar** sin horario.<br>2. Elegir el jueves 15/10 y ver los horarios.<br>3. Elegir un domingo.<br>4. Volver al jueves, elegir un horario y clic en **Continuar**. | Sin horario no avanza. El jueves no ofrece las 09:00. El domingo no tiene horarios. Con un horario libre pasa al paso 3. | Aprobado si no se puede reservar un horario ocupado ni un domingo. |

## Resultados reales

Los cinco casos dieron **Aprobado** (13 de octubre de 2026):

- **CP-01:** no avanza. Vacío: "Ingresá el nombre y apellido." Con `Carolina123`: "El nombre solo puede tener letras, espacios, apóstrofes y guiones."
- **CP-02:** queda `36123456` y avanza. Con `123456`: "El DNI debe tener 7 u 8 dígitos."
- **CP-03:** con `11 55`: "El teléfono debe tener entre 10 y 13 dígitos (ej: 1144332211)." Con el prefijo avanza y se guarda `5491144443322`.
- **CP-04:** "Elegí el protocolo que pide la paciente."
- **CP-05:** "Elegí un día y un horario libre." El jueves 15/10 ofrece 10:30, 13:00, 15:30 y 17:00; el domingo muestra "Domingo: el instituto no atiende".

## Supuestos y notas

- En CP-05 los horarios dependen de la fecha en que se corre la prueba.
- El nombre exige entre 2 y 60 letras, pero no obliga a escribir el apellido
  (es la misma regla que usa Cliente).
- La seña y la cancelación se prueban en los casos CP-06 y CP-07 de abajo.

## Casos agregados (Semanas 2 y 3): cancelación, protocolos, disponibilidad y contingencia

Con los mismos datos de ejemplo. Los resultados salen de las pruebas
automáticas `frontend/pruebas/prueba_gestion.cpp`
(`QT_QPA_PLATFORM=offscreen ctest`).

| Característica | Descripción del caso de prueba | Precondiciones | Pasos de la prueba | Resultados esperados | Criterios de aprobación/reprobación |
|---|---|---|---|---|---|
| **CP-06 RF-10 / RF-13 Cancelar con seña pagada** | Verificar que con más de 24 h se devuelve la seña completa | Gestión abierta en "Buscar turnos"; María Sosa (DNI `30111222`) tiene un turno confirmado dentro de 2 días con la seña pagada | 1. Buscar `30111222`.<br>2. Elegir el turno realizado: **Cancelar turno** queda deshabilitado.<br>3. Elegir el turno confirmado y tocar **Cancelar turno**.<br>4. Confirmar. | El cartel dice que se devuelve la seña completa. El turno pasa a *Cancelado* y la seña figura "(reembolsada)". El recordatorio del turno desaparece. | Aprobado si el reembolso es igual a la seña y el turno realizado no se puede cancelar. |
| **CP-07 RF-10 Cancelar sin seña / elegir No** | Verificar que sin seña no hay nada que devolver y que "No" no cambia nada | Carla Gómez (DNI `33222111`) tiene un turno confirmado con la seña sin pagar | 1. Buscar `33222111` y elegir el turno.<br>2. Cancelar y responder **No**.<br>3. Cancelar de nuevo y responder **Sí**. | Con **No** el turno sigue confirmado. Con **Sí** el cartel dice "la seña no estaba pagada" y el reembolso queda en $0. | Aprobado si **No** no modifica el turno y el reembolso es 0. |
| **CP-08 RF-05/06 Protocolos** | Verificar el alta con precio y duración inválidos | Pantalla "Protocolos" abierta | 1. Probar precio `-1`, `abc` y vacío.<br>2. Probar duración `0`, `-5` y vacía.<br>3. Probar un nombre ya existente.<br>4. Cargar `Hidrafacial`, `30000`, `50`. | Los pasos 1 a 3 rechazan con un cartel que lista cada error. El paso 4 da de alta el protocolo, que se ofrece en "Cargar turno". Una baja lo oculta de "Cargar turno". | Aprobado si precio < 0, duración ≤ 0 y nombre repetido se rechazan, y el precio $0 se acepta. |
| **CP-09 RF-03 Disponibilidad** | Verificar que las franjas de un profesional no se superponen | Pantalla "Profesionales" abierta; un profesional con una franja de 09:00 a 13:00 | 1. Agregar 12:00 a 14:00 el mismo día.<br>2. Agregar 15:00 a 14:00.<br>3. Agregar un día pasado.<br>4. Agregar 13:00 a 18:00 el mismo día. | Los pasos 1 a 3 se rechazan ("se superpone", "la hora de fin tiene que ser posterior", "días pasados"). El paso 4 se agrega: una franja puede empezar justo cuando termina otra. | Aprobado si solo el paso 4 se agrega. |
| **CP-10 RNF-09 Sin conexión** | Verificar el aviso y el modo contingencia | La aplicación abre sin configurar la base | 1. Abrir Gestión.<br>2. Cargar y confirmar un turno.<br>3. Cerrar y volver a abrir. | Una franja amarilla avisa que no hay conexión y que se trabaja en modo contingencia. El turno confirmado queda guardado en el equipo y la franja lo cuenta; el archivo sigue ahí al reabrir. | Aprobado si la franja aparece y no se pierde el turno. |
| **CP-11 RF-11 Avisos** | Verificar que cada turno programa su recordatorio 24 h antes | Gestión abierta | 1. Confirmar un turno para dentro de 5 días.<br>2. Abrir "Avisos".<br>3. Cancelar ese turno. | El aviso aparece como *WhatsApp asistido*, *Pendiente*, programado 24 h antes del turno. Al cancelar el turno el aviso pendiente desaparece. Si faltan menos de 24 h, sale enseguida. | Aprobado si el aviso se programa a la hora correcta y se anula al cancelar. |

### Resultados reales (27 de octubre de 2026)

Las 36 pruebas de `prueba_gestion` dieron **Aprobado**:

- **CP-06 y CP-07:** `ventana_cancelarConMasDe24HorasDevuelveLaSena`, `ventana_cancelarSinSenaNoDevuelveNada`, `ventana_cancelarElegirNoDejaTodoIgual` y los límites de la regla (`reembolso_*`: justo 24 h no alcanza).
- **CP-08:** `ventana_altaYBajaDeProtocolo` (precio negativo rechazado; el alta aparece en "Cargar turno"; la baja lo oculta), `protocolo_preciosYDuracionesInvalidas`, `protocolo_nombreRepetido`.
- **CP-09:** `ventana_franjasNoSePisan` (agrega 9 a 13, rechaza 12 a 14, acepta 13 a 18) y `disponibilidad_*`.
- **CP-10:** `ventana_turnoSinConexionQuedaGuardadoYConAviso` (el turno queda en el archivo del equipo y sigue ahí al reabrir), `ventana_tieneLasPantallasNuevasYLaFranja`, `contingencia_*`, `franja_sinConexionYRecuperada`, `basedatos_*`.
- **CP-11:** `ventana_turnoSinConexionQuedaGuardadoYConAviso` (el aviso se programa al confirmar), `ventana_cancelarConMasDe24HorasDevuelveLaSena` (el aviso se anula al cancelar) y `recordatorio_*` (24 h antes, salida inmediata, canal, estados).

### Notas

- Son pruebas automáticas sobre la ventana real, sin pantalla (`offscreen`);
  no reemplazan una prueba manual en la PC de recepción.
- Con la base real, estos casos se repiten contra los stored procedures
  (cada SP lleva sus 4 pruebas de la consigna).
