---
name: estetica-dermalia
description: Estética y convenciones de la interfaz Qt de Dermalia (estilo spa claro). Usar al crear o tocar cualquier pantalla en frontend/, en especial el apartado Cliente (terminal táctil), para que se vea igual que el apartado Gestión.
---

# Estética Dermalia (Qt Widgets)

El apartado **Gestión** (`frontend/gestion/`) ya está hecho y es la referencia.
El apartado **Cliente** (`frontend/cliente/`) tiene que verse de la misma
familia: misma paleta, mismas tipografías, mismas piezas. Lo único que cambia
es que Cliente es una **terminal táctil vertical**: todo más grande.

Antes de escribir nada, abrir `frontend/gestion/ventanagestion.ui` en Qt
Designer y correr `dermalia_gestion` para ver el resultado.

## Reglas de la Semana 1

- **Solo interfaz y navegación.** Nada de base de datos, nada del backend en C,
  nada de datos simulados en el código.
- Los datos que se ven (nombres, precios, horarios) son **texto fijo escrito en
  el `.ui`**, para que las pantallas no queden vacías.
- El `.cpp` solo tiene `connect()` de navegación y ajustes de aspecto.
- Pantallas en `.ui` (Qt Designer), no armadas a mano en C++.

## Estilo: «spa elegante claro»

Fondo crema, tarjetas blanco cálido, rosa viejo para lo importante, dorado
para los detalles, títulos con serif. Sin colores chillones ni degradés
violetas.

### Colores

| Uso | Color |
|---|---|
| Fondo de la ventana | `#FCF8F2` → `#F5ECE6` (degradé suave) |
| Tarjeta | `#FFFDFA`, borde `#F0E7DC`, radio 14 px |
| Texto principal | `#3A2B2B` |
| Texto secundario | `#7A6A64` |
| Texto apagado / deshabilitado | `#A89C95` |
| Rosa (acción principal, selección) | `#A8475F`, al pasar el mouse `#8E3A50` |
| Rosa suave (fondo de selección) | `#F7E8EB` |
| Dorado (etiquetas de campo, detalles) | `#8A6A3B`, línea `#D9C3A0` |
| Dorado suave (tarjeta de seña) | `#FBF3E6`, borde `#E5D2B0` |
| Verde salvia (confirmado, seña pagada) | `#5F7F63`, fondo `#EAF1EA`, texto `#4F6B53` |
| Rojo (cancelar) | `#A33A3A`, borde `#E3BFBF` |
| Bordes de campos y listas | `#E8DCCF` |

No inventar colores nuevos: si hace falta uno, usar el más parecido de la tabla.

### Tipografías

- **Playfair Display**: títulos de pantalla, títulos de tarjeta, la marca.
- **Lato**: todo lo demás. Los **números van en Lato**, no en Playfair
  (los números de Playfair se ven desparejos).

Las dos están en `frontend/gestion/fuentes/` y viajan dentro del ejecutable.
En `main.cpp` de Cliente cargarlas igual que en Gestión:

```cpp
for (const char *f : { "Lato-Regular.ttf", "Lato-Bold.ttf", "PlayfairDisplay.ttf" })
    QFontDatabase::addApplicationFont(QString(":/fuentes/") + f);
```

### Tamaños: Gestión vs. Cliente

Cliente se usa con el dedo, parada frente a la terminal (RNF-03, RNF-07).

| Elemento | Gestión (mouse) | Cliente (táctil) |
|---|---|---|
| Ventana mínima | 960×600, horizontal | **768×1024, vertical** |
| Texto base | 14 px | **18 px** |
| Título de pantalla | 30 px | **38 px** |
| Título de tarjeta | 18 px | **22 px** |
| Alto de botón | ~38 px | **mínimo 60 px** |
| Alto de campo de texto | ~38 px | **mínimo 56 px** |
| Fila de lista (protocolo, horario) | ~56 px | **mínimo 76 px** |
| Separación entre cosas tocables | 8 px | **mínimo 14 px** |
| Márgenes de la página | 26 px | **36 px** |

