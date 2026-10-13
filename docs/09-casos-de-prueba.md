# Casos de prueba funcional del apartado Gestión (Semana 3)

Cinco casos de prueba, uno por cada validación de la carga de un turno
(RF-02, pasos 1 y 2, y RF-04). Se escribieron con la plantilla de la cátedra:
[`catedra/semana-3-casos-de-prueba-funcional.md`](catedra/semana-3-casos-de-prueba-funcional.md).

Responsable: Santiago (apartado Gestión).

## Supuestos

- Las pruebas se hicieron sin base de datos: la aplicación usa los datos de
  ejemplo de `frontend/gestion/datosprueba.cpp`.
- La ventana de Gestión está abierta, en la pantalla **Cargar turno** (paso 1),
  sin datos escritos.
- Hoy es martes 13 de octubre de 2026. Los horarios que se ofrecen dependen de
  la fecha y de la hora en que se corre la prueba.
- Las reglas de nombre, DNI y teléfono además tienen pruebas automáticas:
  `frontend/pruebas/prueba_validaciones.cpp` (ejecutable `prueba_validaciones`).

## Casos

| Id | Característica | Descripción del caso de prueba | Precondiciones | Pasos de la prueba | Resultados esperados | Resultados reales | Criterios de aprobación/reprobación |
|---|---|---|---|---|---|---|---|
| CP-01 | Validar nombre y apellido | Verificar que el paso 1 rechaza un nombre vacío o con números | La ventana de Gestión está abierta en "Cargar turno" y hay un protocolo elegido, un DNI y un teléfono válidos | 1. Dejar el campo **Nombre y apellido** vacío.<br>2. Hacer clic en **Continuar**.<br>3. Escribir `Carolina123` en el campo.<br>4. Hacer clic en **Continuar**. | No avanza al paso 2.<br>El campo queda marcado en rojo.<br>Aparece un cartel que explica qué está mal. | No avanza en los dos intentos.<br>Vacío: "Ingresá el nombre y apellido."<br>`Carolina123`: "El nombre solo puede tener letras, espacios, apóstrofes y guiones." | **Aprobado** si no avanza y el cartel nombra el error. **Reprobado** si pasa al paso 2 con un nombre inválido. |
| CP-02 | Validar DNI | Verificar que el DNI solo deja escribir números y exige 7 u 8 dígitos | La ventana de Gestión está abierta en "Cargar turno" y hay un nombre, un teléfono y un protocolo válidos | 1. Escribir `36ab12.3456789` en el campo **DNI**.<br>2. Mirar qué quedó escrito.<br>3. Hacer clic en **Continuar**.<br>4. Borrar el DNI y escribir `123456`.<br>5. Hacer clic en **Continuar**. | Al escribir queda solo `36123456` (números, máximo 8) y avanza al paso 2.<br>Con `123456` no avanza y avisa que debe tener 7 u 8 dígitos. | El campo queda en `36123456` y avanza al paso 2.<br>Con `123456` no avanza: "El DNI debe tener 7 u 8 dígitos." | **Aprobado** si las letras no se pueden escribir y el DNI de 6 dígitos no avanza. **Reprobado** si acepta letras o un DNI fuera de 7 u 8 dígitos. |
| CP-03 | Validar teléfono | Verificar que el teléfono exige entre 10 y 13 dígitos y acepta el prefijo `+54` | La ventana de Gestión está abierta en "Cargar turno" y hay un nombre, un DNI y un protocolo válidos | 1. Escribir `11 55` en el campo **Teléfono**.<br>2. Hacer clic en **Continuar**.<br>3. Borrar el teléfono y escribir `+54 9 11 4444-3322`.<br>4. Hacer clic en **Continuar**. | Con `11 55` no avanza y avisa que debe tener entre 10 y 13 dígitos.<br>Con `+54 9 11 4444-3322` avanza al paso 2 y el teléfono se guarda solo con los números. | Con `11 55` no avanza: "El teléfono debe tener entre 10 y 13 dígitos (ej: 1144332211)."<br>Con `+54 9 11 4444-3322` avanza y se guarda `5491144443322`. | **Aprobado** si el teléfono corto no avanza y el largo con prefijo sí. **Reprobado** si el resultado es al revés. |
| CP-04 | Elegir protocolo | Verificar que no se puede continuar sin elegir un protocolo | La ventana de Gestión está abierta en "Cargar turno" y hay un nombre, un DNI y un teléfono válidos | 1. No elegir ningún protocolo de la lista.<br>2. Hacer clic en **Continuar**. | No avanza al paso 2.<br>Aparece un cartel que pide elegir el protocolo. | No avanza: "Elegí el protocolo que pide la paciente." | **Aprobado** si no avanza y el cartel nombra el protocolo. **Reprobado** si pasa al paso 2 sin protocolo. |
| CP-05 | Elegir horario libre | Verificar que no se puede continuar sin horario y que solo se ofrecen horarios libres | Los datos del paso 1 son válidos y se está en el paso 2 (**Elegir horario**). Hay un turno confirmado el jueves 15/10 a las 09:00 | 1. Sin elegir horario, hacer clic en **Continuar**.<br>2. Elegir en el calendario el jueves 15/10 y mirar los horarios.<br>3. Elegir en el calendario un domingo y mirar los horarios.<br>4. Volver al jueves 15/10, elegir un horario y hacer clic en **Continuar**. | Sin horario no avanza y avisa.<br>El jueves no ofrece el 09:00, que ya está ocupado.<br>El domingo no ofrece horarios.<br>Con un horario libre avanza al paso 3. | Sin horario no avanza: "Elegí un día y un horario libre."<br>El jueves 15/10 ofrece 10:30, 13:00, 15:30 y 17:00.<br>El domingo muestra "Domingo: el instituto no atiende".<br>Con un horario elegido pasa al paso 3. | **Aprobado** si no avanza sin horario, el 09:00 del jueves no se ofrece y el domingo no tiene horarios. **Reprobado** si se puede reservar un horario ocupado o un domingo. |

## Notas

- En CP-02 el primer intento avanza porque `36123456` es un DNI válido de 8
  dígitos: lo que se comprueba ahí es la máscara de entrada (solo números,
  máximo 8).
- El nombre solo exige letras y entre 2 y 60 caracteres; no obliga a escribir
  el apellido. Es la misma regla que usa el apartado Cliente.
- No se probaron la seña ni la cancelación: no forman parte de las validaciones
  de esta semana.
