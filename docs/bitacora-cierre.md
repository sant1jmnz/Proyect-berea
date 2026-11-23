# Bitácora del equipo — domingo 22 de noviembre de 2026 (cierre del proyecto)

**Integrantes:** Santiago Jiménez y Bautista Casero · Proyecto Informático I

> Cada integrante tiene
> que revisarla y corregirla con lo que realmente hizo antes de entregarla como propia.

El objetivo fue dejar todo terminado y conectado para la entrega. Primero revisamos el proyecto entero en una
máquina limpia: los diez scripts de la base cargan sin errores, los 239 casos de los stored procedures y las 44
pruebas de la estructura dan bien, Gestión y la terminal compilan y pasan sus seis programas de prueba (también
contra MySQL real) y el sitio se arma sin errores. Al revisar los documentos encontramos que el pitch prometía
cosas que no coincidían con el código: decía que al asistente de IA se le borraban los datos personales, pero esa
función de la base ya no borraba nada; y decía que la sincronización del modo contingencia estaba "prevista",
cuando ya estaba hecha.

Lo más grande fue el **asistente de IA** (RF-14), que era el único requerimiento importante sin pantalla. Lo
hicimos en la API del sitio para que la terminal y la web respondan exactamente lo mismo. Usa la API de Gemini,
pero solo con lo que le damos: el catálogo de la base, los cuidados de cada tratamiento y las reglas del
instituto. Si no hay clave o se corta internet, responde un asistente local que busca en el mismo catálogo, con
sinónimos como "botox" o "lipo", así la demo nunca se queda muda. Antes de mandar la pregunta a Gemini y antes de
guardarla, la API borra los emails y los números largos (DNI, teléfonos), y con eso lo que dice el pitch pasó a
ser cierto. En el sitio es un botón flotante; en la terminal, una tercera opción en la pantalla de inicio. Al
agregarla, la tarjeta "Cómo funciona" quedaba aplastada, así que la pusimos en la misma fila que las otras dos.

Después hicimos que el sistema sea **"plug and play"**: el script `dermalia.sh` instala lo que falta, crea la
base, configura las claves, arma el sitio y compila las apps con `./dermalia.sh instalar`, y todo arranca con
`./dermalia.sh iniciar`. La API ahora también sirve el sitio, así que un solo programa alcanza. Al probar el
script, dos pruebas de Qt se colgaban: habíamos copiado el archivo de conexión a la carpeta de compilación y las
pruebas "sin base" lo encontraban. Lo sacamos de ahí y las apps se abren desde `frontend/`.

Por último actualizamos los documentos. En una tercera búsqueda de la competencia vimos que AgendaPro, Fresha y
Booksy ya tienen asistentes de IA, así que el asistente no es por sí solo nuestro diferencial: lo es que viene
incluido, que está en la terminal del local y que solo responde con la información del instituto. También vimos
que Aiven ya no deja crear bases MySQL gratis (ahora cuesta USD 5 por mes) y lo pasamos al presupuesto junto con
los precios de Gemini y de WhatsApp. Aprendimos que hay que volver a mirar las fuentes antes de presentar, porque
los precios y los productos cambian en semanas, y que lo que se promete en el pitch tiene que poder mostrarse en
la demo.
