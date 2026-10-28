# Casos de prueba funcional del apartado Cliente (Semana 3)

Un caso por requerimiento funcional (RF) que cubre la terminal de la paciente,
con la plantilla de [`catedra/semana-3-casos-de-prueba-funcional.md`](catedra/semana-3-casos-de-prueba-funcional.md).
Responsable: Bautista. Se probó sin base de datos, con los datos de ejemplo
de la terminal. **Los resultados reales salen de las pruebas automáticas**
`frontend/tests/test_cliente.cpp` (se corren con `QT_QPA_PLATFORM=offscreen ctest`):
cada caso indica la prueba que lo verifica.

| Característica | Descripción del caso de prueba | Precondiciones | Pasos de la prueba | Resultados esperados | Criterios de aprobación/reprobación |
|---|---|---|---|---|---|
| **CP-C01 RF-01 Datos de la paciente** | Verificar que el paso 1 no avanza con datos inválidos | Terminal abierta en "Cargar mi turno", paso 1 | 1. Dejar nombre, DNI y teléfono vacíos y tocar **Continuar**.<br>2. Escribir `Carolina Morales`, DNI `123`, teléfono válido y tocar **Continuar**.<br>3. Corregir el DNI y poner el teléfono `123`; tocar **Continuar**. | En los tres intentos no pasa al paso 2 y un cartel explica qué corregir. | Aprobado si en ningún intento avanza. |
| **CP-C02 RF-01 / RF-04 / RF-08 / RF-10 Carga completa** | Verificar el flujo de tres pasos hasta la seña simulada | Datos válidos (`Carolina Morales`, `36123456`, `1144332211`); protocolo Láser Diodo Facial ($22.000) | 1. Completar el paso 1 y **Continuar**.<br>2. Sin elegir horario, tocar **Continuar** (falla).<br>3. Elegir el primer horario libre y **Continuar**.<br>4. Ver la seña y tocar **Confirmar**.<br>5. Tocar **Nuevo turno** y volver al paso 2. | Sin horario no avanza. La seña es el 30% con mínimo $5.000 (**$6.600**). Se confirma el turno con el DNI cargado y la seña de $6.600. Ese horario aparece **Ocupado** y deshabilitado. | Aprobado si cada paso da el resultado esperado y el horario reservado ya no se puede elegir. |
| **CP-C03 RF-05 Buscador** | Verificar que el buscador filtra por palabra clave | Pantalla "Precios y protocolos" abierta | 1. Escribir `peeling`.<br>2. Tocar **Seleccionar** en el resultado. | Aparece un solo resultado, *Peeling Químico Médico* ($18.000, 40 min), sin el aviso de derivación. Al seleccionarlo se carga en el paso 1. | Aprobado si hay exactamente un resultado y llega al formulario con sus datos. |
| **CP-C04 RF-07 Derivación a WhatsApp** | Verificar que sin coincidencias se ofrece WhatsApp | Pantalla "Precios y protocolos" abierta | 1. Escribir `zzzzzz`. | Se muestra el aviso para consultar por WhatsApp al instituto. | Aprobado si el aviso aparece. |
| **CP-C05 RF-11 Recordatorio** | Verificar que cada turno muestra su recordatorio | Hay un turno con DNI `38123456` | 1. En "Buscar mi turno", escribir `38123456` y tocar **Buscar**. | El turno muestra una tarjeta "Recordatorio activo en sistema (RF-11)" con día, hora, lugar y protocolo. | Aprobado si hay un recordatorio por turno. |
| **CP-C06 RF-12 Buscar mi turno** | Verificar la búsqueda por DNI, por teléfono y los casos límite | Terminal abierta en "Buscar mi turno" | 1. Buscar `38123456`.<br>2. Buscar `1144332211`.<br>3. Buscar `1100000000` (sin turnos).<br>4. Buscar `123`.<br>5. Escribir `38abc123456`. | 1: un turno con botón *Cancelar*. 2: el turno de Peeling Químico Médico. 3: "No se encontraron turnos". 4: cartel de dato inválido. 5: el campo queda en `38123456` (no deja escribir letras). | Aprobado si los cinco pasos dan lo esperado. |
| **CP-C07 RF-10 Cancelar con más de 24 h** | Verificar que se devuelve la seña | Turno del DNI `38123456`, dentro de 3 días | 1. Buscar `38123456`.<br>2. Tocar **Cancelar Turno** y confirmar. | Se avisa el reembolso del 100%; el estado de la seña pasa a *Reembolsada (100%)* y el horario queda libre. | Aprobado si la seña figura reembolsada. |
| **CP-C08 RF-10 Cancelar con menos de 24 h** | Verificar que la seña no se devuelve | Turno cargado para hoy, con menos de 24 h por delante | 1. Buscar el DNI del turno.<br>2. Tocar **Cancelar Turno** y confirmar. | Se avisa que no hay reembolso; el estado de la seña pasa a *Sin reembolso (< 24 hs)*. | Aprobado si la seña no se reembolsa. |

## Resultados reales

Corrida del **27 de octubre de 2026**: las 28 pruebas automáticas del apartado
Cliente dieron **Aprobado** (0 fallas), entre ellas:

| Caso | Prueba que lo verifica | Resultado |
|---|---|---|
| CP-C01 | `rf01_paso1_datos_invalidos_no_avanza`, `rf01_mascara_de_entrada` | Aprobado |
| CP-C02 | `rf01_rf04_rf08_rf10_flujo_completo` | Aprobado (seña $6.600; horario reservado queda ocupado) |
| CP-C03 | `rf05_buscador_filtra_por_palabra_clave` | Aprobado |
| CP-C04 | `rf07_sin_coincidencias_deriva_a_whatsapp` | Aprobado |
| CP-C05 | `rf11_cada_turno_muestra_su_recordatorio` | Aprobado |
| CP-C06 | `rf12_buscar_por_dni_y_telefono`, `rf12_busqueda_invalida_muestra_aviso` | Aprobado |
| CP-C07 | `rf10_cancelar_con_mas_de_24hs_reembolsa` | Aprobado |
| CP-C08 | `rf10_cancelar_con_menos_de_24hs_no_reembolsa` | Aprobado |

Las validaciones de DNI, teléfono y nombre tienen además pruebas con datos
límite (7, 8, 6 y 9 dígitos; con puntos; con letras; vacío).

## Supuestos y notas

- Las pruebas automáticas no reemplazan una prueba manual en la terminal táctil
  real (tamaño de botones, comodidad al tocar); queda para el ensayo del Demo Day.
- En CP-C08 el turno se carga para "hoy a las 23:59" para que siempre falten
  menos de 24 horas.
- **Diferencia a resolver con el equipo:** la terminal calcula la seña como
  30% con mínimo de $5.000, mientras que Gestión y `docs/04-requerimientos.md`
  usan solo el porcentaje de la categoría (30%, o 40% en cirugías) sin mínimo.
  Los precios de hoy no dan una seña menor a $5.000, pero con un protocolo
  barato o una cirugía los dos apartados darían montos distintos.
- La carga de turno de la terminal todavía no se conecta a la base: usa datos
  de ejemplo. Ver [`conexion-base.md`](conexion-base.md).
