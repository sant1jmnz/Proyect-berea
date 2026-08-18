---
name: maquetado-ux
description: Diseñar el maquetado funcional — wireframes, mockups, user flow e interfaz propuesta — y evaluarlo con las heurísticas de usabilidad de Nielsen. Usar al diseñar pantallas, navegación o al revisar la usabilidad de la propuesta.
---

# Maquetado, Interfaz y Usabilidad

El maquetado es la validación visual de los requerimientos: cada pantalla tiene
que responder a un RF. Si una pantalla no implementa ningún requerimiento,
sobra; si un RF no aparece en ninguna pantalla, falta diseño.

## Qué producir

1. **User flow** — el mapa de navegación: por dónde entra el usuario, qué
   caminos toma, cómo se conectan los módulos. Va en Mermaid dentro del `.md`.
2. **Wireframes de baja fidelidad** — estructura y jerarquía, sin colores ni
   tipografías. Es donde se discute *qué va* en cada pantalla.
3. **Mockups de alta fidelidad** — de las pantallas principales, con la
   identidad visual ya definida. Figma o Wireframe.cc.
4. **Justificación de las decisiones de diseño** — por qué esta disposición y
   no otra, atada a los requerimientos y al perfil del usuario relevado.

Cada pantalla se rotula con los RF que cubre: `Pantalla 3 — Carga de asistencia
(RF-03, RF-04, RNF-02)`.

## Evaluación heurística (Nielsen)

Antes de dar el maquetado por cerrado, revisarlo contra las 10 heurísticas y
anotar cómo lo resuelve cada pantalla:

1. **Visibilidad del estado del sistema** — mostrar siempre qué está pasando:
   barras de carga, confirmaciones.
2. **Lenguaje del usuario** — evitar tecnicismos; íconos familiares.
3. **Control y libertad** — permitir deshacer; siempre un botón de cancelar o volver.
4. **Consistencia y estándares** — mismos botones y colores en toda la plataforma.
5. **Prevención de errores** — desactivar el envío si faltan datos, antes de que
   el error ocurra.
6. **Reconocer antes que recordar** — opciones visibles, historial de búsqueda;
   no forzar la memoria.
7. **Flexibilidad y eficiencia** — atajos para expertos que no estorben al novato.
8. **Diseño estético y minimalista** — sacar lo irrelevante: cada frase de más
   compite con la información importante.
9. **Ayudar a reconocer y recuperarse de errores** — decir qué falló y cómo
   solucionarlo, nunca un código numérico pelado.
10. **Ayuda y documentación** — guías buscables y FAQ orientadas a tareas concretas.

## Coevaluación

El maquetado se somete a revisión cruzada con otro equipo. Preparar dos
preguntas concretas para esa devolución: qué duda tiene el equipo sobre su
propio diseño, no un "¿qué les parece?".

## Formato de salida

`docs/05-maquetado.md`: user flow en Mermaid, capturas en `docs/assets/`,
enlace al archivo de Figma, tabla pantalla → RF cubiertos, y la revisión
heurística.
