# Casos de prueba funcional del apartado Cliente

Un caso por requerimiento funcional (RF) que cubre la terminal de la paciente
(`dermalia_cliente`), con la plantilla de [`catedra/semana-3-casos-de-prueba-funcional.md`](catedra/semana-3-casos-de-prueba-funcional.md).
Responsable: Bautista. **Los resultados salen de las pruebas automáticas**:
`frontend/pruebas/prueba_ventanacliente.cpp` (sin base, con el archivo local) y
`frontend/pruebas/prueba_cliente_base.cpp` (contra MySQL). Se corren con
`QT_QPA_PLATFORM=offscreen ctest` dentro de la carpeta de compilación; cada caso indica la prueba que lo verifica.

| Característica | Descripción del caso de prueba | Precondiciones | Pasos de la prueba | Resultados esperados | Criterios de aprobación/reprobación |
|---|---|---|---|---|---|
| **CP-C01 RF-01 Elegir protocolo** | Verificar que sin protocolo no se avanza | Terminal en "Elegí tu protocolo" | 1. Tocar **Continuar** sin elegir nada. | Un cartel pide elegir el tratamiento y se queda en el paso 1. | Aprobado si no avanza. |
| **CP-C02 RF-01 / RF-04 Horario** | Verificar que solo se ofrecen horarios libres y fechas válidas | Protocolo elegido | 1. Elegir un día con turnos ocupados.<br>2. Intentar un año anterior a 2026 y un mes que ya pasó.<br>3. Tocar un día de este mes que ya pasó. | 1: el horario ocupado no aparece. 2: el calendario no deja quedarse en esas fechas y los meses pasados están deshabilitados. 3: pregunta si se quiere el mismo día del año que viene. | Aprobado si los tres pasos dan lo esperado. |
| **CP-C03 RF-01 Datos de la paciente** | Verificar que no confirma con datos inválidos | Paso 3 abierto | 1. Nombre sin apellido, DNI `123` y teléfono `123`; tocar **Confirmar turno**.<br>2. Escribir letras en el DNI. | 1: un cartel con todo lo que hay que corregir; no se carga el turno. 2: el campo no deja escribir letras. | Aprobado si no se carga ningún turno. |
| **CP-C04 RF-01 / RF-08 Reserva con seña** | Verificar la reserva completa con la seña | Datos válidos (`Ana Paz`, `35111222`, `1166667777`) | 1. Elegir protocolo y horario.<br>2. Tocar **Pagar seña** y **Confirmar turno**. | El turno queda confirmado con código `SIM-…` y la pantalla pasa a "Buscar mi turno" mostrándolo. Con la base: queda en la base y, si la paciente es nueva, se le pide la fecha de nacimiento. | Aprobado si el turno queda guardado y se muestra. |
| **CP-C05 RF-12 Buscar mi turno** | Verificar la búsqueda por DNI y por teléfono | Hay un turno de `35111222` | 1. Buscar `35111222`.<br>2. Buscar `1166667777`.<br>3. Buscar un DNI sin turnos. | 1 y 2: aparece el turno. 3: avisa que no hay turnos. | Aprobado si los tres pasos dan lo esperado. |
| **CP-C06 RF-10 Cancelar con más de 24 h** | Verificar que se devuelve la seña y se libera el horario | Turno con seña pagada dentro de 10 días | 1. Buscar el turno.<br>2. **Cancelar mi turno** → "No".<br>3. **Cancelar mi turno** → "Sí". | 2: no cambia nada. 3: se devuelve el 100% de la seña, el turno queda "Cancelado" y el horario vuelve a estar libre. | Aprobado si la seña se reembolsa y el horario se libera. |
| **CP-C07 RF-10 Elegir qué turno cancelar** | Verificar que con varios turnos se elige cuál | Dos turnos del mismo DNI | 1. **Cancelar mi turno**.<br>2. Elegir el segundo de la lista y confirmar.<br>3. Repetir y tocar **Volver**. | 2: se cancela solo el elegido. 3: no se cancela nada. | Aprobado si se cancela exactamente el elegido. |
| **CP-C08 RF-10 Cancelar con 24 h o menos** | Verificar que la seña no se devuelve | Turno con menos de 24 h por delante | 1. Cancelar el turno. | Se avisa que la seña no se devuelve. | Aprobado si la seña no se reembolsa. |
| **CP-C09 RNF-09 Sin base** | Verificar que la terminal sigue andando sin base y comparte los turnos con Gestión | Sin conexión | 1. Sacar un turno y cerrar la terminal.<br>2. Volver a abrirla y buscarlo.<br>3. Cargar un turno desde Gestión en el mismo horario. | 2: el turno sigue ahí. 3: ese horario deja de ofrecerse en la terminal. | Aprobado si el turno persiste y el horario se comparte. |
| **CP-C10 RF-05/06 Precios y resumen** | Verificar que el buscador filtra el catálogo real y muestra el resumen | Terminal en "Consultar precios" | 1. Escribir `laser`.<br>2. Tocar *Ver resumen* en una cirugía.<br>3. En el paso 1, elegir un protocolo y tocar *Ver resumen*. | 1: aparecen solo las depilaciones láser, con el precio de la base. 2: la ficha avisa la consulta prequirúrgica. 3: la ficha tiene descripción, sesiones, zona, capa, antes, después y "no es para vos si", igual que la web. | Aprobado si los tres pasos dan lo esperado. |
| **CP-C11 RF-15 Cuenta de la paciente** | Verificar que se crea la cuenta, se ingresa y se sale | Base conectada | 1. *Ingresar* → *Crear una cuenta* con datos válidos.<br>2. Ir al paso 3 de sacar turno.<br>3. Tocar "Hola, …" y salir.<br>4. *Ingresar* con `recepcion1`.<br>5. Crear otra cuenta con el mismo DNI. | 1: queda ingresada y la cuenta está en la base. 2: nombre, DNI y teléfono ya están escritos. 3: se borran sus datos. 4: avisa que es una cuenta del personal. 5: avisa que ya tiene cuenta. | Aprobado si los cinco pasos dan lo esperado. |