En táctil no existe "pasar el mouse": nada importante puede depender de
`:hover`. El estado elegido se tiene que ver solo con `:selected` / `:checked`.

## Cómo reutilizar el estilo

1. Copiar **entera** la propiedad `styleSheet` de la ventana de
   `ventanagestion.ui` a la ventana de Cliente (en Designer: clic derecho en
   la ventana → *Change styleSheet…*).
2. Cambiar solo los tamaños según la tabla de arriba. Los colores no se tocan.
3. Borrar las reglas que Cliente no usa (`#barraLateral`, `#menu`,
   `QTableWidget`).

El estilo funciona con **propiedades dinámicas**: en Designer se agregan con el
`+` del panel de propiedades (tipo *String* o *Bool*). Las que ya existen:

| Propiedad | Valores | En qué widget | Qué hace |
|---|---|---|---|
| `rol` | `titulo`, `subtitulo`, `seccion`, `campo`, `valor`, `nota`, `numero`, `hora`, `apagado` | `QLabel` | Tamaño, peso y color del texto |
| `tarjeta` | `true` | `QFrame` | Caja blanca redondeada |
| `primario` | `true` | `QPushButton` | Botón rosa relleno (uno solo por pantalla) |
| `peligro` | `true` | `QPushButton` | Botón de cancelar, en rojo |
| `paso` | `activo`, `hecho`, `pendiente` | `QLabel` | Indicador "1 · Protocolo" |
| `avatar` | `rosa`, `dorado`, `salvia`, `libre` | `QLabel` 36×36 | Círculo con iniciales |
| `etiqueta` | `ok`, `pendiente` | `QLabel` | Pastilla "Pagada" / "Pendiente" |
| `fila` | `true` | `QFrame` | Renglón con línea fina abajo |
| `icono` | `true` | `QLabel` 40×40 | Círculo rosa con un ícono adentro |

Los íconos SVG están en `frontend/gestion/iconos/` y se usan desde el `.ui`
como `:/iconos/inicio.svg`, `turno.svg`, `precios.svg`, `buscar.svg`. Si hace
falta uno nuevo: SVG de 24×24, solo línea (sin relleno), grosor 2, color
`#8E5A68`. Nunca emojis como íconos.

## Piezas que hay que repetir

- **Cabecera de pantalla**: título en Playfair + una línea gris debajo que
  explica qué hacer.
- **Indicador de pasos** en las 3 pantallas de carga: `1 · Protocolo`,
  `2 · Horario`, `3 · Confirmar`. El actual subrayado en dorado, los hechos con
  `✓` en rosa.
- **Tarjetas** para agrupar; título de tarjeta en Playfair.
- **Botones en píldora** (bordes bien redondeados). El principal, rosa, abajo
  a la derecha; "Volver" a su izquierda, blanco.
- **Lista de protocolos**: `QListWidget`, cada renglón con nombre y debajo
  `60 min · $25.000`. El elegido con borde rosa y fondo rosa suave.
- **Horarios**: `QListWidget` en modo fluido (`flow = LeftToRight`,
  `isWrapping = true`), cada hora una píldora; la elegida, rosa rellena.
- **Tarjeta de seña**: fondo dorado suave, etiqueta `SEÑA A PAGAR`, monto
  grande, la regla del 30 % y el botón.
- **Sombra** debajo de las tarjetas: copiar el bucle de
  `QGraphicsDropShadowEffect` del constructor de `ventanagestion.cpp`.

## Lo que cambia en Cliente

- **Sin barra lateral.** Arriba, una franja con el círculo "D", "Dermalia" y
  un botón "Inicio". La navegación es por botones grandes.
