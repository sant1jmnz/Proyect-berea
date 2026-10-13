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
- No se probaron la seña ni la cancelación: no son parte de esta semana.
