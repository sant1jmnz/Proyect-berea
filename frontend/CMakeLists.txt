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

find_package(Qt6 REQUIRED COMPONENTS Widgets Test)

# Buscador de precios: un widget que usan los dos apartados.
set(COMUN
    comun/buscadorprecios.cpp
    comun/buscadorprecios.h
    comun/buscadorprecios.ui
    comun/reglas.cpp       # validaciones y seña (Semana 3)
    comun/reglas.h
    gestion/recursos.qrc)   # íconos y tipografías

# Apartado Gestión (PC de recepción). Semana 3: validaciones, seña y
# cancelación sobre datos de prueba, todavía sin base.
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
target_link_libraries(dermalia_cliente_bautista PRIVATE Qt6::Widgets)

configure_file(cliente/styles.qss styles.qss COPYONLY)

# Pruebas automáticas de las reglas de negocio (Semana 3). Se corren con el
# ejecutable prueba_reglas o con `ctest` desde la carpeta de compilación.
enable_testing()
add_executable(prueba_reglas
    pruebas/prueba_reglas.cpp
    comun/reglas.cpp
    comun/reglas.h)
target_include_directories(prueba_reglas PRIVATE comun)
target_link_libraries(prueba_reglas PRIVATE Qt6::Core Qt6::Test)
add_test(NAME prueba_reglas COMMAND prueba_reglas)
