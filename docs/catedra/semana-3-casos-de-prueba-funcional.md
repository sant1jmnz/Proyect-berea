# Semana 3: Casos de prueba funcional

Proyecto Informático 1 - Prof. Cynthia Berea


## ¿Qué es un caso de prueba funcional?

Un caso de prueba funcional es un conjunto de instrucciones que describen cómo
probar una función específica en una aplicación de software. Describe los pasos
a seguir, los resultados esperados y las condiciones previas que deben
cumplirse antes de ejecutar la prueba.

Al escribir casos de prueba funcionales, es fundamental identificar las
condiciones de entrada, los resultados esperados y los pasos para ejecutar la
prueba. Una documentación clara ayuda a los evaluadores, desarrolladores y
demás partes interesadas a comprender el proceso y los resultados de las
pruebas.

Los casos de prueba funcionales contribuyen al proceso general de garantía de
calidad al abordar sistemáticamente diversas funcionalidades y ayudar a ofrecer
software fiable y sin errores a los usuarios finales.

## ¿Qué debe contener un caso de prueba funcional?

Un caso de prueba funcional debe definir claramente qué es lo que se está
probando:

- **los pasos para ejecutar la prueba,**
- **los resultados esperados y**
- **las condiciones previas** que deben cumplirse antes de que se pueda
  ejecutar la prueba.

Resumen de los componentes clave de un caso de prueba funcional:

1. **Identificador del caso de prueba:** un identificador único para hacer
   referencia fácilmente al caso de prueba.
2. **Descripción del caso de prueba:** una descripción clara y concisa de la
   función o característica específica que se está probando.
3. **Precondiciones:** deben cumplirse las condiciones antes de que se pueda
   ejecutar la prueba, como iniciar sesión como un usuario específico o tener
   datos concretos disponibles.
4. **Pasos de la prueba:** una lista detallada de los pasos para ejecutar la
   prueba, incluyendo entradas y acciones.
5. **Resultados esperados:** los resultados o desenlaces previstos de la
   prueba.
6. **Resultados reales:** los resultados reales obtenidos al ejecutar la
   prueba.
7. **Criterios de aprobación/reprobación:** determinación precisa de si la
   prueba se aprobó o se suspendió, basándose en la comparación de los
   resultados esperados y los reales.
8. **Supuestos:** cualquier supuesto realizado durante el diseño o la
   ejecución del caso de prueba.
9. **Notas:** información u observaciones adicionales relacionadas con el caso
   de prueba.

## ¿Cómo escribir un caso de prueba funcional?

Pasos para escribir:

1. **Identifique la función o característica:** defina claramente la función o
   característica específica del software que desea probar.
2. **Comprender los requisitos:** revise minuciosamente los requisitos del
   software para comprender el comportamiento y la funcionalidad esperados.
3. **Determinar los pasos de la prueba:** desglosar el proceso de prueba en
   pasos detallados, incluyendo entradas, acciones y validaciones.
4. **Definir los resultados esperados:** especifique los resultados o productos
   esperados para cada paso de la prueba.
5. **Establecer condiciones previas:** identifique las condiciones que deben
   cumplirse antes de ejecutar la prueba.
6. **Establecer criterios de aprobación/reprobación:** determine cómo
   evaluará si la prueba se aprobó o se reprobó comparando los resultados
   esperados con los resultados reales.
7. **Documentar el caso de prueba:** documente el caso de prueba, incluyendo su
   identificador, descripción, precondiciones, pasos de prueba, resultados
   esperados y criterios de aprobación/rechazo.

## Ejemplos de casos de prueba funcionales

Formato de tabla para una mejor comprensión:

| Característica | Descripción del caso de prueba | Precondiciones | Pasos de la prueba | Resultados esperados | Criterios de aprobación/reprobación |
|---|---|---|---|---|---|
| **Acceso** | Verificar la autenticación exitosa del usuario | La cuenta de usuario existe y la contraseña es correcta. | 1. Abre la página de inicio de sesión.<br>2. Introduce un nombre de usuario y una contraseña válidos.<br>3. Haz clic en el botón de inicio de sesión. | El usuario es redirigido a la página de inicio.<br>Se muestra un mensaje de bienvenida. | El usuario es redirigido a la página de inicio, donde se muestra un mensaje de bienvenida. |
| **Buscar** | Prueba la funcionalidad de búsqueda de productos | Se encuentra disponible una función de búsqueda y el catálogo de productos está cargado. | 1. Abre la página de búsqueda de productos.<br>2. Introduce un nombre de producto válido en la barra de búsqueda.<br>3. Haz clic en el botón de búsqueda. | Se muestra una lista de productos coincidentes.<br>Se muestran los detalles de cada producto. | Se muestra una lista de productos coincidentes con los detalles de cada producto. |
| **Añadir a la cesta** | Verificar la adición del producto al carrito de compras | El usuario ha iniciado sesión y el producto está disponible en stock. | 1. Abre la página del producto.<br>2. Selecciona la cantidad deseada.<br>3. Haz clic en el botón "Añadir al carrito". | La cantidad de productos se actualiza en el icono del carrito de compra.<br>Se muestra un mensaje de confirmación. | La cantidad de productos se actualiza en el icono del carrito de compra y se muestra un mensaje de confirmación. |

## ¿Cómo garantizar que sus casos de prueba funcionales cubran el área del producto?

Garantizar que sus casos de prueba funcionales cubran todos los aspectos de su
área de producto es esencial para ofrecer un software de primera calidad.

Algunas tácticas útiles para lograrlo:

1. **Comprender los requisitos del producto:** revise y analice minuciosamente
   los requisitos para comprender la funcionalidad esperada y el comportamiento
   del usuario.
2. **Identificar escenarios de prueba:** desglose las características y
   funcionalidades del producto en escenarios de prueba individuales,
   teniendo en cuenta todas las posibles interacciones del usuario, casos
   extremos y condiciones de error.
3. **Diseño de casos de prueba:** para cada escenario de prueba, cree casos de
   prueba funcionales detallados que describan los pasos de la prueba, los
   resultados esperados, las condiciones previas y los criterios de
   aprobación/rechazo.
4. **Utilice herramientas de prueba:** aproveche las herramientas de gestión de
   pruebas para organizar, realizar un seguimiento y ejecutar casos de prueba
   de manera eficiente.
5. **Realice pruebas exploratorias:** complemente sus casos de prueba
   estructurados con pruebas exploratorias para descubrir defectos ocultos y
   casos límite.
6. **Revisión y actualización continuas:** revise y actualice periódicamente
   los casos de prueba a medida que el producto evoluciona para mantener una
   cobertura integral.
