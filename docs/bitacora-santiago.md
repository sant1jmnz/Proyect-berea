# Bitácora de Santiago

## Martes 13 de octubre de 2026 (Semana 3, la de validaciones y calidad)

### Qué hice

**Frontend de Gestión (C++ y Qt)**
- Agregué las **5 validaciones** de la carga de un turno: nombre y apellido,
  DNI (7 u 8 números), teléfono (10 a 13 dígitos, acepta `+54`), protocolo
  elegido y horario elegido. Si hay errores, los campos se marcan en rojo y un
  cartel lista todo lo que falta.
- El paso 2 solo ofrece horarios libres y futuros, y no ofrece domingos.
- "Buscar turnos" ahora filtra por nombre, DNI o teléfono.
- Pasé los datos de prueba a la estructura del modelo de la base (categoría de
  protocolo, protocolo y turno con estado, origen y seña) y calculé la seña
  como porcentaje de la categoría: 30%, o 40% en cirugías, sin mínimo.

**Calidad**
- Escribí pruebas automáticas de las validaciones y de la seña (30 casos).
- Armé los **5 casos de prueba funcional** de Gestión con la plantilla de la
  cátedra, en una tabla de 6 columnas: `docs/09-casos-de-prueba.md`. Los cinco
  dieron aprobado.

**Equipo y repositorio**
- Revisé que `main` y las ramas fueran iguales. La rama de Bautista tenía su
  apartado Cliente y la de `claude-bbdd` el diagrama de Chen; junté todo en
  `main` y dejé las ramas iguales.
- Cuando Bautista subió sus validaciones, resolví los conflictos y dejé **una
  sola regla de validación** para Cliente y Gestión (`frontend/comun/validaciones`).
- Pasé a Markdown el material de la cátedra sobre casos de prueba
  (`docs/catedra/`).
- Protegí `main` en GitHub: ahora todo entra por pull request, nadie puede
  borrarla ni pisar su historial.

### Problemas y cómo los resolví

| Problema | Solución |
|---|---|
| Mi Git es viejo y no tiene `sparse-checkout` | Usé el método clásico (`core.sparseCheckout` y `.git/info/sparse-checkout`) para bajar solo `frontend/` |
| GitHub no acepta la contraseña de la cuenta | Usé un token personal, sin guardarlo en la PC |
| La rama de Bautista chocaba con `main` (CMake y reparto) | Resolví los conflictos a mano, compilé todo y corrí las pruebas de los dos |
| Cliente y Gestión validaban distinto (el teléfono aceptaba 10 y de 10 a 13 dígitos) | Dejé el módulo de Bautista como único y borré el mío |
| Las dos primeras planillas de casos de prueba estaban mal | Las borré y rehice una sola, con la plantilla de la cátedra |

### Qué aprendí

- Que una validación conviene escribirla una sola vez y compartirla entre los
  dos apartados; si no, cada uno termina con reglas distintas.
- Que la seña no es un monto fijo: depende del porcentaje de la categoría del
  protocolo, y eso es parte del modelo de la base.
- Cómo escribir un caso de prueba funcional: precondiciones, pasos, resultado
  esperado y criterio de aprobación.

### Pendiente

- Seña simulada (RF-08/09) y cancelación con reembolso (RF-10).
- Decidir con Bautista el mínimo de la seña: los requerimientos dicen $20.000
  y el modelo de la base solo tiene porcentaje.
- Separar nombre y apellido en dos campos, como pide la entidad Paciente.
- DER conceptual: completar los atributos de las 27 entidades en draw.io.
