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

## Quiénes participan

El árbol **no lo hace una persona sola**. La cátedra insiste en que hay que
contar con todos los grupos y personas afectadas o relacionadas con el problema,
e incluir tanto a posibles beneficiarios de la solución como a **posibles
detractores** y a quienes van a ejecutar el proyecto. Los problemas se registran
**tal como son percibidos por los involucrados**, no como los interpreta el
equipo.

## Procedimiento

0. **Convocar a los involucrados** y hacer una lluvia de ideas de las
   situaciones insatisfactorias relacionadas con la problemática común.
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
6. **Leer el diagrama completo en voz alta.** La regla de la cátedra: *el
   diagrama debe tener sentido; al leerlo debe entenderse la secuencia lógica de
   la situación analizada*. Si no se entiende leído de corrido, está mal armado.

Distinguir **causas directas** (primer nivel, cuelgan del problema central) de
**causas indirectas** (cuelgan de una causa). La distinción no es decorativa:
determina qué se convierte en objetivo específico y qué en actividad.

## Cómo formular el problema central — el punto de equilibrio

Del video de cátedra, y es más sutil que "que sea concreto":

> Se debe formular el problema central **lo suficientemente concreto** para
> facilitar la búsqueda de soluciones, pero **lo suficientemente amplio** para
> permitir contar con una gama de alternativas de solución, en lugar de una
> solución única.

Si el problema admite una sola solución posible, está formulado demasiado
angosto — y probablemente sea una solución disfrazada. Si admite cualquier cosa,
está demasiado ancho.

Además, el problema se **fecha y se ubica**: "Alta tasa de analfabetismo en el
Cantón X al 2017", no "hay analfabetismo". El lugar y el año son los que después
permiten construir la línea de base del indicador.

## Tabla de contraste — mal y bien formulado

Ejemplos de la cátedra. El patrón es siempre el mismo: la columna izquierda
nombra un recurso que falta; la derecha nombra el estado negativo que eso produce.

| Problema MAL formulado | Problema BIEN formulado |
|---|---|
| Falta de repuestos | Equipo no funciona |
| No hay pesticidas disponibles | Cosecha reducida por las plagas |
| No existe un generador local de energía eléctrica | Limitada provisión de energía eléctrica durante el día |
| Falta de programas de educación inicial | Bajo rendimiento de los niños y niñas en los primeros años de educación primaria |

Aplicado a nuestro caso: "no hay una app de turnos" es la columna izquierda.
La columna derecha sería "los turnos se superponen y se pierden".

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
