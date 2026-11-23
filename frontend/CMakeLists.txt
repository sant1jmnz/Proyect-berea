cmake_minimum_required(VERSION 3.16)
project(dermalia_frontend CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# AUTOMOC genera el código de señales y slots (Q_OBJECT);
# AUTOUIC convierte cada .ui de Qt Designer en un ui_*.h;
# AUTORCC mete dentro del ejecutable los archivos del .qrc (íconos, fuentes).
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets Network Multimedia)

# Ícono del .exe en Windows (el de la ventana va en el qrc).
if(WIN32)
    enable_language(RC)
endif()

# Cliente de MySQL de la cátedra (mysql.h, PPT 006): sudo apt install libmysqlclient-dev
# (en Ubuntu también sirve libmariadb-dev). Si no está, la app compila igual y
# trabaja con datos de prueba, avisando que no hay conexión.
find_path(MYSQL_INCLUDE_DIR NAMES mysql.h PATH_SUFFIXES mysql mariadb)
find_library(MYSQL_LIBRARY NAMES mysqlclient mariadb)
if(MYSQL_INCLUDE_DIR AND MYSQL_LIBRARY)
    message(STATUS "Cliente de MySQL: ${MYSQL_LIBRARY}")
else()
    message(STATUS "Sin cliente de MySQL: la app corre solo con datos de prueba")
endif()

# Lo común a las dos aplicaciones va en una biblioteca: así cada programa y cada prueba
# la usan sin repetir la lista de archivos. DERMALIA_CON_MYSQL solo hace falta al
# compilar basedatos.cpp; la librería de MySQL se pasa a quien use la biblioteca.
add_library(dermalia_comun STATIC
    comun/modelo.h           # entidades: protocolo, profesional, paciente, turno
    comun/datosprueba.cpp    # catálogo inicial y datos de ejemplo
    comun/datosprueba.h
    comun/datosbase.cpp      # filas de los SP → estructuras del modelo
    comun/datosbase.h
    comun/almacenlocal.cpp   # archivo local de la PC cuando no hay base
    comun/almacenlocal.h
    comun/formato.cpp        # pesos, fechas y textos que muestran las pantallas
    comun/formato.h
    comun/codigoqr.cpp       # QR del token de cupón (Qt no trae generador)
    comun/codigoqr.h
    comun/reglasturno.cpp    # reglas de un turno que comparten las dos aplicaciones
    comun/reglasturno.h
    comun/buscadorprecios.cpp
    comun/buscadorprecios.h
    comun/buscadorprecios.ui
    comun/validaciones.cpp   # validaciones compartidas
    comun/validaciones.h
    comun/sena.h             # seña = porcentaje de la categoría
    comun/reembolso.h        # seña devuelta al cancelar (RF-10)
    comun/disponibilidad.h   # franjas de atención que no se pisan
    comun/basedatos.cpp      # conexión a MySQL con mysql.h (PPT 006)
    comun/basedatos.h
    comun/contingencia.cpp   # turnos guardados en el equipo sin conexión
    comun/contingencia.h
    comun/avisoconexion.cpp  # franja "sin conexión con la base"
    comun/avisoconexion.h
    comun/conexionapp.cpp    # junta conexión + contingencia + franja de aviso
    comun/conexionapp.h
    comun/repositorio.cpp    # llamadas a los stored procedures
    comun/repositorio.h
    comun/recordatorios.cpp  # recordatorio de turno y registro de avisos (RF-11)
    comun/recordatorios.h
    comun/resumentratamiento.cpp   # resumen de cada tratamiento, igual al de la web
    comun/resumentratamiento.h)
target_include_directories(dermalia_comun PUBLIC comun)
target_link_libraries(dermalia_comun PUBLIC Qt6::Widgets)
if(MYSQL_INCLUDE_DIR AND MYSQL_LIBRARY)
    target_compile_definitions(dermalia_comun PRIVATE DERMALIA_CON_MYSQL)
    target_include_directories(dermalia_comun PRIVATE ${MYSQL_INCLUDE_DIR})
    target_link_libraries(dermalia_comun PUBLIC ${MYSQL_LIBRARY})
endif()

