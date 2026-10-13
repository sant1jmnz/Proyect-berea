# Casos de prueba funcional del apartado Gestión (Semana 3)

Cinco casos, uno por cada validación de la carga de un turno (RF-02, pasos 1
y 2). Mismo formato que la planilla de Cliente
([`09-casos-de-prueba.md`](09-casos-de-prueba.md)); la plantilla de la cátedra
está en [`catedra/semana-3-casos-de-prueba-funcional.md`](catedra/semana-3-casos-de-prueba-funcional.md).
Responsable: Santiago (apartado Gestión).

**Cómo se ejecutaron:** se abrió la ventana de Gestión, se cargaron los datos
de cada caso en "Cargar turno" y se apretó **Continuar**. Las reglas de nombre,
DNI y teléfono además tienen pruebas automáticas
(`frontend/pruebas/prueba_validaciones.cpp`, ejecutable `prueba_validaciones`).
Todo se probó sin base de datos, con los datos de ejemplo de
`frontend/gestion/datosprueba.cpp`.

**Estados:** *Aprobado* · *Parcial* · *Falla* (mismos criterios que la planilla
de Cliente).

## Casos

| Caso | RF | Apartado | Pasos | Resultado esperado | Resultado obtenido | Estado |
|---|---|---|---|---|---|---|
| CP-G01 | RF-02 | Gestión | En "Cargar turno", dejar el nombre vacío (o escribir `Carolina123`) y apretar Continuar | No avanza al paso 2; el campo queda marcado en rojo y un cartel dice qué está mal | No avanza. Vacío: "Ingresá el nombre y apellido." `Carolina123`: "El nombre solo puede tener letras, espacios, apóstrofes y guiones." | Aprobado |
| CP-G02 | RF-02 | Gestión | Escribir en el DNI `36ab12.3456789`; después `123456` y apretar Continuar | El campo solo deja escribir números (máximo 8); un DNI de 6 dígitos no avanza | `36ab12.3456789` queda `36123456` y avanza. `123456` no avanza: "El DNI debe tener 7 u 8 dígitos." | Aprobado |
| CP-G03 | RF-02 | Gestión | Escribir el teléfono `11 55` y apretar Continuar; después `+54 9 11 4444-3322` | `11 55` no avanza; el teléfono con prefijo avanza y se guarda solo con los números | `11 55` no avanza: "El teléfono debe tener entre 10 y 13 dígitos (ej: 1144332211)." `+54 9 11 4444-3322` avanza y queda guardado `5491144443322` | Aprobado |
| CP-G04 | RF-02 | Gestión | Con los datos de la paciente bien cargados, no elegir ningún protocolo y apretar Continuar | No avanza al paso 2 y pide elegir el protocolo | No avanza: "Elegí el protocolo que pide la paciente." | Aprobado |
| CP-G05 | RF-04 | Gestión | En el paso 2, apretar Continuar sin elegir horario; después mirar los horarios de un día con turnos y los de un domingo | No avanza sin horario; solo se ofrecen los horarios libres; el domingo no hay turnos | Avisa "Elegí un día y un horario libre." y no avanza. El jueves 15/10 ofrece 10:30, 13:00, 15:30 y 17:00 (el 09:00 está ocupado). El domingo muestra "Domingo: el instituto no atiende". Con un horario elegido pasa al paso 3 | Aprobado |

## Reporte de fallos

Ninguno abierto en estos cinco casos. Queda como decisión pendiente de la
planilla de Cliente el mínimo de la seña (BUG-01): en el modelo de la base la
seña es solo un porcentaje de la categoría (30% o 40% en cirugías) y Gestión
ya la calcula así.
