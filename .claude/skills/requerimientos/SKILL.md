---
name: requerimientos
description: Relevar y redactar requerimientos funcionales y no funcionales, historias de usuario y el backlog inicial. Usar al pasar de la MML a la especificación del sistema, al escribir user stories o criterios de aceptación.
---

# Requerimientos y Historias de Usuario

Los requerimientos **se derivan de los Componentes y Actividades de la MML**.
Cada componente del sistema se desagrega en los requerimientos que lo hacen
existir.

## Requerimientos funcionales (RF)

Qué hace el sistema. Uno por línea, numerados `RF-01`, `RF-02`…

Formato: *El sistema debe permitir a [rol] [acción] para [propósito]*.

> RF-03: El sistema debe permitir al preceptor registrar la asistencia de un
> curso completo en una sola pantalla.

Cada RF referencia el componente de la MML del que sale (`R2`) para mantener la
trazabilidad.

## Requerimientos no funcionales (RNF)

Cómo lo hace. Numerados `RNF-01`… Cubrir al menos estas categorías:

- **Rendimiento** — "El listado de alumnos carga en menos de 2 segundos".
- **Usabilidad** — "Un preceptor sin capacitación previa completa la carga en
  menos de 3 minutos".
- **Seguridad** — autenticación, roles, protección de datos de menores.
- **Compatibilidad** — navegadores, dispositivos, funcionamiento sin conexión.
- **Mantenibilidad** — documentación, estructura del repositorio.

Un RNF sin número medible no sirve: "debe ser rápido" no es un requerimiento.

## Historias de usuario

> **Como** [rol], **quiero** [funcionalidad], **para** [beneficio].

Cada historia lleva **criterios de aceptación** — las condiciones concretas que
permiten decir que está terminada:

```
Como preceptor, quiero cargar la asistencia desde el celular,
para no tener que volver a la sala de profesores.

Criterios de aceptación:
- La pantalla funciona en un ancho de 360 px.
- Se puede marcar presente/ausente/tarde con un toque por alumno.
- Al confirmar, muestra un resumen antes de guardar.
- Si se pierde la conexión, los datos no se pierden.
```

Buenas historias: independientes, negociables, valiosas, estimables, chicas y
verificables. Si una historia no entra en el bimestre, partirla.

## Backlog inicial

Organizar las historias en un backlog priorizado (Trello o GitHub Projects),
con etiquetas de prioridad **Must / Should / Could** y la referencia al RF que
implementa cada una.

## Formato de salida

`docs/04-requerimientos.md`: tabla de RF (id, descripción, componente MML de
origen, prioridad), tabla de RNF (id, categoría, criterio medible), y las
historias de usuario con sus criterios de aceptación.