# Íconos, tipografías y las fichas de los tratamientos: van dentro de cada programa.
set(RECURSOS gestion/recursos.qrc)

# Pantallas de Gestión (PC de recepción), en una biblioteca que usan el programa y sus pruebas.
add_library(dermalia_gestion_pantallas STATIC
    gestion/dialogologin.cpp
    gestion/dialogologin.h
    gestion/ventanagestion.cpp
    gestion/ventanagestion.h
    gestion/ventanagestion.ui
    gestion/paginaprotocolos.cpp
    gestion/paginaprotocolos.h
    gestion/paginaprofesionales.cpp
    gestion/paginaprofesionales.h
    gestion/paginapacientes.cpp
    gestion/paginapacientes.h
    gestion/paginaavisos.cpp
    gestion/paginaavisos.h
    gestion/paginareportes.cpp
    gestion/paginareportes.h
    gestion/paginacupones.cpp
    gestion/paginacupones.h
    gestion/paginatarjetas.cpp
    gestion/paginatarjetas.h
    gestion/paginausuarios.cpp
    gestion/paginausuarios.h
    gestion/paginaevaluaciones.cpp
    gestion/paginaevaluaciones.h)
target_include_directories(dermalia_gestion_pantallas PUBLIC gestion)
target_link_libraries(dermalia_gestion_pantallas PUBLIC dermalia_comun)

# Pantallas de la terminal táctil de la paciente.
add_library(dermalia_cliente_pantallas STATIC
    cliente/ventanacliente.cpp
    cliente/ventanacliente.h
    cliente/ventanacliente.ui
    cliente/dialogocuenta.cpp
    cliente/dialogocuenta.h
    cliente/dialogoasistente.cpp   # asistente de IA: le pregunta a la API del sitio (RF-14)
    cliente/dialogoasistente.h)
target_include_directories(dermalia_cliente_pantallas PUBLIC cliente)
target_link_libraries(dermalia_cliente_pantallas PUBLIC dermalia_comun Qt6::Network Qt6::Multimedia)

# Apartado Gestión: con la base usa los stored procedures; sin base, el archivo local.
add_executable(dermalia_gestion gestion/main.cpp ${RECURSOS} $<$<BOOL:${WIN32}>:gestion/gestion.rc>)
target_link_libraries(dermalia_gestion PRIVATE dermalia_gestion_pantallas)

# Apartado Cliente (terminal táctil vertical).
add_executable(dermalia_cliente cliente/main.cpp ${RECURSOS} $<$<BOOL:${WIN32}>:cliente/cliente.rc>)
target_link_libraries(dermalia_cliente PRIVATE dermalia_cliente_pantallas)

# Pruebas automáticas. Solo se arman si Qt Test está instalado.
# Se corren todas con: ctest (las que usan la base necesitan DERMALIA_DB_USER, etc.;
# sin base, esas pruebas se saltean sin fallar).
find_package(Qt6 QUIET COMPONENTS Test)
if(Qt6Test_FOUND)
    enable_testing()

    # Agrega una prueba: el .cpp de pruebas/ más la biblioteca que prueba.
    function(prueba nombre programa biblioteca)
        add_executable(${programa} pruebas/${programa}.cpp ${RECURSOS})
        target_link_libraries(${programa} PRIVATE ${biblioteca} Qt6::Test)
        add_test(NAME ${nombre} COMMAND ${programa})
        set_tests_properties(${nombre} PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    endfunction()

    prueba(validaciones   prueba_validaciones   dermalia_comun)              # nombre, DNI, teléfono, seña
    prueba(codigoqr       prueba_codigoqr       dermalia_comun)              # QR del cupón: tamaño, buscadores, imagen
    prueba(gestion        prueba_gestion        dermalia_gestion_pantallas)  # reglas y pantallas de Gestión
    prueba(base           prueba_base           dermalia_comun)              # stored procedures (con base)
    prueba(gestion_base   prueba_gestion_base   dermalia_gestion_pantallas)  # Gestión conectada a la base
    prueba(ventanacliente prueba_ventanacliente dermalia_cliente_pantallas)  # terminal sin base
    prueba(cliente_base   prueba_cliente_base   dermalia_cliente_pantallas)  # terminal conectada a la base
endif()
