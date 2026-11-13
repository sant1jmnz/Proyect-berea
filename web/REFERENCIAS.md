# Decisiones de diseño del sitio

El sitio usa la paleta y las tipografías de Dermalia (`diseno-dermalia/SKILL.md`).
Cada elemento está porque cumple una función; lo que era solo decoración se sacó
(pantalla de carga, cursor propio, marquesina, letras que ruedan, olas, ilustraciones
sueltas, scroll suave forzado y la física de objetos que rebotaban).

| Elemento | Para qué sirve |
|---|---|
| Corte de la piel en 3D (`tres/piel.js`) | Elegir por zona de acción: tocás una capa y ves los protocolos que actúan ahí; al señalar uno se ve su herramienta (láser, aguja, ondas, producto, bisturí) en la profundidad correcta. |
| Vitrina en 3D (`tres/vitrina.js`, en `protocolos.html`) | Recorrer el catálogo de forma visual: cada objeto es un protocolo (frasco, jeringa, cabezal láser, equipo de ondas, bisturí) y el color indica la categoría. La lista es la vía principal; sin WebGL solo queda la lista. |
| Carta con precios | Leer precio, duración y zona de un vistazo, como una carta de spa. |
| Comparador (hasta 3) | Decidir entre protocolos parecidos con precio, seña, sesiones y duración lado a lado. |
| Ficha de protocolo | Qué hacer antes y después, cuántas sesiones lleva y para quién no es. |
| Calculadora de seña | Mostrar la regla del 30 % (40 % en cirugías) con un ejemplo propio. |
| Consulta prequirúrgica en la reserva | Las cirugías no se reservan directo (RF-25). |

El catálogo (nombres, precios, duraciones, profesionales) sale de `backend/02_datos.sql`
con `npm run generar` (corre solo antes de `dev` y `build`). Lo que la base no guarda
(capa de la piel, sesiones, cuidados) está en `src/datos/fichas.js`.

Skills usadas para el rediseño (en `.claude/skills/`): impeccable, ui-ux-pro-max,
emil-design-eng, review-animations y design-taste-frontend (que reemplazó a
redesign-existing-projects en su repositorio).
