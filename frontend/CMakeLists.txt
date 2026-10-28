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

find_package(Qt6 REQUIRED COMPONENTS Widgets)

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

# Agrega la conexión a MySQL a un ejecutable.
function(con_mysql destino)
    if(MYSQL_INCLUDE_DIR AND MYSQL_LIBRARY)
        target_compile_definitions(${destino} PRIVATE DERMALIA_CON_MYSQL)
        target_include_directories(${destino} PRIVATE ${MYSQL_INCLUDE_DIR})
        target_link_libraries(${destino} PRIVATE ${MYSQL_LIBRARY})
    endif()
endfunction()

# Buscador de precios: un widget que usan los dos apartados.
set(COMUN
    comun/buscadorprecios.cpp
    comun/buscadorprecios.h
    comun/buscadorprecios.ui
    comun/validaciones.cpp   # validaciones compartidas (Semana 3)
    comun/validaciones.h
    comun/sena.h             # seña = porcentaje de la categoría
    comun/reembolso.h        # seña devuelta al cancelar (RF-10)
    comun/basedatos.cpp      # conexión a MySQL con mysql.h
    comun/basedatos.h
    comun/contingencia.cpp   # turnos guardados en el equipo sin conexión
    comun/contingencia.h
    comun/avisoconexion.cpp  # franja "sin conexión con la base"
    comun/avisoconexion.h
    comun/conexionapp.cpp    # junta conexión + contingencia + franja de aviso
    comun/conexionapp.h
    comun/recordatorios.cpp  # recordatorio de turno y registro de avisos (RF-11)
    comun/recordatorios.h
    gestion/recursos.qrc)   # íconos y tipografías

# Apartado Gestión (PC de recepción). Semana 3: validaciones sobre datos de
# prueba, todavía sin base.
add_executable(dermalia_gestion
    gestion/main.cpp
    gestion/datosprueba.cpp
    gestion/datosprueba.h
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
    ${COMUN})
target_include_directories(dermalia_gestion PRIVATE comun)
target_link_libraries(dermalia_gestion PRIVATE Qt6::Widgets)
con_mysql(dermalia_gestion)

# Apartado Cliente (terminal táctil vertical). Semana 1: solo interfaz.
add_executable(dermalia_cliente
    cliente/main.cpp
    cliente/ventanacliente.cpp
    cliente/ventanacliente.h
    cliente/ventanacliente.ui
    ${COMUN})
target_include_directories(dermalia_cliente PRIVATE comun)
target_link_libraries(dermalia_cliente PRIVATE Qt6::Widgets)
con_mysql(dermalia_cliente)

# Implementación de Bautista: flujo funcional de turnos, buscador y
# cancelación. Se mantiene como ejecutable separado para preservar la
# interfaz Cliente ya existente en la rama.
add_executable(dermalia_cliente_bautista
    comun/validaciones.cpp
    comun/validaciones.h
    comun/reembolso.h
    comun/basedatos.cpp
    comun/basedatos.h
    comun/contingencia.cpp
    comun/contingencia.h
    comun/avisoconexion.cpp
    comun/avisoconexion.h
    comun/conexionapp.cpp
    comun/conexionapp.h
    cliente/main_bautista.cpp
    cliente/mainwindow.cpp
    cliente/mainwindow.h
    cliente/mainwindow.ui
    cliente/pasoscargaturnowidget.cpp
    cliente/pasoscargaturnowidget.h
    cliente/pasoscargaturnowidget.ui
    cliente/buscadorwidget.cpp
    cliente/buscadorwidget.h
    cliente/buscadorwidget.ui
    cliente/buscarturnowidget.cpp
    cliente/buscarturnowidget.h
    cliente/buscarturnowidget.ui)
target_include_directories(dermalia_cliente_bautista PRIVATE comun)
target_link_libraries(dermalia_cliente_bautista PRIVATE Qt6::Widgets)
con_mysql(dermalia_cliente_bautista)

configure_file(cliente/styles.qss styles.qss COPYONLY)

# Pruebas automáticas del apartado Cliente (Semana 3, QA). Solo se arman si Qt Test está instalado.
# Se corren con: QT_QPA_PLATFORM=offscreen ./dermalia_tests
find_package(Qt6 QUIET COMPONENTS Test)
if(Qt6Test_FOUND)
    add_executable(dermalia_tests
        tests/test_cliente.cpp
        comun/validaciones.cpp
        comun/validaciones.h
        cliente/pasoscargaturnowidget.cpp
        cliente/pasoscargaturnowidget.h
        cliente/pasoscargaturnowidget.ui
        cliente/buscadorwidget.cpp
        cliente/buscadorwidget.h
        cliente/buscadorwidget.ui
        cliente/buscarturnowidget.cpp
        cliente/buscarturnowidget.h
        cliente/buscarturnowidget.ui)
    target_include_directories(dermalia_tests PRIVATE comun cliente)
    target_link_libraries(dermalia_tests PRIVATE Qt6::Widgets Qt6::Test)
    enable_testing()
    add_test(NAME cliente COMMAND dermalia_tests)

    # Pruebas de las validaciones de Gestión (nombre, DNI y teléfono).
    add_executable(prueba_validaciones
        pruebas/prueba_validaciones.cpp
        comun/validaciones.cpp
        comun/validaciones.h)
    target_include_directories(prueba_validaciones PRIVATE comun)
    target_link_libraries(prueba_validaciones PRIVATE Qt6::Core Qt6::Test)
    add_test(NAME validaciones COMMAND prueba_validaciones)
    set_tests_properties(cliente PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

    # Pruebas de Gestión de las Semanas 2 y 3: reembolso, recordatorios,
    # disponibilidad, contingencia, conexión y pantallas nuevas.
    add_executable(prueba_gestion
        pruebas/prueba_gestion.cpp
        gestion/datosprueba.cpp
        gestion/datosprueba.h
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
        ${COMUN})
    target_include_directories(prueba_gestion PRIVATE comun gestion)
    target_link_libraries(prueba_gestion PRIVATE Qt6::Widgets Qt6::Test)
    con_mysql(prueba_gestion)
    add_test(NAME gestion COMMAND prueba_gestion)
    set_tests_properties(gestion PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endif()
