# Referencias de movimiento

Cinco sitios que eligió el equipo. De cada uno tomamos el **movimiento**, no
la estética: el sitio usa la paleta y las tipografías de Dermalia
(`diseno-dermalia/SKILL.md`).

| Sitio | Qué tiene | Qué tomamos | Dónde va |
|---|---|---|---|
| [ivan.technology](https://ivan.technology/) | Loader centrado con barra fina y porcentaje; cursor de círculo con borde | Loader con barra dorada y porcentaje; cursor propio | `cargador.js`, `cursor.js` |
| [tesseract.postminimal.agency](https://tesseract.postminimal.agency/) | Una esfera de luz en WebGL que responde a "mantené apretado" | La perla 3D del inicio: si la mantenés apretada se infla, brilla y las burbujas giran alrededor | `tres/perla.js` |
| [pixelismo.it](https://www.pixelismo.it/) | Ilustraciones de línea de fondo; ventana redondeada con objetos 3D que caen con física (cannon.js); transiciones con Barba | Ilustraciones de línea (frascos, hojas, gotas) que se dibujan; ventana 3D con objetos que caen al cambiar de categoría; transición entre páginas | `trazos.js`, `tres/vitrina.js`, `transiciones.js` |
| [dark-moon.org](https://dark-moon.org/) | Logo con letras duplicadas que ruedan; horizonte de luz; fila de cifras con íconos de píxeles animados | Letras que ruedan en la marca y en los botones; fila de cifras que cuentan al aparecer | `texto.js`, `contadores.js` |
| [guillaumecolombel.fr](https://guillaumecolombel.fr/) | Nuxt + Three.js; su escena 3D no llegó a cargar en el navegador de prueba | Pendiente: falta saber qué efecto le gusta al equipo | — |

Análisis hecho con Playwright (capturas a 1440 px y lectura de los scripts
que carga cada sitio).