- **Pantalla de inicio propia**: saludo y tres botones enormes, uno debajo del
  otro: *Sacar un turno*, *Consultar precios*, *Buscar mi turno*.
- **Una sola columna.** En vertical no entran dos tarjetas lado a lado.
- **Poco texto para escribir**: nombre y teléfono recién en el paso 3.
- **Le habla a la paciente, de vos**: "Elegí tu protocolo", "Elegí tu
  horario", "Confirmá tu turno", "Pagar seña (simulado)", "Tocá una opción
  para continuar". Nunca "slot" ni "booking".
- Dejar siempre visible que la seña es simulada: no se pide tarjeta.

Pantallas de Cliente (de `docs/05-maquetado.md`):

| # | Pantalla | RF |
|---|---|---|
| 0 | Inicio | — |
| 1 | Elegir protocolo | RF-01, RF-04 |
| 2 | Elegir horario | RF-01, RF-04 |
| 3 | Confirmar y pagar seña | RF-01, RF-08, RF-10 |
| 4 | Buscador de precios | RF-05, RF-07 |
| 5 | Buscar mi turno | RF-12, RF-11 |

El **buscador** (pantalla 4) va como widget aparte (`BuscadorPrecios`, con su
propio `.ui`), porque Gestión lo reutiliza en su página `pagBuscador`.

## Estructura y código

```
frontend/cliente/
  main.cpp
  ventanacliente.h
  ventanacliente.cpp
  ventanacliente.ui
```

Agregar al final de `frontend/CMakeLists.txt` (los íconos y las fuentes se
comparten con Gestión, no se copian):

```cmake
# Apartado Cliente (terminal táctil).
add_executable(dermalia_cliente
    cliente/main.cpp
    cliente/ventanacliente.cpp
    cliente/ventanacliente.h
    cliente/ventanacliente.ui
    gestion/recursos.qrc)
target_link_libraries(dermalia_cliente PRIVATE Qt6::Widgets)
```

Como el `.ui` de Cliente está en otra carpeta, en su última parte va
`<include location="../gestion/recursos.qrc"/>`.

Convenciones, las mismas que en Gestión:

- Todas las pantallas dentro de un `QStackedWidget` llamado `paginas`; un
  `enum Pagina` en el `.cpp` con el mismo orden.
- `connect()` explícito, nunca `on_boton_clicked`:
  `connect(ui->btnContinuar1, &QPushButton::clicked, this, [this] { irA(PagHorario); });`
- Nombres en español con prefijo: `btn`, `edit`, `lbl`, `lista`, `pag`,
  `tarjeta`.
- Comentarios cortos en español; el RF entre paréntesis cuando corresponde.
- `main.cpp` igual al de Gestión: locale `es_AR`, fuentes, mostrar la ventana.

## Probar

```
cmake -S frontend -B <carpeta fuera del repo> -DCMAKE_PREFIX_PATH=<Qt>/6.x/gcc_64
cmake --build <carpeta> && <carpeta>/dermalia_cliente
```

O abrir `frontend/CMakeLists.txt` en Qt Creator y elegir `dermalia_cliente`
al lado de la flecha verde.

## Antes de abrir el Pull Request

- [ ] Entra completa en 768×1024, sin nada cortado ni barras de desplazamiento.
- [ ] Todo lo que se toca mide al menos 56 px de alto.
- [ ] Se recorre 1 → 2 → 3 con "Continuar" y se vuelve con "Volver".
- [ ] Desde cualquier pantalla se llega a Inicio con un toque.
- [ ] Un solo botón rosa relleno por pantalla.
- [ ] Mismos colores y tipografías que Gestión, puestas una al lado de la otra.
- [ ] Sin base, sin backend y sin datos en el código.
- [ ] No se tocó nada de `frontend/gestion/` salvo lo indicado acá.
- [ ] Tareas tildadas en `docs/reparto-4to-bimestre.md`, trabajando en la rama `bautista`.
