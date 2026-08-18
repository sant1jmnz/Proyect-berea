---
name: arbol-de-problemas
description: Construir o revisar el Árbol de Problemas del proyecto — problema central, causas raíz y efectos. Usar al arrancar el diagnóstico, al detectar la problemática, o cuando se pida analizar causas y consecuencias de una necesidad real.
---

# Árbol de Problemas

Diagnóstico de la problemática. Es la raíz de toda la Carpeta de Proyecto:
todo lo demás se deriva de acá.

## Estructura

- **Tronco** — el problema central. Uno solo.
- **Raíces** — las causas. Se pregunta "¿por qué ocurre?" hasta llegar a causas
  sobre las que se puede actuar.
- **Copa** — los efectos. Se pregunta "¿y esto qué provoca?".

## Procedimiento

1. **Delimitar el problema central.** Tiene que ser una situación negativa real
   y verificable de la escuela, el barrio o una PyME/ONG local. Escribirlo en
   presente, en negativo, sin mencionar la solución.
2. **Bajar a causas.** Por cada causa, preguntar "¿por qué?" al menos dos veces.
   Distinguir causas directas (primer nivel) de causas raíz (niveles inferiores).
3. **Subir a efectos.** Preguntar "¿qué consecuencias tiene?" hasta llegar a un
   efecto final que impacte a la comunidad.
4. **Verificar la lógica causal** recorriendo el árbol de abajo hacia arriba:
   "esta causa produce el problema central, que produce este efecto". Si la
   frase no se sostiene leída en voz alta, el vínculo está mal.
5. Numerar: `C1, C2…` causas (con `C1.1` para subcausas), `E1, E2…` efectos.

## Los tres errores que hay que cazar

1. **Solución disfrazada de problema.** "No hay una app de gestión" describe
   una solución ausente, no un problema. Reescribir como la necesidad:
   "La gestión de X se hace en papel y se pierden datos".
2. **Problema demasiado amplio.** "La educación está mal" no se puede abordar
   en un bimestre. Delimitar a un ámbito, un actor y un proceso concretos.
3. **Confundir causa con efecto.** Preguntar "¿esto pasa *antes* o *después*
   del problema central?".

## Formato de salida

Escribir en `docs/01-arbol-de-problemas.md`: contexto y actores relevados,
el diagrama en Mermaid (efectos arriba, problema al medio, causas abajo), y
una tabla de causas numeradas con la evidencia que respalda cada una
(entrevista, encuesta, observación).

Cerrar con: qué causas se van a atacar con software y cuáles quedan fuera del
alcance — esa decisión justifica todo el proyecto.
