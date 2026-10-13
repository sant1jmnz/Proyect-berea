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

# Buscador de precios: un widget que usan los dos apartados.
set(COMUN
    comun/buscadorprecios.cpp
    comun/buscadorprecios.h
    comun/buscadorprecios.ui
    comun/validaciones.cpp   # validaciones compartidas (Semana 3)
    comun/validaciones.h
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
    ${COMUN})
target_include_directories(dermalia_gestion PRIVATE comun)
target_link_libraries(dermalia_gestion PRIVATE Qt6::Widgets)

# Apartado Cliente (terminal táctil vertical). Semana 1: solo interfaz.
add_executable(dermalia_cliente
    cliente/main.cpp
    cliente/ventanacliente.cpp
    cliente/ventanacliente.h
    cliente/ventanacliente.ui
    ${COMUN})
target_include_directories(dermalia_cliente PRIVATE comun)
target_link_libraries(dermalia_cliente PRIVATE Qt6::Widgets)

# Implementación de Bautista: flujo funcional de turnos, buscador y
# cancelación. Se mantiene como ejecutable separado para preservar la
# interfaz Cliente ya existente en la rama.
add_executable(dermalia_cliente_bautista
    comun/validaciones.cpp
    comun/validaciones.h
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
endif()