## Resultados reales

Corrida del **17 de noviembre de 2026** con MySQL 8.0.46: todas las pruebas dieron **Aprobado**.

| Caso | Prueba que lo verifica | Resultado |
|---|---|---|
| CP-C01 | `sinProtocoloNoAvanza` | Aprobado |
| CP-C02 | `horarioOcupadoNoSeOfrece`, `noSePuedeElegirUnAnioAnteriorA2026`, `losMesesQueYaPasaronQuedanBloqueados`, `unDiaPasadoDelMesActualPregunta`, `paraElAnioQueViene2027FuncionaElFlujo` | Aprobado |
| CP-C03 | `datosInvalidosNoConfirman` y las pruebas de `prueba_validaciones.cpp` | Aprobado |
| CP-C04 | `turnoSeCargaAlMomentoYSeEncuentra`; con la base, `terminal_reservaBuscaYCancelaEnLaBase` | Aprobado |
| CP-C05 | `turnoSeCargaAlMomentoYSeEncuentra`, `terminal_reservaBuscaYCancelaEnLaBase` | Aprobado |
| CP-C06 | `cancelarFuncionaYLiberaElHorario`; con la base, `terminal_reservaBuscaYCancelaEnLaBase` | Aprobado |
| CP-C07 | `cancelarConVariosTurnosPideElegirCual`, `cancelarConVariosTurnosYVolverNoCancelaNada` | Aprobado |
| CP-C08 | `reembolso_menosDe24HorasNoDevuelve` y `reembolso_exactamente24HorasNoAlcanza` (regla compartida, `prueba_gestion.cpp`) | Aprobado |
| CP-C09 | `losTurnosSeGuardanYSeVenAlReabrir`, `horarioQueOcupoGestionNoSeOfrece` | Aprobado |
| CP-C10 | `buscador_buscaSinImportarTildesNiMayusculas`, `resumen_cadaProtocoloTieneSuFichaComoEnLaWeb`, `resumen_seAbreDesdeProtocolosYDesdeElBuscador` (`prueba_gestion.cpp`; el buscador y el resumen son los mismos en la terminal) | Aprobado |
| CP-C11 | `terminal_cuentaDeLaPaciente` (`prueba_cliente_base.cpp`) | Aprobado |

## Supuestos y notas

- Las pruebas automáticas no reemplazan una prueba manual en la terminal táctil
  real (tamaño de botones, comodidad al tocar); queda para el ensayo del Demo Day.
- La seña es el porcentaje de la categoría (30%, o 40% en cirugías), igual en la
  terminal, en Gestión y en la base.
- La terminal muestra cada hora una sola vez aunque haya varios profesionales libres:
  reserva con el primero que la tiene libre.
