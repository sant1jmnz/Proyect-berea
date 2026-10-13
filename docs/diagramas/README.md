# Diagramas

Archivos `.drawio` del diseño conceptual (notación de Peter Chen). Se abren en
draw.io (File → Open from → Device) y se acomodan a mano.

| Archivo | Contenido |
|---|---|
| `chen-entidades-y-relaciones.drawio` | Las 27 entidades y las 37 relaciones, **sin atributos todavía**, con el mismo formato que los diagramas de la actividad anterior: rectángulos simples con nombres en CamelCase, rombos con un verbo, etiquetas `1` / `N` / `M` en cada extremo con patas de gallo y el texto `1:N` junto al rombo. Es un borrador de ubicación para acomodar a mano |
| `chen-grupo1.drawio` | Grupo 1: Paciente, Profesional, Protocolo, Turno (con las entidades vecinas como borradores en gris) |

Convenciones (formato de la cátedra): rectángulo = entidad; rombo = relación;
elipse = atributo; atributo subrayado = clave primaria (`ID_Entidad`);
`1`, `N` y `M` junto a cada entidad = cardinalidad. Las relaciones N:M
(`Incluye`, `Realiza`) quedan como rombo, sin entidad intermedia: la tabla
intermedia aparece recién en el diseño lógico. `chen-grupo1.drawio` es el
primer borrador (con otra notación, `(mín,máx)`) y queda de referencia.
